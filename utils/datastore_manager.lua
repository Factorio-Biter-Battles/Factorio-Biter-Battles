local Session = require "utils.datastore.session_data"
local string_split = require "utils.utils".string_split
local Event = require 'utils.event'
local data_filename = "data-request.txt"



local function save_quickbar(player)
	if not player then return end
	local trusted = Session.get_trusted_table()
	if not trusted[player.name] then return end

	local quickbar = {}
	for i=1, 20 do
		if player.get_quick_bar_slot(i) then 
			quickbar[i] = player.get_quick_bar_slot(i).name
		end
	end
	quickbar = game.table_to_json(quickbar)
	local data = {type = "save_quickbar", player = player.name, value = quickbar}
	game.write_file(data_filename, table_to_json(data), true, 0)
end

local function load_quickbar(player)
	if not player then return end
	local trusted = Session.get_trusted_table()
	if not trusted[player.name] then return end

	local data = {type = "load_quickbar", player = player.name}
	game.write_file(data_filename, table_to_json(data), true, 0)
end

local function save_color(player)
	if not player then return end
	local trusted = Session.get_trusted_table()
	if not trusted[player.name] then return end

	local color = game.table_to_json(player.color)
	local data = {type = "save_color", player = player.name, value = color}
	game.write_file(data_filename, table_to_json(data), true, 0)
end

local function load_color(player)
	if not player then return end
	local trusted = Session.get_trusted_table()
	if not trusted[player.name] then return end

	local data = {type = "save_color", player = player.name}
	game.write_file(data_filename, table_to_json(data), true, 0)
end


Event.add(
	defines.events.on_player_left_game,
	function(event)
		local player = game.get_player(event.index)
		save_quickbar(player)
		save_color(player)
	end
)
Event.add(
	defines.events.on_player_joined_game,
	function(event)
		local player = game.get_player(event.index)
		load_quickbar(player)
		load_color(player)
	end
)