"""Small structural checks for the training/evaluation contract."""
import unittest

import numpy as np
import pandas as pd

from experiment import Consensus, metrics, pair_design


class ChoiceTrainingTests(unittest.TestCase):
    def setUp(self):
        self.matches=pd.DataFrame({'match_id':['a','b','c'],'date':['2024-01-01','2024-01-02','2024-01-03']})
        self.rosters=pd.DataFrame({'match_id':['a','b','c'],'player_id':['roster-only']*3})
        self.pairs=pd.DataFrame({'match_id':['a','b','c'],'date':self.matches.date,
            'preferred_player_id':['chosen','chosen','future-only'],
            'other_player_id':['other','other','chosen'],'preferred_prior_captain_games':[0,0,0],
            'other_prior_captain_games':[0,0,0],'pair_weight_base':[2.,2.,2.]})

    def test_training_boundary_and_choice_only_players(self):
        model=Consensus(ridge=.5).fit(self.matches.iloc[:2],self.rosters,self.pairs)
        self.assertIn('chosen',model.names)
        self.assertNotIn('future-only',model.names)
        self.assertGreater(model.score['chosen'],model.score['other'])
        self.assertEqual(model.score['roster-only'],0)
        changed=self.pairs.copy();changed.loc[2,'preferred_player_id']='another-future-player'
        same=Consensus(ridge=.5).fit(self.matches.iloc[:2],self.rosters,changed)
        self.assertEqual(model.score,same.score)

    def test_pair_symmetry_and_missing_prior(self):
        model=Consensus(ridge=.5).fit(self.matches.iloc[:2],self.rosters,self.pairs)
        forward=self.pairs.iloc[:1].copy();reverse=forward.copy()
        reverse['preferred_player_id']=forward.other_player_id
        reverse['other_player_id']=forward.preferred_player_id
        self.assertAlmostEqual(model.predict(forward)[0],-model.predict(reverse)[0])
        z,ex=pair_design(self.pairs.iloc[2:],model.names)
        self.assertEqual(z.shape,(1,len(model.names)))
        self.assertTrue(np.isfinite(ex).all())

    def test_ties_half_credit(self):
        self.assertEqual(metrics([0.,0.])['accuracy'],.5)
        self.assertAlmostEqual(metrics([0.])['log_loss'],np.log(2))
        self.assertEqual(metrics([0.])['brier'],.25)
        self.assertEqual(metrics([1.,-1.,0.],weights=[1.,1.,2.])['accuracy'],.5)


if __name__=='__main__':
    unittest.main()
