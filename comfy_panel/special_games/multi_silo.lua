local Event = require('utils.event')
local AiTargets = require('maps.biter_battles_v2.ai_targets')
local Color = require('utils.color_presets')
local Gui = require('utils.gui')

local Public = {
    name = {
        type = 'label',
        caption = 'Multi silo',
        tooltip = "Create Dr.Claw's multi silo special",
    },
    config = {},
    button = {
        name = 'apply',
        type = 'button',
        caption = 'Apply',
    },
}

---@param player LuaPlayer
---Inserts silo into player inventory and inform them about it
local function insert_silo(player)
    local stack = { name = 'rocket-silo', count = 1 }
    if player.can_insert(stack) then
        player.insert(stack)
    elseif player.connected then
        player.physical_surface.spill_item_stack({
            position = player.physical_position,
            stack = stack,
            enable_looted = false,
            force = nil,
            allow_belts = false,
        })
    else
        log('WARN: Player ' .. player.name .. ' not connected and silo cannot fit in their inventory')
    end

    if player.connected then
        player.print({ 'info.silo_insert' }, { r = 1, g = 1, b = 0 })
        player.create_local_flying_text({
            text = { 'info.silo_insert' },
            position = player.physical_position,
        })
    end
end

function Public.generate(_, player)
    if storage.active_special_games.multi_silo then
        player.print('Multi silo is enabled already!')
        return
    end

    if storage.server_restart_timer then
        player.print('Multi silo cannot be enabled during map reset!')
        return
    end

    storage.active_special_games.multi_silo = {
        ---How far on X axis do we allow silo to be placed.
        max_distance_x = 2500,
        ---How many tiles around placed silo must be void of water.
        safe_placement_radius = 20,
        ---@type { [string]: { x: number, y: number } }
        ---Holds last position of a player transition into death or joining spectator
        last_transition = {},
    }

    local s = game.surfaces[storage.bb_surface_name]
    local msg = 'Multi silo enabled by ' .. player.name
    s.print(msg, { color = Color.yellow })
    log(msg)

    -- In case game has started already.
    -- Important to go through all players, not just connected. So that if someone
    -- joins back after game was enabled, they still can get their silo.
    for _, p in pairs(game.players) do
        if p.connected then
            Public.update_feature_flag(p)
        end

        if storage.chosen_team[p.name] then
            insert_silo(p)
        end
    end
end

function Public.is_disabled()
    -- storage.active_special_games.multi_silo can only be set by clicking a button in admin panel.
    -- storage.server_restart_timer indicates if map is scheduled for a reset.
    return (storage.active_special_games.multi_silo == nil or storage.server_restart_timer)
end

---Adds silo icon into GUI to indicate that special is enabled.
function Public.update_feature_flag(player)
    if Public.is_disabled() then
        return
    end

    local t = Gui.get_top_element(player, 'bb_feature_flags')
    local button = t.add({
        type = 'sprite',
        name = 'multisilo_flag',
        resize_to_sprite = false,
        sprite = 'technology/rocket-silo',
    })
    button.style.height = 15
    button.style.width = 15
    button.tooltip = 'Multisilo enabled!'
end

---@param player LuaPlayer
---Initialize player inventory when switching force. Note that this is not bound
---to proper event and has to be called manually from gui::join_team.
function Public.on_player_changed_force(player)
    if Public.is_disabled() then
        return
    end

    insert_silo(player)
end

---@param entity LuaEntity
---Checks if placed silo meets all requirements. If not a warning is returned.
---@return string|nil
local function silo_position_check(entity)
    local surface = entity.surface
    local position = entity.position
    local r = storage.active_special_games.multi_silo.safe_placement_radius
    local tiles = surface.count_tiles_filtered({
        area = {
            top_left = {
                math.floor(position.x - r),
                math.floor(position.y - r),
            },
            bottom_right = {
                math.floor(position.x + r),
                math.floor(position.y + r),
            },
        },
        name = {
            'water',
            'deepwater',
            'landfill',
        },
    })

    ---@type string|nil
    local warning = nil
    local max_x = storage.active_special_games.multi_silo.max_distance_x
    local curr_x = math.abs(position.x)
    if tiles > 0 then
        warning = 'Too close to water or landfill!'
    elseif curr_x > max_x then
        warning = 'Too far from spawn by ' .. math.floor(curr_x - max_x) .. ' tiles!'
    end

    return warning
end

---@param event LuaOnBuiltEntityEvent
---Performs checks if silo is placed in valid location - if not, then it's
---destroyed and put back into player inventory.
local function on_built_entity(event)
    if Public.is_disabled() then
        return
    end

    local entity = event.entity
    if not entity.valid or entity.name ~= 'rocket-silo' then
        return
    end

    local warning = silo_position_check(entity)
    if warning then
        local player = game.get_player(event.player_index)
        player.insert({ name = 'rocket-silo', count = 1 })
        player.create_local_flying_text({
            position = entity.position,
            text = warning,
            color = { r = 0.98, g = 0.66, b = 0.22 },
        })

        entity.destroy()
        return
    end

    local f_name = entity.force.name
    entity.minable_flag = false
    table.insert(storage.rocket_silo[f_name], entity)
    AiTargets.start_tracking(entity)
end

---@param event LuaOnRobotBuiltEntityEvent
---Does the same as on_built_entity, but for robot.
local function on_robot_built_entity(event)
    if Public.is_disabled() then
        return
    end

    local entity = event.entity
    if not entity.valid or entity.name ~= 'rocket-silo' then
        return
    end

    local warning = silo_position_check(entity)
    if warning then
        local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        inventory.insert({ name = 'rocket-silo', count = 1 })
        entity.destroy()
        return
    end

    local f_name = entity.force.name
    entity.minable_flag = false
    table.insert(storage.rocket_silo[f_name], entity)
    AiTargets.start_tracking(entity)
end

---@param player LuaPlayer
---Reacts to player clicking 'spectate', to make it possible to return to island
---if next to any silo. This prevents a situation where players spawn far away from
---typical silo location and have to run back to origin point to use the button.
---@return boolean True if eligible to join spectator.
function Public.can_spectate(player)
    if Public.is_disabled() then
        return false
    end

    --Do nothing if no associated character.
    if not player.character then
        return false
    end

    local silos = player.physical_surface.count_entities_filtered({
        name = 'rocket-silo',
        position = player.character.position,
        radius = 20,
        limit = 1,
    })

    return (silos ~= 0)
end

---@param player LuaPlayer
---@param force LuaForce
---Finds a spawn/teleport point for a player that was just respawned
---or comes back from spectator.
---@return { x: number, y: number }|nil
function Public.get_spawn_position(player, force)
    if Public.is_disabled() then
        return nil
    end

    local f_name = force.name
    local silos = storage.rocket_silo[f_name]
    local min_dist = 1e9
    ---@type LuaEntity|nil
    local candidate = nil
    local p_pos = storage.active_special_games.multi_silo.last_transition[player.name]
    if not p_pos then
        return nil
    end

    --Go through each silo and find the one which is closest to player last
    --transition location
    for _, silo in ipairs(silos) do
        local silo_pos = silo.position
        local dist = (silo_pos.x - p_pos.x) * (silo_pos.x - p_pos.x) + (silo_pos.y - p_pos.y) * (silo_pos.y - p_pos.y)
        if dist < min_dist then
            min_dist = dist
            candidate = silo
        end
    end

    --No silos remaining
    if not candidate then
        return nil
    end

    --Find suitable position around the silo and teleport player.
    local surf = candidate.surface
    return surf.find_non_colliding_position('character', {
        x = candidate.position.x,
        y = candidate.position.y + 5,
    }, 20, 0.1)
end

---@param player LuaPlayer
---Saves current player position. This function is invoked when player
---transitions to different state, like death or spectating. When they
---join back or respawn, we can find teleport location next to closest
---silo.
function Public.save_position(player)
    if Public.is_disabled() then
        return
    end

    storage.active_special_games.multi_silo.last_transition[player.name] = player.physical_position
end

---@param event LuaOnPlayerRespawnedEvent
---Teleports player to closest silo on their team.
local function on_player_respawned(event)
    if Public.is_disabled() then
        return
    end

    local player = game.get_player(event.player_index)
    local p = Public.get_spawn_position(player, player.force)
    player.character.teleport(p)
end

---@param event LuaOnPlayerDiedEvent
local function on_player_died(event)
    if Public.is_disabled() then
        return
    end

    local player = game.get_player(event.player_index)
    Public.save_position(player)
end

---@param silo LuaEntity
---Goes through all placed silos, finds the reference matching 'silo' and
---unlinks it from the list so that it doesn't count towards the objective.
---@return boolean If operation was successful
local function remove_silo_ref(silo)
    local removed = false
    for _, list in pairs(storage.rocket_silo) do
        -- Abort if it's the last silo remaining in the force
        if #list <= 1 then
            goto remove_silo_ref_loop
        end

        for k, v in pairs(list) do
            if v == silo then
                table.remove(list, k)
                removed = true
                break
            end
        end

        ::remove_silo_ref_loop::
    end

    return removed
end

---@param cmd CustomCommandData
---Remove a silo that is pointed by player selection and drop it on the ground.
local function remove_silo(cmd)
    local player = game.get_player(cmd.player_index)
    if not is_admin(player) then
        player.print('Only admin can use this command')
        return
    end

    if Public.is_disabled() then
        player.print('Only applicable in multi silo mode')
        return
    end

    if storage.server_restart_timer then
        player.print('Cannot use this command during map reset')
        return
    end

    local entity = player.selected
    if not entity or not entity.valid or entity.name ~= 'rocket-silo' then
        player.print('You must point your cursor at a rocket silo when using this command')
        return
    end

    if not remove_silo_ref(entity) then
        player.print("It's the only remaining silo, it cannot be removed without ending the game")
        return
    end

    -- Mine the silo and drop it on the ground
    local position = entity.position
    local surface = entity.surface
    local gps = entity.gps_tag
    local req = {
        inventory = nil,
        force = true,
        raise_destroyed = false,
        ignore_minable = true,
    }
    entity.mine(req)

    req = {
        position = position,
        stack = { name = 'rocket-silo', count = 1 },
        enable_looted = false,
        allow_belts = true,
    }
    surface.spill_item_stack(req)

    local msg = 'Rocket silo at ' .. gps .. ' removed by ' .. player.name
    surface.print(msg, { color = Color.yellow })
    log(msg)
end

commands.add_command(
    'remove-silo',
    'Removes a silo without explosion and drops it on the ground. Point your cursor at a silo and then execute the command. Applicable with multi silo mode active.',
    remove_silo
)

Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_player_respawned, on_player_respawned)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_player_died, on_player_died)

return Public
