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
        'battery-mk2-equipment',
        'fission-reactor-equipment',   
        'exoskeleton-equipment',
        'personal-roboport-mk2-equipment',
        'construction-robot',        
        'electric-mining-drill',
    }
    local gap = 3
    local operable = false
    local surface = game.surfaces[storage.bb_surface_name]
    local position_0 = { x = 0, y = -43 }
    local objects = surface.find_entities_filtered({ name = 'infinity-chest' })
    for _, object in pairs(objects) do
        object.destroy()
    end
    local k = gap + 1
    for i, v in pairs(eq) do
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

    local texts = {
        "SPECIAL GAME - mk2 Fordeka ",
        "Free items, Fast hand mining, Fast bots.",
        }
    local position = {0, -30}
    local area = {{position[1] - 5, position[2] - 5}, {position[1] + 5, position[2] + 5}}
    local existing_chests = surface.find_entities_filtered{area = area, name = "wooden-chest"}
    if #existing_chests > 0 then
        game.print("special game text above island has been changed")
        existing_chests[1].destroy()
    end
    
    local chest = surface.create_entity({name = "wooden-chest", position = {0, -35}})

    chest.destructible = false
    chest.minable_flag = false
    chest.rotatable = false
    chest.operable = false

    for i, text in ipairs(texts) do
        local color = i % 2 == 0 and {255, 255, 0} or {255, 200, 0}
        rendering.draw_text {
        text = text,
        surface = surface,
        target = { entity = chest, offset = {0, 2 * i} },
        color = color,
        scale = 2.00,
        font = "heading-1",
        alignment = "center",
        scale_with_zoom = false
        }
    end
end

local Public = {
    name = {
        type = 'label',
        caption = 'mk2Fordeka',
        tooltip = 'classic fordeka special, hand miming speed 4000, bots speed 15, bots tech, mk2, bots, drills, battery, exoskeleton, fission-reactor, personal-roboport',
    },
    config = {},
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)  
            generate_fordeka()
    end,
}

return Public
