local Event = require('utils.event')
local Color = require('utils.color_presets')

local function generate_disabled_entities(team, eq)
    if not storage.special_games_variables['disabled_entities'] then
        storage.special_games_variables['disabled_entities'] = { ['north'] = {}, ['south'] = {} }
    end
    local tab = {}
    for k, v in pairs(eq) do
        if v then
            tab[v] = true
            if v == 'rail' then
                tab['straight-rail'] = true
                tab['curved-rail'] = true
            end
        end
    end
    if team == 'left' then
        storage.special_games_variables['disabled_entities']['north'] = tab
        game.print(
            'Special game Disabled entities: ' .. table.concat(eq, ', ') .. ' for team North is being generated!',
            { color = Color.warning }
        )
    elseif team == 'right' then
        storage.special_games_variables['disabled_entities']['south'] = tab
        game.print(
            'Special game Disabled entities: ' .. table.concat(eq, ', ') .. ' for team South is being generated!',
            { color = Color.warning }
        )
    else
        storage.special_games_variables['disabled_entities']['south'] = tab
        storage.special_games_variables['disabled_entities']['north'] = tab
        game.print(
            'Special game Disabled entities: ' .. table.concat(eq, ', ') .. ' for both teams is being generated!',
            { color = Color.warning }
        )
    end
    storage.active_special_games['disabled_entities'] = true
end

local function on_built_entity(event)
    if not storage.active_special_games['disabled_entities'] then
        return
    end
    local entity = event.entity
    if not entity then
        return
    end
    if not entity.valid then
        return
    end

    local player = game.get_player(event.player_index)
    local force = player.force
    if storage.special_games_variables['disabled_entities'][force.name][entity.name] then
        player.create_local_flying_text({ text = 'Disabled by special game', position = entity.position })
        if entity.name == 'straight-rail' or entity.name == 'curved-rail' then
            player.character.get_inventory(defines.inventory.character_main).insert({ name = 'rail', count = 1 })
        else
            player.character.get_inventory(defines.inventory.character_main).insert({ name = entity.name, count = 1 })
        end
        entity.destroy()
    elseif
        entity.name == 'entity-ghost'
        and storage.special_games_variables['disabled_entities'][force.name][entity.ghost_name]
    then
        player.create_local_flying_text({ text = 'Disabled by special game', position = entity.position })
        entity.destroy()
    end
end

local function on_marked_for_upgrade(event)
    if not storage.active_special_games['disabled_entities'] then
        return
    end
    local entity = event.entity
    if not entity or not entity.valid then
        return
    end
    if not entity.get_upgrade_target() then
        return
    end
    local player = game.get_player(event.player_index)

    if storage.special_games_variables['disabled_entities'][player.force.name][entity.get_upgrade_target().name] then
        entity.cancel_upgrade(player.force)
        player.create_local_flying_text({ text = 'Disabled by special game', position = entity.position })
    end
end

local function on_pre_ghost_upgraded(event)
    if not storage.active_special_games['disabled_entities'] then
        return
    end
    local entity = event.ghost
    if not entity or not entity.valid then
        return
    end
    local player = game.get_player(event.player_index)

    if storage.special_games_variables['disabled_entities'][player.force.name][event.target.name] then
        local entityName = entity.ghost_name
        local entitySurface = entity.surface
        local entityPosition = entity.position
        local entityForce = entity.force
        entity.destroy()
        entitySurface.create_entity({
            name = 'entity-ghost',
            ghost_name = entityName,
            position = entityPosition,
            force = entityForce,
        })
        player.create_local_flying_text({ text = 'Disabled by special game', position = entityPosition })
    end
end

local Public = {
    name = { type = 'label', caption = 'Disabled entities', tooltip = 'Disables chosen entities from being placed' },
    config = {
        [1] = { name = 'eq1', type = 'choose-elem-button', elem_type = 'item' },
        [2] = { name = 'eq2', type = 'choose-elem-button', elem_type = 'item' },
        [3] = { name = 'eq3', type = 'choose-elem-button', elem_type = 'item' },
        [4] = { name = 'eq4', type = 'choose-elem-button', elem_type = 'item' },
        [5] = { name = 'eq5', type = 'choose-elem-button', elem_type = 'item' },
        [6] = { name = 'eq6', type = 'choose-elem-button', elem_type = 'item' },
        [7] = { name = 'eq7', type = 'choose-elem-button', elem_type = 'item' },
        [8] = {
            name = 'team',
            type = 'switch',
            switch_state = 'none',
            allow_none_state = true,
            tooltip = 'North / Both / South',
        },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        local team = config['team'].switch_state
        local eq = {}
        for v = 1, 1, 7 do
            if config['eq' .. v].elem_value then
                eq[config['eq' .. v].elem_value] = true
            end
        end
        eq = {
            config['eq1'].elem_value,
            config['eq2'].elem_value,
            config['eq3'].elem_value,
            config['eq4'].elem_value,
            config['eq5'].elem_value,
            config['eq6'].elem_value,
            config['eq7'].elem_value,
        }
        generate_disabled_entities(team, eq)
    end,
}

Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_marked_for_upgrade, on_marked_for_upgrade)
Event.add(defines.events.on_pre_ghost_upgraded, on_pre_ghost_upgraded)

return Public
