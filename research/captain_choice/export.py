"""Export the selected choice model and auditable historical pick summaries."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from experiment import Consensus, incumbent, load_data
from context_choice import design


def lua(value):
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,bool):return 'true' if value else 'false'
    if value is None:return 'nil'
    if isinstance(value,dict):return '{ '+', '.join('['+lua(str(k))+'] = '+lua(v) for k,v in value.items())+' }'
    if isinstance(value,(list,tuple)):return '{ '+', '.join(lua(v) for v in value)+' }'
    assert np.isfinite(value)
    return format(value,'.15g')


def compact_rows(players):
    """Return a compact, column-oriented Lua representation of player rows.

    The scenario still reconstructs the same ``Seed.players`` map, but the
    generated file stores each field name once instead of repeating fourteen
    keys for every player.
    """
    columns = ['choice_logodds','base_skill_logodds','prior_games','pick_games',
               'global_pick_games','recent_pick_games','avg_team_pick',
               'median_team_pick','avg_team_pick_fraction','last_pick_date',
               'avg_global_pick','avg_global_pick_fraction','recent_avg_team_pick',
               'recent_avg_team_pick_fraction']
    names = sorted(players)
    lines = ['-- stylua: ignore', 'local choice_names = ' + lua(names),
             '-- stylua: ignore', 'local choice_rows = {']
    lines += ['{' + ','.join(lua(row.get(key)) for key in columns) + '},'
              for name in names for row in [players[name]]]
    lines += ['}', '-- stylua: ignore', 'local choice_columns = ' + lua(columns),
              'Seed.players = {}', 'for i = 1, #choice_names do',
              '    local values = choice_rows[i]', '    local row = {}',
              '    for j, key in ipairs(choice_columns) do',
              '        if values[j] ~= nil then row[key] = values[j] end',
              '    end', '    Seed.players[choice_names[i]] = row', 'end']
    return lines


def run(args):
    model=Path(args.model);out=Path(args.out);out.mkdir(exist_ok=True,parents=True)
    context=Path(args.context);data=load_data(model)
    fit=json.loads((context/'full_fit.json').read_text())
    assert not fit['calibration_config']['roles']
    cfg=json.loads((model/'config.json').read_text(encoding='utf-8-sig'))
    base,_,_=incumbent(data.m,data.m.iloc[-1:],data,cfg)
    base_score=dict(zip(base.player_ids,base.delta_))
    counts=data.r.groupby('player_id').match_id.nunique().to_dict()
    ls=data.ls.copy();gs=data.gs.copy()
    ls['team_pool_size']=ls.groupby(['match_id','team']).team_pick_index.transform('max')
    ls['team_pick_fraction']=(ls.team_pick_index-1)/(ls.team_pool_size-1).replace(0,np.nan)
    gs['global_pool_size']=gs.groupby('match_id').global_pick_number.transform('max')
    gs['global_pick_fraction']=(gs.global_pick_number-1)/(gs.global_pool_size-1).replace(0,np.nan)
    assert not ls.duplicated(['match_id','player_id']).any()
    assert not gs.duplicated(['match_id','player_id']).any()
    assert ls.team_pick_fraction.dropna().between(0,1).all()
    assert gs.global_pick_fraction.dropna().between(0,1).all()
    local=ls.groupby('player_id').agg(pick_games=('match_id','nunique'),avg_team_pick=('team_pick_index','mean'),
        median_team_pick=('team_pick_index','median'),avg_team_pick_fraction=('team_pick_fraction','mean'),
        last_pick_date=('date','max')).to_dict('index')
    glob=gs.groupby('player_id').agg(global_pick_games=('match_id','nunique'),avg_global_pick=('global_pick_number','mean'),
        avg_global_pick_fraction=('global_pick_fraction','mean')).to_dict('index')
    cutoff=pd.to_datetime(data.m.date).max();recent=ls[pd.to_datetime(ls.date)>=cutoff-pd.Timedelta(days=365)]
    rec=recent.groupby('player_id').agg(recent_pick_games=('match_id','nunique'),
        recent_avg_team_pick=('team_pick_index','mean'),recent_avg_team_pick_fraction=('team_pick_fraction','mean')).to_dict('index')
    players={}
    for name,q in sorted(fit['scores'].items()):
        row={'choice_logodds':q,'base_skill_logodds':base_score.get(name,0.),'prior_games':counts.get(name,0),
             'pick_games':0,'global_pick_games':0,'recent_pick_games':0}
        row.update(local.get(name,{}));row.update(glob.get(name,{}));row.update(rec.get(name,{}))
        players[name]={k:(int(v) if k.endswith('games') else v) for k,v in row.items() if not pd.isna(v)}
    manifest=json.loads((Path(args.run)/'manifest.json').read_text())
    met=json.loads((context/'results.json').read_text())['metrics']
    seed={'model_version':'captain-choice-v2-2026-09-11','trained_regime':'historical_classic_122',
          'impact_policy':'shadow_only','historical_matches':len(data.m),'global_drafts':int(gs.match_id.nunique()),
          'historical_picks':len(ls),'choice_players':int(ls.player_id.nunique()),
          'first_match_date':str(data.m.date.min()),'last_match_date':str(data.m.date.max()),
          'experience_tau':80,'experience_coefficient':fit['gamma'],
          'base_experience_coefficient':float(base.experience_penalty_logodds_),
          'stage_choice_weights':fit['beta'][:3],'stage_base_weights':fit['beta'][3:6],
          'recency_half_life_days':fit['choice_config']['half_life'],
          'validation_accuracy':met['accuracy'],'validation_log_loss':met['log_loss'],'validation_brier':met['brier'],
          'validation_matches':117,'validation_pairs':met['n'],
          'validation_status':'retrospective; final period previously examined; ties receive half credit',
          'source_sha256':manifest['source_sha256']}
    lines=['-- Generated by research/captain_choice/export.py. Do not edit player rows by hand.',
           '-- Frozen historical captain preferences and observed pick positions; not win strength.',
           '-- Global data replace local pairs for resolved drafts. Player identities remain exact.',
           'local Seed = {}']
    for k,v in seed.items():
        if k=='source_sha256':lines.append('-- stylua: ignore')
        lines.append('Seed.'+k+' = '+lua(v))
    lines += compact_rows(players)
    lines += ['return Seed','']
    scenario=Path(args.scenario)
    (scenario/'comfy_panel/special_games/captain_impact_choice_seed.lua').write_text('\n'.join(lines),encoding='utf-8')
    (out/'historical-choice-seed.json').write_text(json.dumps(dict(metadata=seed,players=players),ensure_ascii=False,indent=2),encoding='utf-8')
    rows=[]
    for name,row in players.items():
        h=-np.exp(-row['prior_games']/80)
        row=dict(player=name,**row)
        row['early_preference_score']=fit['beta'][0]*(row['choice_logodds']+fit['gamma']*h)+fit['beta'][3]*2*(row['base_skill_logodds']+base.experience_penalty_logodds_*h)
        rows.append(row)
    table=pd.DataFrame(rows).sort_values(['early_preference_score','player'],ascending=[False,True])
    table.to_csv(out/'captain-historical-pick-evidence.csv',index=False,float_format='%.6f')
    # Reference predictions from the Python trainer, for a cross-language test.
    cons=Consensus(**fit['choice_config']);cons.score=fit['scores'];cons.gamma=fit['gamma']
    sample=pd.concat([data.gp[data.gp.chosen_global_pick_number==pick].iloc[[0,-1]] for pick in [1,6,7,15,16,30]])
    expected=design(sample,cons,base,np.zeros((len(sample),9)),False)@np.asarray(fit['beta'])
    golden=[]
    for (_,r),eta in zip(sample.iterrows(),expected):
        golden.append(dict(a=r.preferred_player_id,b=r.other_player_id,pick=int(r.chosen_global_pick_number),
                           a_games=int(r.preferred_prior_captain_games),b_games=int(r.other_prior_captain_games),
                           expected_logit=float(eta)))
    fixtures=scenario/'tests/fixtures';fixtures.mkdir(exist_ok=True,parents=True)
    (fixtures/'captain-choice-golden.lua').write_text('-- Python reference predictions from the full-history fit.\n-- stylua: ignore\nreturn '+lua(golden)+'\n',encoding='utf-8')
    print(json.dumps({'players_in_export':len(players),'picked_players':len(local),'picked_players_without_start':len(set(local)-set(counts)),
                      'global_drafts':seed['global_drafts'],'first':seed['first_match_date'],'last':seed['last_match_date'],
                      'gamma':fit['gamma'],'base_gamma':float(base.experience_penalty_logodds_),
                      'example':players['Jimmy50']},indent=2),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['model','context','run','scenario','out']:p.add_argument('--'+name,required=True)
    run(p.parse_args())
