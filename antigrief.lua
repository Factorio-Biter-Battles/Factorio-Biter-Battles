--antigrief things made by mewmew
--rewritten by gerkiz--
--as an admin, write either /trust or /untrust and the players name in the chat to grant/revoke immunity from protection

local Event = require('utils.event')
local session = require('utils.datastore.session_data')
local Global = require('utils.global')
local Utils = require('utils.core')
local Color = require('utils.color_presets')
local Server = require('utils.server')
local Jail = require('utils.datastore.jail_data')
local pool = require('maps.biter_battles_v2.pool')
local Functions = require('maps.biter_battles_v2.functions')

local Public = {}
local match = string.match
local capsule_bomb_threshold = 8
local de = defines.events

local format = string.format
local size = 1024
local this = {
    enabled = true,
    histories = {
        landfill = pool.malloc(size),
        capsule = pool.malloc(size),
        friendly_fire = pool.malloc(size),
        mining = pool.malloc(size),
        belt_mining = pool.malloc(size),
        corpse = pool.malloc(size),
        cancel_crafting = pool.malloc(size),
    },
    histories_idx = {
        landfill = 0,
        capsule = 0,
        friendly_fire = 0,
        mining = 0,
        belt_mining = 0,
        corpse = 0,
        cancel_crafting = 0,
    },
    whitelist_types = {},
    permission_group_editing = {},
    players_warned = {},
    damage_history = {},
    punish_cancel_craft = false,
    log_tree_harvest = false,
    do_not_check_trusted = true,
    enable_autokick = false,
    enable_autoban = false,
    enable_jail = false,
    enable_capsule_warning = false,
    enable_capsule_cursor_warning = false,
    required_playtime = 2592000,
    damage_entity_threshold = 20,
    explosive_threshold = 16,
}

local blacklisted_types = {
    ['transport-belt'] = true,
    ['wall'] = true,
    ['underground-belt'] = true,
    ['inserter'] = true,
    ['land-mine'] = true,
    ['gate'] = true,
    ['lamp'] = true,
    ['mining-drill'] = true,
    ['splitter'] = true,
    ['tree'] = true,
    ['fish'] = true,
}

local ammo_names = {
    ['artillery-targeting-remote'] = true,
    ['poison-capsule'] = true,
    ['cluster-grenade'] = true,
    ['grenade'] = true,
    ['atomic-bomb'] = true,
    ['cliff-explosives'] = true,
    ['rocket'] = true,
}

local belt_types = {
    ['transport-belt'] = true,
    ['underground-belt'] = true,
    ['splitter'] = true,
}

local chests = {
    ['container'] = true,
    ['logistic-container'] = true,
}

Global.register(this, function(t)
    this = t
end)

--[[
    local function increment_key(t, k, v)
    t[k][#t[k] + 1] = (v or 1)
end
]]
local function increment(t, v)
    t[#t + 1] = (v or 1)
end

local function get_entities(item_name, entities)
    local set = {}
    for i = 1, #entities do
        local e = entities[i]
        local name = e.name

        if name ~= item_name and name ~= 'entity-ghost' then
            local count = set[name]
            if count then
                set[name] = count + 1
            else
                set[name] = 1
            end
        end
    end

    local list = {}
    local i = 1
    for k, v in pairs(set) do
        list[i] = v
        i = i + 1
        list[i] = ' '
        i = i + 1
        list[i] = k
        i = i + 1
        list[i] = ', '
        i = i + 1
    end
    list[i - 1] = nil

    return table.concat(list)
end

local function damage_player(player, kill, print_to_all)
    local msg = ' tried to destroy our base, but it backfired!'
    if player.character then
        if kill then
            player.character.die('enemy')
            if print_to_all then
                game.print(player.name .. msg, { color = Color.yellow })
            end
            return
        end
        player.character.health = player.character.health - math.random(50, 100)
        player.character.surface.create_entity({ name = 'water-splash', position = player.character.position })
        local messages = {
            'Ouch.. That hurt! Better be careful now.',
            'Just a fleshwound.',
            'Better keep those hands to yourself or you might loose them.',
        }
        player.print(messages[math.random(1, #messages)], { color = Color.yellow })
        if player.character.health <= 0 then
            player.character.die('enemy')
            game.print(player.name .. msg, { color = Color.yellow })
            return
        end
    end
end

local function do_action(player, prefix, msg, ban_msg, kill)
    if not prefix or not msg or not ban_msg then
        return
    end
    kill = kill or false

    damage_player(player, kill)
    Utils.action_warning(prefix, msg)

    if this.players_warned[player.index] == 2 then
        if this.enable_autoban then
            Server.ban_sync(player.name, ban_msg, '<script>')
        end
    elseif this.players_warned[player.index] == 1 then
        this.players_warned[player.index] = 2
        if this.enable_jail then
            Jail.try_ul_data(player, true, 'script')
        elseif this.enable_autokick then
            game.kick_player(player, msg)
        end
    else
        this.players_warned[player.index] = 1
    end
end

---returns missing trust warning and chat color
---@param player LuaPlayer can be null
---@return string, {r: integer, g: integer, b: integer}
local function get_not_trusted_warning(player)
    local color = { r = 0.22, g = 0.99, b = 0.99 }
    local generic_part = 'You need to be trusted to do that! Ask an admin for temporary trust or play for '
        .. math.floor(this.required_playtime / (60 * 60 * 60))
        .. 'h. '
    if not player or not player.online_time then
        return generic_part, color
    end
    local tracker = session.get_session_table()
    local playtime = player.online_time
    if tracker[player.name] then
        playtime = player.online_time + tracker[player.name]
    end
    return generic_part .. 'Time remaining: ' .. Functions.format_ticks_as_time(this.required_playtime - playtime),
        color
end

local function on_marked_for_deconstruction(event)
    if not this.enabled then
        return
    end
    local tracker = session.get_session_table()
    local trusted = session.get_trusted_table()
    if not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    if not player then
        return
    end
    if is_admin(player) then
        return
    end
    if trusted[player.name] and this.do_not_check_trusted then
        return
    end

    local playtime = player.online_time
    if tracker[player.name] then
        playtime = player.online_time + tracker[player.name]
    end
    if playtime < this.required_playtime then
        event.entity.cancel_deconstruction(game.get_player(event.player_index).force.name)
        player.print(get_not_trusted_warning(player))
    end
end

local function on_player_ammo_inventory_changed(event)
    if not this.enabled then
        return
    end
    local tracker = session.get_session_table()
    local trusted = session.get_trusted_table()
    local player = game.get_player(event.player_index)
    if is_admin(player) then
        return
    end
    if trusted[player.name] and this.do_not_check_trusted then
        return
    end

    local playtime = player.online_time
    if tracker[player.name] then
        playtime = player.online_time + tracker[player.name]
    end
    if playtime < this.required_playtime then
        if this.enable_capsule_cursor_warning then
            local nukes = player.remove_item({ name = 'atomic-bomb', count = 1000 })
            if nukes > 0 then
                Utils.action_warning('{Nuke}', player.name .. ' tried to equip nukes but was not trusted.')
                damage_player(player)
            end
        end
    end
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    local trusted = session.get_trusted_table()
    if not this.enabled then
        if not trusted[player.name] then
            trusted[player.name] = true
        end
        return
    end

    if match(player.name, '^[Ili1|]+$') then
        Server.ban_sync(player.name, '', '<script>') -- No reason given, to not give them any hints to change their name
    end
end

local function on_player_built_tile(event)
    if not this.enabled then
        return
    end
    local placed_tiles = event.tiles
    if
        placed_tiles[1].old_tile.name ~= 'deepwater'
        and placed_tiles[1].old_tile.name ~= 'water'
        and placed_tiles[1].old_tile.name ~= 'water-green'
    then
        return
    end
    local player = game.get_player(event.player_index)

    local surface = event.surface_index

    --landfill history--

    local data = {
        player_name = player.name,
        event = 'landfilled',
        position = { x = math.floor(placed_tiles[1].position.x), y = math.floor(placed_tiles[1].position.y) },
        time = game.ticks_played,
        server_time = game.tick,
    }
    this.histories_idx.landfill = this.histories_idx.landfill % size + 1
    this.histories.landfill[this.histories_idx.landfill] = data
end

local function on_built_entity(event)
    if not this.enabled then
        return
    end
    local tracker = session.get_session_table()
    local trusted = session.get_trusted_table()
    if event.entity.type == 'entity-ghost' then
        local player = game.get_player(event.player_index)
        if not player then
            return
        end
        if is_admin(player) then
            return
        end
        if trusted[player.name] and this.do_not_check_trusted then
            return
        end

        local playtime = player.online_time
        if tracker[player.name] then
            playtime = player.online_time + tracker[player.name]
        end

        if playtime < this.required_playtime then
            event.entity.destroy()
            player.print(get_not_trusted_warning(player))
        end
    end
end

--Capsule History and Antigrief
local function on_player_used_capsule(event)
    if not this.enabled then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local item = event.item
    if not item then
        return
    end
    local x, y = event.position.x, event.position.y
    local position = { x = math.floor(x), y = math.floor(y) }
    if
        ammo_names[item.name]
        and player.physical_surface.count_entities_filtered({
                force = player.force.name .. '_biters',
                area = { { x - 10, y - 10 }, { x + 10, y + 10 } },
                limit = 1,
            })
            <= 0
    then
        local data = {
            player_name = player.name,
            event = item.name,
            position = position,
            time = game.ticks_played,
            server_time = game.tick,
        }
        this.histories_idx.capsule = this.histories_idx.capsule % size + 1
        this.histories.capsule[this.histories_idx.capsule] = data
    end
end

--Friendly Fire History
local function on_entity_died(event)
    if not this.enabled then
        return
    end
    local cause = event.cause
    if
        cause
        and cause.name == 'character'
        and cause.player
        and cause.force.name == event.entity.force.name
        and not blacklisted_types[event.entity.type]
    then
        local player = cause.player
        if blacklisted_types[event.entity.type] and not this.whitelist_types[event.entity.type] then
            return
        end
        local data = {
            player_name = player.name,
            event = 'destroyed ' .. event.entity.name,
            position = { x = math.floor(event.entity.position.x), y = math.floor(event.entity.position.y) },
            time = game.ticks_played,
            server_time = game.tick,
        }
        if chests[event.entity.type] then
            local inv = event.entity.get_inventory(1)
            data.event = table.concat({ data.event, ' with ', inv.get_item_count(), ' items' })
        end
        this.histories_idx.friendly_fire = this.histories_idx.friendly_fire % size + 1
        this.histories.friendly_fire[this.histories_idx.friendly_fire] = data
    end
end

-- Should be pre-checked for entity/player validity
---@param entity LuaEntity
---@param player LuaPlayer History
function Public.on_player_mined_entity(entity, player)
    if not this.enabled then
        return
    end

    if entity.type == 'offshore-pump' then
        Utils.print_admins(
            player.name
                .. ' mined an offshore pump at'
                .. '[gps='
                .. entity.position.x
                .. ','
                .. entity.position.y
                .. ','
                .. entity.surface.name
                .. ']',
            nil
        )
    end

    if not entity.force.name == player.force.name then
        return
    end
    if not entity.last_user then
        return
    end
    if entity.last_user.name == player.name then
        return
    end
    local data = {
        player_name = player.name,
        event = entity.name,
        position = { x = math.floor(entity.position.x), y = math.floor(entity.position.y) },
        time = game.ticks_played,
        server_time = game.tick,
    }
    if belt_types[entity.type] then
        this.histories_idx.belt_mining = this.histories_idx.belt_mining % size + 1
        this.histories.belt_mining[this.histories_idx.belt_mining] = data
        return
    end
    if this.whitelist_types[entity.type] or not blacklisted_types[entity.type] then
        this.histories_idx.mining = this.histories_idx.mining % size + 1
        this.histories.mining[this.histories_idx.mining] = data
    end
end

local function on_gui_opened(event)
    if not this.enabled then
        return
    end
    if not event.entity then
        return
    end
    if event.entity.name ~= 'character-corpse' then
        return
    end
    local player = game.get_player(event.player_index)
    local corpse_owner = game.get_player(event.entity.character_corpse_player_index)
    if not corpse_owner then
        return
    end

    if corpse_owner.force.name ~= player.force.name then
        return
    end

    local corpse_content = #event.entity.get_inventory(defines.inventory.character_corpse)
    if corpse_content <= 0 then
        return
    end

    if player.name ~= corpse_owner.name then
        Utils.action_warning('{Corpse}', player.name .. ' is looting ' .. corpse_owner.name .. '´s body.')
        local data = {
            player_name = player.name,
            event = table.concat({ 'opened ', corpse_owner.name, ' body' }),
            position = { x = math.floor(event.entity.position.x), y = math.floor(event.entity.position.y) },
            time = game.ticks_played,
            server_time = game.tick,
        }
        this.histories_idx.corpse = this.histories_idx.corpse % size + 1
        this.histories.corpse[this.histories_idx.corpse] = data
    end
end

local function on_pre_player_mined_item(event)
    if not this.enabled then
        return
    end
    local player = game.get_player(event.player_index)

    if not player or not player.valid then
        return
    end

    local entity = event.entity
    if not entity or not entity.valid then
        return
    end

    if entity.name ~= 'character-corpse' then
        return
    end

    local corpse_owner = game.get_player(entity.character_corpse_player_index)
    if not corpse_owner then
        return
    end

    local corpse_content = #entity.get_inventory(defines.inventory.character_corpse)
    if corpse_content <= 0 then
        return
    end
    if corpse_owner.force.name ~= player.force.name then
        return
    end
    if player.name ~= corpse_owner.name then
        Utils.action_warning('{Corpse}', player.name .. ' has looted ' .. corpse_owner.name .. '´s body.')
        local data = {
            player_name = player.name,
            event = table.concat({ 'looted ', corpse_owner.name, ' body' }),
            position = { x = math.floor(event.entity.position.x), y = math.floor(event.entity.position.y) },
            time = game.ticks_played,
            server_time = game.tick,
        }
        this.histories_idx.corpse = this.histories_idx.corpse % size + 1
        this.histories.corpse[this.histories_idx.corpse] = data
    end
end

local function on_player_cursor_stack_changed(event)
    if not this.enabled then
        return
    end
    local tracker = session.get_session_table()
    local trusted = session.get_trusted_table()
    local player = game.get_player(event.player_index)
    if is_admin(player) then
        return
    end
    if trusted[player.name] and this.do_not_check_trusted then
        return
    end

    local item = player.cursor_stack

    if not item then
        return
    end

    if not item.valid_for_read then
        return
    end

    local name = item.name

    local playtime = player.online_time
    if tracker[player.name] then
        playtime = player.online_time + tracker[player.name]
    end

    if playtime < this.required_playtime then
        if this.enable_capsule_cursor_warning then
            if ammo_names[name] then
                local item_to_remove = player.remove_item({ name = name, count = 1000 })
                if item_to_remove > 0 then
                    Utils.action_warning('{Capsule}', player.name .. ' equipped ' .. name .. ' but was not trusted.')
                    damage_player(player)
                end
            end
        end
    end
end

local function on_player_cancelled_crafting(event)
    if not this.enabled then
        return
    end
    local player = game.get_player(event.player_index)

    local crafting_queue_item_count = event.items.get_item_count()
    local free_slots = player.character.get_main_inventory().count_empty_stacks()
    local crafted_items = #event.items

    if crafted_items > free_slots then
        if this.punish_cancel_craft then
            player.character.character_inventory_slots_bonus = crafted_items + #player.get_main_inventory()
            for i = 1, crafted_items do
                player.character.get_main_inventory().insert(event.items[i])
            end

            player.character.die('player')

            Utils.action_warning(
                '{Crafting}',
                player.name
                    .. ' canceled their craft of item '
                    .. event.recipe.name
                    .. ' of total count '
                    .. crafting_queue_item_count
                    .. ' in raw items ('
                    .. crafted_items
                    .. ' slots) but had no inventory left.'
            )
        end

        local data = {
            player_name = player.name,
            event = crafting_queue_item_count .. ' ' .. event.recipe.name,
            position = { x = math.floor(player.physical_position.x), y = math.floor(player.physical_position.y) },
            time = game.ticks_played,
            server_time = game.tick,
        }
        this.histories_idx.cancel_crafting = this.histories_idx.cancel_crafting % size + 1
        this.histories.cancel_crafting[this.histories_idx.cancel_crafting] = data
    end
end

local function on_init()
    if not this.enabled then
        return
    end
    local branch_version = '0.18.35'
    local sub = string.sub
    local is_branch_18 = sub(branch_version, 3, 4)
    local get_active_version = sub(script.active_mods.base, 3, 4)
    local default = game.permissions.get_group('Default')

    is_branch_18 = is_branch_18 .. sub(branch_version, 6, 7)
    get_active_version = get_active_version .. sub(script.active_mods.base, 6, 7)
    if get_active_version >= is_branch_18 then
        default.set_allows_action(defines.input_action.flush_opened_entity_fluid, false)
        default.set_allows_action(defines.input_action.flush_opened_entity_specific_fluid, false)
    end
end

local function on_permission_group_added(event)
    if not this.enabled then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    local group = event.group

    if group then
        Utils.log_msg('{Permission_Group}', player.name .. ' added ' .. group.name)
    end
end

local function on_permission_group_deleted(event)
    if not this.enabled then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    local name = event.group_name
    local id = event.id
    if name then
        Utils.log_msg('{Permission_Group}', player.name .. ' deleted ' .. name .. ' with ID: ' .. id)
    end
end

local function on_permission_group_edited(event)
    if not this.enabled then
        return
    end

    if not event.player_index then
        return
    end

    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    local group = event.group
    if group then
        local action = ''
        for k, v in pairs(defines.input_action) do
            if event.action == v then
                action = k
            end
        end
        Utils.log_msg(
            '{Permission_Group}',
            player.name .. ' edited ' .. group.name .. ' with type: ' .. event.type .. ' with action: ' .. action
        )
    end
    if event.other_player_index then
        local other_player = game.get_player(event.other_player_index)
        if other_player and other_player.valid then
            Utils.log_msg(
                '{Permission_Group}',
                player.name
                    .. ' moved '
                    .. other_player.name
                    .. ' with type: '
                    .. event.type
                    .. ' to group: '
                    .. group.name
            )
        end
    end
    local old_name = event.old_name
    local new_name = event.new_name
    if old_name and new_name then
        Utils.log_msg(
            '{Permission_Group}',
            player.name .. ' renamed ' .. group.name .. '. New name: ' .. new_name .. '. Old Name: ' .. old_name
        )
    end
end

local function on_permission_string_imported(event)
    if not this.enabled then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    Utils.log_msg('{Permission_Group}', player.name .. ' imported a permission string')
end

--- This will reset the table of antigrief
function Public.reset_tables()
    this.histories = {
        landfill = pool.malloc(size),
        capsule = pool.malloc(size),
        friendly_fire = pool.malloc(size),
        mining = pool.malloc(size),
        belt_mining = pool.malloc(size),
        corpse = pool.malloc(size),
        cancel_crafting = pool.malloc(size),
    }
    this.histories_idx = {
        landfill = 0,
        capsule = 0,
        friendly_fire = 0,
        mining = 0,
        belt_mining = 0,
        corpse = 0,
        cancel_crafting = 0,
    }
end

--- Enable this to log when trees are destroyed
---@param value boolean
function Public.log_tree_harvest(value)
    if value then
        this.log_tree_harvest = value
    end

    return this.log_tree_harvest
end

--- Add entity type to the whitelist so it gets logged.
---@param key string
---@param value string
function Public.whitelist_types(key, value)
    if key and value then
        this.whitelist_types[key] = value
    end

    return this.whitelist_types[key]
end

--- If the event should also check trusted players.
---@param value string
function Public.do_not_check_trusted(value)
    if value then
        this.do_not_check_trusted = value
    else
        this.do_not_check_trusted = false
    end

    return this.do_not_check_trusted
end

--- If ANY actions should be performed when a player misbehaves.
---@param value string
function Public.enable_capsule_warning(value)
    if value then
        this.enable_capsule_warning = value
    else
        this.enable_capsule_warning = false
    end

    return this.enable_capsule_warning
end

--- If ANY actions should be performed when a player misbehaves.
---@param value string
function Public.enable_capsule_cursor_warning(value)
    if value then
        this.enable_capsule_cursor_warning = value
    else
        this.enable_capsule_cursor_warning = false
    end

    return this.enable_capsule_cursor_warning
end

--- If the script should jail a person instead of kicking them
---@param value string
function Public.enable_jail(value)
    if value then
        this.enable_jail = value
    else
        this.enable_jail = false
    end

    return this.enable_jail
end

--- Defines what the threshold for amount of explosives in chest should be - logged or not.
---@param value string
function Public.explosive_threshold(value)
    if value then
        this.explosive_threshold = value
    end

    return this.explosive_threshold
end

--- Defines what the threshold for amount of times before the script should take action.
---@param value string
function Public.damage_entity_threshold(value)
    if value then
        this.damage_entity_threshold = value
    end

    return this.damage_entity_threshold
end

--- This is used for the RPG module, when casting capsules.
---@param player LuaPlayer
---@param position MapPosition
---@param msg string
function Public.insert_into_capsule_history(player, position, msg)
    if not this.capsule_history then
        this.capsule_history = {}
    end
    if #this.capsule_history > 1000 then
        this.capsule_history = {}
    end
    local t = math.abs(math.floor(game.tick / 3600))
    local str = '[' .. t .. '] '
    str = str .. '[color=yellow]' .. msg .. '[/color]'
    str = str .. ' at X:'
    str = str .. math.floor(position.x)
    str = str .. ' Y:'
    str = str .. math.floor(position.y)
    str = str .. ' '
    str = str .. 'surface:' .. player.physical_surface_index
    increment(this.capsule_history, str)
end

--- Returns the table.
---@param key string?
function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

Event.on_init(on_init)
Event.add(de.on_entity_died, on_entity_died)
Event.add(de.on_built_entity, on_built_entity)
Event.add(de.on_gui_opened, on_gui_opened)
Event.add(de.on_marked_for_deconstruction, on_marked_for_deconstruction)
Event.add(de.on_player_ammo_inventory_changed, on_player_ammo_inventory_changed)
Event.add(de.on_player_built_tile, on_player_built_tile)
Event.add(de.on_pre_player_mined_item, on_pre_player_mined_item)
Event.add(de.on_player_used_capsule, on_player_used_capsule)
Event.add(de.on_player_cursor_stack_changed, on_player_cursor_stack_changed)
Event.add(de.on_player_cancelled_crafting, on_player_cancelled_crafting)
Event.add(de.on_player_joined_game, on_player_joined_game)
Event.add(de.on_permission_group_added, on_permission_group_added)
Event.add(de.on_permission_group_deleted, on_permission_group_deleted)
Event.add(de.on_permission_group_edited, on_permission_group_edited)
Event.add(de.on_permission_string_imported, on_permission_string_imported)

return Public
