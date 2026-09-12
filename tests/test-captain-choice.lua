-- Run with Lua 5.2 from the scenario root.
local Choice = require('comfy_panel.special_games.captain_impact_choice')
local golden = require('tests.fixtures.captain-choice-golden')
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end

for _, row in ipairs(golden) do
    local a = Choice.score(row.a, row.pick, row.a_games)
    local b = Choice.score(row.b, row.pick, row.b_games)
    check(math.abs(a - b - row.expected_logit) < 1e-11, 'Lua agrees with fitted Python predictions')
    local p = Choice.pair_probability(a, b)
    check(math.abs(p + Choice.pair_probability(b, a) - 1) < 1e-12, 'opposite comparison complements')
    check(p >= 0 and p <= 1, 'valid pair probability')
end

check(Choice.pair_probability(0, 0) == 0.5, 'ties are neutral')
check(Choice.pair_probability(1000, -1000) == 1, 'stable positive extreme')
check(Choice.pair_probability(-1000, 1000) == 0, 'stable negative extreme')
check(Choice.pair_probability(0 / 0, 1) == nil, 'reject NaN')
check(Choice.pair_probability(math.huge, 1) == nil, 'reject infinity')
check(Choice.score('Jimmy50', 0) == nil and Choice.score('Jimmy50', 1.5) == nil, 'reject invalid pick indices')
check(Choice.score('Jimmy50', 1, -1) == nil, 'reject invalid experience')
check(Choice.score('unknown-a', 1) == Choice.score('unknown-b', 1), 'unseen players share a neutral prior')
check(Choice.get_history('unknown-a') == nil, 'no fabricated history for unknown players')
local history = Choice.get_history('Jimmy50')
check(
    history.pick_games == 263 and history.global_pick_games == 205,
    'source counts distinguish local and global evidence'
)
check(math.abs(history.avg_team_pick - 3.3422053231939164) < 1e-12, 'average is an observed position')
history.pick_games = 0
check(Choice.get_history('Jimmy50').pick_games == 263, 'returned history cannot mutate the seed')
local version = Choice.get_metadata().model_version
local metadata = Choice.get_metadata()
metadata.model_version = 'mutated'
check(Choice.get_metadata().model_version == version, 'returned metadata cannot mutate the seed')
check(Choice.history_tooltip('Jimmy50'):find('0%% first', 1, false), 'normalization direction explained')
check(Choice.history_tooltip('-San4ik-'):find('Limited evidence', 1, true), 'sparse history is marked')

-- Live outcome ratings and effort cannot alter the frozen choice model.
local before = Choice.score('Jimmy50', 1)
storage = {
    captain_impact_runtime = { player_skill_delta = { Jimmy50 = 500 } },
    special_games_variables = { captain_mode = { player_effort = { Jimmy50 = 0 } } },
}
check(Choice.score('Jimmy50', 1) == before, 'choice scores are independent of effort and outcome updates')

print('Captain choice checks passed: ' .. checks)
