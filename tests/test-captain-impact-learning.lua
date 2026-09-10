---@diagnostic disable
-- Pure online learner and local/shared journal checks. Run with Lua 5.2.
local function deepcopy(value)
    if type(value) ~= 'table' then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepcopy(child)
    end
    return copy
end
table.deepcopy = deepcopy
local noop = function() end
local next_token = 0
local requests, writes = {}, {}
storage = {}
game = { tick = 100, ticks_played = 100 }
log = noop
helpers = {
    table_to_json = function(value)
        return 'serialized:' .. tostring(value.version or value.match_id or '')
    end,
    write_file = function(path, value, append, target)
        requests[#requests + 1] = { path = path, value = value, append = append, target = target }
    end,
}
package.loaded['utils.server'] = {
    events = { on_server_started = 'server_started' },
    get_time_data_raw = function()
        return { secs = 1789000000, tick = 1 }
    end,
    set_data = function(dataset, key, value)
        writes[#writes + 1] = { dataset = dataset, key = key, value = value }
    end,
    try_get_all_data = noop,
    on_data_set_changed = noop,
}
package.loaded['utils.event'] = { add = noop, on_nth_tick = noop }
package.loaded['utils.token'] = {
    register = function(fn)
        next_token = next_token + 1
        return next_token
    end,
}
local Learning = require('comfy_panel.special_games.captain_impact_learning')
package.loaded['comfy_panel.special_games.captain_impact_store'] = nil
local Store = require('comfy_panel.special_games.captain_impact_store')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end

local state = Learning.new_state()
for index = 1, 30 do
    local observation = {
        schema_version = 1,
        seed_version = Seed.model_version,
        match_id = 'synthetic-' .. index,
        order = index,
        duration_ticks = 18000,
        draft_regime = 'impact_dynamic',
        winner = 'north',
        north = { { name = 'synthetic_north', prior_games = index - 1, effort = 100 } },
        south = { { name = 'synthetic_south', prior_games = index - 1, effort = 100 } },
    }
    check(select(1, Learning.validate_observation(observation)), 'valid synthetic observation')
    Learning.process(state, observation)
end
local snapshot = Learning.snapshot(state, '30-test')
check(snapshot.games == 30, 'all observations processed')
check(
    snapshot.live_leaderboard
        and snapshot.ratings.synthetic_north.eligible
        and snapshot.ratings.synthetic_south.eligible,
    'prospective leaderboard activates after enough games'
)
check(snapshot.player_skill_delta.synthetic_north > 0, 'winning player learns positive delta')
check(snapshot.player_skill_delta.synthetic_south < 0, 'losing player learns negative delta')
check(snapshot.promotions > 0, 'challenger promoted only after held-out improvement')
check(
    snapshot.ratings.synthetic_north.rank < snapshot.ratings.synthetic_south.rank,
    'learned leaderboard ranks winning player first'
)
check(snapshot.ratings.synthetic_north.amwi_pp > snapshot.ratings.synthetic_south.amwi_pp, 'learned AMWI ordering')
check(
    snapshot.ratings.synthetic_north.amwi_low_pp <= snapshot.ratings.synthetic_north.amwi_high_pp,
    'uncertainty interval ordered'
)
check(snapshot.version:find('online%-outcome%-v1', 1, false) ~= nil, 'version identifies learning algorithm')

-- Actual role labels must affect the candidate/champion model, not only the
-- exported match journal.
local role_state = Learning.new_state()
for index = 1, 30 do
    local observation = {
        schema_version = 1,
        seed_version = Seed.model_version,
        match_id = 'role-synthetic-' .. index,
        order = index,
        duration_ticks = 18000,
        draft_regime = 'impact_dynamic',
        winner = 'north',
        north = {
            {
                name = 'role_north',
                prior_games = index - 1,
                effort = 100,
                primary_role = 'main_builder',
                primary_role_credit = 1,
            },
        },
        south = { { name = 'role_south', prior_games = index - 1, effort = 100 } },
    }
    Learning.process(role_state, observation)
end
local role_snapshot = Learning.snapshot(role_state, '30-role-test')
check(role_snapshot.player_role_skill_delta.role_north.main_builder > 0, 'winning primary role learns a positive residual')
check(role_snapshot.role_evidence['role_north:main_builder'] > 0, 'role evidence is counted')
check(role_snapshot.ratings.role_north.role_ratings.main_builder.games > 0, 'role rating is exported')

-- Store accepts only complete real matches, deduplicates immutable IDs and
-- writes an independent leaderboard file/checkpoint without network access.
storage = { captain_impact_learning = nil, captain_impact_history = { games = {} } }
local match = {
    match_id = 'store-synthetic-1',
    status = 'completed',
    test_mode = false,
    schema_version = 3,
    model_snapshot = { model_version = Seed.model_version },
    draft_regime = 'impact_dynamic',
    winner = 'north',
    roster_locked_tick = 100,
    finished_tick = 18100,
    server_time_snapshot = { secs = 1789000000, tick = 1 },
    starting_roster = {
        north = { { player_name = 'store_north', prior_captain_games = 0, effort_percent = 100, connected = true } },
        south = { { player_name = 'store_south', prior_captain_games = 0, effort_percent = 100, connected = true } },
    },
    final_roster = { north = { 'store_north' }, south = { 'store_south' } },
    picks = {},
}
local queued = Store.queue_match(match)
check(queued.accepted, 'complete match enters shared journal')
check(Store.queue_match(deepcopy(match)).duplicate, 'identical match is idempotent')
local classic = deepcopy(match)
classic.match_id = 'store-classic-skipped'
classic.draft_regime = 'classic_122'
check(not Store.queue_match(classic).accepted, 'classic matches do not alter Impact learning')
check(Store.get_status().pending == 1, 'queued match awaits shared submission')
Store.advance()
local status = Store.get_status()
check(status.games == 1 and status.rebuilding == false, 'store replays and publishes automatically')
check(Store.get_snapshot().ratings.store_north ~= nil, 'store snapshot contains new players')
Store.flush()
check(#requests > 0 and requests[1].path == 'bb-captain-impact/leaderboard.json', 'leaderboard exported locally')
check(
    #writes == 1 and writes[1].dataset == 'captain_impact_learning_v1_games',
    'journal submitted before model checkpoint'
)

-- The live model reads the published snapshot while retaining the seed fallback.
package.loaded['comfy_panel.special_games.captain_impact_store'] = {
    get_snapshot = function()
        return snapshot
    end,
}
storage = { captain_impact_runtime = {}, special_games_variables = { captain_mode = {} } }
local Model = require('comfy_panel.special_games.captain_impact_model')
check(Model.get_rank('synthetic_north') == snapshot.ratings.synthetic_north.rank, 'model consumes live rank')
check(Model.get_amwi_pp('synthetic_north') == snapshot.ratings.synthetic_north.amwi_pp, 'model consumes live AMWI')
check(
    Model.prior_captain_games('synthetic_north') == snapshot.completed_games_by_player.synthetic_north,
    'model consumes shared game count'
)
print('Captain Impact learning checks passed: ' .. checks)
