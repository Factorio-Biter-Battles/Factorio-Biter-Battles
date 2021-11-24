--Adds a small gui to quick select an icon tag for your character - mewmew

local Event = require 'utils.event'
local BiterRaffle = require "maps.biter_battles_v2.biter_raffle"
local Feeding = require "maps.biter_battles_v2.feeding"
local Tables = require "maps.biter_battles_v2.tables"
require 'utils.gui_styles'

local function draw_top_gui(player)
	if player.gui.top.simple_stats then return end
	local button = player.gui.top.add({type = "sprite-button", name = "simple_stats", caption = "Stats"})
	button.style.font = "heading-2"
	button.style.font_color = {212, 212, 212}
	element_style({element = button, x = 38, y = 38, pad = -2})
end

local function get_upcoming_biter_tier_list_from_current_evo(evo)
	local biters_tiers = {}
	if evo < Tables.biter_mutagen_thresholds["medium"] then
		table.insert(biters_tiers, "medium")
	end
	if evo < Tables.biter_mutagen_thresholds["big"] then
		table.insert(biters_tiers, "big")
	end
	if evo < Tables.biter_mutagen_thresholds["behemoth"] then
		table.insert(biters_tiers, "behemoth")
	end
	return biters_tiers
end

local function calculate_needed_food(biter_force_name, current_threshold, current_evo, current_evo_factor, food_value, player)
	local evo = current_evo
	local evo_factor = current_evo_factor
	local count = 0
	while (evo*1000 < current_threshold) do
		local e2 = Feeding.calculate_e2(evo_factor)
		local evo_gain = Feeding.evo_gain_from_one_flask(food_value, e2)
		evo = evo + evo_gain
		evo_factor = Feeding.get_new_evo_factor_from_evolution(evo)
		count = count + 1
	end
	return count
end

local function add_biter_puberty_thresholds_for_team(t, team, player)
	local biter_force_name = team.."_biters"
	local current_evo = global.bb_evolution[biter_force_name]
	local current_evo_factor = game.forces[biter_force_name].evolution_factor
	local upcoming_biter_list = get_upcoming_biter_tier_list_from_current_evo(current_evo)
	if #upcoming_biter_list == 0 then
		return
	end

	local l = t.add({ type="label", caption = team })
	for _=1,7 do t.add({type="label", caption= ""}) end

	local l = t.add({ type="label", caption = "Evo: " .. tostring(global.bb_evolution[biter_force_name]*100)})
	for _=1,7 do t.add({type="label", caption= ""}) end

	t.add({type="label", caption= ""})
	for k, v in pairs(Tables.food_values) do
		t.add({type="sprite", sprite="item/"..k})
	end

	for _, v in ipairs(upcoming_biter_list) do
		local c_threshold = Tables.biter_mutagen_thresholds[v]
		t.add({type="sprite", sprite="entity/"..v.."-biter"})
		for kk, vv in pairs(Tables.food_values) do
			local needed = calculate_needed_food(biter_force_name, c_threshold, current_evo, current_evo_factor, vv.value*global.difficulty_vote_value, player)
			t.add({type="label", caption=string.format("%7d", needed)})
		end
	end
	for _=1,8 do t.add({type="label", caption= ""}) end
end

local function add_biter_puberty_thresholds_to_table(t, player)
	for _, x in pairs({"north", "south"}) do
		add_biter_puberty_thresholds_for_team(t, x, player)
	end
end

local function draw_screen_gui(player)
	local frame = player.gui.screen.simple_stats_frame
	if player.gui.screen.simple_stats_frame then
		frame.destroy()
		return
	end
	
	local frame = player.gui.screen.add({
		type = "frame",
		name = "simple_stats_frame",
		direction = "vertical",
	})
	local t = frame.add { type = "table", column_count = 8 }
	frame.location = {x = 3, y = 39 * player.display_scale}
	frame.style.padding = -2
	add_biter_puberty_thresholds_to_table(t, player)
end

local function on_player_joined_game(event)
	local player = game.players[event.player_index]
	draw_top_gui(player)
end

local function on_gui_click(event)
	local element = event.element
	if not element then return end
	if not element.valid then return end
	
	local name = element.name
	if name == "simple_stats" then
		local player = game.players[event.player_index]
		draw_screen_gui(player)
		return
	end
	
	local parent = element.parent
	if not parent then return end
	if not parent.valid then return end
	if not parent.name then return end
	if parent.name ~= "simple_stats_frame" then return end	
	
	local player = game.players[event.player_index]	
	local selected_tag = element.name
	
	if player.tag == selected_tag then
		selected_tag = "" end
	player.tag = selected_tag
	parent.destroy()
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
