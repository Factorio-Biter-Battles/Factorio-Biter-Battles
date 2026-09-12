# Historical Captain-choice model v2

This patch improves prediction of historical captains' choices and exposes observed pick positions in Impact tooltips. It adds a separate, frozen preference seed. It does **not** replace the win-strength seed, AMWI leaderboard, automatic outcome/role learner, or Impact pick-allocation formula.

## Evidence and model

The inputs contain 609 verified normal Captain Games from 2023-12-30 through 2026-09-05, 21,697 team-list selections and 2,218 distinct picked players. Only 407 drafts have high-confidence reconstructed global order. Those drafts supply chosen-versus-remaining-player comparisons across both teams. Other drafts supply only observed within-team order. Global evidence replaces local evidence in the same draft, avoiding duplication. Each draft contributes a total comparison weight of two before recency adjustment, so a large lobby does not dominate merely by generating more pairs.

The regularized Bradley–Terry model estimates a player preference score with a shared experience adjustment. Sparse players shrink toward a neutral persistent preference. A 365-day half-life gives recent historical choices more weight. Calibration blends that score with an auxiliary outcome-model score, with separate weights for picks 1–6, 7–15 and 16 onward. Both score components are frozen in the new seed. Choice evidence can estimate preference for someone without a verified starting-roster appearance; it does not manufacture outcome evidence for that player. The export contains 2,232 player rows: 2,218 selected players plus 14 who have only roster evidence.

The selected predictor uses no expert role features. Capability/need features were tested and failed to improve average validation loss. Played-role learning in the existing outcome model remains available.

## Comparison results

All candidate parameter selection in the reported run used these chronological windows (zero-based, end exclusive): train `[0,260)`, evaluate `[260,336)`; train `[0,336)`, evaluate `[336,411)`; train `[0,411)`, evaluate `[411,487)`. The final retrospective comparison uses training `[0,487)` and later matches `[487,609)`, including 117 reconstructed drafts and 56,945 weighted pairs.

| Predictor on the same later drafts | Pair accuracy | Log loss | Brier |
| --- | ---: | ---: | ---: |
| Original skill-only choice predictor | 66.89% | 0.62242 | 0.21612 |
| Original predictor with newly fitted stage calibration | 66.89% | 0.58556 | 0.20321 |
| Previous role-calibrated comparison | 67.55% | 0.58891 | 0.20388 |
| New calibrated choice model | **69.11%** | **0.55559** | **0.19073** |

Accuracy gives exact ties half credit. The previously quoted **70.3%** gave ties full credit; its comparable accuracy is **67.55%**. With that older convention the new score would be 69.82%, illustrating why treating every tie as a successful prediction is misleading.

Against the previous role-calibrated comparison, the improvement in accuracy is 1.56 percentage points. A paired bootstrap resampling 117 whole matches, not individual correlated pairs, gives a 95% interval of +0.52 to +2.60 percentage points. The log-loss change is -0.03332, with an interval of -0.04489 to -0.01995. These intervals condition on the fitted predictions and do not include model selection or training uncertainty.

The new calibrated choice model's mean loss across the three earlier validation periods is 0.58993. A tested transfer of preference scores into win strength made mean outcome loss worse: **0.66290 → 0.66460**. That transfer is rejected even though it improved the already-examined later slice. There is no new claim of improved win prediction in this patch.

These are **retrospective** comparisons. The last historical period was examined in earlier development, and the previous role-calibration parameter search overlapped it. It is not a fresh, untouched test. Historical captain choices can also reflect roles, familiarity, groups, late arrivals, and reconstruction error. Do not advertise 69.11% as a guaranteed accuracy on future Impact games. The new dynamic draft changes incentives and needs its own prospective evaluation.

## What changes in game

In an Impact draft, hovering over a player's name, Rank or AMWI shows average and median team pick, the number of observed drafts, average position adjusted for team-list size, average global pick where order is reconstructed, and the last historical year's average. Normalized position is `(pick - 1) / (list size - 1)`: 0% means first, 100% means last. A single-player list has no normalized position. Captains are excluded from pick-position counts. A selection is counted even when the selected player did not appear in the verified starting roster. Small samples are explicitly marked.

These are dated historical summaries, not automatically updated lifetime statistics. The preference score accounts for available alternatives and therefore need not order players exactly by their raw average pick number.

For initial Impact drafts, the recorder saves the model version and each candidate's preference score **before assignment**, then records chosen-versus-alternative probabilities for manual captain choices. Scores are evaluated in shadow mode: they do not determine draft turns, effort discounts, or AMWI. Later joiner drafts are excluded. Forced/community assignments do not produce captain-choice comparison results. Existing player, role, winner, roster and persistence recording continues as before. Classic play and its UI remain unchanged.

The trust dashboard labels historical comparisons as retrospective and distinguishes the earlier tie convention. The new seed has its own version; the existing outcome seed version is unchanged, preserving its learning journal.

## Reproduce

Requires Python 3.12 or compatible, with NumPy, pandas and SciPy. Exact versions used are in `requirements.txt`. A separate reproduction archive accompanies this patch and contains the frozen `bbimpact` source, configuration, six input CSVs, capability annotations, earlier comparison predictions and fitted outputs. Large datasets are not added to the scenario PR.

From the scenario root, set `$model` to the archived `model` directory (or the original `BB_Captain_Impact_Model_v0_1` folder) and `$previous` to the archived `previous-role-choice-predictions.csv` file:

```powershell
python research/captain_choice/test_training.py
python research/captain_choice/experiment.py --model $model --out work/choice/run --fit-full
python research/captain_choice/context_choice.py --model $model --run work/choice/run --out work/choice/context
python research/captain_choice/audit.py --model $model --context work/choice/context --previous $previous --out work/choice/audit
python research/captain_choice/export.py --model $model --context work/choice/context --run work/choice/run --scenario . --out work/choice/export
lua tests/test-captain-choice.lua
lua tests/test-captain-impact.lua
lua tests/test-captain-impact-learning.lua
```

The final export refits the chosen specification on all 609 matches; evaluation uses separately fitted historical prefixes. Source-data hashes and parameter-selection tables are committed under `validation/`. The export also creates a complete pick-evidence CSV and Python reference predictions used by the Lua compatibility test. Formatting generated Lua with the repository's StyLua configuration does not change its numeric contents.

For future monitoring, evaluate `historical_choice_comparisons` by completed draft/match, with equal decision weight and alternatives sharing each decision's weight. Keep Impact and Classic regimes, initial and later drafts, and human and forced choices separate. Do not use the model's own displayed suggestions as independent evidence of improved playing strength. Promotion into win ratings would require separate prospective outcome evidence.
