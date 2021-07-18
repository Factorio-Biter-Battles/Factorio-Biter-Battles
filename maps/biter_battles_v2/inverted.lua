local Event = require 'utils.event'
local Tables = require "maps.biter_battles_v2.tables"

base_silo_bonus_health = 1000000

local Public = {}

function Public.init()
    global.silo_bonus_health = {}
    global.silo_bonus_health_text_id = {}

    for force, silo in pairs(global['rocket_silo']) do

        global.silo_bonus_health[force] = base_silo_bonus_health
		
        global.silo_bonus_health_text_id[force] =
            rendering.draw_text {
                text = "HP: " .. global.silo_bonus_health[force] .. " / " ..
                    base_silo_bonus_health,
                surface = silo.surface,
                target = silo,
                target_offset = {0, -2.5},
                color = {255, 255, 0},
                scale = 1.00,
                font = "heading-1",
                alignment = "center",
                scale_with_zoom = true
            }

            game.forces[force].friendly_fire = false
    end
end

function Public.disable_mode()
	rendering.clear()
    for force, v in pairs(Tables.enemy_team_of) do
        game.forces[force].friendly_fire = true
    end
    global.silo_bonus_health = {}
    global.silo_bonus_health_text_id = {}
    global.bb_settings.inverted = false
end

local function on_entity_damaged(event)
    if global.bb_settings.inverted then
        local entity = event.entity
        local surface = entity.surface
        if not entity.valid then return end
        if entity.name == 'rocket-silo' then
            local silo = global['rocket_silo']['north']
            local force_name = 'north'
            if entity.unit_number == global['rocket_silo']['north'].unit_number then
                force_name = 'north'
            else
                force_name = 'south'
                silo = global['rocket_silo']['south']
            end

            global['silo_bonus_health'][force_name] =
                global['silo_bonus_health'][force_name] -
                    event.final_damage_amount

            if (global['silo_bonus_health'][force_name] < 0) then
                silo.health = silo.health +
                                  global['silo_bonus_health'][force_name]
                global['silo_bonus_health'][force_name] = 0
            else
                -- restore hp to silo
                silo.health = silo.health + event.final_damage_amount
            end
            local health_text = "HP: " ..
                                    math.round(
                                        global['silo_bonus_health'][force_name],
                                        0) .. " / " .. base_silo_bonus_health
            rendering.set_text(global['silo_bonus_health_text_id'][force_name],
                               health_text)
        end
    end
end

Event.add(defines.events.on_entity_damaged, on_entity_damaged)

return Public
