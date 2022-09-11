local get_active_frame = require 'comfy_panel.main'.comfy_panel_get_active_frame
local AntiGrief_get = require 'antigrief'.get
local lower = string.lower
local Event = require 'utils.event'
local Global = require 'utils.global'
local pos_from_gps = require 'utils.string'.position_from_gps_tag
local distance =  require 'utils.core'.distance
local this = {
    player_name_search = {},
    event_search = {},
    waiting_for_gps = {},
    filter_by_gps = {},
    sort_by = {},
	selected_history_index = {}
}

Global.register(
    this,
    function(t)
        this = t
    end
)

local function match_test(value, pattern)
    return lower(value:gsub('-', ' ')):find(pattern)
end

local function filter_brackets(str)
    return (string.find(str, '%[') ~= nil)
end

local function contains_text(key, value, search_text)
	if filter_brackets(search_text) then
		return false
	end
	if value then
		if not match_test(key[value], search_text) then
			return false
		end
	else
		if not match_test(key, search_text) then
			return false
		end
	end
	return true
end

local sorting_methods = {
	["Player name"] = "name_desc",
	["▲Player name"] = "name_desc",
	["▼Player name"] = "name_asc",
	["Time"] = "time_desc",
	["▲Time"] = "time_desc",
	["▼Time"] = "time_asc",
	["Event"] = "event_desc",
	["▲Event"] = "event_desc",
	["▼Event"] = "event_asc"
}

local comparators = {
	['name_asc'] = function(a, b) return a.player_name:lower() < b.player_name:lower() end,
	['name_desc'] = function(a, b) return a.player_name:lower() > b.player_name:lower() end,
	['time_asc'] = function(a, b) return a.server_time < b.server_time end,
	['time_desc'] = function(a, b) return a.server_time > b.server_time end,
	['event_asc'] = function(a, b) return a.event:lower() < b.event:lower() end,
	['event_desc'] = function(a, b) return a.event:lower() > b.event:lower() end
}

local histories_dict = {
	[1] = {history = "mining", name = "Mining History"},
	[2] = {history = "belt_mining", name = "Belt Mining History"},
	[3] = {history = "capsule", name = "Capsule History"},
	[4] = {history = "friendly_fire", name = "Friendly Fire History"},
	[5] = {history = "landfill", name = "Landfill History"},
	[6] = {history = "corpse", name = "Corpse Looting History"},
	[7] = {history = "cancel_crafting", name = "Cancel Crafting History"}
}

local function draw_events(player, frame)
	local radius = 10
	local event_search = this.event_search[player.name]
	local player_name_search = this.player_name_search[player.name]
	local gps_position = this.filter_by_gps[player.name]
	local selected_history_index = this.selected_history_index[player.name]
	
	if not this.sort_by[player.name] then
		this.sort_by[player.name] = "time_desc"
	end
	local histories = AntiGrief_get("histories")
	local history = histories[histories_dict[selected_history_index].history]

	--Headers captions
	local history_headers = {
		[1] = "Time",
		[2] = "Player name",
		[3] = "Event",
		[4] = "Location"
	}
	local symbol_asc = '▲'
	local symbol_desc = '▼'
	local header_modifier = {
		['time_asc'] = function(h) h[1] = symbol_asc .. h[1] end,
		['time_desc'] = function(h) h[1] = symbol_desc .. h[1] end,
		['name_asc'] = function(h) h[2] = symbol_asc .. h[2] end,
		['name_desc'] = function(h) h[2] = symbol_desc .. h[2] end,
		['event_asc'] = function(h) h[3] = symbol_asc .. h[3] end,
		['event_desc'] = function(h) h[3] = symbol_desc .. h[3] end
	}
	local sort_by = this.sort_by[player.name]
	header_modifier[sort_by](history_headers)
	
	--Headers
	local column_widths = {80, 200, 300, 100}
	if frame.history_headers then
		frame.history_headers.clear()
	else
		frame.add {type = "table", name = "history_headers", column_count = #history_headers}
	end
	for k, v in pairs(history_headers) do
		local h = frame.history_headers.add {type = "label", caption = v, name = v}
		h.style.width = column_widths[k]
		h.style.font = 'default-bold'
		h.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
	end

	--Scroll panel
	if not frame.history_scroll then
		frame.add{type = "scroll-pane", name = "history_scroll", direction = 'vertical', horizontal_scroll_policy = 'never', vertical_scroll_policy = 'auto'}.style.height = 330
	end

	--History table in panel
	if frame.history_scroll.history_table then
		frame.history_scroll.history_table.clear()
	else
		frame.history_scroll.add {type = "table", name = "history_table", column_count = #history_headers}
	end
	
	local temp = {}
	if not history then return end
	-- filtering the history
	for k, v in pairs(history) do
		if v ~= 0 then
			if gps_position and distance(gps_position, v.position)>radius then
				goto CONTINUE
			end
			if player_name_search and not contains_text(v.player_name, nil, player_name_search) then
				goto CONTINUE
			end
			if event_search and not contains_text(v.event, nil, event_search) then
				goto CONTINUE
			end
			table.insert(temp, v)
		end
		::CONTINUE::
	end
	table.sort(temp, comparators[sort_by])

	for k, v in pairs(temp) do
		local hours = math.floor(v.time / 216000)
		local minutes = math.floor((v.time - hours * 216000) / 3600)
		local formatted_time = hours .. ":" .. minutes
		frame.history_scroll.history_table.add{type = "label", caption = formatted_time}.style.width = column_widths[1]
		frame.history_scroll.history_table.add{type = "label", caption = v.player_name}.style.width = column_widths[2]
		frame.history_scroll.history_table.add{type = "label", caption = v.event}.style.width = column_widths[3]
		frame.history_scroll.history_table.add{type = "label", name = "coords_" .. k, caption = v.position.x .. " , " .. v.position.y}.style.width = column_widths[4]
	end
end

local create_histories_panel = (function(player, frame)
	frame.clear()
	this.player_name_search[player.name] = nil
	this.event_search[player.name] = nil
	this.waiting_for_gps[player.name] = false
	this.filter_by_gps[player.name] = nil
	
	local histories_names = {}
	for k, v in pairs(histories_dict) do
		table.insert(histories_names, v.name)
	end
	if histories_names ==  nil then return end

	local filter_headers = {"Choose history", "Search player", "Search event", "Search by gps"}
	local filter_table = frame.add {type = "table", name = "filter_table", column_count = #filter_headers}
	for k, v in pairs(filter_headers) do
		filter_table.add {type = "label", caption = v}
	end

	if not this.selected_history_index[player.name] then
		this.selected_history_index[player.name] = 1
	end
	filter_table.add {type = "drop-down", name = 'history_select', items = histories_names, selected_index = this.selected_history_index[player.name]}
	filter_table.add{type = 'textfield', name = "player_search_text"}.style.width = 180
	filter_table.add{type = "textfield", name = "event_search_text"}.style.width = 180
	local flow = filter_table.add {type = "flow", direction = "horizontal", name = "gps"}
	flow.add {type = "button", name = "filter_by_gps", caption = "Filter by GPS", tooltip = "Click this button and then ping on map to filter history"}
	flow.add {type = "button", name = "clear_gps", caption = "Clear GPS"}

	draw_events(player, frame)
end)

local function on_gui_selection_state_changed(event)
	local element = event.element
	if not element then return end
	if not element.valid then return end
	local player = game.get_player(event.player_index)
	local name = event.element.name
	if name == "history_select" then
		this.selected_history_index[player.name] = element.selected_index
		local frame = get_active_frame(player)
		if frame then
			draw_events(player, frame)
		end
	end
end

local function on_gui_text_changed(event)
	local element = event.element
	if element and element.valid then
		local player = game.get_player(event.player_index)
		local frame = get_active_frame(player)
		if frame and frame.name == "Histories" then
			if event.text == "" then event.text = nil end
			if element.name == "player_search_text" then
				this.player_name_search[player.name] = event.text
			end
			if element.name == "event_search_text" then
				this.event_search[player.name] = event.text
			end
			draw_events(player, frame)
		end
	end
end

local function on_gui_click(event)
	local player = game.get_player(event.player_index)
	local element = event.element
	if element and element.valid then
		local frame = get_active_frame(player)
		if frame and frame.name == "Histories" then
			if sorting_methods[element.name] then
				this.sort_by[player.name] = sorting_methods[element.name]
				draw_events(player, frame)
				return
			end

			if element.name == "filter_by_gps" then
				event.element.caption = "Waiting for ping..."
				this.waiting_for_gps[player.name] = true
				return
			end

			if element.name == "clear_gps" then
				this.waiting_for_gps[player.name] = false
				this.filter_by_gps[player.name] = nil
				element.parent.children[1].caption = "Filter by GPS"
				draw_events(player, frame)
				return
			end

			if contains_text(element.name, nil, "coords_") then
				local a, b = string.find(element.caption, " , ")
				local x = string.sub(element.caption, 1, a)
				local y = string.sub(element.caption, b)
				player.zoom_to_world({x, y})
				return
			end
		end
	end
end


local function on_console_chat(event)
	if not event.player_index then return end
	local player = game.get_player(event.player_index)
	if this.waiting_for_gps[player.name] then
		local frame = get_active_frame(player)
		if frame and frame.name == "Histories" then
			this.filter_by_gps[player.name] = pos_from_gps(event.message)
			frame.filter_table.gps.filter_by_gps.caption = "Filter by GPS"
			draw_events(player, frame)
		end
	end
end


comfy_panel_tabs["Histories"] = {gui = create_histories_panel, admin = true}

Event.add(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
Event.add(defines.events.on_gui_text_changed, on_gui_text_changed)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_console_chat, on_console_chat)