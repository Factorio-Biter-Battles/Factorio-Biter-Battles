--adds a health bar and health increase to a unit
local Public = {}

local function create_healthbar(entity, size)
	global.update_text_index = entity.unit_number
	return rendering.draw_sprite({
		sprite="virtual-signal/signal-white",
		tint={0, 200, 0},
		x_scale=size * 15, y_scale=size, render_layer="light-effect",
		target=entity, target_offset={0, -2.5}, surface=entity.surface,
	}),
	rendering.draw_text({
		text = 0,
		surface=entity.surface,
		target=entity,
		target_offset={0, -3},
		scale = 1.5,
		alignment='center',
		color={1, 1, 1, 1},
	})
end

local function set_healthbar(boss_unit)
	local m = boss_unit.health / boss_unit.max_health
	local x_scale = rendering.get_y_scale(boss_unit.healthbar_id) * 15
	rendering.set_x_scale(boss_unit.healthbar_id, x_scale * m)
	rendering.set_color(boss_unit.healthbar_id, {math.floor(255 - 255 * m), math.floor(200 * m), 0})
end

function Public.add_boss_unit(entity, health_factor, size)
	if not entity then return end
	if not entity.unit_number then return end
	if not health_factor then return end
	local health = math.floor(entity.prototype.max_health * health_factor)
	if health == 0 then return end
	local s = 0.5
	if size then s = size end
	local healthbar_id, healthtext_id = create_healthbar(entity, s)
	global.boss_units[entity.unit_number] = {entity = entity, max_health = health, health = health, healthbar_id = healthbar_id, healthtext_id = healthtext_id, last_update = game.tick}
end

local function on_entity_damaged(event)
	local entity = event.entity
	local boss = global.boss_units[entity.unit_number]
	if not boss then return end
	entity.health = entity.health + event.final_damage_amount
	boss.health = boss.health - event.final_damage_amount
	if boss.health <= 0 then
		global.boss_units[entity.unit_number] = nil
		rendering.destroy(boss.healthtext_id)
		entity.die()

		if not next(global.boss_units) then
			global.update_text_index = nil
		end
	else
		if boss.last_update + 30 < game.tick then
			set_healthbar(global.boss_units[entity.unit_number])
			boss.last_update = game.tick
		end
	end
end

local function on_tick()
	if global.update_text_index then
		local current_boss = global.boss_units[global.update_text_index]
		if current_boss then
			rendering.set_text(current_boss.healthtext_id, math.floor(current_boss.health))
			global.update_text_index = next(global.boss_units, global.update_text_index)
			if not global.update_text_index then
				global.update_text_index = next(global.boss_units)
			end
		else
			global.update_text_index = next(global.boss_units)
		end
	end
end

local function on_init()
	global.boss_units = {}
end

local event = require 'utils.event'
event.on_init(on_init)
event.add(defines.events.on_entity_damaged, on_entity_damaged)
event.add(defines.events.on_tick, on_tick)
event.add_event_filter(defines.events.on_entity_damaged, {
	filter = "type",
	type = "unit",
})

return Public
