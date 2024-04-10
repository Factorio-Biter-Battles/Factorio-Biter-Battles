--adds a health bar and health increase to a unit
local Public = {}

---@class HighHealthUnit
---@field entity LuaEntity
---@field health_factor number
---@field original_health_factor number?
---@field healthbar_id integer?
---@field text_id integer?

---@param health_factor number
---@return string
local function health_factor_to_rendered_string(health_factor)
	-- We print the number of revives remaining, so excluding the starting health
	health_factor = health_factor - 1
	if health_factor < 1 then
		return string.format("%.1f", health_factor)
	else
		return tostring(math.floor(health_factor))
	end
end

---@param entity LuaEntity
---@param health_factor number
local function add_health_factor_text(entity, health_factor)
	local text = health_factor_to_rendered_string(health_factor)
	return rendering.draw_text({
		text = text,
		draw_on_ground = true,
		surface = entity.surface,
		target = entity,
		target_offset = {0, -3},
		scale = 1.5,
		alignment = 'center',
		color = {1, 1, 1, 1},
	})
end

---@param entity LuaEntity
---@param size number
local function create_healthbar(entity, size)
	return rendering.draw_sprite({
		sprite = "virtual-signal/signal-white",
		tint = {0, 200, 0},
		x_scale = size * 15, y_scale = size, render_layer = "light-effect",
		target = entity, target_offset={0, -2.5}, surface = entity.surface,
	})
end

---@param healthbar_id number
---@param health number
local function set_healthbar(healthbar_id, health)
	local x_scale = rendering.get_y_scale(healthbar_id) * 15
	rendering.set_x_scale(healthbar_id, x_scale * health)
	rendering.set_color(healthbar_id, {math.floor(255 - 255 * health), math.floor(200 * health), 0})
end

---@param entity LuaEntity
---@param health_factor number
---@param is_boss boolean
function Public.add_high_health_unit(entity, health_factor, is_boss)
	if health_factor <= 1 then return end
	---@type HighHealthUnit
	local unit = {entity = entity, health_factor = health_factor}
	if is_boss then
		unit.healthbar_id = create_healthbar(entity, 0.55)
		unit.original_health_factor = health_factor
	end
	if global.bb_draw_health_factor_text then
		unit.text_id = add_health_factor_text(entity, health_factor)
	end
	global.high_health_units[entity.unit_number] = unit
end

---@param event EventData.on_entity_damaged
local function on_entity_damaged(event)
	local entity = event.entity
	---@type HighHealthUnit
	local unit = global.high_health_units[entity.unit_number]
	if not unit then return end
	if entity.health == 0 then
		local adjustment = math.min(unit.health_factor - 1, 1)
		entity.health = entity.prototype.max_health * adjustment
		unit.health_factor = unit.health_factor - adjustment
		if unit.healthbar_id then
			set_healthbar(unit.healthbar_id, unit.health_factor / unit.original_health_factor)
		end
		-- Slightly over 1 just to deal with weird floating point math possibilities
		if unit.health_factor <= 1.0000001 then
			global.high_health_units[entity.unit_number] = nil
			-- We do not destroy unit.healthbar_id here because we want it to
			-- remain visible for the units "last life". It will automatically
			-- be destroyed when "entity" is destroyed.
			if unit.text_id then rendering.destroy(unit.text_id) end
		else
			if unit.text_id then
				rendering.set_text(unit.text_id, health_factor_to_rendered_string(unit.health_factor))
			end
		end
	end
end

script.on_event(defines.events.on_entity_damaged, on_entity_damaged,
	{{filter = "type", type = "unit"}, {filter = "final-health", comparison = "=", value = 0, mode = "and"}})

return Public
