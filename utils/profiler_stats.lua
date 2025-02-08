-- Collection and summarization of a series of `LuaProfiler` measures.
--
-- All measures are stored in order to calculate median value,
-- so it may introduce performance hit if misused.
-- Waring: this may cause desyncs, if observed by the game state.

local Event = require('utils.event')

local Public = {}

local pending_records = {}

function Public.new()
    local records = {}
    return {
        ---@param profiler LuaProfiler used and stopped factorio profiler. Don't reuse this profiler after supplying it as the argument to this function
        ---@return boolean
        add_record = function(profiler)
            local player = game.player or (#game.connected_players > 0 and game.connected_players[1] or nil)
            if not player then
                log(
                    'warning: as a workaround, at least 1 connected player is required for accessing factorio profiling'
                )
                return false
            end

            -- In order to prevent desyncs, factorio disallows to directly read measures from `LuaProfiler`,
            -- it expected to be directly printed without being observed by the game state. Fortunately,
            -- we can leverage (abuse) `LuaPlayer::request_translation` to convert this lua object to
            -- localized string.
            local perm_group = player.permission_group
            if perm_group and not perm_group.allows_action(defines.input_action.translate_string) then
                perm_group.set_allows_action(defines.input_action.translate_string, true)
            end
            local req_id = player.request_translation(profiler)
            if not req_id then
                log("warning: couldn't translate profiler record via player translation request")
                return false
            end
            pending_records[req_id] = records
            return true
        end,

        ---@return number # typically corresponds to the number of `add_record` calls minus pending/failed measure extractions
        records_count = function()
            return #records
        end,

        ---@return string # returns summarization of all records in format "min/avg/max (median)" or "-" if absent
        --- all values are in milliseconds
        summarize_records = function()
            if #records == 0 then
                return '-'
            end

            table.sort(records)
            local min, max = records[1], records[#records]
            local total = 0
            for _, record in pairs(records) do
                total = total + record
            end

            local median = records[math.floor(#records / 2) + 1]
            return string.format('%.3f/%.3f/%.3f (%.3f)', min, (total / #records), max, median)
        end,
    }
end

---@return number?
local function extract_profiler_measure(s)
    local result = s:match('%d+%.%d+')
    return result and tonumber(result)
end

-- we circumvent desync prevention by using the `on_string_translated` event to get the actual profiler time
-- (which will potentially be different on each client)
Event.add(defines.events.on_string_translated, function(event)
    local req_id = event.id
    local records = pending_records[req_id]
    if not records then
        return
    end
    pending_records[req_id] = nil

    local measure = extract_profiler_measure(event.result)
    if measure then
        records[#records + 1] = measure
    else
        log("warning: couldn't parse profiling record, maybe player has incompatible locale")
    end
end)

return Public
