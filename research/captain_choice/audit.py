"""Paired comparisons and match-cluster uncertainty for historical choices."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.special import expit

from experiment import Consensus, incumbent, load_data, metrics, pair_design, subset
from context_choice import Calibrator, design


def cluster_comparison(frame, baseline, candidate, draws=3000):
    w=frame.pair_weight_base.to_numpy(float)
    a,b=frame[baseline].to_numpy(float),frame[candidate].to_numpy(float)
    correct=lambda eta:np.where(eta==0,.5,(eta>0).astype(float))
    d=pd.DataFrame({'match_id':frame.match_id,'weight':w,
        'log_loss':w*(np.logaddexp(0,-b)-np.logaddexp(0,-a)),
        'brier':w*((expit(b)-1)**2-(expit(a)-1)**2),
        'accuracy':w*(correct(b)-correct(a))}).groupby('match_id').sum()
    rng=np.random.default_rng(20260911)
    ix=rng.integers(len(d),size=(draws,len(d)))
    out={}
    for key in ['log_loss','brier','accuracy']:
        delta=d[key].to_numpy()[ix].sum(axis=1)/d.weight.to_numpy()[ix].sum(axis=1)
        out[key]={'candidate_minus_baseline':float(d[key].sum()/d.weight.sum()),
                  'bootstrap_95_percent_interval':np.quantile(delta,[.025,.975]).tolist()}
    return out


def run(args):
    model=Path(args.model);out=Path(args.out);out.mkdir(exist_ok=True,parents=True)
    data=load_data(model);cfg=json.loads((model/'config.json').read_text(encoding='utf-8-sig'))
    context=Path(args.context);full=json.loads((context/'full_fit.json').read_text())
    comparisons=[]
    for end,stop in [(260,336),(336,411),(411,487),(487,609)]:
        train,test=data.m.iloc[:end],data.m.iloc[end:stop]
        base,_,_=incumbent(train,test,data,cfg)
        cons=Consensus(**full['choice_config']).fit(train,data.r,data.pairs)
        tp,ep=subset(data.gp,train.match_id),subset(data.gp,test.match_id)
        aa=design(tp,cons,base,np.zeros((len(tp),9)),False)
        bb=design(ep,cons,base,np.zeros((len(ep),9)),False)
        # Same simple stage calibration available to incumbent: a fair control.
        controls=[]
        for ridge in [.1,1,10]:
            cc=Calibrator(ridge,False).fit(aa[:,3:],tp.pair_weight_base.to_numpy(float))
            pred=cc.predict(bb[:,3:])
            controls.append({'ridge':ridge,'metrics':metrics(pred,weights=ep.pair_weight_base)})
        comparisons.append({'fold':[end,stop],'controls':controls})
        if end==487:
            new=Calibrator(full['calibration_config']['ridge'],False).fit(aa,tp.pair_weight_base.to_numpy(float))
            p=ep[['match_id','preferred_player_id','other_player_id','chosen_global_pick_number','pair_weight_base']].copy()
            p['new']=new.predict(bb);p['original']=bb[:,3:].sum(axis=1)
            final_a,final_b,final_w=aa,bb,tp.pair_weight_base.to_numpy(float)
    # Select control ridge using only pretest folds.
    ri=min(range(3),key=lambda i:np.mean([f['controls'][i]['metrics']['log_loss'] for f in comparisons[:3]]))
    ridge=comparisons[0]['controls'][ri]['ridge']
    p['calibrated_original']=Calibrator(ridge,False).fit(final_a[:,3:],final_w).predict(final_b[:,3:])
    prior=pd.read_csv(args.previous,dtype={'match_id':str})
    keys=['match_id','preferred_player_id','other_player_id','chosen_global_pick_number']
    p=p.merge(prior[keys+['role_calibrated_logit']],on=keys,validate='one_to_one')
    assert len(p)==56945 and p.match_id.nunique()==117
    score={k:metrics(p[k],weights=p.pair_weight_base) for k in ['original','calibrated_original','role_calibrated_logit','new']}
    ci={k:cluster_comparison(p,k,'new') for k in ['original','calibrated_original','role_calibrated_logit']}
    result={'metrics':score,'paired_match_bootstrap':ci,'control_grid':comparisons,
            'selected_control_ridge':ridge,'uncertainty_scope':'117 match clusters, fixed fitted predictions; not training/selection uncertainty'}
    (out/'audit.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({'metrics':score,'comparison':ci},indent=2),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['model','context','previous','out']:p.add_argument('--'+name,required=True)
    run(p.parse_args())
