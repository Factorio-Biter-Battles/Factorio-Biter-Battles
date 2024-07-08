local Color = require 'utils.color_presets'
local Event = require 'utils.event'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Team_manager = require "maps.biter_battles_v2.team_manager"
local session = require 'utils.datastore.session_data'
local Functions = require 'maps.biter_battles_v2.functions'
local Tables = require "maps.biter_battles_v2.tables"
local Player_list = require "comfy_panel.player_list"
local gui_style = require 'utils.utils'.gui_style
local ternary = require 'utils.utils'.ternary
local ComfyPanelGroup = require 'comfy_panel.group'
local CaptainRandomPick = require 'comfy_panel.special_games.captain_random_pick'
local math_random = math.random
local closable_frame = require "utils.ui.closable_frame"
local bb_diff = require "maps.biter_battles_v2.difficulty_vote"

local Public = {
    name = {type = "label", caption = "Captain event", tooltip = "Captain event"},
    config = {
			{name = "label4", type = "label", caption = "Referee"},
			{name = 'refereeName', type = "textfield", text = "", numeric = false, width = 140},
			{name = "autoTrust", type = "switch", switch_state = "right", allow_none_state = false, tooltip = "Trust all players automatically : Yes / No"},
			{name = "captainKickPower", type = "switch", switch_state = "left", allow_none_state = false, tooltip = "Captain can eject players from his team : Yes / No"},
			{name = "specialEnabled", type = "switch", switch_state = "right", allow_none_state = false, tooltip = "A special will be added to the event : Yes / No"}
    },
    button = {name = "apply", type = "button", caption = "Apply"},
}

local function cpt_get_player(playerName)
	local special = global.special_games_variables["captain_mode"]
	if special and special.test_players and special.test_players[playerName] then
		local res = table.deepcopy(special.test_players[playerName])
		res.print = function(msg, color)
			game.print("to player " .. playerName .. ":" .. msg, color)
		end
		res.force = {name = (global.chosen_team[playerName] or "spectator")}
		return res
	end
	return game.get_player(playerName)
end

local function is_test_player(player)
	return not player.gui
end

local function is_test_player_name(player_name)
	local special = global.special_games_variables["captain_mode"]
	return special.test_players and special.test_players[player_name]
end

local function isStringInTable(tab, str)
    for _, entry in ipairs(tab) do
        if entry == str then
            return true
        end
    end
    return false
end

local function removeStringFromTable(tab, str)
    for i, entry in ipairs(tab) do
        if entry == str then
            table.remove(tab, i)
            break  -- Stop the loop once the string is found and removed
        end
    end
end

local function add_to_trust(playerName)
	if global.special_games_variables["captain_mode"]["autoTrust"] then
		local trusted = session.get_trusted_table()
		if not trusted[playerName] then
			trusted[playerName] = true
		end
	end
end

local function switchTeamOfPlayer(playerName, playerForceName)
	if global.chosen_team[playerName] then
		if global.chosen_team[playerName] ~= playerForceName then
			game.print(playerName .. ' is already on ' .. global.chosen_team[playerName] .. ' and thus was not switched to ' .. playerForceName, Color.red)
		end
		return
	end
	local special = global.special_games_variables["captain_mode"]
	local player = cpt_get_player(playerName)
	if is_test_player_name(playerName) or not player.connected then
		global.chosen_team[playerName] = playerForceName
	else
		Team_manager.switch_force(playerName, playerForceName)
	end
	local forcePickName = playerForceName .. "Picks"
	table.insert(special["stats"][forcePickName], playerName)
	if not special["playerPickedAtTicks"][playerName] then
		special["playerPickedAtTicks"][playerName] = Functions.get_ticks_since_game_start()
	end
	add_to_trust(playerName)
end

local function clear_gui_captain_mode()
	for _, player in pairs(game.players) do
		local top_guis = {
			"captain_manager_toggle_button",
			"captain_referee_toggle_button",
			"captain_player_toggle_button",
		}
		local center_guis = {
			"captain_poll_alternate_pick_choice_frame",
			"bb_captain_countdown",
			"captain_manager_gui",
			"captain_referee_gui",
			"captain_player_gui",
		}
		local playergui = player.gui
		for _, gui in pairs(top_guis) do
			if playergui.top[gui] then playergui.top[gui].destroy() end
		end
		for _, gui in pairs(center_guis) do
			-- This is a bit of a hack, but I don't want to figure out which ones are center and which ones are screen.
			if playergui.center[gui] then playergui.center[gui].destroy() end
			if playergui.screen[gui] then playergui.screen[gui].destroy() end
		end
	end
end

local function clear_character_corpses()
	for _, object in pairs(game.surfaces[global.bb_surface_name].find_entities_filtered {name = 'character-corpse'}) do object.destroy() end
end

local function force_end_captain_event()
	game.print('Captain event was canceled')
	global.special_games_variables["captain_mode"] = nil
	global.tournament_mode = false
	if global.freeze_players == true then
		global.freeze_players = false
		Team_manager.unfreeze_players()
		game.print(">>> Players have been unfrozen!", {r = 255, g = 77, b = 77})
	end
	global.active_special_games["captain_mode"] = false
	global.bb_threat["north_biters"] = 0
	global.bb_threat["south_biters"] = 0
	rendering.clear()
	clear_gui_captain_mode()
	for _, pl in pairs(game.connected_players) do
		if pl.force.name ~= "spectator" then
			Team_manager.switch_force(pl.name,"spectator")
		end
	end
	global.difficulty_votes_timeout = game.ticks_played + 36000
	clear_character_corpses()
end

---@param frame LuaGuiElement
local function createButton(frame,nameButton,captionButton, wordToPutInstead)
	local newNameButton = nameButton:gsub("Magical1@StringHere", wordToPutInstead)
	local newCaptionButton = captionButton:gsub("Magical1@StringHere", wordToPutInstead)
	local b = frame.add({type = "button", name = newNameButton, caption = newCaptionButton, style="green_button", tooltip="Click to select"})
	b.style.font = "heading-2"
	b.style.minimal_width = 100
end

local function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function addGuiShowPlayerInfo(_t,_button1Name,_button1Text,_pl,_groupName,_playtimePlayer)
	local special = global.special_games_variables["captain_mode"]
	createButton(_t,_button1Name,_button1Text,_pl)
	local b = _t.add({type = "label", caption = _groupName})
	b.style.font_color = Color.antique_white
	b.style.font = "heading-2"
	b.style.minimal_width = 100
	b = _t.add({type = "label", caption = _playtimePlayer})
	b.style.font_color = Color.white
	b.style.font = "heading-2"
	b.style.minimal_width = 100
	b = _t.add({type = "label", caption = special["player_info"][_pl]})
	b.style.font_color = Color.white
	b.style.font = "heading-2"
	b.style.minimal_width = 100
	b.style.maximal_width = 800
	b.style.single_line = false
end

local function pickPlayerGenerator(player,tableBeingLooped,frameName,questionText,button1Text,button1Name)
	if player.gui.center[frameName] then player.gui.center[frameName].destroy() return end
	local frame = player.gui.center.add { type = "frame", caption = questionText, name = frameName, direction = "vertical" }
	local t = frame.add { type = "table", column_count = 4 }
	if tableBeingLooped ~=nil then
		local b = t.add({type = "label", caption = "playerName"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		b = t.add({type = "label", caption = "GroupName"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		b = t.add({type = "label", caption = "Total playtime"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		b = t.add({type = "label", caption = "Notes"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		local listGroupAlreadyDone = {}
		for _,pl in pairs(tableBeingLooped) do
			if button1Text ~= nil then
				local groupCaptionText = ""
				local groupName = ""
				local playerIterated = cpt_get_player(pl)
				local playtimePlayer = "0 minutes"
				if global.total_time_online_players[playerIterated.name] then
					playtimePlayer = Player_list.get_formatted_playtime_from_ticks(global.total_time_online_players[playerIterated.name])
				end
				if startswith(playerIterated.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX) then
					if not listGroupAlreadyDone[playerIterated.tag] then
						groupName = playerIterated.tag
						listGroupAlreadyDone[playerIterated.tag] = true
						addGuiShowPlayerInfo(t,button1Name,button1Text,pl,groupName,playtimePlayer)
						for _,plOfGroup in pairs(tableBeingLooped) do
							if plOfGroup ~= pl then
								local groupNameOtherPlayer = cpt_get_player(plOfGroup).tag
								if groupNameOtherPlayer ~= "" and groupName == groupNameOtherPlayer then
									playtimePlayer = "0 minutes"
									local nameOtherPlayer = cpt_get_player(plOfGroup).name
									if global.total_time_online_players[nameOtherPlayer] then
										playtimePlayer = Player_list.get_formatted_playtime_from_ticks(global.total_time_online_players[nameOtherPlayer])
									end
									addGuiShowPlayerInfo(t,button1Name,button1Text,plOfGroup,groupName,playtimePlayer)
								end
							end
						end
					end
				else
					addGuiShowPlayerInfo(t,button1Name,button1Text,pl,groupName,playtimePlayer)
				end
			end
		end
	end
end

local function poll_alternate_picking(player)
	pickPlayerGenerator(player,global.special_games_variables["captain_mode"]["listPlayers"],
	"captain_poll_alternate_pick_choice_frame","Who do you want to pick ?",
	"Magical1@StringHere","captain_player_picked_Magical1@StringHere")
end

local function renderText(textId, textChosen, targetPos, color, scaleChosen, fontChosen)
	global.special_games_variables["rendering"][textId] = rendering.draw_text{
		text = textChosen,
		surface = game.surfaces[global.bb_surface_name],
		target = targetPos,
		color = color,
		scale = scaleChosen,
		font = fontChosen,
		alignment = "center",
		scale_with_zoom = false
	}
end

local function generateGenericRenderingCaptain()
	local y = -14
	renderText("captainLineOne", "Special event rule only : ",
		{-65,y}, {1,1,1,1}, 3, "heading-1")
	y = y + 2
	renderText("captainLineTwo","-Use of /nth /sth /north-chat /south-chat /s /shout by spectator can be punished (warn-tempban event)",
		{-65,y}, Color.captain_versus_float, 3, "heading-1")
	y = y + 4
	renderText("captainLineThree","Notes: ",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
	renderText("captainLineFour","-Chat of spectator can only be seen by spectators for players",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
	renderText("captainLineSix","-Teams are locked, if you want to play, click 'Join Info' at top of screen",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
	renderText("captainLineSeven","-We are using discord bb for comms (not required), feel free to join to listen, even if no mic",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
	renderText("captainLineEight","-If you are not playing, you can listen to any team, but your mic must be off",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
	renderText("captainLineNine","-No sign up required, anyone can play the event!",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
end

local function auto_pick_all_of_group(cptPlayer,playerName)
	local special = global.special_games_variables["captain_mode"]
	if special["captainGroupAllowed"] and not special["initialPickingPhaseFinished"] then
		local playerChecked = cpt_get_player(playerName)
		local amountPlayersSwitchedForGroup = 0
		local playersToSwitch = {}
		for _, playerName in ipairs(special["listPlayers"]) do
			local player = cpt_get_player(playerName)
			if global.chosen_team[playerName] == nil and player.tag == playerChecked.tag and player.force.name == "spectator" then -- only pick player without a team within the same group
				if amountPlayersSwitchedForGroup < special["groupLimit"] - 1 then
					table.insert(playersToSwitch, playerName)
					amountPlayersSwitchedForGroup = amountPlayersSwitchedForGroup + 1
				else
					game.print(playerName .. ' was not picked automatically with group system, as the group limit was reached', Color.red)
				end
			end
		end
		for _, playerName in ipairs(playersToSwitch) do
			local player = cpt_get_player(playerName)
			game.print(playerName .. ' was automatically picked with group system', Color.cyan)
			switchTeamOfPlayer(playerName, playerChecked.force.name)
			player.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
			removeStringFromTable(special["listPlayers"], playerName)
		end
	end
end

---@param playerName string
---@return boolean
local function is_player_in_group_system(playerName)
	--function used to balance team when a team is picked
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		local playerChecked = cpt_get_player(playerName)
		if playerChecked and playerChecked.tag ~= "" and startswith(playerChecked.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX) then
			return true
		end
	end
	return false
end

---@param playerNames string[]
---@return table<string, string[]>
local function generate_groups(playerNames)
	local special = global.special_games_variables["captain_mode"]
	local groups = {}
	for _, playerName in pairs(playerNames) do
		if is_player_in_group_system(playerName) then
			local player = cpt_get_player(playerName)
			if player then
				local groupName = player.tag
				local group = groups[groupName]
				if not group then
					group = {}
					groups[groupName] = group
				end
				local group_size = 0
				for _ in pairs(group) do
					group_size = group_size + 1
				end
				if group_size < special["groupLimit"] then
					table.insert(group, playerName)
				end
			end
		end
	end
	for groupName, group in pairs(groups) do
		if #group <= 1 then
			groups[groupName] = nil
		end
	end
	return groups
end

local function check_if_enough_playtime_to_play(player)
	return (global.total_time_online_players[player.name] or 0) >= global.special_games_variables["captain_mode"]["minTotalPlaytimeToPlay"]
end

local function allow_vote()
            local tick = game.ticks_played
            global.difficulty_votes_timeout = tick + 999999
            global.difficulty_player_votes = {}
            game.print('[font=default-large-bold]Difficulty voting is opened until the referee starts the picking phase ![/font]', Color.cyan)
end

local function generate_captain_mode(refereeName, autoTrust, captainKick, specialEnabled)
	if Functions.get_ticks_since_game_start() > 0 then
		game.print("Must start the captain event on a fresh map. Enable tournament_mode and do '/instant_map_reset current' to reset to current seed.", Color.red)
		return
	end
	captainKick = captainKick == "left"
	autoTrust = autoTrust == "left"

	local auto_pick_interval_ticks = 5*60*60 -- 5 minutes
	local special = {
		["captainList"] = {},
		["refereeName"] = refereeName,
		["listPlayers"] = {},
		["player_info"] = {},
		["kickedPlayers"] = {},
		["listTeamReadyToPlay"] = {},
		["prepaPhase"] = true,
		["countdown"] = 9,
		["minTotalPlaytimeToPlay"]= 30 * 60 * 60 , -- 30 minutes
		["pickingPhase"] = false,
		["initialPickingPhaseStarted"] = false,
		["initialPickingPhaseFinished"] = false,
		["nextAutoPicksFavor"] = {north = 0, south = 0},
		["autoPickIntervalTicks"] = auto_pick_interval_ticks,
		["nextAutoPickTicks"] = auto_pick_interval_ticks,
		["autoTrust"] = autoTrust,
		["captainKick"] = captainKick,
		["northEnabledScienceThrow"] = true,
		["northThrowPlayersListAllowed"] = {},
		["southEnabledScienceThrow"] = true,
		["southThrowPlayersListAllowed"] = {},
		["captainGroupAllowed"] = true,
		["groupLimit"] = 3,
		["teamAssignmentSeed"] = math.random(10000, 100000),
		["playerPickedAtTicks"] = {},
		["stats"] = {["northPicks"]={},["southPicks"]={},["tickGameStarting"]=0,["playerPlaytimes"]={},["playerSessionStartTimes"]={}}}
	global.special_games_variables["captain_mode"] = special
	global.active_special_games["captain_mode"] = true
	local referee = cpt_get_player(special["refereeName"])
	if referee == nil then
		game.print("Event captain aborted, referee is not a player connected. Provided referee name was: " .. special["refereeName"])
		global.special_games_variables["captain_mode"] = nil
		global.active_special_games["captain_mode"] = false
		return
	end

	if not check_if_enough_playtime_to_play(referee) then
		game.print("Referee does not seem to have enough playtime (which is odd), so disabling min playtime requirement", Color.red)
		special["minTotalPlaytimeToPlay"] = 0
	end

	global.bb_threat["north_biters"] = -99999999999
	global.bb_threat["south_biters"] = -99999999999
	clear_gui_captain_mode()
	for _, pl in pairs(game.connected_players) do
		if pl.force.name ~= "spectator" then
			pl.print('Captain event is on the way, switched you to spectator')
			Team_manager.switch_force(pl.name,"spectator")
		end
		Public.draw_captain_player_button(pl)
		Public.draw_captain_player_gui(pl)
	end
	global.chosen_team = {}
	clear_character_corpses()
	game.print('Captain mode started !! Have fun ! Referee will be '.. referee.name)
	if special["autoTrust"] then
		game.print('Option was enabled : All players will be trusted once they join a team', Color.cyan)
	end
	if special["captainKick"] then
		game.print('Option was enabled : Captains can eject players of their team', Color.cyan)
	end
	game.print('Picking system : 1-2-2-2-2...', Color.cyan)
	referee.print("Command only allowed for referee to change a captain : /replaceCaptainNorth <playerName> or /replaceCaptainSouth <playerName>", Color.cyan)
	for _, player in pairs(game.connected_players) do
		if player.admin then
			game.print("Command only allowed for referee or admins to change the current referee : /replaceReferee <playerName>", Color.cyan)
		end
	end

	if specialEnabled == "left" then
		special["stats"]["specialEnabled"] = 1
	else
		special["stats"]["specialEnabled"] = 0
	end

	global.tournament_mode = true
	if global.freeze_players == false or global.freeze_players == nil then
		global.freeze_players = true
		Team_manager.freeze_players()
		game.print(">>> Players have been frozen!", {r = 111, g = 111, b = 255})
	end
	allow_vote()

	local y = 0
	if global.special_games_variables["rendering"] == nil then global.special_games_variables["rendering"] = {} end
	rendering.clear()
	renderText("captainLineTen","Special Captain's tournament mode enabled", {0,-16}, {1,0,0,1}, 5, "heading-1")
	renderText("captainLineEleven","team xx vs team yy. Referee: " .. refereeName .. ". Teams on VC", {0,10}, Color.captain_versus_float, 1.5,"heading-1")
	generateGenericRenderingCaptain()
	Public.draw_captain_referee_button(referee)
	Public.draw_captain_referee_gui(referee)
end

local function delete_player_from_playersList(playerName,isNorthPlayerBoolean)
	local special = global.special_games_variables["captain_mode"]
	local tableChosen = special["stats"]["southPicks"]
	if isNorthPlayerBoolean then
		tableChosen = special["stats"]["northPicks"]
	end
	local index={}
	for k,v in pairs(tableChosen) do
		index[v] = k
	end
	local indexPlayer = index[playerName]
	table.remove(tableChosen, indexPlayer)
end

local function generate_vs_text_rendering()
	if global.active_special_games and global.special_games_variables["rendering"] and global.special_games_variables["rendering"]["captainLineVersus"] then
		rendering.destroy(global.special_games_variables["rendering"]["captainLineVersus"])
	end

	local special = global.special_games_variables["captain_mode"]
	local text = string.format("Team %s (North) vs (South) Team %s. Referee: %s. Teams on Voice Chat",
		special["captainList"][1],
		special["captainList"][2],
		special["refereeName"]
	)

	renderText("captainLineVersus", text, {0,10}, Color.captain_versus_float, 1.5, "heading-1")
end

local function start_captain_event()
	Functions.set_game_start_tick()
	game.print('[font=default-large-bold]Time to start the game!! Good luck and have fun everyone ![/font]', Color.cyan)
	if global.freeze_players == true then
		global.freeze_players = false
		Team_manager.unfreeze_players()
		game.print(">>> Players have been unfrozen!", {r = 255, g = 77, b = 77})
		log("Players have been unfrozen! Game starts now!")
	end
	global.special_games_variables["captain_mode"]["prepaPhase"] = false
	global.special_games_variables["captain_mode"]["stats"]["tickGameStarting"] = game.ticks_played
	global.special_games_variables["captain_mode"]["stats"]["NorthInitialCaptain"] = global.special_games_variables["captain_mode"]["captainList"][1]
	global.special_games_variables["captain_mode"]["stats"]["SouthInitialCaptain"] = global.special_games_variables["captain_mode"]["captainList"][2]
	global.special_games_variables["captain_mode"]["stats"]["InitialReferee"] = global.special_games_variables["captain_mode"]["refereeName"]
	local difficulty = Tables.difficulties[global.difficulty_vote_index].name;
	if "difficulty" == "I'm Too Young to Die" then difficulty = "ITYTD"
	elseif "difficulty" == "Fun and Fast" then difficulty = "FNF"
	elseif "difficulty" == "Piece of Cake" then difficulty = "POC" end
	global.special_games_variables["captain_mode"]["stats"]["extrainfo"] = difficulty
	global.bb_threat["north_biters"] = 0
	global.bb_threat["south_biters"] = 0

	rendering.clear()
	renderText("captainLineSeventeen","Special Captain's tournament mode enabled", {0, -16}, {1,0,0,1}, 5, "heading-1")
	generate_vs_text_rendering()
	generateGenericRenderingCaptain()
	renderText("captainLineEighteen","Want to play? Click 'Join Info' button at top of screen!", {0, -9}, {1,1,1,1}, 3, "heading-1")

	for _, player in pairs(game.connected_players) do
		if player.force.name == "north" or player.force.name == "south" then
			global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] = Functions.get_ticks_since_game_start();
		end
	end
end

local countdown_captain_start_token = Token.register(
    function()
		if global.special_games_variables["captain_mode"]["countdown"] > 0 then
			for _, player in pairs(game.connected_players) do
				local _sprite="file/png/"..global.special_games_variables["captain_mode"]["countdown"]..".png"
				if player.gui.center["bb_captain_countdown"] then player.gui.center["bb_captain_countdown"].destroy() end
				player.gui.center.add{name = "bb_captain_countdown", type = "sprite", sprite = _sprite}
			end	
			global.special_games_variables["captain_mode"]["countdown"] = global.special_games_variables["captain_mode"]["countdown"] - 1
		else
			for _, player in pairs(game.connected_players) do
				if player.gui.center["bb_captain_countdown"] then player.gui.center["bb_captain_countdown"].destroy() end
			end	
			start_captain_event()
		end
    end
)

local function prepare_start_captain_event()
	local special = global.special_games_variables["captain_mode"]
	special["listTeamReadyToPlay"] = {"north", "south"}
	Public.update_all_captain_player_guis()

	Task.set_timeout_in_ticks(60, countdown_captain_start_token)
	Task.set_timeout_in_ticks(120, countdown_captain_start_token)
	Task.set_timeout_in_ticks(180, countdown_captain_start_token)
	Task.set_timeout_in_ticks(240, countdown_captain_start_token)
	Task.set_timeout_in_ticks(300, countdown_captain_start_token)
	Task.set_timeout_in_ticks(360, countdown_captain_start_token)
	Task.set_timeout_in_ticks(420, countdown_captain_start_token)
	Task.set_timeout_in_ticks(480, countdown_captain_start_token)
	Task.set_timeout_in_ticks(540, countdown_captain_start_token)
	Task.set_timeout_in_ticks(600, countdown_captain_start_token)
end

local function close_difficulty_vote()
            global.difficulty_votes_timeout = game.ticks_played
            game.print('[font=default-large-bold]Difficulty voting is now closed ![/font]', Color.cyan)
end

local function captain_log_start_time_player(player)
	if global.special_games_variables["captain_mode"] ~=nil and (player.force.name == "south" or player.force.name == "north") and not global.special_games_variables["captain_mode"]["prepaPhase"] then
		if not global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] then
			global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] = Functions.get_ticks_since_game_start()
		end
	end
end

function Public.generate(config, player)
	local refereeName = ternary(config["refereeName"].text == "", player.name, config["refereeName"].text)
	local autoTrustSystem = config["autoTrust"].switch_state
	local captainCanKick = config["captainKickPower"].switch_state
	local specialEnabled = config["specialEnabled"].switch_state
	generate_captain_mode(refereeName, autoTrustSystem, captainCanKick, specialEnabled)
end

-- Update the 'dropdown' GuiElement with the new items, trying to preserve the current selection (otherwise go to index 1).
local function update_dropdown(dropdown, new_items)
	local selected_index = dropdown.selected_index
	if selected_index == 0 then selected_index = 1 end
	local change_items = #dropdown.items ~= #new_items
	if not change_items then
		for i = 1, #new_items do
			if new_items[i] ~= dropdown.items[i] then
				change_items = true
				break
			end
		end
	end
	if change_items then
		local existing_selection = dropdown.items[selected_index]
		selected_index = 1  -- if no match, go back to "Select Player"
		for index, item in ipairs(new_items) do
			if item == existing_selection then
				selected_index = index
				break
			end
		end
		dropdown.items = new_items
		dropdown.selected_index = selected_index
	end
end

function Public.draw_captain_manager_gui(player)
	if is_test_player(player) then return end
	if player.gui.screen["captain_manager_gui"] then player.gui.screen["captain_manager_gui"].destroy() end
	local frame = closable_frame.create_main_closable_frame(player, "captain_manager_gui", "Cpt Captain")
	frame.add({type = "label", name = "diff_vote_duration"})
	frame.add({type = "button", name = "captain_is_ready"})
	frame.add({type = "label", caption = "[font=heading-1][color=purple]Management for science throwing[/color][/font]"})
	frame.add({
		type = "button",
		name = "captain_toggle_throw_science"
	})
	local t = frame.add({type = "table", name = "captain_manager_root_table", column_count = 2})
	t.add({
		type = "button",
		name = "captain_add_someone_to_throw_trustlist",
		caption = "Add to throw trustlist",
		tooltip = "Add someone to be able to throw science when captain disabled throwing science from their team"
	})
	t.add({name = 'captain_add_trustlist_playerlist', type = "drop-down", width = 140})
	t.add({
		type = "button",
		name = "captain_remove_someone_to_throw_trustlist",
		caption = "Remove from throw trustlist",
		tooltip = "Remove someone to be able to throw science when captain disabled throwing science from their team"
	})
	t.add({name = 'captain_remove_trustlist_playerlist', type = "drop-down", width = 140})

	frame.add({type = "label", name = "throw_science_label"})

	frame.add({type = "label", name = "trusted_to_throw_list_label"})
	frame.add({type = "label", caption = ""})
	frame.add({type = "label", caption = "[font=heading-1][color=purple]Management for your players[/color][/font]"})
	local t2 = frame.add({type = "table", name = "captain_manager_root_table_two", column_count = 3})
	t2.add({
		type = "button",
		name = "captain_eject_player",
		caption = "Eject a player of your team",
		tooltip = "If you don't want someone to be in your team anymore, use this button (used for griefers, players not listening and so on..)"
	})
	t2.add({name = 'captain_eject_playerlist', type = "drop-down", width = 140})
	Public.update_captain_manager_gui(player)
end

function Public.update_captain_manager_gui(player)
	local frame = player.gui.screen["captain_manager_gui"]
	if not frame then return end
	local special = global.special_games_variables["captain_mode"]
	local force_name = global.chosen_team[player.name]
	local button = nil
	frame.diff_vote_duration.visible = false
	frame.captain_is_ready.visible = false
	if special["prepaPhase"] and not isStringInTable(special["listTeamReadyToPlay"], force_name) then
		frame.captain_is_ready.visible = true
		frame.captain_is_ready.caption = "Team is Ready!"
		frame.captain_is_ready.style = "green_button"
		if game.ticks_played < global.difficulty_votes_timeout then
			frame.diff_vote_duration.visible = true
			frame.diff_vote_duration.caption = string.format("Difficulty vote ongoing for %ds longer. Consider waiting until it is over before marking yourself as ready.", (global.difficulty_votes_timeout - game.ticks_played) / 60)
			frame.captain_is_ready.caption = "Mark team as ready even though difficulty vote is ongoing!"
			frame.captain_is_ready.style = "red_button"
		end
	end
	local throwScienceSetting = special["northEnabledScienceThrow"]
	if special["captainList"][2] == player.name then
		throwScienceSetting = special["southEnabledScienceThrow"]
	end
	if throwScienceSetting then
		caption = "Click to disable throwing science for the team"
	else
		caption = "Click to enable throwing science for the team"
	end
	frame.captain_toggle_throw_science.caption = caption
	frame.throw_science_label.caption = "Can anyone throw science ? : " .. (throwScienceSetting and "[color=green]YES[/color]" or "[color=red]NO[/color]")

	local tablePlayerListThrowAllowed = special["northThrowPlayersListAllowed"]
	if player.name == special["captainList"][2] then
		tablePlayerListThrowAllowed = special["southThrowPlayersListAllowed"]
	end
	frame.trusted_to_throw_list_label.caption = "List of players trusted to throw : " .. table.concat(tablePlayerListThrowAllowed, ' | ')
	local team_players = {}
	for name, force in pairs(global.chosen_team) do
		if force == force_name then
			table.insert(team_players, name)
		end
	end
	table.sort(team_players)
	table.insert(team_players, 1, 'Select Player')
	local t = frame.captain_manager_root_table
	update_dropdown(t.captain_add_trustlist_playerlist, team_players)
	update_dropdown(t.captain_remove_trustlist_playerlist, tablePlayerListThrowAllowed)
	local t2 = frame.captain_manager_root_table_two
	local allow_kick = (not special["prepaPhase"] and special["captainKick"])
	t2.visible = allow_kick

	if allow_kick then
		local dropdown = t2.captain_eject_playerlist
		update_dropdown(dropdown, team_players)
	end
end

function Public.draw_captain_manager_button(player)
	if is_test_player(player) then return end
	if player.gui.top["captain_manager_toggle_button"] then player.gui.top["captain_manager_toggle_button"].destroy() end
	local button = player.gui.top.add({type = "sprite-button", name = "captain_manager_toggle_button", caption = "Cpt Captain"})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 114, height = 38, padding = -2})
end

function Public.update_all_captain_player_guis()
	if not global.special_games_variables["captain_mode"] then return end
	for _, player in pairs(game.connected_players) do
		if player.gui.screen["captain_player_gui"] then
			Public.update_captain_player_gui(player)
		end
		if player.gui.screen["captain_manager_gui"] then
			Public.update_captain_manager_gui(player)
		end
	end
	local referee = cpt_get_player(global.special_games_variables["captain_mode"]["refereeName"])
	if referee.gui.screen["captain_referee_gui"] then
		Public.update_captain_referee_gui(referee)
	end
end

function Public.toggle_captain_player_gui(player)
	if player.gui.screen["captain_player_gui"] then
		player.gui.screen["captain_player_gui"].destroy()
	else
		Public.draw_captain_player_gui(player)
	end
end

function Public.toggle_captain_manager_gui(player)
	if player.gui.screen["captain_manager_gui"] then
		player.gui.screen["captain_manager_gui"].destroy()
	else
		Public.draw_captain_manager_gui(player)
	end
end

function Public.toggle_captain_referee_gui(player)
	if player.gui.screen["captain_referee_gui"] then
		player.gui.screen["captain_referee_gui"].destroy()
	else
		Public.draw_captain_referee_gui(player)
	end
end

local function get_player_list_with_groups()
	local special = global.special_games_variables["captain_mode"]
	local result = table.concat(special["listPlayers"], ", ")
	local groups = generate_groups(special["listPlayers"])
	local group_strings = {}
	for _, group in pairs(groups) do
		table.insert(group_strings, "(" .. table.concat(group, ", ") .. ")")
	end
	if #group_strings > 0 then
		result = result .. "\nGroups: " .. table.concat(group_strings, ", ")
	end
	return result
end

function Public.draw_captain_referee_gui(player)
	if is_test_player(player) then return end
	if player.gui.screen["captain_referee_gui"] then player.gui.screen["captain_referee_gui"].destroy() end
	local frame = closable_frame.create_main_closable_frame(player, "captain_referee_gui", "Cpt Referee")
	frame.style.maximal_width = 800
	frame.add({type = "scroll-pane", name = "scroll", direction = "vertical"})
	Public.update_captain_referee_gui(player)
end

function Public.update_captain_referee_gui(player)
	local special = global.special_games_variables["captain_mode"]
	local frame = player.gui.screen.captain_referee_gui
	if not frame then return end
	local scroll = frame.scroll
	-- Technically this would be more efficient if we didn't do the full clear here, and
	-- instead made elements visible/invisible as needed. But this is simpler and I don't
	-- think that performance really matters.
	scroll.clear()

	-- if game hasn't started, and at least one captain isn't ready, show a button to force both captains to be ready
	if special["prepaPhase"] and special["initialPickingPhaseStarted"] and not special["pickingPhase"] then
		if #special["listTeamReadyToPlay"] < 2 then
			scroll.add({type = "label", caption = "Teams ready to play: " .. table.concat(special["listTeamReadyToPlay"], ", ")})
			local b = scroll.add({type = "button", name = "captain_force_captains_ready", caption = "Force all captains to be ready", style="red_button"})
		end
	end

	local ticks_until_autopick = special["nextAutoPickTicks"] - Functions.get_ticks_since_game_start()
	if ticks_until_autopick < 0 then ticks_until_autopick = 0 end
	local caption
	if special["pickingPhase"] then
		caption = "Players remaining to be picked"
	else
		caption = "Players waiting for next join poll"
	end
	local l = scroll.add({type = "label", caption = #special["listPlayers"] .. " " .. caption .. ": " .. get_player_list_with_groups(), ", "})
	l.style.single_line = false
	scroll.add({type = "label", caption = string.format("Next auto picking phase in %ds", ticks_until_autopick / 60)})
	if #special["listPlayers"] > 0 and not special["pickingPhase"] and not special["prepaPhase"] and ticks_until_autopick > 0 then
		local button = scroll.add({type = "button", name = "captain_start_join_poll", caption = "Start poll for players to join the game (instead of waiting)"})
	end

	if #special["listPlayers"] > 0 and special["pickingPhase"] then
		local button = scroll.add({type = "button", name = "referee_force_picking_to_stop", caption = "Force the current round of picking to stop (only useful if changing captains)", style = "red_button"})
	end

	if special["prepaPhase"] and not special["initialPickingPhaseStarted"] then
		scroll.add({type = "label", caption = "Captain volunteers: " .. table.concat(special["captainList"], ", ")})
		-- turn listPlayers into a map for efficiency
		local players = {}
		for _, player in pairs(special["listPlayers"]) do
			players[player] = true
		end
		local spectators = {}
		for _, player in pairs(game.connected_players) do
			if not players[player.name] then
				table.insert(spectators, player.name)
			end
		end
		table.sort(spectators)
		scroll.add({type = "label", caption = string.format("Everyone else: ", table.concat(spectators, " ,"))})
		---@type LuaGuiElement
		local b = scroll.add({type = "button", name = "captain_force_end_event", caption = "Cancel captains event", style = "red_button"})
		b.style.font = "heading-2"
		caption = "Confirm captains and start the picking phase"
		if special["balancedRandomTeamsMode"] then
			caption = "Confirm captains and instantly assign players to teams (balanced random teams mode)"
		end
		b = scroll.add({type = "button", name = "captain_end_captain_choice", caption = caption, style = "confirm_button", enabled = #special["captainList"] == 2, tooltip = "People can add themselves to the first round of picking right up until you press this button"})
		b.style.font = "heading-2"
		b.style.minimal_width = 540
		b.style.horizontal_align = "center"
		for index, captain in ipairs(special["captainList"]) do
			b = scroll.add({type = "button", name = "captain_remove_captain_" .. tostring(index), caption = "Remove " .. captain .. " as a captain", style = "red_button", tags = {captain = captain}})
			b.style.font = "heading-2"
		end
		scroll.add({type = "switch", name = "captain_enable_groups_switch", switch_state = special["captainGroupAllowed"] and "left" or "right", left_label_caption = "Groups allowed", right_label_caption = "Groups not allowed"})
		-- horizontal flow
		local flow = scroll.add({type = "flow", direction = "horizontal"})
		flow.add({type = "label", caption = string.format('Max players in a group (%d): ', special["groupLimit"])})

		local slider = flow.add({type = "slider", name = "captain_group_limit_slider", minimum_value = 2, maximum_value = 5, value = special["groupLimit"], discrete_slider = true})
	end

	if special["prepaPhase"] and not special["initialPickingPhaseStarted"] then
		scroll.add({type = "label", caption = "The below logic is used for the initial picking phase!"})
		scroll.add({type = "label", caption = "north will be the first (non-rejected) captain in the list of captain volunteers above."})
	end
	for _, force in pairs({"north", "south"}) do
		-- add horizontal flow
		local flow = scroll.add({type = "flow", direction = "horizontal", name = force})
		local favor = special["nextAutoPicksFavor"][force]
		flow.add({type = "label", caption = string.format("Favor %s with next picking phase preference %d times. ", force, favor)})
		local button = flow.add({type = "button", name = "captain_favor_plus", caption = "+1"})
		gui_style(button, {width = 40, padding = -2})
		if favor > 0 then
			button = flow.add({type = "button", name = "captain_favor_minus", caption = "-1"})
			gui_style(button, {width = 40, padding = -2})
		end
	end
	if not special["initialPickingPhaseStarted"] then
		scroll.add({type = "switch", name = "captain_balanced_random_teams_mode", switch_state = special["balancedRandomTeamsMode"] and "left" or "right", left_label_caption = "Balanced random teams", right_label_caption = "Traditional picking"})
		if special["balancedRandomTeamsMode"] then
			-- add a label
			l = scroll.add({type = "label", caption = "Move players into buckets of approximately equal team benefit/skill. Left click a player to move them to a 'better' bucket, right click to move them to a 'worse' bucket. Do not worry too much about accuracy, as players will be randomly assigned to teams as well. There is no harm in having many buckets or few buckets."})
			l.style.single_line = false
			scroll.add({type = "line"})
			scroll.add({type = "label", caption = "Best"})
			scroll.add({type = "line"})
			for i = 1, #special["playerBuckets"] do
				local bucket = special["playerBuckets"][i]
				local players = {}
				for _, player in pairs(bucket) do
					table.insert(players, player)
				end
				table.sort(players)
				local flow = scroll.add({type = "flow", direction = "horizontal"})
				for _, player in pairs(players) do
					if #flow.children >= 6 then
						flow = scroll.add({type = "flow", direction = "horizontal"})
					end
					local b = flow.add({type = "button", name = "captain_bucket_player_" .. player, caption = player, tags = {bucket = i, player = player}})
					b.style.minimal_width = 40
				end
				scroll.add({type = "line"})
			end
			scroll.add({type = "label", caption = "Worst"})
			scroll.add({type = "line"})
			scroll.add({type = "switch", name = "captain_peek_at_assigned_teams", switch_state = special["peekAtRandomTeams"] and "left" or "right", left_label_caption = "Peek", right_label_caption = "No Peeking"})
			local flow = scroll.add({type = "flow", direction = "horizontal"})
			flow.add({type = "label", caption = "Random seed: " .. special["teamAssignmentSeed"]})
			local button = flow.add({type = "button", name = "captain_change_assignment_seed", caption = "Change seed"})
			if special["peekAtRandomTeams"] then
				local forced_assignments = {}
				for team, captain in ipairs(special["captainList"]) do
					if not global.chosen_team[captain] then
						forced_assignments[captain] = team
					end
				end
				local groups = generate_groups(special["listPlayers"])
				local result = CaptainRandomPick.assign_teams_from_buckets(special["playerBuckets"], forced_assignments, groups, special["teamAssignmentSeed"])
				-- horizontal flow
				local flow = scroll.add({type = "flow", direction = "horizontal"})
				for i, team in ipairs(result) do
					local l = flow.add({type = "label", caption = Functions.team_name_with_color(i == 1 and "north" or "south") .. "\n" .. table.concat(team, "\n")})
					l.style.minimal_width = 220
					l.style.single_line = false
				end
			end
		end
	end
end

function Public.draw_captain_player_gui(player)
	if is_test_player(player) then return end
	if player.gui.screen["captain_player_gui"] then player.gui.screen["captain_player_gui"].destroy() end
	local special = global.special_games_variables["captain_mode"]
	local frame = closable_frame.create_draggable_frame(player, "captain_player_gui", "Join Info")
	frame.style.maximal_width = 800

	local prepa_flow = frame.add({type = "flow", name = "prepa_flow", direction = "vertical"})
	prepa_flow.add({type = "label", caption = "A captains game will start soon!"})
	prepa_flow.add({type = "line"})
	local l = prepa_flow.add({type = "label", name = "want_to_play_players_list"})
	l.style.single_line = false
	prepa_flow.add({type = "label", name = "captain_volunteers_list"})
	l = prepa_flow.add({type = "label", name = "remaining_players_list"})
	l.style.single_line = false

	frame.add({type = "line"})
	l = frame.add({type = "label", name = "status_label"})
	l.style.single_line = false

	frame.add({type = "line"})
	local want_to_play_row = frame.add({type = "table", name = "captain_player_want_to_play_row", column_count = 2})
	local b = want_to_play_row.add({type = "button", name = "captain_player_want_to_play", caption = "I want to be a PLAYER!", style = "confirm_button", tooltip = "Yay"})
	b.style.font = "heading-2"
	b.style.horizontally_stretchable = true
	b.style.horizontal_align = "left"
	b = want_to_play_row.add({type = "button", name = "captain_player_do_not_want_to_play", caption = "Nevermind, I don't want to play", style = "red_button", tooltip = "Boo"})

	local want_to_be_captain_row = frame.add({type = "table", name = "captain_player_want_to_be_captain_row", column_count = 2})
	b = want_to_be_captain_row.add({type = "button", name = "captain_player_want_to_be_captain", caption = "I want to be a CAPTAIN!", style = "confirm_button", tooltip = "The community needs you"})
	b.style.font = "heading-2"
	b.style.horizontally_stretchable = true
	b.style.horizontal_align = "left"
	b = want_to_be_captain_row.add({type = "button", name = "captain_player_do_not_want_to_be_captain", caption = "Nevermind, I don't want to captain", style = "red_button", tooltip = "The weight of responsibility is too great"})

	-- Add a textbox for the player to enter info for the captains to see when picking
	local player_info_flow = frame.add({type = "flow", name = "captain_player_info_flow", direction = "vertical"})
	player_info_flow.add({type = "line", name = "captain_player_info_label_above_line"})
	l = player_info_flow.add({type = "label", name = "captain_player_info_label", caption = "Enter any info you want the captains to see when picking players,\ni.e. 'I will be on discord. I can threatfarm. I can build lots of power.'"})
	l.style.single_line = false
	local textbox = player_info_flow.add({type = "textfield", name = "captain_player_info", text = special["player_info"][player.name] or "", tooltip = "Enter any info you want the captains to see when picking players."})
	textbox.style.horizontally_stretchable = true
	textbox.style.width = 0

	frame.add({type = "line", name = "player_table_line"})
	local scroll = frame.add({type = "scroll-pane", name = "player_table_scroll", direction = "vertical"})
	scroll.style.maximal_height = 600
	Public.update_captain_player_gui(player)
end

function Public.update_captain_player_gui(player)
	local frame = player.gui.screen.captain_player_gui
	if not frame then return end
	local special = global.special_games_variables["captain_mode"]
	local prepa_flow = frame.prepa_flow
	prepa_flow.visible = special["prepaPhase"]
	if special["prepaPhase"] then
		local want_to_play = prepa_flow.want_to_play_players_list
		local cpt_volunteers = prepa_flow.captain_volunteers_list
		local rem = prepa_flow.remaining_players_list
		if not special["initialPickingPhaseStarted"] then
			want_to_play.visible = true
			want_to_play.caption = "Players (" .. #special["listPlayers"] .. "): " .. get_player_list_with_groups()
			cpt_volunteers.visible = true
			cpt_volunteers.caption = "Captain volunteers (" .. #special["captainList"] .. "): " .. table.concat(special["captainList"], ", ")
			rem.visible = false
		else
			want_to_play.visible = false
			cpt_volunteers.visible = false
			rem.visible = true
			rem.caption = #special["listPlayers"] .. " " .. "Players remaining to be picked: " .. table.concat(special["listPlayers"], ", ")
		end
	end
	frame.captain_player_want_to_play_row.captain_player_want_to_play.visible = false
	frame.captain_player_want_to_play_row.captain_player_do_not_want_to_play.visible = false
	frame.captain_player_want_to_be_captain_row.captain_player_want_to_be_captain.visible = false
	frame.captain_player_want_to_be_captain_row.captain_player_do_not_want_to_be_captain.visible = false
	local waiting_to_be_picked = isStringInTable(special["listPlayers"], player.name)
	local status_strings = {}
	if global.chosen_team[player.name] then
		table.insert(status_strings, "On team " .. global.chosen_team[player.name] .. ": " .. Functions.team_name_with_color(global.chosen_team[player.name]))
	elseif special["kickedPlayers"][player.name] then
		table.insert(status_strings, "You were kicked from a team, talk to the Referee about joining if you want to play.")
	elseif special["pickingPhase"] and waiting_to_be_picked then
		table.insert(status_strings, "Currently waiting to be picked by a captain.")
	elseif special["pickingPhase"] then
		table.insert(status_strings, "A picking phase is currently active, wait until it is done before you can indicate that you want to play.")
	end
	if waiting_to_be_picked and not special["pickingPhase"] then
		frame.captain_player_info_flow.visible = true
	else
		frame.captain_player_info_flow.visible = false
	end
	if not global.chosen_team[player.name] and not special["pickingPhase"] and not special["kickedPlayers"][player.name] then
		frame.captain_player_want_to_play_row.captain_player_want_to_play.visible = true
		frame.captain_player_want_to_play_row.captain_player_want_to_play.enabled = not waiting_to_be_picked
		frame.captain_player_want_to_play_row.captain_player_do_not_want_to_play.visible = true
		frame.captain_player_want_to_play_row.captain_player_do_not_want_to_play.enabled = waiting_to_be_picked
		if special["prepaPhase"] and not special["initialPickingPhaseStarted"] then
			if special["captainGroupAllowed"] then
				table.insert(status_strings, string.format('Groups of players: ENABLED, group name must start with "%s"', ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PREFIX))
				table.insert(status_strings, string.format('Max players allowed in a group: %d', special["groupLimit"]))
			else
				table.insert(status_strings, 'Groups of players: DISABLED')
			end

			frame.captain_player_want_to_be_captain_row.captain_player_want_to_be_captain.visible = true
			frame.captain_player_want_to_be_captain_row.captain_player_do_not_want_to_be_captain.visible = true
			if isStringInTable(special["captainList"], player.name) then
				table.insert(status_strings, "You are willing to be a captain! Thank you!")
				frame.captain_player_want_to_be_captain_row.captain_player_want_to_be_captain.enabled = false
				frame.captain_player_want_to_be_captain_row.captain_player_do_not_want_to_be_captain.enabled = true
			else
				table.insert(status_strings, "You are not currently willing to be captain.")
				frame.captain_player_want_to_be_captain_row.captain_player_want_to_be_captain.enabled = waiting_to_be_picked
				frame.captain_player_want_to_be_captain_row.captain_player_do_not_want_to_be_captain.enabled = false
			end
		end
	end
	if not special["prepaPhase"] then
		-- waiting for next picking phase (with time remaining)
		local ticks_until_autopick = special["nextAutoPickTicks"] - Functions.get_ticks_since_game_start()
		if ticks_until_autopick < 0 then ticks_until_autopick = 0 end
		table.insert(status_strings, string.format("Next auto picking phase in %ds.", ticks_until_autopick / 60))
	end
	frame.status_label.caption = table.concat(status_strings, "\n")

	local player_info = {}
	for player_name, force_name in pairs(global.chosen_team) do
		local info = {
			force = force_name,
			status = {},
			playtime = Public.get_total_playtime_of_player(player_name),
			picked_at = special["playerPickedAtTicks"][player_name]
		}
		player_info[player_name] = info
		local player = cpt_get_player(player_name)
		if player_name == special["refereeName"] then
			table.insert(info.status, "Referee")
		end
		if isStringInTable(special["captainList"], player_name) then
			table.insert(info.status, "Captain")
		end
		if player and not player.connected then
			table.insert(info.status, "Disconnected")
		elseif player and player.force.name == "spectator" then
			table.insert(info.status, "Spectating")
		end
	end
	if global.captains_add_silly_test_players_to_list then
		local forces = {"north", "south"}
		for i = 1, 10 do
			local status = (i % 2 == 0) and {"Spectating"} or {}
			for index, player_name in ipairs({"alice", "bob", "charlie", "dave", "eve"}) do
				if index % 2 == 0 then
					table.insert(status, "Disconnected")
				end
				player_info[player_name .. tostring(i)] = {force = forces[index % 2 + 1], status = status, playtime = i * 60*60*10, picked_at = i * 60*60*1}
			end
		end
		table.insert(player_info["alice1"].status, "Captain")
		table.insert(player_info["alice1"].status, "Referee")
	end
	local sorted_players = {}
	for player_name, _ in pairs(player_info) do
		table.insert(sorted_players, player_name)
	end
	table.sort(sorted_players, function(a, b)
		local info_a = player_info[a]
		local info_b = player_info[b]
		if info_a.force ~= info_b.force then return info_a.force == "north" end
		if info_a.playtime ~= info_b.playtime then return info_a.playtime > info_b.playtime end
		return a < b
	end)
	local scroll = frame.player_table_scroll
	if #sorted_players > 0 then
		frame.player_table_line.visible = true
		scroll.visible = true
		scroll.clear()
		local tab = scroll.add({type = "table", name = "player_table", column_count = 5, draw_horizontal_line_after_headers = true})
		tab.add({type = "label", caption = "Player"})
		tab.add({type = "label", caption = "Team"})
		tab.add({type = "label", caption = "PickedAt"})
		tab.add({type = "label", caption = "Playtime [img=info]", tooltip = "Amount of time actively on their team (fraction of time, since being picked, that the player is online and not spectating)"})
		tab.add({type = "label", caption = "Status"})
		local now_tick = Functions.get_ticks_since_game_start()
		for _, player_name in ipairs(sorted_players) do
			local info = player_info[player_name]
			local pick_duration = info.picked_at and (now_tick - info.picked_at) or 0
			local playtime_frac = pick_duration > 0 and info.playtime / pick_duration or 1
			tab.add({type = "label", caption = player_name})
			tab.add({type = "label", caption = Functions.team_name_with_color(info.force)})
			tab.add({type = "label", caption = info.picked_at and Functions.format_ticks_as_time(info.picked_at) or ""})
			tab.add({type = "label", caption = string.format("%s (%d%%)", Functions.format_ticks_as_time(info.playtime), 100 * playtime_frac)})
			tab.add({type = "label", caption = table.concat(info.status, ", ")})
		end
	else
		frame.player_table_line.visible = false
		scroll.visible = false
	end
end

function Public.draw_captain_player_button(player)
	if is_test_player(player) then return end
	if player.gui.top["captain_player_toggle_button"] then player.gui.top["captain_player_toggle_button"].destroy() end
	local button = player.gui.top.add({type = "sprite-button", name = "captain_player_toggle_button", caption = "Join Info"})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 114, height = 38, padding = -2})
end

function Public.draw_captain_referee_button(player)
	if is_test_player(player) then return end
	if player.gui.top["captain_referee_toggle_button"] then player.gui.top["captain_referee_toggle_button"].destroy() end
	local button = player.gui.top.add({type = "sprite-button", name = "captain_referee_toggle_button", caption = "Cpt Referee"})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 114, height = 38, padding = -2})
end

function Public.reset_special_games()
	if global.active_special_games["captain_mode"] then
		global.tournament_mode = false
	end
end

function Public.get_total_playtime_of_player(playerName)
	local playtime = 0
	local stats = global.special_games_variables["captain_mode"]["stats"]
	local playerPlaytimes = stats["playerPlaytimes"]
	if playerPlaytimes[playerName] then
		playtime = playerPlaytimes[playerName]
	end
	if stats["playerSessionStartTimes"][playerName] then
		local sessionTime = Functions.get_ticks_since_game_start() - stats["playerSessionStartTimes"][playerName]
		playtime = playtime + sessionTime
	end
	return playtime
end

function Public.captain_log_end_time_player(player)
	if global.special_games_variables["captain_mode"] ~=nil and not global.special_games_variables["captain_mode"]["prepaPhase"] then
		local stats = global.special_games_variables["captain_mode"]["stats"]
		if stats["playerSessionStartTimes"][player.name] then
			local sessionTime = Functions.get_ticks_since_game_start() - stats["playerSessionStartTimes"][player.name]
			if stats["playerPlaytimes"][player.name] then
				stats["playerPlaytimes"][player.name] = stats["playerPlaytimes"][player.name] + sessionTime
			else
				stats["playerPlaytimes"][player.name] = sessionTime
			end
			stats["playerSessionStartTimes"][player.name] = nil
		end
	end
end

function Public.clear_gui_special()
	clear_gui_captain_mode()
end

local function insertPlayerByPlaytime(playerName)
	local special = global.special_games_variables["captain_mode"]
    local playtime = 0
	if global.total_time_online_players[playerName] then
		playtime = global.total_time_online_players[playerName]
	end
    local listPlayers = special["listPlayers"]
    if isStringInTable(listPlayers, playerName) then return end
    local insertionPosition = 1
    for i, player in ipairs(listPlayers) do
		local playtimeOtherPlayer = 0
		if global.total_time_online_players[player] then
			playtimeOtherPlayer = global.total_time_online_players[player]
		end
        if playtimeOtherPlayer < playtime then
            insertionPosition = i
            break
		else
            insertionPosition = i + 1
        end
    end
    table.insert(listPlayers, insertionPosition, playerName)
	if special["balancedRandomTeamsMode"] and not special["initialPickingPhaseStarted"] then
		local playerBuckets = special["playerBuckets"]
		table.insert(playerBuckets[#playerBuckets], playerName)
	end
end

local function end_of_picking_phase()
	local special = global.special_games_variables["captain_mode"]
	special["pickingPhase"] = false
	if not special["initialPickingPhaseFinished"] then
		special["initialPickingPhaseFinished"] = true
		if special["captainGroupAllowed"] then
			game.print('[font=default-large-bold]Initial Picking Phase done - group picking is now disabled[/font]', Color.cyan)
		end
	end
	special["nextAutoPickTicks"] = Functions.get_ticks_since_game_start() + special["autoPickIntervalTicks"]
	if special["prepaPhase"] then
		game.print('[font=default-large-bold]All players were picked by captains, time to start preparation for each team ! Once your team is ready, captain, click on yes on top popup[/font]', Color.cyan)
		for _, captain_name in pairs(global.special_games_variables["captain_mode"]["captainList"]) do
			local captain = cpt_get_player(captain_name)
			captain.print("As a captain, you can handle your team by clicking on 'Cpt Captain' button top of screen",{r=1,g=1,b=0})
			Public.draw_captain_manager_button(captain)
			Public.draw_captain_manager_gui(captain)
			if not is_test_player(captain) then
				Team_manager.custom_team_name_gui(captain, captain.force.name)
			end
		end
	end
	Public.update_all_captain_player_guis()
end

local function start_picking_phase()
	local special = global.special_games_variables["captain_mode"]
	local is_initial_picking_phase = not special["initialPickingPhaseStarted"]
	special["pickingPhase"] = true
	special["initialPickingPhaseStarted"] = true
	if special["balancedRandomTeamsMode"] and is_initial_picking_phase then
		special["initialPickingPhaseStarted"] = true
		local groups = generate_groups(special["listPlayers"])
		local forced_assignments = {}
		for team = 1, 2 do
			forced_assignments[special["captainList"][team]] = team
		end
		local result = CaptainRandomPick.assign_teams_from_buckets(special["playerBuckets"], forced_assignments, groups, special["teamAssignmentSeed"])
		for i, team in ipairs(result) do
			for _, player in pairs(team) do
				switchTeamOfPlayer(player, i == 1 and "north" or "south")
				removeStringFromTable(special["listPlayers"], player)
			end
		end
		assert(#special["listPlayers"] == 0)
		special["playerBuckets"] = {{}}
		end_of_picking_phase()
		return
	end
	if special["prepaPhase"] then
		close_difficulty_vote()
		game.print('[font=default-large-bold]Picking phase started, captains will pick their team members[/font]', Color.cyan)
	end
	if #special["listPlayers"] == 0 then
		end_of_picking_phase()
	else
		special["pickingPhase"] = true
		local captainChosen
		local favor = special["nextAutoPicksFavor"]
		for index, force in ipairs({"north", "south"}) do
			if favor[force] > 0 then
				favor[force] = favor[force] - 1
				captainChosen = index
				break
			end
		end
		if captainChosen == nil then
			local counts = {north = 0, south = 0}
			for _, player in pairs(game.connected_players) do
				local force = player.force.name
				if force == "north" or force == "south" then  -- exclude "spectator"
					counts[force] = counts[force] + 1
				end
			end
			local northThreshold = 0.5 - 0.1 * (counts.north - counts.south)
			captainChosen = math_random() < northThreshold and 1 or 2
			log("Captain chosen: " .. captainChosen)
		end
		poll_alternate_picking(cpt_get_player(special["captainList"][captainChosen]))
	end
	Public.update_all_captain_player_guis()
end

local function check_if_right_number_of_captains(firstRun, referee)
	local special = global.special_games_variables["captain_mode"]
	if #special["captainList"] < 2 then
		referee.print('Not enough captains! Ask people to volunteer!', Color.cyan)
	elseif #special["captainList"] == 2 then
		for index, force_name in ipairs({"north", "south"}) do
			local captainName = special["captainList"][index]
			add_to_trust(captainName)
			if not special["balancedRandomTeamsMode"] then
				switchTeamOfPlayer(captainName, force_name)
				removeStringFromTable(special["listPlayers"], captainName)
			end
		end
		start_picking_phase()
	else
		referee.print('Too many captains! Remove some first!', Color.cyan)
	end
end

local function get_dropdown_value(dropdown)
	if dropdown and dropdown.selected_index then
		return dropdown.items[dropdown.selected_index]
	end
end

if false then
	commands.add_command("cpt-test-func", "Run some test-only code for captains games", function(event)
		if #game.players > 1 then
			game.print("This command is only for testing, and should only be run when there is exactly one player in the game.", Color.red)
			return
		end
		local refereeName = game.player.name
		local autoTrustSystem = "left"
		local captainCanKick = "left"
		local specialEnabled = "left"
		generate_captain_mode(refereeName, autoTrustSystem, captainCanKick, specialEnabled)
		local special = global.special_games_variables["captain_mode"]
		special.test_players = {}
		for _, playerName in ipairs({"alice", "bob", "charlie", "eve1", "eve2", "eve3", "fredrick_longname", "greg1", "greg2"}) do
			local group_name = ""
			if startswith(playerName, "eve") then group_name = "[cpt_eve]" end
			if startswith(playerName, "greg") then group_name = "[cpt_greg]" end
			special.test_players[playerName] = {name = playerName, tag = group_name}
			table.insert(special["listPlayers"], playerName)
		end
		special["player_info"]["alice"] = "I am a test player"
		special["player_info"]["charlie"] = "I am a test player. I write a very very very long description about what I am thinking about doing during the game that goes on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on and on."
		special["minTotalPlaytimeToPlay"] = 0
	end)
end

local function on_gui_switch_state_changed(event)
    local element = event.element
    if not element then return end
    if not element.valid then return end
	local special = global.special_games_variables["captain_mode"]
	if element.name == "captain_balanced_random_teams_mode" then
		special["balancedRandomTeamsMode"] = element.switch_state == "left"
		special["playerBuckets"] = {{}}
		for _, player in ipairs(special["listPlayers"]) do
			table.insert(special["playerBuckets"][1], player)
		end
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_peek_at_assigned_teams" then
		special["peekAtRandomTeams"] = element.switch_state == "left"
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_enable_groups_switch" then
		special["captainGroupAllowed"] = element.switch_state == "left"
		Public.update_all_captain_player_guis()
	end
end

local function on_gui_text_changed(event)
	local element = event.element
	if not element then return end
	if not element.valid then return end
	local player = cpt_get_player(event.player_index)
	local special = global.special_games_variables["captain_mode"]
	if not special then return end
	if element.name == "captain_player_info" then
		if #element.text > 200 then
			player.print("Info must be 200 characters or less", Color.warning)
			element.text = string.sub(element.text, 1, 200)
		end
		special["player_info"][player.name] = element.text
	end
end

local function on_gui_value_changed(event)
    local element = event.element
    if not element then return end
    if not element.valid then return end
	local special = global.special_games_variables["captain_mode"]
	if not special then return end
	if element.name == "captain_group_limit_slider" then
		special["groupLimit"] = element.slider_value
		Public.update_all_captain_player_guis()
	end
end

local function on_gui_click(event)
    local element = event.element
    if not element then return end
    if not element.valid then return end
	if not element.type == "button" then return end
	local player = cpt_get_player(event.player_index)
	if not player then return end
	local special = global.special_games_variables["captain_mode"]
	if not special then return end

	if element.name == "captain_player_want_to_play" then
		if not special["pickingPhase"] then
			if check_if_enough_playtime_to_play(player) then
				insertPlayerByPlaytime(player.name)
				Public.update_all_captain_player_guis()
			else
				player.print("You need to have spent more time on biter battles server to join the captain game event ! Learn and watch a bit meanwhile", Color.red)
			end
		end
	elseif element.name == "captain_player_do_not_want_to_play" then
		if not special["pickingPhase"] then
			bb_diff.remove_player_from_difficulty_vote(player)
			removeStringFromTable(special["listPlayers"], player.name)
			removeStringFromTable(special["captainList"], player.name)
			Public.update_all_captain_player_guis()
		end
	elseif element.name == "captain_player_want_to_be_captain" then
		if not special["initialPickingPhaseStarted"] and not isStringInTable(special["captainList"], player.name) and isStringInTable(special["listPlayers"], player.name) then
			table.insert(special["captainList"], player.name)
			Public.update_all_captain_player_guis()
		end
	elseif element.name == "captain_player_do_not_want_to_be_captain" then
		if not special["initialPickingPhaseStarted"] then
			removeStringFromTable(special["captainList"], player.name)
			Public.update_all_captain_player_guis()
		end
	elseif element.name == "captain_force_end_event" then
		force_end_captain_event()
	elseif element.name == "captain_end_captain_choice" then
		-- This marks the start of a picking phase, so players can no longer volunteer to become captain or play
		if not special["initialPickingPhaseStarted"] then
			game.print('The referee ended the poll to get the list of captains and players playing', Color.cyan)
			check_if_right_number_of_captains(true, player)
		end
	elseif string.find(element.name, "captain_remove_captain_") == 1 then
		local captain = element.tags.captain
		removeStringFromTable(special["captainList"], captain)
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_start_join_poll" then
		if not global.special_games_variables["captain_mode"]["pickingPhase"] then
			start_picking_phase()
		end
	elseif element.name == "referee_force_picking_to_stop" then
		if special["pickingPhase"] then
			end_of_picking_phase()
			-- destroy any open picking UIs
			for _, player in pairs(game.connected_players) do
				if player.gui.center["captain_poll_alternate_pick_choice_frame"] then
					player.gui.center["captain_poll_alternate_pick_choice_frame"].destroy()
				end
			end
			game.print('[font=default-large-bold]Referee ' .. player.name .. ' has forced the picking phase to stop[/font]', Color.cyan)
		end
	elseif string.find(element.name, "captain_player_picked_") == 1 then
		local playerPicked = element.name:gsub("^captain_player_picked_", "")
		if player.gui.center["captain_poll_alternate_pick_choice_frame"] then player.gui.center["captain_poll_alternate_pick_choice_frame"].destroy() end
		game.print(playerPicked .. " was picked by Captain " .. player.name)
		local listPlayers = special["listPlayers"]
		local forceToGo = "north"
		if player.name == special["captainList"][2] then forceToGo = "south" end
		switchTeamOfPlayer(playerPicked, forceToGo)
		cpt_get_player(playerPicked).print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
		for index, name in pairs(listPlayers) do
			if name == playerPicked then
				table.remove(listPlayers,index)
				break
			end
		end
		if is_player_in_group_system(playerPicked) then
			auto_pick_all_of_group(player, playerPicked)
		end

		if #global.special_games_variables["captain_mode"]["listPlayers"] == 0 then
			special["pickingPhase"] = false
			end_of_picking_phase()
		else
			local captain_to_pick_next
			if not special["initialPickingPhaseFinished"] then
				-- The logic below defaults to a 1-2-2-2-2-... picking system. However, if large groups
				-- are picked, then whatever captain is picking gets to keep picking until they have more
				-- players than the other team, so if there is one group of 3 that is picked first, then
				-- the picking would go 3-4-2-2-2-...
				if #special["stats"]["southPicks"] > #special["stats"]["northPicks"] then
					captain_to_pick_next = 1
				elseif #special["stats"]["northPicks"] > #special["stats"]["southPicks"] then
					captain_to_pick_next = 2
				else
					-- default to the same captain continuing to pick
					captain_to_pick_next = (player.name == special["captainList"][1] and 1 or 2)
				end
			else
				-- just alternate picking
				captain_to_pick_next = (player.name == special["captainList"][1] and 2 or 1)
			end
			poll_alternate_picking(cpt_get_player(special["captainList"][captain_to_pick_next]))
		end
		Public.update_all_captain_player_guis()
	elseif string.find(element.name, "captain_is_ready") then
		if not isStringInTable(special["listTeamReadyToPlay"], player.force.name) then
			game.print('[font=default-large-bold]Team of captain ' .. player.name .. ' is ready ![/font]', Color.cyan)
			table.insert(special["listTeamReadyToPlay"], player.force.name)
			if #special["listTeamReadyToPlay"] >= 2 then
				prepare_start_captain_event()
			end
		end
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_force_captains_ready" then
		if #special["listTeamReadyToPlay"] < 2 then
			game.print('[font=default-large-bold]Referee ' .. player.name .. ' force started the game ![/font]', Color.cyan)
			prepare_start_captain_event()
			Public.update_all_captain_player_guis()
		end
	elseif element.name == "captain_toggle_throw_science" then
		if special["captainList"][2] == player.name then
			special["southEnabledScienceThrow"] = not special["southEnabledScienceThrow"]
			game.forces["south"].print("Can anyone throw science in your team ? " .. tostring(special["southEnabledScienceThrow"]), {r=1,g=1,b=0})
		else
			special["northEnabledScienceThrow"] = not special["northEnabledScienceThrow"]
			game.forces["north"].print("Can anyone throw science in your team ? " .. tostring(special["northEnabledScienceThrow"]), {r=1,g=1,b=0})
		end
		Public.draw_captain_manager_gui(player)
	elseif element.name == "captain_favor_plus" then
		local force = element.parent.name
		special["nextAutoPicksFavor"][force] = special["nextAutoPicksFavor"][force] + 1
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_favor_minus" then
		local force = element.parent.name
		special["nextAutoPicksFavor"][force] = math.max(0, special["nextAutoPicksFavor"][force] - 1)
		Public.update_all_captain_player_guis()
	elseif string.find(element.name, "captain_bucket_player_") == 1 then
		local player_to_move = element.tags.player
		local bucket = element.tags.bucket
		local playerBuckets = special["playerBuckets"]
		local playerBucket = playerBuckets[bucket]
		if not isStringInTable(playerBucket, player_to_move) then return end
		removeStringFromTable(playerBucket, player_to_move)
		local direction = (event.button == defines.mouse_button_type.right) and 1 or -1
		if bucket + direction < 1 then
			table.insert(playerBuckets, 1, {player_to_move})
			bucket = bucket + 1
		elseif bucket + direction > #playerBuckets then
			table.insert(playerBuckets, {player_to_move})
		else
			table.insert(playerBuckets[bucket + direction], player_to_move)
		end
		if #playerBucket == 0 then
			table.remove(playerBuckets, bucket)
		end
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_change_assignment_seed" then
		special["teamAssignmentSeed"] = math_random(10000, 100000)
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_manager_toggle_button" then
		Public.toggle_captain_manager_gui(player)
	elseif element.name == "captain_player_toggle_button" then
		Public.toggle_captain_player_gui(player)
	elseif element.name == "captain_referee_toggle_button" then
		Public.toggle_captain_referee_gui(player)
	elseif element.name == "captain_add_someone_to_throw_trustlist" then
		local playerNameUpdateText = get_dropdown_value(player.gui.screen["captain_manager_gui"]["captain_manager_root_table"]["captain_add_trustlist_playerlist"])
		if playerNameUpdateText and playerNameUpdateText ~= "" then
			local tableToUpdate = special["northThrowPlayersListAllowed"]
			local forceForPrint = "north"
			if player.name == special["captainList"][2] then
				tableToUpdate = special["southThrowPlayersListAllowed"]
				forceForPrint = "south"
			end
			local playerToAdd = cpt_get_player(playerNameUpdateText)
			if playerToAdd ~= nil and playerToAdd.valid then
				if not isStringInTable(tableToUpdate, playerNameUpdateText) then
					table.insert(tableToUpdate, playerNameUpdateText)
					game.forces[forceForPrint].print(playerNameUpdateText .. " added to throw trustlist !", Color.green)
				else
					player.print(playerNameUpdateText .. " was already added to throw trustlist !", Color.red)
				end
				Public.draw_captain_manager_gui(player)
				Public.draw_captain_manager_gui(player)
			else
				player.print(playerNameUpdateText .. " does not even exist or not even valid !", Color.red)
			end
		end
	elseif element.name == "captain_remove_someone_to_throw_trustlist" then
		local playerNameUpdateText = get_dropdown_value(player.gui.screen["captain_manager_gui"]["captain_manager_root_table"]["captain_remove_trustlist_playerlist"])
		if playerNameUpdateText and playerNameUpdateText ~= "" then
			local tableToUpdate = special["northThrowPlayersListAllowed"]
			local forceForPrint = "north"
			if player.name == special["captainList"][2] then
				tableToUpdate = special["southThrowPlayersListAllowed"]
				forceForPrint = "south"
			end
			if isStringInTable(tableToUpdate, playerNameUpdateText) then
				removeStringFromTable(tableToUpdate, playerNameUpdateText)
				game.forces[forceForPrint].print(playerNameUpdateText .. " was removed in throw trustlist !", Color.green)
			else
				player.print(playerNameUpdateText .. " was not found in throw trustlist !", Color.red)
			end
			Public.draw_captain_manager_gui(player)
			Public.draw_captain_manager_gui(player)
		end
	elseif element.name == "captain_eject_player" then
		local dropdown = player.gui.screen["captain_manager_gui"]["captain_manager_root_table_two"]["captain_eject_playerlist"]
		local victim = cpt_get_player(get_dropdown_value(dropdown))
		if victim and victim.valid then
			if victim.name == player.name then return player.print("You can't select yourself!", Color.red) end
			game.print("Captain " .. player.name .. " has decided that " .. victim.name .. " must not be in the team anymore.")
			special["kickedPlayers"][victim.name] = true
			delete_player_from_playersList(victim.name, victim.force.name)
			if victim.character then victim.character.die('player')	end
			Team_manager.switch_force(victim.name,"spectator")
		else
			player.print("Invalid name", Color.red)
		end
	end
end

function Public.captain_is_player_prohibited_to_throw(player)
	if global.active_special_games["captain_mode"] then
		local throwScienceSetting = global.special_games_variables["captain_mode"]["northEnabledScienceThrow"]
		local throwList = global.special_games_variables["captain_mode"]["northThrowPlayersListAllowed"]
		if player.force.name == "south" then
			throwScienceSetting = global.special_games_variables["captain_mode"]["southEnabledScienceThrow"]
			throwList = global.special_games_variables["captain_mode"]["southThrowPlayersListAllowed"]
		end
		if throwScienceSetting == false and isStringInTable(throwList, player.name) == false then
			return true
		end
	end
	return false
end

local function changeCaptain(cmd,isItForNorth)
	if not cmd.player_index then return end
		local playerOfCommand = cpt_get_player(cmd.player_index)
		if not playerOfCommand then return end
		if not global.active_special_games["captain_mode"] then
			return playerOfCommand.print('This command is only allowed in captain event, what are you doing ?!',Color.red)
		end
		if global.special_games_variables["captain_mode"]["prepaPhase"] then
			return playerOfCommand.print('This command is only allowed when prepa phase of event is over, wait for it to start',Color.red)
		end
		if global.special_games_variables["captain_mode"]["refereeName"] ~= playerOfCommand.name then
			return playerOfCommand.print("Only referee have licence to use that command",Color.red)
		end
		
		if global.special_games_variables["captain_mode"]["captainList"][1] == nil or global.special_games_variables["captain_mode"]["captainList"][2] == nil then
			return playerOfCommand.print("Something broke, no captain in the captain variable..",Color.red)
		end
		if cmd.parameter then 			 
			local victim = cpt_get_player(cmd.parameter)
			if victim and victim.valid then
					if not victim.connected then
						return playerOfCommand.print('You can only use this command on a connected player.',Color.red)
					end
					if isItForNorth then
						if victim.force.name ~= 'north' then
							return playerOfCommand.print("You cant elect a player as a captain if he is not in the team of the captain ! What are you even doing !",Color.red)
						end
						game.print(playerOfCommand.name .. " has decided that " .. victim.name .. " will be the new captain instead of " .. global.special_games_variables["captain_mode"]["captainList"][1],Color.cyan)
						local oldCaptain = cpt_get_player(global.special_games_variables["captain_mode"]["captainList"][1])
						if oldCaptain.gui.screen["captain_manager_gui"] then oldCaptain.gui.screen["captain_manager_gui"].destroy() end
						if oldCaptain.gui.top["captain_manager_toggle_button"] then oldCaptain.gui.top["captain_manager_toggle_button"].destroy() end
						global.special_games_variables["captain_mode"]["captainList"][1] = victim.name
						Public.draw_captain_manager_button(cpt_get_player(victim.name))
						generate_vs_text_rendering()
					else
						if victim.force.name ~= 'south' then
							return playerOfCommand.print("You cant elect a player as a captain if he is not in the team of the captain ! What are you even doing !",Color.red)
						end
						game.print(playerOfCommand.name .. " has decided that " .. victim.name .. " will be the new captain instead of " .. global.special_games_variables["captain_mode"]["captainList"][2],Color.cyan)
						local oldCaptain = cpt_get_player(global.special_games_variables["captain_mode"]["captainList"][2])
						if oldCaptain.gui.screen["captain_manager_gui"] then oldCaptain.gui.screen["captain_manager_gui"].destroy() end
						if oldCaptain.gui.top["captain_manager_toggle_button"] then oldCaptain.gui.top["captain_manager_toggle_button"].destroy() end
						global.special_games_variables["captain_mode"]["captainList"][2] = victim.name
						Public.draw_captain_manager_button(cpt_get_player(victim.name))
						generate_vs_text_rendering()
					end
			else 
				playerOfCommand.print("Invalid name", Color.warning)
			end
		else
			playerOfCommand.print("Usage: /replaceCaptainNorth <playerName>", Color.warning)
		end
end

commands.add_command('replaceCaptainNorth', 'Referee can decide to change the captain of north team',
                     function(cmd)	
	changeCaptain(cmd,true)
end)

commands.add_command('replaceCaptainSouth', 'Referee can decide to change the captain of south team',
                     function(cmd)	
	changeCaptain(cmd,false)
end)

commands.add_command('replaceReferee', 'Admin or referee can decide to change the referee',
                     function(cmd)	
	if not cmd.player_index then return end
		local playerOfCommand = cpt_get_player(cmd.player_index)
		if not playerOfCommand then return end
		if not global.active_special_games["captain_mode"] then
			return playerOfCommand.print('This command is only allowed in captain event, what are you doing ?!',Color.red)
		end
		if global.special_games_variables["captain_mode"]["prepaPhase"] then
			return playerOfCommand.print('This command is only allowed when prepa phase of event is over, wait for it to start',Color.red)
		end
		if global.special_games_variables["captain_mode"]["refereeName"] ~= playerOfCommand.name and not playerOfCommand.admin then
			return playerOfCommand.print("Only referee or admin have licence to use that command",Color.red)
		end

		if global.special_games_variables["captain_mode"]["refereeName"] == nil then
			return playerOfCommand.print("Something broke, no refereeName in the refereeName variable..",Color.red)
		end
		if cmd.parameter then	 
			local victim = cpt_get_player(cmd.parameter)
			if victim and victim.valid then
			if not victim.connected then
				return playerOfCommand.print('You can only use this command on a connected player.',Color.red)
			end

			local refPlayer = cpt_get_player(global.special_games_variables["captain_mode"]["refereeName"])
			if refPlayer.gui.top["captain_referee_toggle_button"] then refPlayer.gui.top["captain_referee_toggle_button"].destroy() end
			if refPlayer.gui.screen["captain_referee_gui"] then refPlayer.gui.screen["captain_referee_gui"].destroy() end
			Public.draw_captain_referee_button(victim)
			game.print(playerOfCommand.name .. " has decided that " .. victim.name .. " will be the new referee instead of " .. global.special_games_variables["captain_mode"]["refereeName"],Color.cyan)
			global.special_games_variables["captain_mode"]["refereeName"] = victim.name
			refPlayer = victim
			generate_vs_text_rendering()
			else
				playerOfCommand.print("Invalid name", Color.warning)
			end
		else
			playerOfCommand.print("Usage: /replaceReferee <playerName>", Color.warning)
		end
end)

commands.add_command('captainDisablePicking', 'Convert to a normal game, disable captain event and tournament mode',
                     function(cmd)
	if not cmd.player_index then return end
		local playerOfCommand = cpt_get_player(cmd.player_index)
		if not playerOfCommand then return end
		if not global.active_special_games["captain_mode"] then
			return playerOfCommand.print('This command is only allowed in captain event, what are you doing ?!',Color.red)
		end
		if global.special_games_variables["captain_mode"]["prepaPhase"] then
			return playerOfCommand.print('This command is only allowed when prepa phase of event is over, wait for it to start',Color.red)
		end
		if global.special_games_variables["captain_mode"]["refereeName"] ~= playerOfCommand.name and not playerOfCommand.admin then
			return playerOfCommand.print("Only referee or admin have licence to use that command",Color.red)
		end

		if global.special_games_variables["captain_mode"]["refereeName"] == nil then
			return playerOfCommand.print("Something broke, no refereeName in the refereeName variable..",Color.red)
		end
		playerOfCommand.print("You disabled tournament mode and captain event, now players can freely join",Color.red)

		global.active_special_games["captain_mode"] = false
		global.tournament_mode = false
		game.print("Players are now free to join whatever team they want (tournament mode disabled), choice made by " .. playerOfCommand.name,Color.green)
		clear_gui_captain_mode()
end)

local function on_player_changed_force(event)
    local player = game.get_player(event.player_index)
	if player.force.name == "spectator" then
		Public.captain_log_end_time_player(player)
	else
		captain_log_start_time_player(player)
	end
	Public.update_all_captain_player_guis()
end

local function on_player_left_game(event)
    local player = game.get_player(event.player_index)
	Public.captain_log_end_time_player(player)
	Public.update_all_captain_player_guis()
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
	if global.special_games_variables["captain_mode"] ~=nil and player.gui.center["bb_captain_countdown"] then player.gui.center["bb_captain_countdown"].destroy() end
	captain_log_start_time_player(player)
	if global.special_games_variables["captain_mode"] then
		Public.draw_captain_player_button(player)
		if not global.chosen_team[player.name] then
			Public.draw_captain_player_gui(player)
		end
	end
	Public.update_all_captain_player_guis()
end

local function every_5sec(event)
	if global.special_games_variables["captain_mode"] then
		Public.update_all_captain_player_guis()
		if Functions.get_ticks_since_game_start() >= global.special_games_variables["captain_mode"]["nextAutoPickTicks"] then
			if not global.special_games_variables["captain_mode"]["pickingPhase"] then
				start_picking_phase()
			end
		end
	end
end

Event.on_nth_tick(300, every_5sec)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
Event.add(defines.events.on_gui_text_changed, on_gui_text_changed)
Event.add(defines.events.on_gui_value_changed, on_gui_value_changed)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game,on_player_left_game)
Event.add(defines.events.on_player_changed_force,on_player_changed_force)
return Public
