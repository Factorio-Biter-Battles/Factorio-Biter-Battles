"""Choice calibration from pre-pick roster needs and historical choices.

Capability annotations are today's expert priors, used retrospectively under
the same stable-capability assumption as the earlier model. No whole-history
fitted rating or outcome enters the feature construction.
"""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.special import expit

from experiment import Consensus, incumbent, load_data, metrics, pair_design, subset

FEATURES=['main_need','support_need','defender_need','main_capable','support_capable',
          'defender_capable','specialist_flex','main_scarcity','support_scarcity']


def build_features(data,model):
    caps=pd.read_csv(model/'data/roles/player_role_capabilities.csv')
    roles=['Main builder','Mining/ore support','Defender']
    specialists=['Oil support','Wood chopper / burner feeder / blueprint filler','Laser outposter','BC/LDS outposter','Power Builder']
    lookup={str(r['Player']).strip().casefold():np.r_[r[roles].to_numpy(float),r[specialists].to_numpy(float).mean()]
            for _,r in caps.iterrows()}
    def profile(name):return lookup.get(str(name).strip().casefold(),np.zeros(4))
    result=np.zeros((len(data.gp),len(FEATURES)))
    # data.gp may retain original row labels after subset().
    gp=data.gp.reset_index(drop=True)
    pairs={mid:g for mid,g in gp.groupby('match_id',sort=False)}
    captains={}
    for r in data.r[data.r.is_captain.astype(bool)].itertuples():
        captains.setdefault(r.match_id,{}).setdefault(r.team,[]).append(r.player_name)
    for mid,g in data.gs.groupby('match_id',sort=False):
        if mid not in pairs:continue
        seq=g.sort_values('global_pick_number')
        current={t:sum((profile(n)[:3] for n in captains.get(mid,{}).get(t,[])),np.zeros(3)) for t in ['north','south']}
        remaining=sum((profile(n)[:3] for n in seq.player_name),np.zeros(3))
        grouped={k:v for k,v in pairs[mid].groupby('chosen_global_pick_number')}
        for row in seq.itertuples():
            p=grouped.get(row.global_pick_number)
            if p is not None:
                need=np.clip(np.array([1,2,1])-current[row.team],0,1)
                def feat(name):
                    a=profile(name)
                    return np.r_[a[:3]*need,a[:3],a[3],a[:2]*need[:2]/np.maximum(1,remaining[:2])]
                chosen=feat(row.player_name)
                alt=np.vstack([feat(n) for n in p.other_player_id])
                result[p.index]=chosen-alt
            a=profile(row.player_name)[:3]
            current[row.team]+=a;remaining-=a
    return result


def design(pairs,cons,base,features,use_roles=True):
    q=cons.predict(pairs)
    z,ex=pair_design(pairs,base.player_ids)
    b=2*(z@base.delta_+base.experience_penalty_logodds_*ex)
    # The same stage applies to both alternatives: only the present pick is used.
    pick=pairs.chosen_global_pick_number.to_numpy(float)
    stage=np.select([pick<=6,pick<=15],[0,1],default=2)
    sc=np.eye(3)[stage]
    X=np.c_[sc*q[:,None],sc*b[:,None]]
    return np.c_[X,features] if use_roles else X


class Calibrator:
    def __init__(self,ridge=1,roles=True):self.ridge,self.roles=ridge,roles
    def fit(self,X,w):
        def fg(beta):
            eta=X@beta
            loss=w@np.logaddexp(0,-eta)+.5*self.ridge*(beta@beta)
            return float(loss),X.T@(-w*expit(-eta))+self.ridge*beta
        fit=minimize(fg,np.zeros(X.shape[1]),jac=True,method='L-BFGS-B',
                     bounds=[(0,4)]*min(6,X.shape[1])+[(-3,3)]*max(0,X.shape[1]-6),options={'ftol':1e-10,'maxiter':500})
        if not fit.success:raise RuntimeError(fit.message)
        self.beta=fit.x
        return self
    def predict(self,X):return X@self.beta


def run(args):
    model=Path(args.model);out=Path(args.out);out.mkdir(exist_ok=True,parents=True)
    data=load_data(model);data.gp=data.gp.reset_index(drop=True)
    cfg=json.loads((model/'config.json').read_text(encoding='utf-8-sig'))
    chosen=json.loads((Path(args.run)/'selection.json').read_text())['choice']
    ccfg={k:chosen[k] for k in ['ridge','half_life','stage_weight']}
    print('Building capability-only features (captains included)',flush=True)
    feats=build_features(data,model);np.save(out/'features.npy',feats)
    folds=[]
    for end,stop in [(260,336),(336,411),(411,487)]:
        train,test=data.m.iloc[:end],data.m.iloc[end:stop]
        cons=Consensus(**ccfg).fit(train,data.r,data.pairs)
        base,_,_=incumbent(train,test,data,cfg)
        tp,ep=subset(data.gp,train.match_id),subset(data.gp,test.match_id)
        folds.append((design(tp,cons,base,feats[tp.index]),design(ep,cons,base,feats[ep.index]),tp,ep))
        print('prepared',end,stop,flush=True)
    rows=[]
    for roles in [False,True]:
        for ridge in [.1,1,10]:
            met=[]
            for a,b,tp,ep in folds:
                aa,bb=(a,b) if roles else (a[:,:6],b[:,:6])
                cal=Calibrator(ridge,roles).fit(aa,tp.pair_weight_base.to_numpy(float))
                met.append(metrics(cal.predict(bb),weights=ep.pair_weight_base))
            rec=dict(roles=roles,ridge=ridge,folds=met,mean_ll=float(np.mean([x['log_loss'] for x in met])),
                     mean_acc=float(np.mean([x['accuracy'] for x in met])))
            rows.append(rec);print('calibration',json.dumps(rec),flush=True)
    selected=min(rows,key=lambda x:x['mean_ll'])
    (out/'selection.json').write_text(json.dumps(dict(selected=selected,grid=rows),indent=2))
    train,test=data.m.iloc[:487],data.m.iloc[487:]
    cons=Consensus(**ccfg).fit(train,data.r,data.pairs)
    base,_,_=incumbent(train,test,data,cfg)
    tp,ep=subset(data.gp,train.match_id),subset(data.gp,test.match_id)
    a,b=design(tp,cons,base,feats[tp.index],selected['roles']),design(ep,cons,base,feats[ep.index],selected['roles'])
    cal=Calibrator(selected['ridge'],selected['roles']).fit(a,tp.pair_weight_base.to_numpy(float))
    pred=cal.predict(b);met=metrics(pred,weights=ep.pair_weight_base)
    met['legacy_ties_count_as_correct_accuracy']=float(ep.pair_weight_base.to_numpy()@(pred>=0)/ep.pair_weight_base.sum())
    (out/'results.json').write_text(json.dumps(dict(metrics=met,beta=list(cal.beta),features=FEATURES),indent=2))
    p=ep[['match_id','preferred_player_id','other_player_id','chosen_global_pick_number','pair_weight_base']].copy();p['candidate_logit']=pred
    p.to_json(out/'choice_predictions.json',orient='records',indent=2)
    print('TEST',met,flush=True)
    cons=Consensus(**ccfg).fit(data.m,data.r,data.pairs)
    base,_,_=incumbent(data.m,data.m.iloc[-1:],data,cfg)
    a=design(data.gp,cons,base,feats,selected['roles'])
    full=Calibrator(selected['ridge'],selected['roles']).fit(a,data.gp.pair_weight_base.to_numpy(float))
    (out/'full_fit.json').write_text(json.dumps(dict(choice_config=ccfg,calibration_config=selected,
        gamma=cons.gamma,scores=cons.score,beta=list(full.beta),features=FEATURES),indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for a in ['model','out','run']:p.add_argument('--'+a,required=True)
    run(p.parse_args())
