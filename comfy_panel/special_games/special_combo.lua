local Color = require('utils.color_presets')

local function generate_fordeka()
    game.print('Generated special: fordeka', { color = Color.warning })
    for k, force in pairs({ 'north', 'south' }) do
        game.forces[force].manual_mining_speed_modifier = 4000
        game.forces[force].technologies['construction-robotics'].researched = true
        game.forces[force].technologies['worker-robots-speed-1'].researched = true
        game.forces[force].technologies['worker-robots-speed-2'].researched = true
        game.forces[force].technologies['worker-robots-speed-3'].researched = true
        game.forces[force].technologies['worker-robots-speed-4'].researched = true
        game.forces[force].technologies['worker-robots-speed-5'].researched = true
        game.forces[force].technologies['worker-robots-speed-6'].level = 15
    end
    local eq = {
        'power-armor-mk2',
        'personal-roboport-mk2-equipment',
        'battery-mk2-equipment',
        'exoskeleton-equipment',
        'construction-robot',
        'fission-reactor-equipment',
        'electric-mining-drill',
    }
    local gap = 0
    local operable = false
    local surface = game.surfaces[storage.bb_surface_name]
    local position_0 = { x = 0, y = -43 }
    local objects = surface.find_entities_filtered({ name = 'infinity-chest' })
    for _, object in pairs(objects) do
        object.destroy()
    end
    local k = gap + 1
    for i, v in ipairs(eq) do
        local chest = surface.create_entity({
            name = 'infinity-chest',
            position = position_0,
            force = 'neutral',
            fast_replace = true,
        })
        chest.minable_flag = false
        chest.operable = operable
        chest.destructible = false
        chest.set_infinity_container_filter(i, { name = v, index = i, count = prototypes.item[v].stack_size })
        chest.clone({ position = { position_0.x, -position_0.y } })
        position_0.x = position_0.x + (i * k)
        k = k * -1
    end
    storage.active_special_games['infinity_chest'] = true
    local special = storage.special_games_variables['infinity_chest']
    if not special then
        special = { freebies = {} }
        storage.special_games_variables['infinity_chest'] = special
    end
    for i, v in ipairs(eq) do
        special.freebies[v] = true
    end
end

local function generate_carl3()
    game.print('Generated special: carl', { color = Color.warning })
    for k, force in pairs({ 'north', 'south' }) do
        game.forces[force].manual_mining_speed_modifier = 4000
        game.forces[force].technologies['construction-robotics'].researched = true
        game.forces[force].technologies['worker-robots-speed-1'].researched = true
        game.forces[force].technologies['worker-robots-speed-2'].researched = true
        game.forces[force].technologies['worker-robots-speed-3'].researched = true
        game.forces[force].technologies['worker-robots-speed-4'].researched = true
    end
    local eq = {
        'modular-armor',
        'battery-mk2-equipment',
        'exoskeleton-equipment',
        'solar-panel-equipment',
    }
    local gap = 0
    local operable = false
    local surface = game.surfaces[storage.bb_surface_name]
    local position_0 = { x = 0, y = -43 }
    local objects = surface.find_entities_filtered({ name = 'infinity-chest' })
    for _, object in pairs(objects) do
        object.destroy()
    end
    local k = gap + 1
    for i, v in ipairs(eq) do
        local chest = surface.create_entity({
            name = 'infinity-chest',
            position = position_0,
            force = 'neutral',
            fast_replace = true,
        })
        chest.minable_flag = false
        chest.operable = operable
        chest.destructible = false
        chest.set_infinity_container_filter(i, { name = v, index = i, count = prototypes.item[v].stack_size })
        chest.clone({ position = { position_0.x, -position_0.y } })
        position_0.x = position_0.x + (i * k)
        k = k * -1
    end
    storage.active_special_games['infinity_chest'] = true
    local special = storage.special_games_variables['infinity_chest']
    if not special then
        special = { freebies = {} }
        storage.special_games_variables['infinity_chest'] = special
    end
    for i, v in ipairs(eq) do
        special.freebies[v] = true
    end
end

local Public = {
    name = {
        type = 'label',
        caption = 'special combo',
        tooltip = 'use pre-defined settings',
    },
    config = {
        [1] = {
            name = 'names',
            type = 'drop-down',
            items = { 'fordeka', 'carl3' },
        },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        if tonumber(config['names'].selected_index) == 1 then
            generate_fordeka()
        end
        if tonumber(config['names'].selected_index) == 2 then
            generate_carl3()
        end
    end,
}

return Public
