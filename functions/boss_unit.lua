--adds a health bar and health increase to a unit
local Public = {}
local healthbartext_playerlist

local function create_healthbar(entity, size)
	global.next_healthbar_update = entity.unit_number

	local healthbar_id = rendering.draw_sprite({
		sprite="virtual-signal/signal-white",
		tint={0, 200, 0},
		x_scale=size * 15, y_scale=size, render_layer="light-effect",
		target=entity, target_offset={0, -2.5}, surface=entity.surface,
	})

	local healthtext_id = rendering.draw_text({
		text = 0,
		surface=entity.surface,
		target=entity,
		target_offset={0, -3},
		scale = 1.5,
		alignment='center',
		color={1, 1, 1, 1},
		players=healthbartext_playerlist, --need to do this because empty playerlist means no filter and cannot give it fake names
		visible=#healthbartext_playerlist > 0,
	})

	return healthbar_id, healthtext_id
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
	global.boss_units[entity.unit_number] = {entity = entity, max_health = health, health = health, healthbar_id = healthbar_id, healthtext_id = healthtext_id}
end

function Public.healthbarnumbers_enable_for_player(playerName, enable)
	local foundIndex, didChanges
	for i = 1, #healthbartext_playerlist do
		if healthbartext_playerlist[i] == playerName then
			foundIndex = i
			break
		end
	end

	if (enable) then
		if not foundIndex then
			didChanges = true
			table.insert(healthbartext_playerlist, playerName)
		end
	else
		if (foundIndex) then
			didChanges = true
			table.remove(healthbartext_playerlist, foundIndex)
		end
	end

	if didChanges then
		for _,boss in pairs(global.boss_units) do
			rendering.set_visible(boss.healthtext_id ,#healthbartext_playerlist>0)
			rendering.set_players(boss.healthtext_id ,healthbartext_playerlist)
		end
	end
end

function Public.healthbarnumbers_enabled_for_player(playerName)
	for i = 1, #healthbartext_playerlist do
		if healthbartext_playerlist[i] == playerName then
			return true
		end
	end
end

local function on_entity_damaged(event)
	local entity = event.entity
	local boss = global.boss_units[entity.unit_number]
	if not boss then return end
	entity.health = entity.health + event.final_damage_amount
	boss.health = boss.health - event.final_damage_amount
	if boss.health <= 0 then
		global.boss_units[entity.unit_number] = nil
		entity.die()
		if not next(global.boss_units) then
			global.next_healthbar_update = nil
		end
	end
end

local function on_tick()
	if global.next_healthbar_update then
		local current_boss = global.boss_units[global.next_healthbar_update]
		if current_boss then
			-- update healthbar
			local m = current_boss.health / current_boss.max_health
			local x_scale = rendering.get_y_scale(current_boss.healthbar_id) * 15
			rendering.set_x_scale(current_boss.healthbar_id, x_scale * m)
			rendering.set_color(current_boss.healthbar_id, {math.floor(255 - 255 * m), math.floor(200 * m), 0})

			local text = 0
			if current_boss.health >= 10^6 then
		        text = string.format("%.2fM", current_boss.health / 10^6)
		    elseif current_boss.health >= 10^3 then
		        text = string.format("%.2fK", current_boss.health / 10^3)
		    else
		        text = tostring(current_boss.health)
		    end
			rendering.set_text(current_boss.healthtext_id, text)

			global.next_healthbar_update = next(global.boss_units, global.next_healthbar_update)
			if not global.next_healthbar_update then
				global.next_healthbar_update = next(global.boss_units)
			end
		else
			global.next_healthbar_update = next(global.boss_units)
		end
	end
end

local function on_init()
	global.boss_units = {}
	healthbartext_playerlist = {}
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
