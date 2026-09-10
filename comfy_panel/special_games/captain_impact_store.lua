-- An immutable Impact Dynamic observation journal is authoritative. Replaying
-- its sorted union avoids lost model updates when two BB servers finish games
-- concurrently while leaving Classic Captain games out of the deployed model.
local Learning = require('comfy_panel.special_games.captain_impact_learning')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local Server = require('utils.server')
local Event = require('utils.event')
local Token = require('utils.token')
local Public = {}
local JOURNAL = 'captain_impact_learning_v1_games'
local MODELS = 'captain_impact_learning_v1_models'
local STEP_GAMES = 8
local RETRY_TICKS = 60 * 60
local REFRESH_TICKS = 5 * 60 * 60

local function ensure()
    storage.captain_impact_learning = storage.captain_impact_learning
        or {
            journal = {},
            pending = {},
            applied = {},
            fingerprints = {},
            engine = Learning.new_state(),
            errors = {},
            dirty = false,
        }
    local s = storage.captain_impact_learning
    s.journal = s.journal or {}
    s.pending = s.pending or {}
    s.applied = s.applied or {}
    s.fingerprints = s.fingerprints or {}
    if
        not s.engine
        or s.engine.algorithm_version ~= Learning.VERSION
        or s.engine.seed_version ~= Seed.model_version
    then
        s.engine = Learning.new_state()
        s.applied = {}
        s.fingerprints = {}
        s.order = nil
        s.dirty = true
    end
    s.errors = s.errors or {}
    if s.order == nil and next(s.journal) ~= nil then
        s.dirty = true
    end
    s.dirty = s.dirty or false
    return s
end
local function failure(message)
    local s = ensure()
    s.last_error = tostring(message)
    s.errors[#s.errors + 1] = { tick = game.tick, message = tostring(message) }
    if #s.errors > 50 then
        table.remove(s.errors, 1)
    end
    log('Captain Impact learning: ' .. tostring(message))
end
local function wrapper_available()
    local time = Server.get_time_data_raw()
    return time and type(time.secs) == 'number'
end
local function canonical(o)
    local clean = {
        schema_version = o.schema_version,
        seed_version = o.seed_version,
        match_id = o.match_id,
        order = o.order,
        duration_ticks = o.duration_ticks,
        winner = o.winner,
        draft_regime = o.draft_regime,
        north = {},
        south = {},
    }
    for _, force in ipairs({ 'north', 'south' }) do
        for _, row in ipairs(o[force]) do
            clean[force][#clean[force] + 1] = { name = row.name, prior_games = row.prior_games, effort = row.effort }
        end
    end
    return clean
end

local function merge(key, observation, remote)
    local ok, reason = Learning.validate_observation(observation)
    if not ok or observation.match_id ~= key then
        failure('Rejected journal entry ' .. tostring(key) .. ': ' .. tostring(reason))
        return false
    end
    local s = ensure()
    local previous = s.journal[key]
    if previous and Learning.fingerprint(previous) ~= Learning.fingerprint(observation) then
        -- Never overwrite conflicting immutable evidence. Stop writes for this key.
        s.pending[key] = nil
        s.conflicts = s.conflicts or {}
        s.conflicts[key] = true
        failure('Conflicting immutable match ID: ' .. key)
        return false
    end
    if not previous then
        s.journal[key] = canonical(observation)
        s.dirty = true
    end
    if remote then
        s.pending[key] = nil
    end
    return true
end

function Public.queue_match(match)
    local observation, reason = Learning.observation_from_match(match)
    if not observation then
        return { accepted = false, reason = reason }
    end
    local s = ensure()
    if s.journal[observation.match_id] then
        local same = Learning.fingerprint(s.journal[observation.match_id]) == Learning.fingerprint(observation)
        if not same then
            merge(observation.match_id, observation, false)
        end
        return { accepted = same, duplicate = same, reason = same and 'already queued' or 'conflicting match' }
    end
    if merge(observation.match_id, observation, false) then
        s.pending[observation.match_id] = true
        return { accepted = true, match_id = observation.match_id }
    end
    return { accepted = false, reason = 'journal validation failed' }
end

local function order_journal(s)
    local ids = {}
    for id, observation in pairs(s.journal) do
        local valid, reason = Learning.validate_observation(observation)
        if valid and observation.match_id == id and not (s.conflicts and s.conflicts[id]) then
            ids[#ids + 1] = id
        elseif not (s.conflicts and s.conflicts[id]) then
            s.conflicts = s.conflicts or {}
            s.conflicts[id] = true
            failure('Rejected persisted journal entry ' .. tostring(id) .. ': ' .. tostring(reason))
        end
    end
    table.sort(ids, function(a, b)
        local oa, ob = s.journal[a].order, s.journal[b].order
        if oa ~= ob then
            return oa < ob
        end
        return a < b
    end)
    local prefix = #s.applied <= #ids
    for i, id in ipairs(s.applied) do
        if ids[i] ~= id or s.fingerprints[id] ~= Learning.fingerprint(s.journal[id]) then
            prefix = false
            break
        end
    end
    if not prefix then
        s.engine, s.applied, s.fingerprints = Learning.new_state(), {}, {}
    end
    s.order, s.dirty = ids, false
end

local function revision(s)
    local a, b = 17, 29
    for _, id in ipairs(s.applied) do
        local value = s.fingerprints[id]
        for i = 1, #value do
            a = (a * 131 + value:byte(i)) % 2147483647
            b = (b * 137 + value:byte(i)) % 2147483629
        end
    end
    return tostring(#s.applied) .. '-' .. string.format('%x-%x', a, b)
end

local function publish(s)
    local version = revision(s)
    if s.snapshot and s.snapshot.revision == version then
        return
    end
    s.snapshot = Learning.snapshot(s.engine, version)
    s.checkpoint_pending = true
    local ok, err = pcall(function()
        helpers.write_file('bb-captain-impact/leaderboard.json', helpers.table_to_json(s.snapshot) .. '\n', false, 0)
    end)
    if not ok then
        s.file_pending = true
        failure('Leaderboard export: ' .. tostring(err))
    else
        s.file_pending = false
    end
    local last = s.snapshot.transitions[#s.snapshot.transitions]
    if last and s.last_transition ~= last.kind .. ':' .. last.match_id then
        s.last_transition = last.kind .. ':' .. last.match_id
        log('Captain Impact automatic ' .. last.kind .. ' after ' .. tostring(last.games) .. ' eligible games')
    end
end

function Public.advance()
    local s = ensure()
    if s.dirty then
        order_journal(s)
    end
    if not s.order then
        return
    end
    local stop = math.min(#s.order, #s.applied + STEP_GAMES)
    for i = #s.applied + 1, stop do
        local id = s.order[i]
        Learning.process(s.engine, s.journal[id])
        s.applied[i] = id
        s.fingerprints[id] = Learning.fingerprint(s.journal[id])
    end
    if #s.applied == #s.order then
        publish(s)
    end
end

local receive_journal = Token.register(function(data)
    local s = ensure()
    if data.data_set ~= JOURNAL then
        return
    end
    s.requested_tick = nil
    if data.entries ~= nil and type(data.entries) ~= 'table' then
        failure('Invalid journal response')
        return
    end
    -- A complete empty response is different from an unanswered request.
    s.synced = true
    s.last_sync_tick = game.tick
    for key, observation in pairs(data.entries or {}) do
        merge(key, observation, true)
    end
    -- Preserve locally queued evidence absent from a delayed/stale remote response.
    for key in pairs(s.journal) do
        if not (data.entries and data.entries[key]) and not (s.conflicts and s.conflicts[key]) then
            s.pending[key] = true
        end
    end
end)

function Public.request_sync()
    local s = ensure()
    if not wrapper_available() then
        return false
    end
    if s.requested_tick and game.tick - s.requested_tick < RETRY_TICKS then
        return false
    end
    s.requested_tick = game.tick
    local ok, err = pcall(Server.try_get_all_data, JOURNAL, receive_journal)
    if not ok then
        s.requested_tick = nil
        failure('Journal read: ' .. tostring(err))
    end
    return ok
end

function Public.flush()
    local s = ensure()
    if s.file_pending and s.snapshot then
        local ok, err = pcall(function()
            helpers.write_file(
                'bb-captain-impact/leaderboard.json',
                helpers.table_to_json(s.snapshot) .. '\n',
                false,
                0
            )
        end)
        if ok then
            s.file_pending = false
        else
            failure('Leaderboard export: ' .. tostring(err))
        end
    end
    if not wrapper_available() then
        return
    end
    local ids = {}
    for id in pairs(s.pending) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    -- Limit wrapper traffic per tick. Readback, not set_data's nil return, acknowledges it.
    local sent = 0
    for _, id in ipairs(ids) do
        if sent >= 8 then
            break
        end
        if not (s.conflicts and s.conflicts[id]) then
            local ok, err = pcall(Server.set_data, JOURNAL, id, s.journal[id])
            if not ok then
                failure('Journal write: ' .. tostring(err))
            end
            sent = sent + 1
        end
    end
    if s.checkpoint_pending and s.snapshot and s.synced then
        local ok, err = pcall(Server.set_data, MODELS, s.snapshot.version, s.snapshot)
        if ok then
            s.checkpoint_pending = false
        else
            failure('Model checkpoint: ' .. tostring(err))
        end
    end
    if sent > 0 then
        Public.request_sync()
    end
end

function Public.prepare()
    local s = ensure()
    if not s.imported_local_history then
        s.imported_local_history = true
        local history = storage.captain_impact_history
        for _, match in ipairs(history and history.games or {}) do
            Public.queue_match(match)
        end
    end
    Public.advance()
    Public.request_sync()
end

function Public.get_snapshot()
    local s = ensure()
    return s.snapshot
end

function Public.get_status()
    local s = ensure()
    local pending, conflicts = 0, 0
    for _ in pairs(s.pending) do
        pending = pending + 1
    end
    for _ in pairs(s.conflicts or {}) do
        conflicts = conflicts + 1
    end
    return {
        version = s.snapshot and s.snapshot.version or Seed.model_version,
        games = s.snapshot and s.snapshot.games or 0,
        promotions = s.snapshot and s.snapshot.promotions or 0,
        rollbacks = s.snapshot and s.snapshot.rollbacks or 0,
        pending = pending,
        conflicts = conflicts,
        synced = s.synced or false,
        rebuilding = s.dirty or (s.order and #s.applied < #s.order) or false,
        last_error = s.last_error,
    }
end

Server.on_data_set_changed(JOURNAL, function(data)
    if data.value then
        merge(data.key, data.value, true)
    end
end)
Event.add(Server.events.on_server_started, function()
    local s = ensure()
    s.requested_tick = nil
    Public.prepare()
end)
Event.on_nth_tick(60, function()
    local s = ensure()
    local ok, err = pcall(Public.advance)
    if not ok then
        failure('Replay stopped: ' .. tostring(err))
        return
    end
    if not s.last_flush_tick or game.tick - s.last_flush_tick >= RETRY_TICKS then
        s.last_flush_tick = game.tick
        Public.flush()
    end
    if
        (s.requested_tick and game.tick - s.requested_tick >= RETRY_TICKS)
        or not s.last_sync_tick
        or game.tick - s.last_sync_tick >= REFRESH_TICKS
    then
        Public.request_sync()
    end
end)

return Public
