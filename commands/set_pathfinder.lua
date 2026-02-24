local Utils = require('utils.utils')
local Color = require('utils.color_presets')

local Public = {}

-- Preset: original BB settings
local PRESET_BB_DEFAULT = {
    fwd2bwd_ratio = 2,
    goal_pressure_ratio = 3,
    general_entity_collision_penalty = 5,
    general_entity_subsequent_collision_penalty = 1,
    short_cache_size = 30,
    long_cache_size = 50,
    short_cache_min_cacheable_distance = 10,
    long_cache_min_cacheable_distance = 60,
    short_cache_min_algo_steps_to_cache = 50,
    max_clients_to_accept_any_new_request = 4,
    max_clients_to_accept_short_new_request = 150,
    start_to_goal_cost_multiplier_to_terminate_path_find = 10000,
    unit_group = {},
}

-- Preset: current BB settings (pathfinder fix attempt)
local PRESET_BB_NEW = {
    fwd2bwd_ratio = 2,
    goal_pressure_ratio = 3,
    general_entity_collision_penalty = 5,
    general_entity_subsequent_collision_penalty = 1,
    short_cache_size = 30,
    long_cache_size = 50,
    short_cache_min_cacheable_distance = 10,
    long_cache_min_cacheable_distance = 60,
    short_cache_min_algo_steps_to_cache = 50,
    max_clients_to_accept_any_new_request = 10, -- Changed.
    max_clients_to_accept_short_new_request = 150,
    start_to_goal_cost_multiplier_to_terminate_path_find = 10000,
    -- Unit group cohesion tuning to reduce disbandment from pathfinding issues.
    -- In BB, groups travel long distances through congested terrain. These
    -- settings keep groups together better than the vanilla defaults.
    unit_group = {
        max_member_speedup_when_behind = 1.6, -- default 1.4; faster catch-up
        max_group_slowdown_factor = 0.2, -- default 0.3; group slows more for stragglers
        max_group_member_fallback_factor = 5, -- default 3; more slack before triggering slowdown
    },
}

-- Preset: vanilla Factorio engine defaults
local PRESET_DEFAULT = {
    fwd2bwd_ratio = 5,
    goal_pressure_ratio = 2,
    general_entity_collision_penalty = 10,
    general_entity_subsequent_collision_penalty = 3,
    short_cache_size = 5,
    long_cache_size = 25,
    short_cache_min_cacheable_distance = 10,
    long_cache_min_cacheable_distance = 30,
    short_cache_min_algo_steps_to_cache = 50,
    max_clients_to_accept_any_new_request = 10,
    max_clients_to_accept_short_new_request = 100,
    start_to_goal_cost_multiplier_to_terminate_path_find = 2000,
    unit_group = {},
}

local PRESETS = {
    ['bb-default'] = PRESET_BB_DEFAULT,
    ['bb-new'] = PRESET_BB_NEW,
    ['default'] = PRESET_DEFAULT,
}

local PRESET_NAMES = {}
for k, _ in pairs(PRESETS) do
    PRESET_NAMES[#PRESET_NAMES + 1] = k
end
table.sort(PRESET_NAMES)
local PRESET_NAMES_STR = table.concat(PRESET_NAMES, ' | ')

---Returns a copy of the named preset table.
---@param name string
---@return table?
function Public.get_preset(name)
    local preset = PRESETS[name]
    if not preset then
        return nil
    end
    return table.deepcopy(preset)
end

---Applies storage.bb_pathfinder to game.map_settings.path_finder and
---game.map_settings.unit_group.
function Public.apply()
    local settings = storage.bb_pathfinder
    if not settings then
        return
    end
    for k, v in pairs(settings) do
        if k == 'unit_group' then
            for uk, uv in pairs(v) do
                game.map_settings.unit_group[uk] = uv
            end
        else
            game.map_settings.path_finder[k] = v
        end
    end
end

---@param player_index number?
---@return boolean, LuaPlayer?
local function check_player_permission(player_index)
    if not player_index then
        return false
    end
    local player = game.get_player(player_index)
    if not player or not player.valid then
        return false
    end
    if not is_admin(player) then
        player.print('This command can only be used by admins', { color = Color.warning })
        return false
    end
    return true, player
end

local function set_pathfinder(cmd)
    local allowed, player = check_player_permission(cmd.player_index)
    if not allowed then
        return
    end

    local preset_name = cmd.parameter
    if not preset_name or preset_name == '' then
        player.print('Usage: /set-pathfinder <' .. PRESET_NAMES_STR .. '>', { color = Color.warning })
        return
    end

    local preset = Public.get_preset(preset_name)
    if not preset then
        player.print('Unknown preset: ' .. preset_name, { color = Color.warning })
        return
    end

    storage.bb_pathfinder = preset
    Public.apply()
    local msg = '[Pathfinder] ' .. player.name .. ' changed preset to: ' .. preset_name
    for _, p in pairs(game.connected_players) do
        if p.admin then
            p.print(msg, { color = Color.admin })
        end
    end
    log(msg)
end

commands.add_command('set-pathfinder', 'Switch pathfinder preset (bb-default | bb-new | default)', function(cmd)
    Utils.safe_wrap_cmd(cmd, set_pathfinder, cmd)
end)

return Public
