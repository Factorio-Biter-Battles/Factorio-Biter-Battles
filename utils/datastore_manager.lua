local Session = require "utils.datastore.session_data"
local string_split = require "utils.utils".string_split
local data_filename = "data-request.txt"
local TABLES = {
	players = {
		quickbar = "string",
		color = "string"
	}
}
local valid_parameters = {
	help,
	load = {
		quickbar = true,
		color = true
	},
	save = {
		quickbar = true,
		color = true
	}
}

-- todo: Figure out a way to translate the command with functions in nested table (valid_parameters)
-- instead of dozens of conditions
-- /hg ...
local function hedwig_command(cmd)
	if not cmd.player_index then return end
	if not cmd.parameter then return end
	local player = game.get_player(cmd.player_index)
	local arg = string_split(cmd.parameter)


	local trusted = Session.get_trusted_table()
	-- /hg save ...
	if trusted[player.name] then
		if arg[1] == "save" then
			-- /hg save quickbar
			if arg[2] == "quickbar" then
				local quickbar = {}
				for i=1, 20 do
					if player.get_quick_bar_slot(i) then 
						quickbar[i] = player.get_quick_bar_slot(i).name
					end
				end
				quickbar = game.table_to_json(quickbar)
				local data = {type = "[UPLOAD]", player = player.name, table = "players", key = "quickbar", value = quickbar}
				game.write_file(data_filename, table_to_json(data), true, 0)
			
			-- /hg save color
			elseif arg[2] == "color" then
				local color = game.table_to_json(player.color)
				local data = {type = "[UPLOAD]", player = player.name, table = "players", key = "color", value = color}
				game.write_file(data_filename, table_to_json(data), true, 0)
			end
		-- /hg load ...
		elseif arg[1] == "load" then
			if arg[2] == "quickbar" then
				local data = {type = "[DOWNLOAD]", player = player.name, table = "players", key = "quickbar"}
				game.write_file(data_filename, table_to_json(data), true, 0)
			-- /hg save color
			elseif arg[2] == "color" then
				local data = {type = "[DOWNLOAD]", player = player.name, table = "players", key = "color"}
				game.write_file(data_filename, table_to_json(data), true, 0)
			end
		end
	end
end

commands.add_command(
	"hg",
	"Communicate with Hedwig. Use /hg help for more info"
	hedwig_command(cmd)
)