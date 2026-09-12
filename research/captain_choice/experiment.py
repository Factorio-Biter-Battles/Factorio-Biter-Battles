"""Chronological Captain-choice experiment; no writes to the scenario checkout.

The later historical comparison period was examined in previous experiments;
it is deliberately called a retrospective test, never an untouched holdout.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import pandas as pd
from scipy import sparse
from scipy.optimize import minimize
from scipy.special import expit


def subset(frame, ids):
    return frame[frame.match_id.isin(set(ids))].copy()


def metrics(eta, y=None, weights=None):
    eta = np.asarray(eta, float)
    y = np.ones(len(eta)) if y is None else np.asarray(y, float)
    w = np.ones(len(eta)) if weights is None else np.asarray(weights, float)
    assert len(eta) and w.sum() > 0 and np.isfinite(eta).all()
    p = expit(eta)
    # An exact tie receives half credit for a pairwise ordering, not a free win.
    correct = np.where(p == .5, .5, ((p > .5) == (y > .5)).astype(float))
    return dict(n=len(eta), weight=float(w.sum()),
                log_loss=float(w @ (np.logaddexp(0, eta) - y * eta) / w.sum()),
                brier=float(w @ ((p-y)**2) / w.sum()),
                accuracy=float(w @ correct / w.sum()))


def pair_design(frame, names, tau=80):
    index = {p: i for i, p in enumerate(names)}
    n = len(frame)
    aa = frame.preferred_player_id.map(index).fillna(-1).to_numpy(int)
    bb = frame.other_player_id.map(index).fillna(-1).to_numpy(int)
    ix = np.arange(n)
    Z = sparse.csr_matrix((np.r_[np.ones((aa >= 0).sum()), -np.ones((bb >= 0).sum())],
                          (np.r_[ix[aa >= 0], ix[bb >= 0]], np.r_[aa[aa >= 0], bb[bb >= 0]])),
                         shape=(n, len(names)))
    expdiff = -np.exp(-frame.preferred_prior_captain_games.to_numpy(float) / tau)
    expdiff += np.exp(-frame.other_prior_captain_games.to_numpy(float) / tau)
    return Z, expdiff


def match_design(matches, rosters, names, tau=80):
    pi = {p: i for i, p in enumerate(names)}
    mi = {p: i for i, p in enumerate(matches.match_id)}
    r = subset(rosters, matches.match_id)
    x = r.match_id.map(mi).to_numpy(int)
    j = r.player_id.map(pi).fillna(-1).to_numpy(int)
    sign = np.where(r.team == 'north', 1., -1.)
    X = sparse.csr_matrix((sign[j >= 0], (x[j >= 0], j[j >= 0])), shape=(len(matches), len(names)))
    count = np.bincount(x, weights=sign, minlength=len(matches))
    ex = np.bincount(x, weights=sign * -np.exp(-r.prior_captain_games.to_numpy(float)/tau), minlength=len(matches))
    return X, count, ex, (matches.winner == 'north').to_numpy(float)


class Consensus:
    """Regularized Bradley-Terry choices, with one bounded weight per draft.

    Full reconstructed choices replace same-match local choices. Unresolved
    matches contribute only observed within-team order. Unknown players have
    score zero before the shared pre-match experience adjustment.
    """
    def __init__(self, ridge=.25, half_life=0, stage_weight=False):
        self.ridge, self.half_life, self.stage_weight = ridge, half_life, stage_weight

    def fit(self, matches, rosters, pairs):
        pairs = subset(pairs, matches.match_id)
        self.names = sorted(set(subset(rosters, matches.match_id).player_id)
                            | set(pairs.preferred_player_id) | set(pairs.other_player_id))
        Z, ex = pair_design(pairs, self.names)
        w = pairs.pair_weight_base.to_numpy(float).copy()
        if self.stage_weight:
            # Within-team list length and global pool size have distinct units.
            w *= np.where(pairs.pick_fraction.to_numpy(float) <= .33, 1., .25)
        if self.half_life:
            days = (pd.to_datetime(matches.date).max() - pd.to_datetime(pairs.date)).dt.total_seconds().to_numpy()/86400
            w *= np.exp2(-days / self.half_life)
        w *= pairs.pair_weight_base.sum() / w.sum()
        n = len(self.names)
        def fg(theta):
            q, g = theta[:n], theta[n]
            eta = Z @ q + g * ex
            err = -w * expit(-eta)
            loss = w @ np.logaddexp(0, -eta) + .5*self.ridge*(q@q) + .5*(g/2)**2
            grad = np.r_[Z.T@err + self.ridge*q, ex@err + g/4]
            return float(loss), grad
        fit = minimize(fg, np.zeros(n+1), jac=True, method='L-BFGS-B',
                       bounds=[(None,None)]*n+[(0,5)], options={'maxiter':700,'ftol':1e-10,'gtol':1e-6})
        if not fit.success:
            raise RuntimeError(f'Consensus optimizer failed: {fit.message}')
        self.q, self.gamma = fit.x[:n], float(fit.x[n])
        self.score = dict(zip(self.names, self.q))
        self.fit_info = dict(objective=float(fit.fun), iterations=int(fit.nit), pairs=len(pairs),
                             drafts=int(pairs.match_id.nunique()), gamma=self.gamma)
        return self

    def predict(self, pairs):
        return (pairs.preferred_player_id.map(self.score).fillna(0).to_numpy(float)
                - pairs.other_player_id.map(self.score).fillna(0).to_numpy(float)
                + self.gamma*(-np.exp(-pairs.preferred_prior_captain_games.to_numpy(float)/80)
                              +np.exp(-pairs.other_prior_captain_games.to_numpy(float)/80)))


class Outcome:
    """Outcome player residuals shrunk toward a fitted consensus direction.

    The consensus multiplier is estimated from outcomes. A zero multiplier
    disables the transfer. Both sparse players and the global transfer shrink
    toward zero; no fixed main/support/defender bonus is imposed.
    """
    def __init__(self, residual_ridge=16, transfer_ridge=4):
        self.residual_ridge, self.transfer_ridge = residual_ridge, transfer_ridge

    def fit(self, matches, rosters, local_pairs, consensus):
        self.names = consensus.names
        X, count, ex, y = match_design(matches, rosters, self.names)
        q = consensus.q - consensus.q.mean()
        cq = X @ q
        p = subset(local_pairs, matches.match_id)
        Z, pe = pair_design(p, self.names)
        pq = Z @ q
        w = p.pair_weight_base.to_numpy(float)*.1
        n = len(q)
        def fg(theta):
            u, c, gamma, a = theta[:n], theta[n], theta[n+1], theta[n+2]
            d = u-u.mean()
            eta = X@d + c*count + gamma*ex + a*cq
            pl = 4*(Z@d + gamma*pe + a*pq)
            loss = np.sum(np.logaddexp(0,eta)-y*eta) + w@np.logaddexp(0,-pl)
            loss += .5*self.residual_ridge*(u@u) + .5*c*c + .5*(gamma/.5)**2 + .5*self.transfer_ridge*a*a
            err, perr = expit(eta)-y, -4*w*expit(-pl)
            du = np.asarray(X.T@err+Z.T@perr).ravel()
            grad = np.r_[du-du.mean()+self.residual_ridge*u, count@err+c,
                         ex@err+pe@perr+gamma/.25, cq@err+pq@perr+self.transfer_ridge*a]
            return float(loss), grad
        fit = minimize(fg,np.zeros(n+3),jac=True,method='L-BFGS-B',
                       bounds=[(None,None)]*(n+1)+[(0,1.5),(0,1)],
                       options={'maxiter':700,'ftol':1e-10,'gtol':1e-6})
        if not fit.success:
            raise RuntimeError(f'Outcome optimizer failed: {fit.message}')
        self.delta = fit.x[:n]-fit.x[:n].mean()+fit.x[n+2]*q
        self.count, self.gamma, self.transfer = map(float,fit.x[n:])
        return self

    def predict(self,matches,rosters):
        X,c,e,y=match_design(matches,rosters,self.names)
        return X@self.delta+self.count*c+self.gamma*e


def load_data(model):
    sys.path.insert(0,str(model))
    from bbimpact.real_data import load_real_starting_data
    from bbimpact.experience_model import add_prior_game_counts
    m,r,warnings=load_real_starting_data(model/'data/real/matches.csv',model/'data/real/rosters.csv')
    m=m.sort_values(['date','match_id']).reset_index(drop=True)
    r=add_prior_game_counts(m,r.reset_index(drop=True))
    read=lambda f:pd.read_csv(model/f'data/real/{f}.csv',dtype={'match_id':str,'player_id':str})
    lp,gp,ls,gs=map(read,['draft_preferences','global_draft_preferences','draft_sequences','global_draft_sequences'])
    lp['pick_fraction']=lp.preferred_team_pick_index/lp.groupby(['match_id','team']).other_team_pick_index.transform('max')
    gp['pick_fraction']=gp.chosen_global_pick_number/(gp.chosen_global_pick_number+gp.alternatives_remaining)
    pairs=pd.concat([gp,lp[~lp.match_id.isin(set(gp.match_id))]],ignore_index=True)
    keys=['match_id','preferred_player_id','other_player_id']
    assert not pairs.duplicated(keys).any(), 'duplicate choice pair'
    assert m.match_id.is_unique and not r.duplicated(['match_id','player_id']).any()
    # Source CSVs can contain choices for matches omitted by roster verification.
    pairs,lp,gp,ls,gs=[subset(x,m.match_id) for x in (pairs,lp,gp,ls,gs)]
    return SimpleNamespace(m=m,r=r,lp=lp,gp=gp,pairs=pairs,ls=ls,gs=gs,warnings=warnings)


def incumbent(train,test,data,config):
    from bbimpact.dual_draft_model import DualDraftImpactModel
    from bbimpact.experience_training import _common_kwargs,_exp_kwargs
    model=DualDraftImpactModel(lambda_player=16,experience_tau=80,local_preference_weight=.1,
             global_preference_weight=0,local_temperature=4,global_temperature=2,
             **_common_kwargs(config),**_exp_kwargs(config)).fit(train,subset(data.r,train.match_id),
                 subset(data.lp,train.match_id),data.gp.iloc[:0])
    def pred(m):
        X,c,e,y=match_design(m,data.r,model.player_ids)
        return X@model.delta_+c*model.historical_count_coefficient_+e*model.experience_penalty_logodds_
    return model,pred(train),pred(test)


def run(args):
    out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    model=Path(args.model);data=load_data(model);m=data.m
    config=json.loads((model/'config.json').read_text(encoding='utf-8-sig'))
    print('data',len(m),len(data.r),len(data.pairs),data.gp.match_id.nunique(),flush=True)
    # All tuning windows end before the final 122 games, unlike the old search.
    folds=[(260,336),(336,411),(411,487)]
    manifest={'matches':len(m),'source_sha256':{},'tuning_folds':folds,'retrospective_test':[487,len(m)],
              'test_status':'previously examined historical data; future evaluation still required',
              'pair_tie_policy':'half credit','duplicate_pair_policy':'global replaces local for resolved games'}
    for filename in ['matches','rosters','draft_preferences','global_draft_preferences','draft_sequences','global_draft_sequences']:
        manifest['source_sha256'][filename]=hashlib.sha256((model/f'data/real/{filename}.csv').read_bytes()).hexdigest()
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
    prepared=[]
    for end,stop in folds:
        train,test=m.iloc[:end],m.iloc[end:stop]
        old,old_train,old_test=incumbent(train,test,data,config)
        tg=subset(data.gp,test.match_id);tl=subset(data.lp,test.match_id)
        z,xe=pair_design(tg,old.player_ids);base_choice=2*(z@old.delta_+old.experience_penalty_logodds_*xe)
        prepared.append((train,test,old,old_test,tg,base_choice))
    rows=[];models={}
    configs=[dict(ridge=r,half_life=h,stage_weight=s) for r in [.1,.5,2] for h in [0,365] for s in [False,True]]
    for k,cfg in enumerate(configs):
        runs=[]
        for fold,(train,test,old,old_test,tg,base_choice) in enumerate(prepared):
            cons=Consensus(**cfg).fit(train,data.r,data.pairs)
            cp=cons.predict(tg)
            bm,cm=metrics(base_choice,weights=tg.pair_weight_base),metrics(cp,weights=tg.pair_weight_base)
            models[k,fold]=cons
            runs.append(dict(fold=fold,baseline=bm,candidate=cm))
        row={'id':k,**cfg,'mean_choice_ll':float(np.mean([x['candidate']['log_loss'] for x in runs])),
             'mean_choice_acc':float(np.mean([x['candidate']['accuracy'] for x in runs])),'folds':runs}
        rows.append(row);print('choice',k,cfg,row['mean_choice_ll'],row['mean_choice_acc'],flush=True)
    selected=min(rows,key=lambda x:x['mean_choice_ll']);print('SELECTED CHOICE',selected,flush=True)
    # Select outcome transfer separately using only the same development windows.
    outcome_rows=[]
    for ridge in [8,16,32]:
        for transfer_ridge in [1,16,256]:
            runs=[]
            for fold,(train,test,old,old_test,tg,base_choice) in enumerate(prepared):
                candidate=Outcome(ridge,transfer_ridge).fit(train,data.r,data.lp,models[selected['id'],fold])
                y=(test.winner=='north').to_numpy(float)
                bm,cm=metrics(old_test,y),metrics(candidate.predict(test,data.r),y)
                runs.append(dict(fold=fold,baseline=bm,candidate=cm,transfer=candidate.transfer))
            row=dict(residual_ridge=ridge,transfer_ridge=transfer_ridge,folds=runs,
                     mean_ll=float(np.mean([x['candidate']['log_loss'] for x in runs])),
                     mean_brier=float(np.mean([x['candidate']['brier'] for x in runs])))
            outcome_rows.append(row);print('outcome',ridge,transfer_ridge,row['mean_ll'],row['mean_brier'],flush=True)
    outcome_selected=min(outcome_rows,key=lambda x:x['mean_ll'])
    (out/'selection.json').write_text(json.dumps(dict(choice=selected,outcome=outcome_selected,choice_grid=rows,outcome_grid=outcome_rows),indent=2))
    train,test=m.iloc[:487],m.iloc[487:]
    cfg={k:selected[k] for k in ['ridge','half_life','stage_weight']}
    cons=Consensus(**cfg).fit(train,data.r,data.pairs)
    candidate=Outcome(outcome_selected['residual_ridge'],outcome_selected['transfer_ridge']).fit(train,data.r,data.lp,cons)
    old,old_train,old_test=incumbent(train,test,data,config)
    tg=subset(data.gp,test.match_id);z,xe=pair_design(tg,old.player_ids)
    base_choice=2*(z@old.delta_+old.experience_penalty_logodds_*xe)
    cp=cons.predict(tg);y=(test.winner=='north').to_numpy(float)
    result=dict(choice_baseline=metrics(base_choice,weights=tg.pair_weight_base),choice_candidate=metrics(cp,weights=tg.pair_weight_base),
                outcome_baseline=metrics(old_test,y),outcome_candidate=metrics(candidate.predict(test,data.r),y),transfer=candidate.transfer)
    pred=test[['match_id','date','winner']].copy();pred['baseline_logit']=old_test;pred['candidate_logit']=candidate.predict(test,data.r)
    pred.to_json(out/'outcome_predictions.json',orient='records',indent=2)
    c=tg[['match_id','preferred_player_id','other_player_id','chosen_global_pick_number','pair_weight_base']].copy();c['baseline_logit']=base_choice;c['candidate_logit']=cp
    c.to_json(out/'choice_predictions.json',orient='records',indent=2)
    (out/'results.json').write_text(json.dumps(result,indent=2));print('TEST',json.dumps(result),flush=True)
    if args.fit_full:
        cons=Consensus(**cfg).fit(m,data.r,data.pairs)
        candidate=Outcome(outcome_selected['residual_ridge'],outcome_selected['transfer_ridge']).fit(m,data.r,data.lp,cons)
        full=dict(choice=dict(config=cfg,gamma=cons.gamma,scores=cons.score),outcome=dict(
            residual_ridge=outcome_selected['residual_ridge'],transfer_ridge=outcome_selected['transfer_ridge'],
            count=candidate.count,gamma=candidate.gamma,transfer=candidate.transfer,players=dict(zip(candidate.names,candidate.delta))))
        (out/'full_fit.json').write_text(json.dumps(full,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--model',required=True);parser.add_argument('--out',required=True)
    parser.add_argument('--fit-full',action='store_true')
    run(parser.parse_args())
