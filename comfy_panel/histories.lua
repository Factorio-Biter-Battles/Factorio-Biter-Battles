local Tabs = require 'comfy_panel.main'
local AntiGrief = require 'antigrief'
local lower = string.lower
local Event = require 'utils.event'
local Admin = require 'comfy_panel.admin'
local Global = require 'utils.global'

local this = {
    player_search = {},
    event_search = {},
    waiting_for_gps = {},
    filter_by_gps = {},
    sort_by = {}
}

Global.register(
    this,
    function(t)
        this = t
    end
)

local Public = {}
function Public.get_this()
    return this
end

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
	['name_asc'] = function(a, b) return a.player:lower() < b.player:lower() end,
	['name_desc'] = function(a, b) return a.player:lower() > b.player:lower() end,
	['time_asc'] = function(a, b) return a.server_time < b.server_time end,
	['time_desc'] = function(a, b) return a.server_time > b.server_time end,
	['event_asc'] = function(a, b) return a.event:lower() < b.event:lower() end,
	['event_desc'] = function(a, b) return a.event:lower() > b.event:lower() end
}

local function draw_events(data)
	local radius = 10
	local frame = data.frame
	local player = data.player
	local antigrief = AntiGrief.get()
	local event_search = this.event_search[player.name]
	local player_search = this.player_search[player.name]
	local history_index = this.selected_history_index[player.name]

	if not this.sort_by then
		this.sort_by = {}
	end
	if not this.sort_by[player.name] then
		this.sort_by[player.name] = "time_desc"
	end
	local sort_by = this.sort_by[player.name]
	local histories = {
		[1] = antigrief.capsule_history,
		[2] = antigrief.friendly_fire_history,
		[3] = antigrief.mining_history,
		[4] = antigrief.belt_mining_history,
		[5] = antigrief.landfill_history,
		[6] = antigrief.corpse_history,
		[7] = antigrief.cancel_crafting_history
	}
	local history_headers = {
        [1] = "Time",
        [2] = "Player name",
        [3] = "Event",
        [4] = "Location"
    }
	if frame.history_headers then
		frame.history_headers.clear()
	else
		frame.add {type = "table", name = "history_headers", column_count = #history_headers}
	end

	local column_widths = {80, 200, 300, 100}

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

	header_modifier[sort_by](history_headers)
	for k, v in pairs(history_headers) do
		local h = frame.history_headers.add {type = "label", caption = v, name = v}
		h.style.width = column_widths[k]
		h.style.font = 'default-bold'
		h.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
	end
	if not frame.history_scroll then
		frame.add{type = "scroll-pane", name = "history_scroll", direction = 'vertical', horizontal_scroll_policy = 'never', vertical_scroll_policy = 'auto'}.style.height = 330
	end
	if frame.history_scroll.history_table then
		frame.history_scroll.history_table.clear()
	else
		frame.history_scroll.add {type = "table", name = "history_table", column_count = #history_headers}
	end
	if not history_index or not histories[history_index] or #histories[history_index] <= 0 then
		return
	end
	local history = histories[history_index]
	local temp = {}
	local gps = nil
	if this.filter_by_gps[player.name] then
		gps = {x = this.filter_by_gps[player.name].x, y = this.filter_by_gps[player.name].y}
	end
	for k, v in pairs(history) do
		if gps and not (v.x < gps.x + radius and v.x > gps.x - radius and v.y < gps.y + radius and v.y > gps.y - radius) then
			goto CONTINUE
		end
		if player_search and not contains_text(v.player, nil, player_search) then
			goto CONTINUE
		end
		if event_search and not contains_text(v.event, nil, event_search) then
			goto CONTINUE
		end
		table.insert(temp, v)
		::CONTINUE::
	end
	table.sort(temp, comparators[sort_by])

	for k, v in pairs(temp) do
		local hours = math.floor(v.time / 216000)
		local minutes = math.floor((v.time - hours * 216000) / 3600)
		local formatted_time = hours .. ":" .. minutes
		frame.history_scroll.history_table.add{type = "label", caption = formatted_time}.style.width = column_widths[1]
		frame.history_scroll.history_table.add{type = "label", caption = v.player}.style.width = column_widths[2]
		frame.history_scroll.history_table.add{type = "label", caption = v.event}.style.width = column_widths[3]
		frame.history_scroll.history_table.add{type = "label", name = "coords_" .. k, caption = v.x .. " , " .. v.y}.style.width = column_widths[4]
	end
end

local create_histories_panel = (function(player, frame)
	local antigrief = AntiGrief.get()
	frame.clear()
	this.player_search[player.name] = nil
	this.event_search[player.name] = nil
	this.waiting_for_gps[player.name] = false
	this.filter_by_gps[player.name] = nil
	local histories = {}
	if antigrief.capsule_history then
		table.insert(histories, 'Capsule History')
	end
	if antigrief.friendly_fire_history then
		table.insert(histories, 'Friendly Fire History')
	end
	if antigrief.mining_history then
		table.insert(histories, 'Mining History')
	end
	if antigrief.belt_mining_history then
		table.insert(histories, 'Belt Mining History')
	end
	if antigrief.landfill_history then
		table.insert(histories, 'Landfill History')
	end
	if antigrief.corpse_history then
		table.insert(histories, 'Corpse Looting History')
	end
	if antigrief.cancel_crafting_history then
		table.insert(histories, 'Cancel Crafting History')
	end

	if #histories == 0 then
		return
	end

	local filter_headers = {"Choose history", "Search player", "Search event", "Search by gps"}
	local filter_headers_table = frame.add {type = "table", name = "filter_headers_table", column_count = #filter_headers}
	local filter_table = frame.add {type = "table", name = "filter_table", column_count = #filter_headers}
	for k, v in pairs(filter_headers) do
		filter_table.add {type = "label", caption = v}
	end
	if not this.selected_history_index then
		this.selected_history_index = {}
	end
	if not this.selected_history_index[player.name] then
		this.selected_history_index[player.name] = 1
	end
	filter_table.add {type = "drop-down", name = 'history_select', items = histories, selected_index = this.selected_history_index[player.name]}
	filter_table.add{type = 'textfield', name = "player_search_text"}.style.width = 180
	filter_table.add{type = "textfield", name = "event_search_text"}.style.width = 180
	local flow = filter_table.add {type = "flow", direction = "horizontal", name = "gps"}
	flow.add {type = "button", name = "filter_by_gps", caption = "Filter by GPS", tooltip = "Click this button and then ping on map to filter history"}
	flow.add {type = "button", name = "clear_gps", caption = "Clear GPS"}
	local data = {player = player, frame = frame}

	draw_events(data)
end)

local function on_gui_selection_state_changed(event)
	local player = game.get_player(event.player_index)
	local name = event.element.name
	if not name == "history_select" then
		return
	end
	if not this.selected_history_index then
		this.selected_history_index = {}
	end
	this.selected_history_index[player.name] = event.element.selected_index
	local frame = Tabs.comfy_panel_get_active_frame(player)
	if not frame or not frame.name == "Admin" then
		return
	end
	local data = {player = player, frame = frame}
	draw_events(data)
end

local function on_gui_text_changed(event)
	local element = event.element
	if not element then
		return
	end
	if not element.valid then
		return
	end
	local player = game.get_player(event.player_index)

	local frame = Tabs.comfy_panel_get_active_frame(player)
	if not frame then
		return
	end
	if frame.name ~= 'Histories' then
		return
	end
	if element.name == "player_search_text" then
		this.player_search[player.name] = event.text
	end
	if element.name == "event_search_text" then
		this.event_search[player.name] = event.text
	end
	draw_events({player = player, frame = frame})
end

local function on_gui_click(event)
	local player = game.get_player(event.player_index)
	local element = event.element
	if not element then
		return
	end
	if not element.valid then
		return
	end
	local frame = Tabs.comfy_panel_get_active_frame(player)
	if not frame then
		return
	end
	if frame.name ~= 'Histories' then
		return
	end

	if sorting_methods[element.name] then
		this.sort_by[player.name] = sorting_methods[element.name]
		draw_events({player = player, frame = frame})
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
		draw_events({player = player, frame = frame})
		return
	end
	if game.players[element.caption] then
		player.gui.left.comfy_panel.tabbed_pane.selected_tab_index = 2 -- Admin
		Tabs.comfy_panel_refresh_active_tab(player)
		local new_frame = Tabs.comfy_panel_get_active_frame(player)
		new_frame.player_search.player_search_text.text = string.lower(element.caption)
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

local function on_console_chat(event)
	local player = game.get_player(event.player_index)
	if not this.waiting_for_gps[player.name] then
		return
	end
	local frame = Tabs.comfy_panel_get_active_frame(player)
	if not frame then
		return
	end
	if frame.name ~= 'Histories' then
		return
	end
	local a, b = string.find(event.message, "gps=")
	if not b then
		return
	end
	local dot = string.find(event.message, ",", b)
	local ending = string.find(event.message, ",", dot + 1)
	local x = string.sub(event.message, b + 1, dot - 1)
	local y = string.sub(event.message, dot + 1, ending - 1)
	this.filter_by_gps[player.name] = {x = tonumber(x), y = tonumber(y)}
	this.waiting_for_gps[player.name] = false
	frame.filter_table.gps.filter_by_gps.caption = "Filter by GPS"
	draw_events({player = player, frame = frame})
end

comfy_panel_tabs['Histories'] = {gui = create_histories_panel, admin = true}
Event.add(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
Event.add(defines.events.on_gui_text_changed, on_gui_text_changed)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_console_chat, on_console_chat)

return Public
