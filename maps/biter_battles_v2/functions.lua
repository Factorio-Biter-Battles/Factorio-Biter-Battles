local _TEST = storage['_TEST'] or false
local Color = require('utils.color_presets')
local Tables = require('maps.biter_battles_v2.tables')
local ClosableFrame, Config, Gui, Server, simplex_noise
if not _TEST then
    ClosableFrame = require('utils.ui.closable_frame')
    Config = require('maps.biter_battles_v2.config')
    Gui = require('utils.gui')
    Server = require('utils.server')
    simplex_noise = require('utils.simplex_noise').d2
end

local gui_style = require('utils.utils').gui_style

local math_abs = math.abs
local math_floor = math.floor
local math_min = math.min
local math_random = math.random
local math_round = math.round
local string_find = string.find
local string_format = string.format
local string_sub = string.sub

local function get_ammo_modifier(ammo_category)
    return Tables.base_ammo_modifiers[ammo_category] or 0
end
local function get_turret_attack_modifier(turret_category)
    return Tables.base_turret_attack_modifiers[turret_category] or 0
end
local function get_upgrade_modifier(ammo_category)
    return Tables.upgrade_modifiers[ammo_category] or 0
end

-- Only add upgrade research balancing logic in this section
-- All values should be in tables.lua
local function proj_buff(current_value, force_name)
    if not storage.combat_balance[force_name].bullet then
        storage.combat_balance[force_name].bullet = get_ammo_modifier('bullet')
    end
    storage.combat_balance[force_name].bullet = storage.combat_balance[force_name].bullet + current_value
    game.forces[force_name].set_ammo_damage_modifier('bullet', storage.combat_balance[force_name].bullet)
end
local function laser_buff(current_value, force_name)
    if not storage.combat_balance[force_name].laser_damage then
        storage.combat_balance[force_name].laser_damage = get_turret_attack_modifier('laser-turret')
    end
    storage.combat_balance[force_name].laser_damage = storage.combat_balance[force_name].laser_damage
        + current_value
        - get_upgrade_modifier('laser-turret')
    game.forces[force_name].set_turret_attack_modifier('laser-turret', current_value)
end
local function flamer_buff(current_value_ammo, current_value_turret, force_name)
    if not storage.combat_balance[force_name].flame_damage then
        storage.combat_balance[force_name].flame_damage = get_ammo_modifier('flamethrower')
    end
    storage.combat_balance[force_name].flame_damage = storage.combat_balance[force_name].flame_damage
        + current_value_ammo
        - get_upgrade_modifier('flamethrower')
    game.forces[force_name].set_ammo_damage_modifier('flamethrower', storage.combat_balance[force_name].flame_damage)

    if not storage.combat_balance[force_name].flamethrower_damage then
        storage.combat_balance[force_name].flamethrower_damage = get_turret_attack_modifier('flamethrower-turret')
    end
    storage.combat_balance[force_name].flamethrower_damage = storage.combat_balance[force_name].flamethrower_damage
        + current_value_turret
        - get_upgrade_modifier('flamethrower-turret')
    game.forces[force_name].set_turret_attack_modifier(
        'flamethrower-turret',
        storage.combat_balance[force_name].flamethrower_damage
    )
end
local balance_functions = {
    ['refined-flammables'] = function(force_name)
        flamer_buff(
            get_upgrade_modifier('flamethrower') * 2,
            get_upgrade_modifier('flamethrower-turret') * 2,
            force_name
        )
    end,
    ['refined-flammables-1'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['refined-flammables-2'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['refined-flammables-3'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['refined-flammables-4'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['refined-flammables-5'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['refined-flammables-6'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['refined-flammables-7'] = function(force_name)
        flamer_buff(0.06, 0.06, force_name)
    end,
    ['laser-weapons-damage'] = function(force_name)
        laser_buff(get_upgrade_modifier('laser-turret') * 2, force_name)
    end,
    ['laser-weapons-damage-1'] = function(force_name)
        laser_buff(0.2, force_name)
    end,
    ['laser-weapons-damage-2'] = function(force_name)
        laser_buff(0.2, force_name)
    end,
    ['laser-weapons-damage-3'] = function(force_name)
        laser_buff(0.4, force_name)
    end,
    ['laser-weapons-damage-4'] = function(force_name)
        laser_buff(0.4, force_name)
    end,
    ['laser-weapons-damage-5'] = function(force_name)
        laser_buff(0.4, force_name)
    end,
    ['laser-weapons-damage-6'] = function(force_name)
        laser_buff(0.5, force_name)
    end,
    ['laser-weapons-damage-7'] = function(force_name)
        laser_buff(0.5, force_name)
    end,
    ['stronger-explosives'] = function(force_name)
        if not storage.combat_balance[force_name].grenade_damage then
            storage.combat_balance[force_name].grenade_damage = get_ammo_modifier('grenade')
        end
        storage.combat_balance[force_name].grenade_damage = storage.combat_balance[force_name].grenade_damage
            + get_upgrade_modifier('grenade')
        game.forces[force_name].set_ammo_damage_modifier('grenade', storage.combat_balance[force_name].grenade_damage)

        if not storage.combat_balance[force_name].land_mine then
            storage.combat_balance[force_name].land_mine = get_ammo_modifier('landmine')
        end
        storage.combat_balance[force_name].land_mine = storage.combat_balance[force_name].land_mine
            + get_upgrade_modifier('landmine')
        game.forces[force_name].set_ammo_damage_modifier('landmine', storage.combat_balance[force_name].land_mine)
    end,
    ['stronger-explosives-1'] = function(force_name)
        if not storage.combat_balance[force_name].land_mine then
            storage.combat_balance[force_name].land_mine = get_ammo_modifier('landmine')
        end
        storage.combat_balance[force_name].land_mine = storage.combat_balance[force_name].land_mine
            - get_upgrade_modifier('landmine')
        game.forces[force_name].set_ammo_damage_modifier('landmine', storage.combat_balance[force_name].land_mine)
    end,
    ['physical-projectile-damage'] = function(force_name)
        if not storage.combat_balance[force_name].shotgun then
            storage.combat_balance[force_name].shotgun = get_ammo_modifier('shotgun-shell')
        end
        storage.combat_balance[force_name].shotgun = storage.combat_balance[force_name].shotgun
            + get_upgrade_modifier('shotgun-shell')
        game.forces[force_name].set_ammo_damage_modifier('shotgun-shell', storage.combat_balance[force_name].shotgun)
        game.forces[force_name].set_turret_attack_modifier('gun-turret', 0)
    end,
    ['physical-projectile-damage-1'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
    ['physical-projectile-damage-2'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
    ['physical-projectile-damage-3'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
    ['physical-projectile-damage-4'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
    ['physical-projectile-damage-5'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
    ['physical-projectile-damage-6'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
    ['physical-projectile-damage-7'] = function(force_name)
        proj_buff(0.3, force_name)
    end,
}

local no_turret_blacklist = {
    ['ammo-turret'] = true,
    ['artillery-turret'] = true,
    ['electric-turret'] = true,
    ['fluid-turret'] = true,
}

local landfill_biters_vectors = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
local landfill_biters = {
    ['big-biter'] = true,
    ['big-spitter'] = true,
    ['behemoth-biter'] = true,
    ['behemoth-spitter'] = true,
}

local spawn_positions = {}
local spawn_r = 7
local spawn_r_square = spawn_r ^ 2
for x = spawn_r * -1, spawn_r, 0.5 do
    for y = spawn_r * -1, spawn_r, 0.5 do
        if x ^ 2 + y ^ 2 < spawn_r_square then
            table.insert(spawn_positions, { x = x, y = y })
        end
    end
end
local size_of_spawn_positions = #spawn_positions

local Functions = {}

---@param event EventData.on_player_mined_entity|EventData.on_pre_player_crafted_item|EventData.on_player_mined_item
function Functions.maybe_set_game_start_tick(event)
    if storage.bb_game_start_tick then
        return
    end
    if not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    if player.force.name ~= 'north' and player.force.name ~= 'south' then
        return
    end
    Functions.set_game_start_tick()
end

function Functions.set_game_start_tick()
    if storage.bb_game_start_tick then
        return
    end
    storage.bb_game_start_tick = game.ticks_played
    local message = 'The match has started! '
    Server.to_discord_bold(table.concat({ '*** ', message, ' ***' }))
end

function Functions.biters_landfill(entity)
    if not landfill_biters[entity.name] then
        return
    end
    local position = entity.position
    if math_abs(position.y) < 8 then
        return true
    end
    local surface = entity.surface
    for _, vector in pairs(landfill_biters_vectors) do
        local tile = surface.get_tile({ position.x + vector[1], position.y + vector[2] })
        if tile.collides_with('resource') then
            surface.set_tiles({ { name = 'dirt-1', position = tile.position } })
            local particle_pos = { tile.position.x + 0.5, tile.position.y + 0.5 }
            for _ = 1, 50, 1 do
                surface.create_particle({
                    name = 'stone-particle',
                    position = particle_pos,
                    frame_speed = 0.1,
                    vertical_speed = 0.12,
                    height = 0.01,
                    movement = { -0.05 + math_random(0, 100) * 0.001, -0.05 + math_random(0, 100) * 0.001 },
                })
            end
        end
    end
    return true
end

function Functions.combat_balance(event)
    local research_name = event.research.name
    local force_name = event.research.force.name
    local key
    for b = 1, string.len(research_name), 1 do
        key = string_sub(research_name, 0, b)
        if balance_functions[key] then
            if not storage.combat_balance[force_name] then
                storage.combat_balance[force_name] = {}
            end
            balance_functions[key](force_name)
        end
    end
end

---@param surface LuaSurface
---Returns non-colliding position on spectator island or hardcoded coordinate
---of island as a fallback
local function find_teleport_point(surface)
    local p = spawn_positions[math_random(1, size_of_spawn_positions)]
    -- At this point surface has to have several chunks already, but if not fallback
    -- to random point on the island.
    return surface.find_non_colliding_position('character', p, 4, 0.5) or p
end

---@param player LuaPlayer
---Sets random bright color for a player that joins the server for
---the first time. This gets rid of annoying situation where player
---gets assigned very dark color that is barely readable.
function Functions.set_random_color(player)
    local color = {
        r = math_random(150, 255),
        g = math_random(150, 255),
        b = math_random(150, 255),
        a = math_random(150, 255),
    }

    player.color = color
    player.chat_color = color
end

function Functions.init_player(player)
    if not player.connected then
        if player.force.index ~= 1 then
            player.force = game.forces.player
        end
        return
    end

    -- If we don't get rid of character, associated construction
    -- bots will be teleported as well and there is no API to destroy them.
    -- Leave the character on previous surface, to avoid destroying and
    -- creating new one for a player in single tick as it might cause
    -- problem with subsequent assignment. Destruction of character will take
    -- place in LuaGameScript::delete_surface.
    player.character = nil

    local s = game.surfaces[storage.bb_surface_name]
    local p = find_teleport_point(s)
    player.teleport(p, s)

    -- Avoid using create_character() as even though it was called, player in
    -- rare case did not have assigned character.
    local ch = s.create_entity({
        name = 'character',
        position = p,
    })
    -- Mark as non-destructible before assigning to controller
    -- to avoid accessing through LuaPlayer which might be in weird state.
    ch.destructible = false
    player.set_controller({
        type = defines.controllers.character,
        character = ch,
    })

    if not player.character then
        log(
            'BUG: character assigned for '
                .. player.name
                .. ' at { '
                .. p.x
                .. ', '
                .. p.y
                .. ' } but still not accessible'
        )
    end

    player.spectator = true
    player.show_on_map = false
    player.force = game.forces.spectator
    game.permissions.get_group('spectator').add_player(player)
end

function Functions.is_roughly_biter_area(position)
    local bitera_area_distance = Config.bitera_area_distance * -1
    local a = bitera_area_distance - (math_abs(position.x) * Config.biter_area_slope)
    return position.y <= a
end

function Functions.no_turret_creep(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if not no_turret_blacklist[event.entity.type] then
        return
    end

    local posEntity = entity.position
    if posEntity.y > 0 then
        posEntity.y = (posEntity.y + 100) * -1
    end
    if posEntity.y < 0 then
        posEntity.y = posEntity.y - 100
    end
    if not Functions.is_roughly_biter_area(posEntity) then
        return
    end

    local surface = event.entity.surface
    local spawners = surface.find_entities_filtered({
        type = 'unit-spawner',
        area = {
            { entity.position.x - 70, entity.position.y - 70 },
            { entity.position.x + 70, entity.position.y + 70 },
        },
    })
    if #spawners == 0 then
        return
    end

    local allowed_to_build = true

    for _, e in pairs(spawners) do
        if (e.position.x - entity.position.x) ^ 2 + (e.position.y - entity.position.y) ^ 2 < 4096 then
            allowed_to_build = false
            break
        end
    end

    if allowed_to_build then
        return
    end

    if event.player_index then
        local player = game.get_player(event.player_index)
        player.insert({ name = entity.name, count = 1 })
        player.create_local_flying_text({
            position = entity.position,
            text = 'Turret too close to spawner!',
            color = { r = 0.98, g = 0.66, b = 0.22 },
        })
    else
        -- TODO: Create flying text differently for bots
        local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
        inventory.insert({ name = entity.name, count = 1 })
    end

    entity.destroy()
end

function Functions.no_landfill_by_untrusted_user(event, trusted_table)
    local entity = event.entity
    if not entity.valid or not event.player_index or entity.name ~= 'tile-ghost' or entity.ghost_name ~= 'landfill' then
        return
    end
    local player = game.get_player(event.player_index)
    if not trusted_table[player.name] then
        player.print(
            'You have not grown accustomed to this technology yet.',
            { color = { r = 0.22, g = 0.99, b = 0.99 } }
        )
        entity.destroy()
        return
    end
end

--- Returns the number of ticks since the game started, or 0 if it has not started.
--- @return integer
function Functions.get_ticks_since_game_start()
    local start_tick = storage.bb_game_start_tick
    if not start_tick then
        return 0
    end
    return game.ticks_played - start_tick
end

function Functions.team_name(force_name)
    local name = storage.tm_custom_name[force_name]
    if name == nil then
        if force_name == 'north' then
            name = Config.north_side_team_name
        elseif force_name == 'south' then
            name = Config.south_side_team_name
        end
    end
    return name or force_name
end

function Functions.team_name_with_color(force_name)
    local name = Functions.team_name(force_name)
    if force_name == 'north' then
        return '[color=120, 120, 255]' .. name .. '[/color]'
    elseif force_name == 'south' then
        return '[color=255, 65, 65]' .. name .. '[/color]'
    else
        return name
    end
end

-- Returns every possible player name that follows "@" or "@ " in the message, as well as every name that preceeds "@"
--- @param message string
--- @return table<string, boolean>
function Functions.extract_possible_pings(message)
    local possible_pings = {}
    for name in string.gmatch(message, '@%s?([a-zA-Z0-9_-]+)') do
        possible_pings[name] = true
    end
    for name in string.gmatch(message, '([a-zA-Z0-9_-]+)@') do
        possible_pings[name] = true
    end
    return possible_pings
end

---@param forcePlayerList LuaPlayer[]
---@param playerNameSendingMessage string
---@param msgToPrint string
---@param colorChosen Color?
---@param ping_fn fun(from_player_name: string, to_player: LuaPlayer, message: string)
function Functions.print_message_to_players(forcePlayerList, playerNameSendingMessage, msgToPrint, colorChosen, ping_fn)
    local possible_pings = Functions.extract_possible_pings(msgToPrint)
    for _, playerOfForce in pairs(forcePlayerList) do
        local player_name = playerOfForce.name
        if
            storage.ignore_lists[player_name] == nil
            or not storage.ignore_lists[player_name][playerNameSendingMessage]
        then
            if ping_fn and possible_pings[player_name] then
                ping_fn(playerNameSendingMessage, playerOfForce, msgToPrint)
            end
            playerOfForce.print(msgToPrint, { color = colorChosen })
        end
    end
end

function Functions.spy_fish(player, event)
    local button = event.button
    local shift = event.shift
    if not player.character then
        return
    end
    if event.control then
        return
    end
    local duration_per_unit = 2700
    local i2 = player.character.get_inventory(defines.inventory.character_main)
    if not i2 then
        return
    end
    local owned_fish = i2.get_item_count('raw-fish')
    local send_amount = 1
    if owned_fish == 0 then
        player.print('You have no fish in your inventory.', { r = 0.98, g = 0.66, b = 0.22 })
    else
        if shift then
            if button == defines.mouse_button_type.left then
                send_amount = owned_fish
            elseif button == defines.mouse_button_type.right then
                send_amount = math_floor(owned_fish / 2)
            end
        else
            if button == defines.mouse_button_type.left then
                send_amount = 1
            elseif button == defines.mouse_button_type.right then
                send_amount = math_min(owned_fish, 5)
            end
        end

        local x = i2.remove({ name = 'raw-fish', count = send_amount })
        if x == 0 then
            i2.remove({ name = 'raw-fish', count = send_amount })
        end
        local enemy_team = 'south'
        if player.force.name == 'south' then
            enemy_team = 'north'
        end
        if storage.spy_fish_timeout[player.force.name] - game.tick > 0 then
            storage.spy_fish_timeout[player.force.name] = storage.spy_fish_timeout[player.force.name]
                + duration_per_unit * send_amount
            local spy_time_seconds = math_floor((storage.spy_fish_timeout[player.force.name] - game.tick) / 60)
            if spy_time_seconds > 60 then
                local minute_label = ' minute and '
                if spy_time_seconds > 120 then
                    minute_label = ' minutes and '
                end
                player.print(
                    math_floor(spy_time_seconds / 60)
                        .. minute_label
                        .. math_floor(spy_time_seconds % 60)
                        .. ' seconds of enemy vision left.',
                    { color = { r = 0.98, g = 0.66, b = 0.22 } }
                )
            else
                player.print(
                    spy_time_seconds .. ' seconds of enemy vision left.',
                    { color = { r = 0.98, g = 0.66, b = 0.22 } }
                )
            end
        else
            game.print(
                player.name .. ' sent ' .. send_amount .. ' fish to spy on ' .. enemy_team .. ' team!',
                { color = { r = 0.98, g = 0.66, b = 0.22 } }
            )
            storage.spy_fish_timeout[player.force.name] = game.tick + duration_per_unit * send_amount
        end
    end
end

function Functions.create_map_intro_button(player)
    Gui.add_top_element(player, {
        type = 'sprite-button',
        sprite = 'utility/custom_tag_icon',
        name = 'map_intro_button',
        tooltip = { 'gui.map_intro_top_button' },
    })
end

function Functions.show_intro(player)
    if player.gui.screen.map_intro_frame then
        player.gui.screen.map_intro_frame.destroy()
    end

    local frame = ClosableFrame.create_main_closable_frame(player, 'map_intro_frame', '-- Biter Battles --')

    local scroll = frame.add({ type = 'scroll-pane' })
    local label =
        scroll.add({ type = 'label', caption = { 'biter_battles.map_info' }, name = 'biter_battles_map_intro' })
    gui_style(label, { single_line = false, font_color = { 255, 255, 255 } })
end

function Functions.map_intro_click(player, element)
    if element.name == 'map_intro_button' then
        if player.gui.screen.map_intro_frame then
            player.gui.screen.map_intro_frame.destroy()
            return true
        else
            Functions.show_intro(player)
            return true
        end
    end
end

function Functions.format_ticks_as_time(ticks)
    local seconds = (ticks - (ticks % 60)) / 60
    local hour_f = seconds % 3600
    local hours = (seconds - hour_f) / 3600
    seconds = hour_f % 60
    local minutes = (hour_f - seconds) / 60
    return string_format('%d:%02d:%02d', hours, minutes, seconds)
end

function Functions.get_entity_contents(entity)
    local totals = {}
    if not (entity and entity.valid) then
        return totals
    end
    for i_id = 1, entity.get_max_inventory_index() do
        local inventory = entity.get_inventory(i_id)
        if inventory and inventory.valid and not inventory.is_empty() then
            for _, item in pairs(inventory.get_contents()) do
                totals[item.name] = (totals[item.name] or 0) + item.count
            end
        end
    end
    return totals
end

---@param player LuaPlayer
---@param radius number? #radius
function Functions.clear_corpses(player, radius)
    if not (player and player.valid) then
        return
    end
    radius = radius or storage.default_clear_corpses_radius
    local pos = player.position
    -- we could replace area with radius, as find_entities_filtered have radius key
    local area = { { pos.x + -radius, pos.y + -radius }, { pos.x + radius, pos.y + radius } }
    for _, entity in pairs(player.surface.find_entities_filtered({ area = area, type = 'corpse' })) do
        if entity.corpse_expires then
            entity.destroy()
        end
    end
    player.print('Cleared biter-corpses.', { color = Color.success })
end

--- Will create the text only for those on the same surface
--- See the docs for LuaPlayer::create_local_flying_text, + surface param
---@param params {surface: string|integer|LuaSurface}
function Functions.create_local_flying_text(params)
    local surface = game.get_surface(params.surface.name or params.surface.index or params.surface)
    if not surface then
        return
    end
    for _, player in pairs(game.connected_players) do
        if player.surface_index == surface.index then
            player.create_local_flying_text(params)
        end
    end
end

return Functions
