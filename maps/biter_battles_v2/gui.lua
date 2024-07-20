local Public = {}
global.player_data_afk = {}
local Server = require "utils.server"
local Color = require 'utils.color_presets'

local bb_config = require "maps.biter_battles_v2.config"
local bb_diff = require "maps.biter_battles_v2.difficulty_vote"
local event = require "utils.event"
local Functions = require "maps.biter_battles_v2.functions"
local Feeding = require "maps.biter_battles_v2.feeding"
local ResearchInfo = require "maps.biter_battles_v2.research_info"
local TeamStatsCompare = require "maps.biter_battles_v2.team_stats_compare"
local Tables = require "maps.biter_battles_v2.tables"
local DifficultyVote = require 'maps.biter_battles_v2.difficulty_vote'
local Captain_event = require "comfy_panel.special_games.captain"
local player_utils = require "utils.player"

local wait_messages = Tables.wait_messages
local food_names = Tables.gui_foods
local automation_feed = Tables.food_values["automation-science-pack"].value * 75

local math_random = math.random
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local string_format = string.format

local Gui = require 'utils.gui'
local gui_style = require "utils.utils".gui_style
local has_life = require "comfy_panel.special_games.limited_lives".has_life
local gui_values = {
	["north"] = {
		force_name = "north",
		biter_force = "north_biters",
		n1 = "join_north_button",
		t1 = "Evolution of north side biters.",
		t2 = "Threat causes biters to attack. Reduces when biters are slain.",
		color1 = { r = 0.55, g = 0.55, b = 0.99 },
		color2 = { r = 0.66, g = 0.66, b = 0.99 },
	},
	["south"] = {
		force_name = "south",
		biter_force = "south_biters",
		n1 = "join_south_button",
		t1 = "Evolution of south side biters.",
		t2 = "Threat causes biters to attack. Reduces when biters are slain.",
		color1 = { r = 0.99, g = 0.33, b = 0.33 },
		color2 = { r = 0.99, g = 0.44, b = 0.44 },
	}
}

-- The on_player_joined_team event is raised only once when a player joins a team for the first time
-- at this stage, the player already has a character and starting items
-- @usage
-- local Gui = require "maps.biter_battles_v2.gui"
-- local Event = require 'utils.event'
--
-- Event.add(Gui.events.on_player_joined_team,
-- function(event)
--      local player = game.get_player(event.player_index)
-- end)
Public.events = {on_player_joined_team = event.generate_event_name()}

function Public.clear_copy_history(player)
	if player and player.valid and player.cursor_stack then
		for i = 1, 21 do
			-- Imports blueprint of single burner miner into the cursor stack
			stack = player.cursor_stack.import_stack(
				"0eNp9jkEKgzAURO8y67jQhsbmKqUUrR/5kHwliVKR3L3GbrrqcoaZN7OjdwvNgSXB7uDXJBH2viPyKJ0rXtpmggUn8lCQzhfVL0EoVJ6FZayGwM4hK7AM9Iat80OBJHFi+uJOsT1l8T2FI/AXpDBP8ehOUvYPnjYKG2x1bXMhn1fsz3OFlUI8801ba3NrzEVroxud8wdvA0sn")
			player.add_to_clipboard(player.cursor_stack)
			player.clear_cursor()
		end
	end
end

function Public.reset_tables_gui()
	global.player_data_afk = {}
end

function Public.create_biter_gui_button(player)
	local button = Gui.add_top_button(player,{ type = "sprite-button", name = "bb_toggle_button", sprite = "entity/big-biter", tooltip = "[font=default-bold]Game Info[/font] - Toggle left gui" })
end

function Public.create_statistics_gui_button(player)
	if Gui.get_top_button(player, 'bb_toggle_statistics') then
		return
	end

	local summary = Gui.add_top_button(player, { type = "sprite-button", name = "bb_toggle_statistics", sprite = "utility/expand", tooltip = 'Show game status!' })

	local frame = summary.parent.add { type = 'frame', name = 'bb_frame_statistics', style = 'finished_game_subheader_frame' }
	frame.location = { x = 1, y = 38 }
	gui_style(frame, { minimal_height = 36, maximal_height = 36 })

	local label, line

	label = frame.add({ type = 'label', caption = 'North', name = 'north_name'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.north.color1 })

	label = frame.add({ type = 'label', caption = ' ', name = 'north_players'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = { 165, 165, 165 } })

	line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line' })

	label = frame.add({ type = 'label', caption = ' ', name = 'north_evolution', font_color = { 165, 165, 165 }})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.north.color1 })

	line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line' })

	label = frame.add({ type = 'label', caption = ' ', name = 'north_threat'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.north.color1 })

	line = frame.add({ type = 'line', direction = 'vertical' })

	label = frame.add({ type = 'label', caption = '00:00', name = 'clock'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = { 165, 165, 165 } })

	line = frame.add({ type = 'line', direction = 'vertical' })

	label = frame.add({ type = 'label', caption = ' ', name = 'south_threat'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.south.color1 })

	line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line', font_color = { 165, 165, 165 } })

	label = frame.add({ type = 'label', caption = ' ', name = 'south_evolution'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.south.color1 })

	line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line' })

	label = frame.add({ type = 'label', caption = ' ', name = 'south_players'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = { 165, 165, 165 } })

	label = frame.add({ type = 'label', caption = 'South', name = 'south_name'})
	gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.south.color1 })

	Public.refresh_statistics(player)
	frame.visible = false
end

Gui.on_click('bb_toggle_statistics', function (event)
	local button = event.element
	local player = event.player

	local default = button.sprite == 'utility/expand'
	button.sprite = default and 'utility/collapse' or 'utility/expand' 
	button.tooltip = default and 'Hide game status!' or 'Show game status!'

	local frame = Gui.get_top_button(player, 'bb_frame_statistics')
	if frame then
		frame.visible = not frame.visible
	end
end)

local style = {
	bold = function(str) return '[font=default-bold]'..str..'[/font]' end,
	listbox = function(str) return '[font=default-listbox]'..str..'[/font]' end,
	stat = function(str) return '[font=count-font]'..str..'[/font]' end,
	green = function(str) return '[color=green]'..str..'[/color]' end,
	yellow = function(str) return '[color=yellow]'..str..'[/color]' end,
	red = function(str) return '[color=red]'..str..'[/color]' end,
	blue = function(str) return '[color=blue]'..str..'[/color]' end,
}

---@param frame LuaGuiElement
local function create_clock(frame)
	local inner_frame = frame.add { type = "flow", name = "bb_main_clock_flow", direction = "horizontal" }
	local clock_ui = inner_frame.add { type = "label", name = "bb_main_clock_label"}
	clock_ui.style.font = "default-bold"
	clock_ui.style.font_color = { r = 0.98, g = 0.66, b = 0.22 }

	ResearchInfo.create_research_info_button(inner_frame)
end

local function get_format_time()
	local time_caption = "Not started"
	local total_ticks = Functions.get_ticks_since_game_start()
	if total_ticks > 0 then
		local total_minutes = math_floor(total_ticks / (60 * 60))
		local total_hours = math_floor(total_minutes / 60)
		local minutes = total_minutes - (total_hours * 60)
		time_caption = string_format("%02d:%02d", total_hours, minutes)
	end
	return time_caption
end

---@param frame LuaGuiElement
---@param player LuaPlayer
local function update_clock(frame, player)
	frame.bb_main_clock_flow.bb_main_clock_label.caption = string_format("Time: %s   Speed: %.2f", get_format_time(), game.speed)
	
	local is_spec = player.force.name == "spectator"
	frame.bb_main_clock_flow.research_info_button.visible =
		global.bb_show_research_info == "always"
		or (global.bb_show_research_info == "spec" and is_spec)
		or (global.bb_show_research_info == "pure-spec" and not global.chosen_team[player.name])
end

---@param force string
---@return string
local function get_player_list_caption(force_name)
	local players_with_colors = player_utils.get_sorted_colored_player_list(game.forces[force_name].connected_players)
	return table.concat(players_with_colors, "    ")
end

---@param threat_value number
---@return string
function threat_to_pretty_string(threat_value)
	if math_abs(threat_value) >= 1000000 then
		return string_format("%.2fM", threat_value / 1000000)
	elseif math_abs(threat_value) >= 100000 then
		return string_format("%.0fk", threat_value / 1000)
	else
		return string_format("%.0f", threat_value)
	end
end

function Public.create_main_gui(player)
	local is_spec = player.force.name == 'spectator' or not global.chosen_team[player.name]
	if player.gui.left.bb_main_gui then
		player.gui.left.bb_main_gui.destroy()
	end
	
	local main_frame = player.gui.left.add { type = 'frame', name = 'bb_main_gui', direction = 'vertical', caption = 'Biter menu' }
	gui_style(main_frame, { padding = 2, font_color = { 165, 165, 165 }, font = 'heading-3' })

	local flow = main_frame.add { type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' }
	local inner_frame = flow.add { type = 'frame', name = 'inner_frame', style = 'window_content_frame_packed', direction = 'vertical' }
	local subheader = inner_frame.add { type = 'frame', name = 'subheader', style = 'subheader_frame' }
	gui_style(subheader, { horizontally_stretchable = true, use_header_filler = true })
	
	create_clock(subheader)

	local sp = inner_frame.add { type = 'scroll-pane', name = 'scroll_pane', style = 'scroll_pane_under_subheader', direction = 'vertical' }

	-- Science sending GUI
	local science_frame = sp.add { type = 'frame', name = 'science_frame', style = 'bordered_frame', direction = 'vertical', caption = 'Feeding' }
	gui_style(science_frame, { horizontally_stretchable = true, horizontal_align = 'center' })

	local flow = science_frame.add { type = 'flow', direction = 'vertical' }
	gui_style(flow, { horizontally_stretchable = true, horizontal_align = 'center' })

	local table_frame = flow.add { type = 'frame', name = 'table_frame', direction = 'horizontal', style = 'quick_bar_inner_panel' } --slot_button_deep_frame, quick_bar_window_frame
	gui_style(table_frame, { horizontally_stretchable = true, margin = 0, use_header_filler = false })

	local t = table_frame.add { type = 'table', name = 'bb_main_send_table', column_count = 5, style = 'filter_slot_table' }
	gui_style(t, { horizontally_stretchable = true })

	for food_name, tooltip in pairs(food_names) do
		local s = t.add { type = 'sprite-button', name = food_name, sprite = 'item/' .. food_name, style = 'quick_bar_slot_button' }
		gui_style(s, { minimal_height = 41, minimal_width = 41, padding = 0 })
	end
	local s = t.add { type = 'sprite-button', name = 'send_all', caption = 'All', style = 'quick_bar_slot_button' }
	gui_style(s, { minimal_height = 41, minimal_width = 41, padding = 0, font_color = { r = 0.9, g = 0.9, b = 0.9 } })

	-- Join
	local join_frame = sp.add { type = 'frame', name = 'auto_frame', style = 'bordered_frame', direction = 'horizontal', caption = 'Join' }
	gui_style(join_frame, { horizontally_stretchable = true })

	local t = join_frame.add { type = 'table', column_count = 3}
	gui_style(t, { vertical_align = 'center' })

	local button = t.add { type = 'button', name = 'join_north', caption = 'North ', style = 'back_button' }
	gui_style(button, { font = 'default-semibold', font_color = Color.dark_blue, width = 80, height = 24, horizontal_align = 'right' })

	local button = t.add { type = 'button', name = 'join_random_button', caption = 'Random', style = 'dialog_button' }
	gui_style(button, { font = 'default-semibold', font_color = Color.dark_green, width = 90, height = 24 })

	local button = t.add { type = 'button', name = 'join_south', caption = ' South', style = 'forward_button' }
	gui_style(button, { font = 'default-semibold', font_color = Color.dark_red, width = 80, height = 24, horizontal_align = 'left' })

	if true then return end

	local first_team = true
	local view_player_list = global.bb_view_players[player.name]
	if view_player_list == nil then view_player_list = true end
	for force_name, gui_value in pairs(gui_values) do
		-- Line separator
		if not first_team then
			frame.add { type = "line", direction = "horizontal" }
		else
			first_team = false
		end

		-- Team name & Player count
		local t = frame.add { type = "table", name = "team_name_table_" .. force_name, column_count = 4 }

		-- Team name
		local l = t.add { type = "label", name = "team_name" }
		gui_style(l, { font = "default-bold", font_color = gui_value.color1, single_line = false, maximal_width = 102 })
		-- Number of players
		local l = t.add { type = "label", caption = " - " }
		local l = t.add { type = "label", name = "team_player_count" }
		l.style.font = "default"
		l.style.font_color = { r = 0.22, g = 0.88, b = 0.22 }

		-- Player list
		local l = frame.add { type = "label", name = "player_list_" .. force_name }
		l.style.single_line = false
		l.style.maximal_width = 350

		-- Statistics
		local t = frame.add { type = "table", name = "stats_" .. force_name, column_count = 5 }

		-- Evolution
		local l = t.add { type = "label", name = "evo_label_" .. force_name, caption = "Evo:" }
		--l.style.minimal_width = 25

		local l = t.add { type = "label", name = "evo_value_label_" .. force_name }
		l.style.minimal_width = 40
		l.style.font_color = gui_value.color2
		l.style.font = "default-bold"
		l.tooltip = tooltip

		-- Threat
		local l = t.add { type = "label", name = "threat_label_" .. force_name, caption = "Threat: " }
		l.style.minimal_width = 25

		local threat_value = threat_to_pretty_string(global.bb_threat[gui_value.biter_force])
		local l = t.add { type = "label", name = "threat_" .. force_name, caption = threat_value }
		l.style.font_color = gui_value.color2
		l.style.font = "default-bold"
		l.style.width = 50
		l.tooltip = gui_value.t2

		-- Join button
		local c = "JOIN "
		local font_color = gui_value.color1
		local b = frame.add { type = "sprite-button", name = gui_value.n1, caption = c }
		b.style.font = "default-large-bold"
		b.style.font_color = font_color
		b.style.width = 350
	end

	frame.add { type = "line", direction = "horizontal" }
	-- Action horizontal flow
	local flow = frame.add { type = "flow", name = "bb_main_action_flow", direction = "horizontal" }
	local b = flow.add { type = "sprite-button", name = "bb_leave_spectate", caption = "Rejoin Team" }
	local b = flow.add { type = "sprite-button", name = "bb_spectate", caption = "Spectate" }

	-- Playerlist button
	local b = flow.add { type = "sprite-button", name = "bb_hide_players", caption = "Playerlist" }
	local b = flow.add { type = "sprite-button", name = "bb_view_players", caption = "Playerlist" }

	for _, b in pairs(flow.children) do
		b.style.font = "default-bold"
		b.style.font_color = { r = 0.98, g = 0.66, b = 0.22 }
		b.style.top_padding = 1
		b.style.left_padding = 1
		b.style.right_padding = 1
		b.style.bottom_padding = 1
		b.style.maximal_height = 30
		b.style.width = 86
	end
	Public.refresh_main_gui(player)
end

---@param player LuaPlayer
function Public.refresh_statistics(player)
	local frame = Gui.get_top_button(player, 'bb_frame_statistics')
	if not frame or not frame.visible then
		return
	end

	local difficulty = DifficultyVote.difficulty_name()
	local color = DifficultyVote.difficulty_print_color()
	frame.clock.caption = get_format_time()
	frame.clock.tooltip = style.listbox('Difficulty: ') .. style.stat(string_format('[color=%.2f,%.2f,%.2f]%s[/color]', color.r, color.g, color.b, difficulty)) .. 
		string_format(style.listbox('\nGame speed: ') .. style.yellow(style.stat('%.2f')), game.speed)

	for force_name, gui_value in pairs(gui_values) do
		local biter_force = game.forces[gui_value.biter_force]
		local damage, revive = (biter_force.get_ammo_damage_modifier('melee') + 1) * 100, global.reanim_chance[biter_force.index]
		local evolution_tooltip = style.listbox('Damage: ') .. style.yellow(style.stat(damage)) .. style.listbox('%\nRevive: ') .. style.yellow(style.stat(revive)) .. style.listbox('%')

		frame[force_name..'_name'].tooltip = style.bold(Functions.team_name(force_name))
		
		frame[force_name..'_players'].caption = '(' .. style.green(#game.forces[force_name].connected_players) .. ')'
		frame[force_name..'_players'].tooltip = get_player_list_caption(force_name)

		frame[force_name..'_evolution'].caption = (math_floor(1000 * global.bb_evolution[biter_force.name]) * 0.1) .. '%'
		frame[force_name..'_evolution'].tooltip = evolution_tooltip
		
		frame[force_name..'_threat'].caption = threat_to_pretty_string(global.bb_threat[biter_force.name])
		frame[force_name..'_threat'].tooltip = style.listbox('Passive feed:') .. style.yellow(style.stat(' +'..math_ceil(automation_feed * global.evo_raise_counter)))
	end
end

function Public.refresh_main_gui(player)
	local is_spec = player.force.name == "spectator" or not global.chosen_team[player.name]
	local frame = player.gui.left["bb_main_gui"]
	if not frame then return end
	
	if true then return end

	update_clock(frame.flow.subheader, player)
	-- Science sending GUI
	if not is_spec and not global.bb_game_won_by_team then
		local t = frame["bb_main_send_table"]
		t.visible = true
		frame["bb_main_send_table_line"].visible = true
		for food_name, tooltip in pairs(food_names) do
			local s = t[food_name]
			s.enabled = true
			s.tooltip = tooltip
			if global.active_special_games["disable_sciences"] and global.special_games_variables.disabled_food[food_name] then
				s.enabled = false
				s.tooltip = "Disabled by special game"
			end
			if Captain_event.captain_is_player_prohibited_to_throw(player) and food_name ~= "raw-fish" then
				s.enabled = false
				s.tooltip = "Disabled by special captain game"
			end
		end
		local s = t["send_all"]
		s.enabled = true
		s.tooltip = "LMB - low to high, RMB - high to low"
		if global.active_special_games["disable_sciences"] then
			s.enabled = false
			s.tooltip = "Disabled by special game"
		end
		if Captain_event.captain_is_player_prohibited_to_throw(player) then
			s.enabled = false
			s.tooltip = "Disabled by special captain game"
		end
	else
		frame["bb_main_send_table"].visible = false
		frame["bb_main_send_table_line"].visible = false
	end

	local join_random_button_visible = not global.chosen_team[player.name] and not global.bb_game_won_by_team
	frame["join_random_button"].visible = join_random_button_visible
	frame["join_random_line"].visible = join_random_button_visible

	local view_player_list = global.bb_view_players[player.name]
	if view_player_list == nil then view_player_list = true end
	for force_name, gui_value in pairs(gui_values) do
		-- Team name & Player count
		local t = frame["team_name_table_" .. force_name]

		-- Team name
		t["team_name"].caption = Functions.team_name(force_name)
		-- Number of players
		local c = #game.forces[force_name].connected_players .. " Player"
		if #game.forces[force_name].connected_players ~= 1 then c = c .. "s" end
		t["team_player_count"].caption = c

		-- Player list
		local l = frame["player_list_" .. force_name]
		l.visible = view_player_list
		if view_player_list then
			l.caption = get_player_list_caption(force_name)
		end

		local t = frame["stats_" .. force_name]
		--l.style.minimal_width = 25
		local biter_force = game.forces[gui_value.biter_force]
		local tooltip = gui_value.t1 ..
			"\nDamage: " ..
			(biter_force.get_ammo_damage_modifier("melee") + 1) * 100 ..
			"%\nRevive: " .. global.reanim_chance[biter_force.index] .. "%"

		t["evo_label_" .. force_name].tooltip = tooltip

		local evo = math_floor(1000 * global.bb_evolution[gui_value.biter_force]) * 0.1
		t["evo_value_label_" .. force_name].caption = evo .. "%"
		t["evo_value_label_" .. force_name].tooltip = tooltip

		-- Threat
		t["threat_label_" .. force_name].tooltip = gui_value.t2

		local l = t["threat_" .. force_name]
		local threat_value = threat_to_pretty_string(global.bb_threat[gui_value.biter_force])
		l.caption = threat_value
		l.tooltip = gui_value.t2

		-- Join button
		local b = frame[gui_value.n1]
		b.visible = not global.chosen_team[player.name] and not global.bb_game_won_by_team
	end

	-- Difficulty mutagen effectivness update
	bb_diff.difficulty_gui(player)

	local flow = frame["bb_main_action_flow"]
	flow["bb_leave_spectate"].visible = global.chosen_team[player.name] and not global.bb_game_won_by_team and is_spec
	flow["bb_spectate"].visible = global.chosen_team[player.name] and not global.bb_game_won_by_team and not is_spec

	flow["bb_hide_players"].visible = view_player_list
	flow["bb_view_players"].visible = not view_player_list
end

function Public.refresh()
	for _, player in pairs(game.connected_players) do
		Public.refresh_statistics(player)
		Public.refresh_main_gui(player)
	end
	global.gui_refresh_delay = game.tick + 30
end

function Public.refresh_threat()
	if global.gui_refresh_delay > game.tick then return end
	local north_threat_text = threat_to_pretty_string(global.bb_threat["north_biters"])
	local south_threat_text = threat_to_pretty_string(global.bb_threat["south_biters"])
	for _, player in pairs(game.connected_players) do
		if player.gui.left["bb_main_gui"] then
			if player.gui.left["bb_main_gui"].stats_north then
				player.gui.left["bb_main_gui"].stats_north.threat_north.caption = north_threat_text
				player.gui.left["bb_main_gui"].stats_south.threat_south.caption = south_threat_text
			end
		end
	end
	global.gui_refresh_delay = game.tick + 30
end

local get_player_data = function (player, remove)
	if remove and global.player_data_afk[player.name] then
		global.player_data_afk[player.name] = nil
		return
	end
	if not global.player_data_afk[player.name] then
		global.player_data_afk[player.name] = {}
	end
	return global.player_data_afk[player.name]
end

local function drop_burners(player, forced_join)
	if forced_join then 
		global.got_burners[player.name] = nil
		return
	end
	if global.training_mode or not (global.bb_settings.burners_balance) then 		
		return
	end			
	local burners_to_drop = player.get_item_count("burner-mining-drill")	
	if burners_to_drop ~= 0 then
    local items = player.surface.spill_item_stack(player.position,{name="burner-mining-drill", count = burners_to_drop}, false, nil, false )
		player.remove_item({name="burner-mining-drill", count = burners_to_drop})
	end
end

local function on_player_left_game(event)
	local player = game.get_player(event.player_index)
	drop_burners(player)
end

function Public.burners_balance(player)
	if player.force.name == "spectator" then 
		return 
	end
	if global.got_burners[player.name] then 
		return
	end	
	if global.training_mode or not (global.bb_settings.burners_balance) then 
		global.got_burners[player.name] = true
		player.insert { name = "burner-mining-drill", count = 10 }
		return
	end
	local enemy_force = "north"
	if player.force.name == "north" then 
		enemy_force = "south" 
	end
	local player2
	-- factorio Lua promises that pairs() iterates in insertion order
	for enemy_player_name, _ in pairs(global.got_burners) do 
		if not (global.got_burners[enemy_player_name]) and (game.get_player(enemy_player_name).force.name == enemy_force) and game.get_player(enemy_player_name).connected then
			player2 = game.get_player(enemy_player_name)
			break
		end
	end
	if not player2 then
		global.got_burners[player.name] = false
		return 		
	end				
	local burners_to_insert = 10
	for i = 1 , 0, -1 do
		local inserted
		global.got_burners[player.name] = true		
		inserted = player.insert { name = "burner-mining-drill", count = burners_to_insert }	
		if inserted < burners_to_insert then
			local items = player.surface.spill_item_stack(player.position,{name="burner-mining-drill", count = burners_to_insert - inserted}, false, nil, false )
		end
		player.print("You have received ".. burners_to_insert .. " x [item=burner-mining-drill] check inventory",{ r = 1, g = 1, b = 0 })
		player.create_local_flying_text({text = "You have received ".. burners_to_insert .. " x [item=burner-mining-drill] check inventory", position = player.position})
		player=player2
	end
end

function join_team(player, force_name, forced_join, auto_join)
	if not player.character then return end
	if not player.spectator then return end
	if not forced_join then
		if (global.tournament_mode and not global.active_special_games["captain_mode"]) or (global.active_special_games["captain_mode"] and not global.chosen_team[player.name]) then
			player.print("The game is set to tournament mode. Teams can only be changed via team manager.",
				{ r = 0.98, g = 0.66, b = 0.22 })
			return
		end
	end
	if not force_name then return end
	local surface = player.surface
	local enemy_team = "south"
	if force_name == "south" then enemy_team = "north" end

	if not global.training_mode and global.bb_settings.team_balancing then
		if not forced_join then
			if #game.forces[force_name].connected_players > #game.forces[enemy_team].connected_players then
				if not global.chosen_team[player.name] then
					player.print(Functions.team_name_with_color(force_name) .. " has too many players currently.",
						{ r = 0.98, g = 0.66, b = 0.22 })
					return
				end
			end
		end
	end

	if global.chosen_team[player.name] then
		if not forced_join then
			if global.active_special_games["limited_lives"] and not has_life(player.name) then
				player.print(
					"Special game in progress. You have no lives left until the end of the game.",
					{ r = 0.98, g = 0.66, b = 0.22 }
				)
				return
			end
			if global.suspended_players[player.name] and (game.ticks_played - global.suspended_players[player.name]) < global.suspended_time then
				player.print(
					"Not ready to return to your team yet as you are still suspended. Please wait " ..
					math_ceil((global.suspended_time - (math_floor((game.ticks_played - global.suspended_players[player.name])))) /
						60) .. " seconds.",
					{ r = 0.98, g = 0.66, b = 0.22 }
				)
				return
			end
			if global.spectator_rejoin_delay[player.name] and game.tick - global.spectator_rejoin_delay[player.name] < 3600 then
				player.print(
					"Not ready to return to your team yet. Please wait " ..
					60 - (math_floor((game.tick - global.spectator_rejoin_delay[player.name]) / 60)) .. " seconds.",
					{ r = 0.98, g = 0.66, b = 0.22 }
				)
				return
			end
		end
		local p = nil
		local p_data = get_player_data(player)
		if p_data and p_data.position then
			p = surface.find_non_colliding_position("character", p_data.position, 16, 0.5)
			get_player_data(player, true)
		else
			p = surface.find_non_colliding_position("character", game.forces[force_name].get_spawn_position(surface), 16,
				0.5)
		end
		if not p then
			game.print("No spawn position found for " .. player.name .. "!", { 255, 0, 0 })
			return
		end
		player.teleport(p, surface)
		player.force = game.forces[force_name]
		player.character.destructible = true
		Public.refresh()
		game.permissions.get_group("Default").add_player(player)
		local msg = table.concat({ "Team ", player.force.name, " player ", player.name, " is no longer spectating." })
		game.print(msg, { r = 0.98, g = 0.66, b = 0.22 })
		Sounds.notify_allies(player.force, "utility/build_blueprint_large")
		Server.to_discord_bold(msg)
		global.spectator_rejoin_delay[player.name] = game.tick
		player.spectator = false
		Public.burners_balance(player)
		return
	end
	local pos = surface.find_non_colliding_position("character", game.forces[force_name].get_spawn_position(surface), 8,
		1)
	if not pos then pos = game.forces[force_name].get_spawn_position(surface) end
	player.teleport(pos)
	player.force = game.forces[force_name]
	player.character.destructible = true
	game.permissions.get_group("Default").add_player(player)
	if not forced_join then
		-- In case bots are parsing discord messages, we always refer to teams as "north" or "south"
		Server.to_discord_bold(table.concat({ player.name, " has joined team ", player.force.name, "!" }))
		local join_text = "has joined"
		if auto_join then join_text = "was automatically assigned to" end
		local message = table.concat({ player.name, " ", join_text, " ", Functions.team_name_with_color(player.force
			.name), "!" })
		game.print(message, { r = 0.98, g = 0.66, b = 0.22 })
	end
	local i = player.get_inventory(defines.inventory.character_main)
	i.clear()
	player.insert { name = "pistol", count = 1 }
	player.insert { name = "raw-fish", count = 3 }
	player.insert { name = "firearm-magazine", count = 32 }
	player.insert { name = "iron-gear-wheel", count = 8 }
	player.insert { name = "iron-plate", count = 16 }
	player.insert { name = "wood", count = 2 }
	global.chosen_team[player.name] = force_name
	global.spectator_rejoin_delay[player.name] = game.tick
	player.spectator = false
	Public.burners_balance(player)
	Public.clear_copy_history(player)
	Public.refresh()

	script.raise_event(Public.events.on_player_joined_team, {
		player_index = player.index,
	})
end

function spectate(player, forced_join, stored_position)
	if not player.character then return end
	if player.spectator then return end
	if not forced_join then
		if global.tournament_mode and not global.active_special_games["captain_mode"] then
			player.print("The game is set to tournament mode. Teams can only be changed via team manager.",
				{ r = 0.98, g = 0.66, b = 0.22 })
			return
		end
		if global.active_special_games["captain_mode"] and global.special_games_variables["captain_mode"]["prepaPhase"] then
			player.print(
				"The game is in prepa phase of captain event, no spectating allowed until the captain game started",
				{ r = 0.98, g = 0.66, b = 0.22 })
			return
		end
	end

	while player.crafting_queue_size > 0 do
		player.cancel_crafting(player.crafting_queue[1])
	end

	player.driving = false
	player.clear_cursor()
	drop_burners(player, forced_join)

	if stored_position then
		local p_data = get_player_data(player)
		p_data.position = player.position
	end
	player.teleport(player.surface.find_non_colliding_position("character", { 0, 0 }, 4, 1))
	Sounds.notify_player(player, "utility/build_blueprint_large")
	player.force = game.forces.spectator
	player.character.destructible = false
	if not forced_join then
		local msg = player.name .. " is spectating."
		game.print(msg, { r = 0.98, g = 0.66, b = 0.22 })
		Server.to_discord_bold(msg)
	end
	game.permissions.get_group("spectator").add_player(player)
	global.spectator_rejoin_delay[player.name] = game.tick
	Public.create_main_gui(player)
	player.spectator = true
end

local function join_gui_click(name, player, auto_join)
	if not name then return end

	join_team(player, name, false, auto_join)
end

local spy_forces = { { "north", "south" }, { "south", "north" } }
function Public.spy_fish()
	for _, f in pairs(spy_forces) do
		if global.spy_fish_timeout[f[1]] - game.tick > 0 then
			local r = 96
			local surface = game.surfaces[global.bb_surface_name]
			for _, player in pairs(game.forces[f[2]].connected_players) do
				game.forces[f[1]].chart(surface,
					{ { player.position.x - r, player.position.y - r }, { player.position.x + r, player.position.y + r } })
			end
		else
			global.spy_fish_timeout[f[1]] = 0
		end
	end
end

local function on_gui_click(event)
	if not event.element then return end
	if not event.element.valid then return end
	local player = game.get_player(event.player_index)
	local name = event.element.name
	if name == "bb_toggle_button" then
		if player.gui.left["bb_main_gui"] then
			player.gui.left["bb_main_gui"].destroy()
		else
			Public.create_main_gui(player)
		end
		return
	end
	for force_name, gui_values in pairs(gui_values) do
		if name == gui_values.n1 then
			join_gui_click(force_name, player)
			return
		end
	end

	if name == "join_random_button" then
		local teams_equal = true
		local a = #game.forces["north"].connected_players -- Idk how to choose the 1st force without calling 'north'

		-- checking if teams are equal	
		for force_name, gui_values in pairs(gui_values) do
			if a ~= #game.forces[force_name].connected_players then
				teams_equal = false
				break
			end
		end

		-- choosing a team at random if teams are equal
		if teams_equal then
			local teams = {}
			for force_name, gui_values in pairs(gui_values) do table.insert(teams, force_name) end
			join_gui_click(teams[math_random(#teams)], player, true)
		else                                       -- checking which team is smaller and joining it
			local smallest_team = gui_values["north"].force -- Idk how to choose the 1st force without calling 'north'
			for force_name, gui_values in pairs(gui_values) do
				if a > #game.forces[force_name].connected_players then
					smallest_team = force_name
					a = #game.forces[force_name].connected_players
				end
			end
			join_gui_click(smallest_team, player, true)
		end
		return
	end

	if name == "raw-fish" then
		Functions.spy_fish(player, event)
		return
	end

	if food_names[name] then Feeding.feed_biters_from_inventory(player, name) return end

	if name == "send_all" then Feeding.feed_biters_mixed_from_inventory(player, event.button) return end
	if name == "bb_leave_spectate" then join_team(player, global.chosen_team[player.name])	end

	if name == "bb_spectate" then
		if player.position.y ^ 2 + player.position.x ^ 2 < 12000 then
			spectate(player)
		else
			player.print("You are too far away from spawn to spectate.", { r = 0.98, g = 0.66, b = 0.22 })
		end
		return
	end

	if name == "suspend_yes" then
		local suspend_info = global.suspend_target_info
		if suspend_info then
			if player.force.name == suspend_info.target_force_name then
				if suspend_info.suspend_votes_by_player[player.name] ~= 1 then
					suspend_info.suspend_votes_by_player[player.name] = 1
					game.print(player.name .. " wants to suspend " .. suspend_info.suspendee_player_name,
						{ r = 0.1, g = 0.9, b = 0.0 })
				end
			else
				player.print("You cannot vote from a different force!", { r = 0.9, g = 0.1, b = 0.1 })
			end
		end
	end
	if name == "suspend_no" then
		local suspend_info = global.suspend_target_info
		if suspend_info then
			if player.force.name == suspend_info.target_force_name then
				if suspend_info.suspend_votes_by_player[player.name] ~= 0 then
					suspend_info.suspend_votes_by_player[player.name] = 0
					game.print(player.name .. " doesn't want to suspend " .. suspend_info.suspendee_player_name,
						{ r = 0.9, g = 0.1, b = 0.1 })
				end
			else
				player.print("You cannot vote from a different force!", { r = 0.9, g = 0.1, b = 0.1 })
			end
		end
	end
	if name == "bb_hide_players" then
		global.bb_view_players[player.name] = false
		Public.refresh_main_gui(player)
	end
	if name == "bb_view_players" then
		global.bb_view_players[player.name] = true
		Public.refresh_main_gui(player)
	end

	if name == "reroll_yes" then
		if global.reroll_map_voting[player.name] ~= 1 then
			global.reroll_map_voting[player.name] = 1
			game.print(player.name .. " wants to reroll map ", { r = 0.1, g = 0.9, b = 0.0 })
		end
	end
	if name == "reroll_no" then
		if global.reroll_map_voting[player.name] ~= 0 then
			global.reroll_map_voting[player.name] = 0
			game.print(player.name .. " wants to keep this map", { r = 0.9, g = 0.1, b = 0.1 })
		end
	end
end


local function on_player_joined_game(event)
	local player = game.get_player(event.player_index)
	if player.online_time == 0 then
		Functions.show_intro(player)
	end
	if not global.bb_view_players then global.bb_view_players = {} end
	if not global.chosen_team then global.chosen_team = {} end

	--if not global.chosen_team[player.name] then
	--	if global.tournament_mode then
	--		player.force = game.forces.spectator
	--	else
	--		player.force = game.forces.player
	--	end
	--end

	--Public.create_top_gui_buttons(player)
  Public.create_main_gui(player)
	--Shortcuts.get_main_frame(player)
end


event.add(defines.events.on_gui_click, on_gui_click)
event.add(defines.events.on_player_joined_game, on_player_joined_game)
event.add(defines.events.on_player_left_game, on_player_left_game)

return Public
