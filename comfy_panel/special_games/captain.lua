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
local ComfyPanelGroup = require 'comfy_panel.group'
local math_random = math.random

local Public = {
    name = {type = "label", caption = "Captain event", tooltip = "Captain event"},
    config = {
			[1] = {name = "label4", type = "label", caption = "Referee"},
			[2] = {name = 'refereeName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140},
			[3] = {name = "autoTrust", type = "switch", switch_state = "right", allow_none_state = false, tooltip = "Trust all players automatically : Yes / No"},
			[4] = {name = "captainKickPower", type = "switch", switch_state = "left", allow_none_state = false, tooltip = "Captain can eject players from his team : Yes / No"},
			[5] = {name = "pickingMode", type = "switch", switch_state = "left", allow_none_state = false, tooltip = "Picking order at start of event : 1 1 1 1 1 1 1 / 1 2 1 1 1 1 1"},
			[6] = {name = "captainGroupAllowed", type = "switch", switch_state = "left", allow_none_state = false, tooltip = "Groups of players are allowed for picking phase : Yes / No"},
			[7] = {name = "groupLimit", type = "textfield", text = "0", numeric = true, width = 40, type = "textfield", text = "3", numeric = true, width = 40, tooltip = "Amount of players max in a group (0 for infinite)"},
			[8] = {name = "specialEnabled", type = "switch", switch_state = "right", allow_none_state = false, tooltip = "A special will be added to the event : Yes / No"}
    },
    button = {name = "apply", type = "button", caption = "Apply"},
}

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
	local special = global.special_games_variables["captain_mode"]
	Team_manager.switch_force(playerName, playerForceName)
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
			"captain_poll_chosen_choice_frame",
			"captain_poll_firstpicker_choice_frame",
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
			if playergui.center[gui] then playergui.center[gui].destroy() end
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
	clear_character_corpses()
end

local function createButton(frame,nameButton,captionButton, wordToPutInstead)
	local newNameButton = nameButton:gsub("Magical1@StringHere", wordToPutInstead)
	local newCaptionButton = captionButton:gsub("Magical1@StringHere", wordToPutInstead)
	local b = frame.add({type = "button", name = newNameButton, caption = newCaptionButton})
	b.style.font_color = Color.green
	b.style.font = "heading-2"
	b.style.minimal_width = 100
end

local function pollGenerator(player,isItTopFrame,tableBeingLooped,frameName,questionText,button1Text,button1Name,button2Text,button2Name,button3Text,button3Name)
	local frame = nil
	if isItTopFrame then
		if player.gui.top[frameName] then player.gui.top[frameName].destroy() return end
		frame = player.gui.top.add { type = "frame", caption = questionText, name = frameName, direction = "vertical" }
	else
		if player.gui.center[frameName] then player.gui.center[frameName].destroy() return end
		frame = player.gui.center.add { type = "frame", caption = questionText, name = frameName, direction = "vertical" }
	end
	if tableBeingLooped ~=nil then
		for _,pl in pairs(tableBeingLooped) do
			if button1Text ~= nil then
				createButton(frame,button1Name,button1Text,pl)
			end
			if button2Text ~= nil then
				createButton(frame,button2Name,button2Text,pl)
			end
			if button3Text ~= nil then
				createButton(frame,button3Name,button3Text,pl)
			end
		end
	else
		if button1Text ~= nil then
			createButton(frame,button1Name,button1Text,"")
		end
		if button2Text ~= nil then
			createButton(frame,button2Name,button2Text,"")
		end
		if button3Text ~= nil then
			createButton(frame,button3Name,button3Text,"")
		end
	end
end

local function get_bonus_picks_amount(captainName)
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		if captainName == global.special_games_variables["captain_mode"]["captainList"][1] then
			return global.special_games_variables["captain_mode"]["bonusPickCptOne"]
		else
			return global.special_games_variables["captain_mode"]["bonusPickCptTwo"]
		end
	else
		return 0
	end
end

local function poll_removing_captain(player)
	pollGenerator(player,false,global.special_games_variables["captain_mode"]["captainList"],
	"captain_poll_chosen_choice_frame","Who should be removed from captain list (popup until 2 captains remains)?",
	"The player Magical1@StringHere wont be a captain","removing_captain_in_list_Magical1@StringHere",nil,nil,nil,nil)
end

local function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function addGuiShowPlayerInfo(_finalParentGui,_button1Name,_button1Text,_pl,_groupName,_playtimePlayer)
	createButton(_finalParentGui,_button1Name,_button1Text,_pl)
	b = _finalParentGui.add({type = "label", caption = _groupName})
	b.style.font_color = Color.antique_white
	b.style.font = "heading-2"
	b.style.minimal_width = 100
	b = _finalParentGui.add({type = "label", caption = _playtimePlayer})
	b.style.font_color = Color.white
	b.style.font = "heading-2"
	b.style.minimal_width = 100
end

local function pickPlayerGenerator(player,tableBeingLooped,frameName,questionText,button1Text,button1Name)
	local frame = nil
	local finalParentGui = nil
	if player.gui.center[frameName] then player.gui.center[frameName].destroy() return end
	frame = player.gui.center.add { type = "frame", caption = questionText, name = frameName, direction = "vertical" }
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		finalParentGui = frame.add { type = "table", column_count = 3 }
	else
		finalParentGui = frame
	end
	if tableBeingLooped ~=nil then
		local b = finalParentGui.add({type = "label", caption = "playerName"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		b = finalParentGui.add({type = "label", caption = "GroupName"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		b = finalParentGui.add({type = "label", caption = "Total playtime"})
		b.style.font_color = Color.antique_white
		b.style.font = "heading-2"
		b.style.minimal_width = 100
		local listGroupAlreadyDone = {}
		for _,pl in pairs(tableBeingLooped) do
			if button1Text ~= nil then
				local groupCaptionText = ""
				local groupName = ""
				local playerIterated = game.get_player(pl)
				local playtimePlayer = "0 minutes"
				if global.total_time_online_players[playerIterated.name] then
					playtimePlayer = Player_list.get_formatted_playtime_from_ticks(global.total_time_online_players[playerIterated.name])
				end
				if startswith(playerIterated.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX) then
					if not listGroupAlreadyDone[playerIterated.tag] then
						groupName = playerIterated.tag
						listGroupAlreadyDone[playerIterated.tag] = true
						addGuiShowPlayerInfo(finalParentGui,button1Name,button1Text,pl,groupName,playtimePlayer)
						for _,plOfGroup in pairs(tableBeingLooped) do
							if plOfGroup ~= pl then
								local groupNameOtherPlayer = game.get_player(plOfGroup).tag
								if groupNameOtherPlayer ~= "" and groupName == groupNameOtherPlayer then
									playtimePlayer = "0 minutes"
									local nameOtherPlayer = game.get_player(plOfGroup).name
									if global.total_time_online_players[nameOtherPlayer] then
										playtimePlayer = Player_list.get_formatted_playtime_from_ticks(global.total_time_online_players[nameOtherPlayer])
									end
									addGuiShowPlayerInfo(finalParentGui,button1Name,button1Text,plOfGroup,groupName,playtimePlayer)
								end
							end
						end
					end
				else
					addGuiShowPlayerInfo(finalParentGui,button1Name,button1Text,pl,groupName,playtimePlayer)
				end
			end
		end
	end
end

local function poll_alternate_picking(player)
	pickPlayerGenerator(player,global.special_games_variables["captain_mode"]["listPlayers"],
	"captain_poll_alternate_pick_choice_frame","Who do you want to pick ? Bonus pick remaining : " .. get_bonus_picks_amount(player.name),
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
	renderText("captainLineSix","-Teams are locked, if you want to play, open 'Cpt Player' window and click the button",
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

local function update_bonus_picks_enemyCaptain(captainName,valueAdded)
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		if captainName == global.special_games_variables["captain_mode"]["captainList"][1] then
			global.special_games_variables["captain_mode"]["bonusPickCptTwo"] = global.special_games_variables["captain_mode"]["bonusPickCptTwo"] + valueAdded
		else
			global.special_games_variables["captain_mode"]["bonusPickCptOne"] = global.special_games_variables["captain_mode"]["bonusPickCptOne"] + valueAdded
		end
	end
end

local function update_bonus_picks(captainName,valueAdded)
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		if captainName == global.special_games_variables["captain_mode"]["captainList"][1] then
			global.special_games_variables["captain_mode"]["bonusPickCptOne"] = global.special_games_variables["captain_mode"]["bonusPickCptOne"] + valueAdded
			game.print('captain' .. captainName .. ' has now bonus picks : ' .. global.special_games_variables["captain_mode"]["bonusPickCptOne"])
		else
			global.special_games_variables["captain_mode"]["bonusPickCptTwo"] = global.special_games_variables["captain_mode"]["bonusPickCptTwo"] + valueAdded
			game.print('captain' .. captainName .. ' has now bonus picks : ' .. global.special_games_variables["captain_mode"]["bonusPickCptTwo"])
		end
	end
end

local function does_player_wanna_play(playerName)
	for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
	   if playerName == v then return true end
	end
	return false
end

local function auto_pick_all_of_group(cptPlayer,playerName)
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		local playerChecked = game.get_player(playerName)
		local amountPlayersSwitchedForGroup = 0
		for _, player in pairs(game.connected_players) do
			if global.chosen_team[player.name] == nil and player.tag == playerChecked.tag and player.force.name == "spectator" then -- only pick player without a team within the same group
				if does_player_wanna_play(player.name) then
					if amountPlayersSwitchedForGroup < global.special_games_variables["captain_mode"]["groupLimit"] - 1 then 
						game.print(player.name .. ' was automatically picked with group system', Color.cyan)
						switchTeamOfPlayer(player.name,playerChecked.force.name)
						game.get_player(player.name).print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
						local index={}
						for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
						   index[v]=k
						end
						local indexPlayer = index[player.name]
						table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
						update_bonus_picks_enemyCaptain(cptPlayer.name,1)
						amountPlayersSwitchedForGroup = amountPlayersSwitchedForGroup + 1
					else
						game.print(player.name .. ' was not picked automatically with group system, as the group limit was reached', Color.red)
					end
				end
			end
		end 
	end
end

---@param playerName string
---@return boolean
local function is_player_in_group_system(playerName)
	--function used to balance team when a team is picked
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		local playerChecked = game.get_player(playerName)
		if playerChecked and playerChecked.tag ~= "" and startswith(playerChecked.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX) then
			return true
		end
	end
	return false
end

local function generate_captain_mode(refereeName, autoTrust, captainKick, pickingMode, captainGroupAllowed, groupLimit, specialEnabled)
	if Functions.get_ticks_since_game_start() > 0 then
		game.print("Must start the captain event on a fresh map. Enable tournament_mode and do '/instant_map_reset current' to reset to current seed.", Color.red)
		return
	end
	captainKick = captainKick == "left"
	autoTrust = autoTrust == "left"
	pickingMode = pickingMode == "left"
	captainGroupAllowed = captainGroupAllowed == "left"

	local auto_pick_interval_ticks = 5*60*60 -- 5 minutes
	global.special_games_variables["captain_mode"] = {
		["captainList"] = {},
		["refereeName"] = refereeName,
		["listPlayers"] = {},
		["listTeamReadyToPlay"] = {},
		["prepaPhase"] = true,
		["countdown"] = 9,
		["pickingPhase"] = false,
		["initialPickingPhaseStarted"] = false,
		["nextAutoPicksFavor"] = {north = 0, south = 0},
		["autoPickIntervalTicks"] = auto_pick_interval_ticks,
		["nextAutoPickTicks"] = auto_pick_interval_ticks,
		["autoTrust"] = autoTrust,
		["captainKick"] = captainKick,
		["northEnabledScienceThrow"] = true,
		["northThrowPlayersListAllowed"] = {},
		["southEnabledScienceThrow"] = true,
		["southThrowPlayersListAllowed"] = {},
		["pickingModeAlternateBasic"] = pickingMode,
		["firstPick"] = true,
		["captainGroupAllowed"] = captainGroupAllowed,
		["groupLimit"] = tonumber(groupLimit),
		["bonusPickCptOne"] = 0,
		["bonusPickCptTwo"] = 0,
		["playerPickedAtTicks"] = {},
		["stats"] = {["northPicks"]={},["southPicks"]={},["tickGameStarting"]=0,["playerPlaytimes"]={},["playerSessionStartTimes"]={}}}
	global.active_special_games["captain_mode"] = true
	local referee = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
	if referee == nil then
		game.print("Event captain aborted, referee is not a player connected.. Referee name of player was : ".. global.special_games_variables["captain_mode"]["refereeName"])
		global.special_games_variables["captain_mode"] = nil
		global.active_special_games["captain_mode"] = false
		return
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
	if global.special_games_variables["captain_mode"]["autoTrust"] then
		game.print('Option was enabled : All players will be trusted once they join a team', Color.cyan)
	end
	if global.special_games_variables["captain_mode"]["captainKick"] then
		game.print('Option was enabled : Captains can eject players of their team', Color.cyan)
	end
	if global.special_games_variables["captain_mode"]["pickingModeAlternateBasic"] then 
		game.print('Picking system : 1-1-1-1-1-1-1...', Color.cyan)
	else
		game.print('Picking system : 1-2-1-1-1-1-1-1...', Color.cyan)
	end
	referee.print("Command only allowed for referee to change a captain : /replaceCaptainNorth <playerName> or /replaceCaptainSouth <playerName>", Color.cyan)
	for _, player in pairs(game.connected_players) do
		if player.admin then
			game.print("Command only allowed for referee or admins to change the current referee : /replaceReferee <playerName>", Color.cyan)
		end
	end

	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		game.print('Groups of players : ENABLED, group name must start by ' .. ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PREFIX, Color.cyan)
		local amountOfPlayers = "no limit"
		if global.special_games_variables["captain_mode"]["groupLimit"] == 0 then
			amountOfPlayers = "no limit"
			global.special_games_variables["captain_mode"]["groupLimit"] = 9999
		end
		if global.special_games_variables["captain_mode"]["groupLimit"] ~= 0 then amountOfPlayers = tostring(global.special_games_variables["captain_mode"]["groupLimit"]) end
		game.print('Amount of players max allowed in a group : ' .. amountOfPlayers, Color.cyan)
	else
		game.print('Groups of players : DISABLED', Color.cyan)
	end

	if specialEnabled == "left" then
		global.special_games_variables["captain_mode"]["stats"]["specialEnabled"] = 1
	else
		global.special_games_variables["captain_mode"]["stats"]["specialEnabled"] = 0
	end

	global.tournament_mode = true
	if global.freeze_players == false or global.freeze_players == nil then
		global.freeze_players = true
		Team_manager.freeze_players()
		game.print(">>> Players have been frozen!", {r = 111, g = 111, b = 255})
	end

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
	local tableChosen = global.special_games_variables["captain_mode"]["stats"]["southPicks"]
	if isNorthPlayerBoolean then
		tableChosen = global.special_games_variables["captain_mode"]["stats"]["northPicks"]
	end
	local index={}
	for k,v in pairs(tableChosen) do
		index[v]=k
	end
	local indexPlayer = index[playerName]
	table.remove(tableChosen,indexPlayer)
end

local function generate_vs_text_rendering()
	if global.active_special_games and global.special_games_variables["rendering"] and global.special_games_variables["rendering"]["captainLineVersus"] then
		rendering.destroy(global.special_games_variables["rendering"]["captainLineVersus"])
	end

	local cptMode = global.special_games_variables["captain_mode"]
	local text = string.format("Team %s (North) vs (South) Team %s. Referee: %s. Teams on Voice Chat",
		cptMode["captainList"][1],
		cptMode["captainList"][2],
		cptMode["refereeName"]
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
	renderText("captainLineEighteen","Want to play? Click 'Cpt Player' button at top of screen!", {0, -9}, {1,1,1,1}, 3, "heading-1")

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

local function allow_vote()
            local tick = game.ticks_played
            global.difficulty_votes_timeout = tick + 10800
            global.difficulty_player_votes = {}
			game.print('[font=default-large-bold]Difficulty voting is opened for 3 minutes![/font]', Color.cyan)
end

local function group_system_pick(player,playerPicked,captainChosen)
	if is_player_in_group_system(playerPicked) then
		auto_pick_all_of_group(player,playerPicked)
	end
	if get_bonus_picks_amount(player.name) > 0 then
		if get_bonus_picks_amount(player.name) > 0 then 
			player.print("You have " .. get_bonus_picks_amount(player.name) .. " bonus pick remaining")
		end
		update_bonus_picks(player.name,-1)
		poll_alternate_picking(player)
	else
		poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][captainChosen]))
	end
end

local function captain_log_start_time_player(player)
	if global.special_games_variables["captain_mode"] ~=nil and (player.force.name == "south" or player.force.name == "north") and not global.special_games_variables["captain_mode"]["prepaPhase"] then
		if not global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] then
			global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] = Functions.get_ticks_since_game_start()
		end
	end
end

function Public.generate(config, player)
	local refereeName = config["refereeName"].text
	local autoTrustSystem = config["autoTrust"].switch_state
	local captainCanKick = config["captainKickPower"].switch_state
	local pickingMode = config["pickingMode"].switch_state
	local captainGroupAllowed = config["captainGroupAllowed"].switch_state
	local groupLimit = config["groupLimit"].text
	local specialEnabled = config["specialEnabled"].switch_state
	generate_captain_mode(refereeName,autoTrustSystem,captainCanKick,pickingMode,captainGroupAllowed,groupLimit,specialEnabled)
end

local function add_close_button(frame)
	local flow = frame.add({type = "flow", direction = "horizontal"})
	flow.style.horizontal_align = "right"
	flow.style.horizontally_stretchable = true
	local button = flow.add({type = "sprite-button", name = "captain_gui_close", sprite = "utility/close_white", tooltip = "Close"})
	gui_style(button, {width = 38, height = 38, padding = -2})
end

function Public.draw_captain_manager_gui(player)
	if player.gui.center["captain_manager_gui"] then player.gui.center["captain_manager_gui"].destroy() end
	local frame = player.gui.center.add({type = "frame", name = "captain_manager_gui", caption = "Cpt Captain", direction = "vertical"})
	add_close_button(frame)
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
		caption = "Add someone to throw trustlist",
		tooltip = "Add someone to be able to throw science when captain disabled throwing science from his team"
	})
	t.add({name = 'captain_add_playerName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140})
	t.add({
		type = "button",
		name = "captain_remove_someone_to_throw_trustlist",
		caption = "Remove someone to throw trustlist",
		tooltip = "Remove someone to be able to throw science when captain disabled throwing science from his team"
	})
	t.add({name = 'captain_remove_playerName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140})

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
	t2.add({name = 'captain_eject_playerName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140})
	Public.update_captain_manager_gui(player)
end

function Public.update_captain_manager_gui(player)
	local frame = player.gui.center["captain_manager_gui"]
	if not frame then return end
	local special = global.special_games_variables["captain_mode"]
	local force_name = global.chosen_team[player.name]
	local button = nil
	frame.diff_vote_duration.visible = false
	frame.captain_is_ready.visible = false
	if special["prepaPhase"] and not isStringInTable(special["listTeamReadyToPlay"], force_name) then
		frame.captain_is_ready.visible = true
		frame.captain_is_ready.caption = "Team is Ready!"
		frame.captain_is_ready.style.font_color = Color.green
		if game.ticks_played < global.difficulty_votes_timeout then
			frame.diff_vote_duration.visible = true
			frame.diff_vote_duration.caption = string.format("difficulty vote ongoing for %ds longer. Consider waiting until it is over before marking yourself as ready.", (global.difficulty_votes_timeout - game.ticks_played) / 60)
			frame.captain_is_ready.caption = "Mark team as ready even though difficulty vote is ongoing!"
			frame.captain_is_ready.style.font_color = Color.red
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
	local t2 = frame.captain_manager_root_table_two
	local allow_kick = (not special["prepaPhase"] and special["captainKick"])
	t2.visible = allow_kick
end

function Public.draw_captain_manager_button(player)
	if player.gui.top["captain_manager_toggle_button"] then player.gui.top["captain_manager_toggle_button"].destroy() end
	local button = player.gui.top.add({type = "sprite-button", name = "captain_manager_toggle_button", caption = "Cpt Captain"})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 114, height = 38, padding = -2})
end

function Public.update_all_captain_player_guis()
	if not global.special_games_variables["captain_mode"] then return end
	for _, player in pairs(game.connected_players) do
		if player.gui.center["captain_player_gui"] then
			Public.update_captain_player_gui(player)
		end
		if player.gui.center["captain_manager_gui"] then
			Public.update_captain_manager_gui(player)
		end
	end
	local referee = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
	if referee.gui.center["captain_referee_gui"] then
		Public.draw_captain_referee_gui(referee)
	end
end

function Public.toggle_captain_player_gui(player)
	if player.gui.center["captain_player_gui"] then
		player.gui.center["captain_player_gui"].destroy()
	else
		Public.draw_captain_player_gui(player)
	end
end

function Public.toggle_captain_manager_gui(player)
	if player.gui.center["captain_manager_gui"] then
		player.gui.center["captain_manager_gui"].destroy()
	else
		Public.draw_captain_manager_gui(player)
	end
end

function Public.toggle_captain_referee_gui(player)
	if player.gui.center["captain_referee_gui"] then
		player.gui.center["captain_referee_gui"].destroy()
	else
		Public.draw_captain_referee_gui(player)
	end
end

-- Technically we could break this up into draw_ and update_ functions, and it would be more efficient,
-- and would move-around less for referees. But, it is annoying to do that rewrite, so I am just
-- leaving this as-is.
function Public.draw_captain_referee_gui(player)
	local special = global.special_games_variables["captain_mode"]
	if player.gui.center["captain_referee_gui"] then player.gui.center["captain_referee_gui"].destroy() end
	local frame = player.gui.center.add({type = "frame", name = "captain_referee_gui", caption = "Cpt Referee", direction = "vertical"})
	frame.style.maximal_width = 800
	add_close_button(frame)

	-- if game hasn't started, and at least one captain isn't ready, show a button to force both captains to be ready
	if special["prepaPhase"] and special["initialPickingPhaseStarted"] and not special["pickingPhase"] then
		if #special["listTeamReadyToPlay"] < 2 then
			frame.add({type = "label", caption = "Teams ready to play: " .. table.concat(special["listTeamReadyToPlay"], ", ")})
			local b = frame.add({type = "button", name = "captain_force_captains_ready", caption = "Force all captains to be ready"})
			b.style.font_color = Color.red
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
	local l = frame.add({type = "label", caption = caption .. ": " .. table.concat(special["listPlayers"], ", ")})
	l.style.single_line = false
	frame.add({type = "label", caption = string.format("Next auto picking phase in %ds", ticks_until_autopick / 60)})
	if #special["listPlayers"] > 0 and not special["pickingPhase"] and not special["prepaPhase"] and ticks_until_autopick > 0 then
		local button = frame.add({type = "button", name = "captain_start_join_poll", caption = "Start poll for players to join the game (instead of waiting)"})
		button.style.font_color = Color.red
	end

	if #special["listPlayers"] > 0 and special["pickingPhase"] then
		local button = frame.add({type = "button", name = "referee_force_picking_to_stop", caption = "Force the current round of picking to stop (only useful if changing captains)"})
		button.style.font_color = Color.red
	end

	if special["prepaPhase"] and not special["initialPickingPhaseStarted"] then
		frame.add({type = "label", caption = "Captain volunteers: " .. table.concat(special["captainList"], ", ")})
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
		frame.add({type = "label", caption = string.format("Everyone else: ", table.concat(spectators, " ,"))})
		local caption
		local color = Color.green
		if #special["captainList"] < 2 then
			caption = "Cancel captains event (not enough captains)"
			color = Color.red
		elseif #special["captainList"] == 2 then
			caption = "Confirm captions and start the picking phase"
		else
			caption = "Select captains and start the picking phase"
		end
		local b = frame.add({type = "button", name = "captain_end_captain_choice", caption = caption})
		b.style.font_color = color
		b.style.font = "heading-2"
		b.style.minimal_width = 540
	end

	if special["prepaPhase"] and not special["initialPickingPhaseStarted"] then
		frame.add({type = "label", caption = "The below logic is used for the initial picking phase!"})
		frame.add({type = "label", caption = "north will be the first (non-rejected) captain in the list of captain volunteers above."})
	end
	for _, force in pairs({"north", "south"}) do
		-- add horizontal flow
		local flow = frame.add({type = "flow", direction = "horizontal", name = force})
		local favor = special["nextAutoPicksFavor"][force]
		flow.add({type = "label", caption = string.format("Favor %s with next picking phase preference %d times. ", force, favor)})
		local button = flow.add({type = "button", name = "captain_favor_plus", caption = "+1"})
		gui_style(button, {width = 40, padding = -2})
		if favor > 0 then
			button = flow.add({type = "button", name = "captain_favor_minus", caption = "-1"})
			gui_style(button, {width = 40, padding = -2})
		end
	end
end

function Public.draw_captain_player_gui(player)
	if player.gui.center["captain_player_gui"] then player.gui.center["captain_player_gui"].destroy() end
	local frame = player.gui.center.add({type = "frame", name = "captain_player_gui", caption = "Cpt Player", direction = "vertical"})
	frame.style.maximal_width = 800
	add_close_button(frame)

	local prepa_flow = frame.add({type = "flow", name = "prepa_flow", direction = "vertical"})
	prepa_flow.add({type = "label", caption = "A captains game will start soon!"})
	local l = prepa_flow.add({type = "label", name = "want_to_play_players_list"})
	l.style.single_line = false
	prepa_flow.add({type = "label", name = "captain_volunteers_list"})
	l = prepa_flow.add({type = "label", name = "remaining_players_list"})
	l.style.single_line = false

	l = frame.add({type = "label", name = "status_label"})
	l.style.single_line = false
	frame.add({type = "button", name = "captain_player_want_to_play", caption = "I want to play"})
	frame.add({type = "button", name = "captain_player_want_to_be_captain", caption = "I am willing to be a captain"})

	frame.add({type = "line", name = "player_table_line"})
	local scroll = frame.add({type = "scroll-pane", name = "player_table_scroll", direction = "vertical"})
	scroll.style.maximal_height = 600
	Public.update_captain_player_gui(player)
end

function Public.update_captain_player_gui(player)
	local frame = player.gui.center.captain_player_gui
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
			want_to_play.caption = "Players: " .. table.concat(special["listPlayers"], ", ")
			cpt_volunteers.visible = true
			cpt_volunteers.caption = "Captain volunteers: " .. table.concat(special["captainList"], ", ")
			rem.visible = false
		else
			want_to_play.visible = false
			cpt_volunteers.visible = false
			rem.visible = true
			rem.caption = "Players remaining to be picked: " .. table.concat(special["listPlayers"], ", ")
		end
	end
	local want_to_play_visible = false
	local want_to_be_captain_visible = false
	local status_string = ""
	if global.chosen_team[player.name] then
		status_string = "On team " .. global.chosen_team[player.name] .. ": " .. Functions.team_name_with_color(global.chosen_team[player.name])
	elseif not isStringInTable(special["listPlayers"], player.name) then
		status_string = "Currently spectating the game"
		-- if not in picking phase, add a button to join the game
		if special["pickingPhase"] then
			status_string = status_string .. "\nA picking phase is currently active."
		else
			want_to_play_visible = true
		end
	else
		if special["pickingPhase"] then
			status_string = "Currently waiting to be picked by a captain."
		else
			status_string = "Currently waiting for the picking phase to start."
		end
		if special["prepaPhase"] and not special["initialPickingPhaseStarted"] then
			if isStringInTable(special["captainList"], player.name) then
				status_string = status_string .. "\nYou are willing to be a captain! Thank you!"
			else
				status_string = status_string .. "\nYou are not currently willing to be captain."
				want_to_be_captain_visible = true
			end
		end
	end
	if not special["prepaPhase"] then
		-- waiting for next picking phase (with time remaining)
		local ticks_until_autopick = special["nextAutoPickTicks"] - Functions.get_ticks_since_game_start()
		if ticks_until_autopick < 0 then ticks_until_autopick = 0 end
		status_string = status_string .. string.format("\nNext auto picking phase in %ds.", ticks_until_autopick / 60)
	end
	frame.status_label.caption = status_string
	if frame.captain_player_want_to_play.visible ~= want_to_play_visible then
		frame.captain_player_want_to_play.visible = want_to_play_visible
	end
	if frame.captain_player_want_to_be_captain.visible ~= want_to_be_captain_visible then
		frame.captain_player_want_to_be_captain.visible = want_to_be_captain_visible
	end

	local player_info = {}
	for player_name, force_name in pairs(global.chosen_team) do
		local info = {
			force = force_name,
			status = {},
			playtime = Public.get_total_playtime_of_player(player_name),
			picked_at = special["playerPickedAtTicks"][player_name]
		}
		player_info[player_name] = info
		local player = game.get_player(player_name)
		local status = {}
		if player_name == special["refereeName"] then
			table.insert(info.status, "Referee")
		end
		if isStringInTable(special["captainList"], player_name) then
			table.insert(info.status, "Captain")
		end
		if player and player.force.name == "spectator" then
			table.insert(info.status, "Spectating")
		end
		if player and not player.connected then
			table.insert(info.status, "Disconnected")
		end
	end
	if global.captains_add_silly_test_players_to_list then
		local forces = {"north", "south"}
		for i = 1, 10 do
			status = (i % 2 == 0) and {"Spectating"} or {}
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
		tab.add({type = "label", caption = "Player name"})
		tab.add({type = "label", caption = "Team"})
		tab.add({type = "label", caption = "PickedAt"})
		tab.add({type = "label", caption = "Playtime"})
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
	if player.gui.top["captain_player_toggle_button"] then player.gui.top["captain_player_toggle_button"].destroy() end
	local button = player.gui.top.add({type = "sprite-button", name = "captain_player_toggle_button", caption = "Cpt Player"})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 114, height = 38, padding = -2})
end

function Public.draw_captain_referee_button(player)
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
    local playtime = 0
	if global.total_time_online_players[playerName] then
		playtime = global.total_time_online_players[playerName]
	end
    local listPlayers = global.special_games_variables["captain_mode"]["listPlayers"]
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
end

local function end_of_picking_phase()
	local special = global.special_games_variables["captain_mode"]
	special["pickingPhase"] = false
	special["nextAutoPickTicks"] = Functions.get_ticks_since_game_start() + special["autoPickIntervalTicks"]
	if special["prepaPhase"] then
		allow_vote()
		game.print('[font=default-large-bold]All players were picked by captains, time to start preparation for each team ! Once your team is ready, captain, click on yes on top popup[/font]', Color.cyan)
		for _, captain_name in pairs(global.special_games_variables["captain_mode"]["captainList"]) do
			local captain = game.get_player(captain_name)
			captain.print("As a captain, you can handle your team by clicking on 'Cpt Captain' button top of screen",{r=1,g=1,b=0})
			Public.draw_captain_manager_button(captain)
			Public.draw_captain_manager_gui(captain)
			Team_manager.custom_team_name_gui(captain, captain.force.name)
		end
	end
	Public.update_all_captain_player_guis()
end

local function start_picking_phase()
	local special = global.special_games_variables["captain_mode"]
	special["pickingPhase"] = true
	if special["prepaPhase"] then
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
			local northThreshold = 0.5
			-- if listplayers has an odd number of players, then favor the captain with fewer players
			if #special["listPlayers"] % 2 == 1 then
				local counts = {north = 0, south = 0}
				for _, player in pairs(game.connected_players) do
					local force = player.force.name
					if force == "north" or force == "south" then  -- exclude "spectator"
						counts[force] = counts[force] + 1
					end
				end
				if counts.north == counts.south then
					northThreshold = 0.5
				else
					-- So, for instance, if north has 8 players and south has 10, then mismatch = 0.2,
					-- adjusted_mismatch =~ 0.32 / 2 = 0.16, so northThreshold = 0.5 + 0.16 = 0.66
					local mismatch = 1 - math.min(counts.north, counts.south) / math.max(counts.north, counts.south)
					local adjusted_mismatch = math.pow(mismatch, 0.7) / 2
					if counts.north < counts.south then
						northThreshold = 0.5 + adjusted_mismatch
					else
						northThreshold = 0.5 - adjusted_mismatch
					end
				end
			end

		 	captainChosen = math_random() < northThreshold and 1 or 2
			log("Captain chosen: " .. captainChosen)
		end
		poll_alternate_picking(game.get_player(special["captainList"][captainChosen]))
	end
	Public.update_all_captain_player_guis()
end

local function check_if_right_number_of_captains(firstRun, referee)
	if #global.special_games_variables["captain_mode"]["captainList"] < 2 then
		game.print('[font=default-large-bold]Not enough captains, event canceled..[/font]', Color.cyan)
		force_end_captain_event()
		return
	elseif #global.special_games_variables["captain_mode"]["captainList"] == 2 then
		for index, force_name in ipairs({"north", "south"}) do
			local captainName = global.special_games_variables["captain_mode"]["captainList"][index]
			switchTeamOfPlayer(captainName, force_name)
			add_to_trust(captainName)
			removeStringFromTable(global.special_games_variables["captain_mode"]["listPlayers"], captainName)
		end
		start_picking_phase()
	else
		if firstRun then
			game.print('As there are too many players wanting to be captain, referee will pick who will be the 2 captains', Color.cyan)
		end
		poll_removing_captain(referee)
	end
end

local function on_gui_click(event)
    local element = event.element
    if not element then return end
    if not element.valid then return end
	if not element.type == "button" then return end
	local player = game.get_player(event.player_index)
	if not player then return end
	local special = global.special_games_variables["captain_mode"]

	if element.name == "captain_gui_close" then
		element.parent.parent.destroy()
	elseif element.name == "captain_player_want_to_play" then
		insertPlayerByPlaytime(player.name)
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_player_want_to_be_captain" then
		table.insert(special["captainList"],player.name)
		Public.update_all_captain_player_guis()
	elseif element.name == "captain_end_captain_choice" then
		-- This marks the start of a picking phase, so players can no longer volunteer to become captain or play
		special["pickingPhase"] = true
		special["initialPickingPhaseStarted"] = true

		game.print('The referee ended the poll to get the list of captains and players playing', Color.cyan)

		check_if_right_number_of_captains(true, player)
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
	elseif string.find(element.name, "removing_captain_in_list_") then
		local playerPicked = element.name:gsub("^removing_captain_in_list_", "")
		removeStringFromTable(special["captainList"], playerPicked)
		player.gui.center["captain_poll_chosen_choice_frame"].destroy()
		game.print('[font=default-large-bold]' .. playerPicked .. ' was removed in the captains list[/font]', Color.cyan)
		check_if_right_number_of_captains(false, player)
	elseif element.name == "captain_pick_one_in_list_choice" or
			element.name == "captain_pick_second_in_list_choice" or
			element.name == "captain_pick_random_in_list_choice" then
		local captainChosen
		local chooser = "The referee"
		if element.name == "captain_pick_one_in_list_choice" then
			captainChosen = 1
		elseif element.name == "captain_pick_second_in_list_choice" then
			captainChosen = 2
		elseif element.name == "captain_pick_random_in_list_choice" then
			captainChosen = math_random(1, 2)
			chooser = "Fortune"
		end
		game.print(chooser .. " has chosen that " .. special["captainList"][captainChosen] .. " will pick first", Color.cyan)
		game.get_player(special["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
		if #special["listPlayers"] == 0 then
			end_of_picking_phase()
		else
			poll_alternate_picking(game.get_player(special["captainList"][captainChosen]))
		end
	elseif string.find(element.name, "captain_player_picked_") then
		local playerPicked = element.name:gsub("^captain_player_picked_", "")
		if player.gui.center["captain_poll_alternate_pick_choice_frame"] then player.gui.center["captain_poll_alternate_pick_choice_frame"].destroy() end
		game.print(playerPicked .. " was picked by Captain " .. player.name)
		local listPlayers = special["listPlayers"]
		local forceToGo = "north"
		if player.name == special["captainList"][2] then forceToGo = "south" end
		switchTeamOfPlayer(playerPicked, forceToGo)
		game.get_player(playerPicked).print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
		for index, name in pairs(listPlayers) do
			if name == playerPicked then
				table.remove(listPlayers,index)
				break
			end
		end

		if #global.special_games_variables["captain_mode"]["listPlayers"] == 0 then
			special["pickingPhase"] = false
			end_of_picking_phase()
		else
			if player.name == game.get_player(special["captainList"][1]).name then
				if not special["pickingModeAlternateBasic"] and special["firstPick"] then
					update_bonus_picks_enemyCaptain(player.name, 1)
					special["firstPick"] = false
				end
				group_system_pick(player, playerPicked, 2)
			else
				if not special["pickingModeAlternateBasic"] and special["firstPick"] then
					update_bonus_picks_enemyCaptain(player.name, 1)
					special["firstPick"] = false
				end
				group_system_pick(player, playerPicked, 1)
			end
		end
	elseif string.find(element.name, "captain_is_ready") then
		local refereeName = special["refereeName"]
		game.print('[font=default-large-bold]Team of captain ' .. player.name .. ' is ready ![/font]', Color.cyan)
		if not isStringInTable(special["listTeamReadyToPlay"], player.force.name) then
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
		end
		Public.update_all_captain_player_guis()
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
	elseif element.name == "captain_manager_toggle_button" then
		Public.toggle_captain_manager_gui(player)
	elseif element.name == "captain_player_toggle_button" then
		Public.toggle_captain_player_gui(player)
	elseif element.name == "captain_referee_toggle_button" then
		Public.toggle_captain_referee_gui(player)
	elseif element.name == "captain_add_someone_to_throw_trustlist" then
		local playerNameUpdateText = player.gui.center["captain_manager_gui"]["captain_manager_root_table"]["captain_add_playerName"].text
		if playerNameUpdateText and playerNameUpdateText ~= "" then
		
			local tableToUpdate = special["northThrowPlayersListAllowed"]
			local forceForPrint = "north"
			if player.name == special["captainList"][2] then
				tableToUpdate = special["southThrowPlayersListAllowed"]
				forceForPrint = "south"
			end
			
			local playerToadd = game.get_player(playerNameUpdateText) 
			if playerToadd ~= nil and playerToadd.valid then
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
		local playerNameUpdateText = player.gui.center["captain_manager_gui"]["captain_manager_root_table"]["captain_remove_playerName"].text
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
		local victim = game.get_player(player.gui.center["captain_manager_gui"]["captain_manager_root_table_two"]["captain_eject_playerName"].text)
		if victim and victim.valid then
				if victim.name == player.name then return player.print("You can't select yourself!", Color.red) end
				if victim.force.name == "spectator" then return player.print('You cant use this command on a spectator.', Color.red) end
				if victim.force.name ~=  player.force.name then return player.print('You cant use this command on a player of enemy team.', Color.red)	end
				if not victim.connected then return player.print('You can only use this command on a connected player.', Color.red)	end
				game.print("Captain ".. player.name .. " has decided that " .. victim.name .. " must not be in the team anymore.")
				delete_player_from_playersList(victim.name,victim.force.name)
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
		local playerOfCommand = game.get_player(cmd.player_index)
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
			local victim = game.get_player(cmd.parameter)
			if victim and victim.valid then
					if not victim.connected then
						return playerOfCommand.print('You can only use this command on a connected player.',Color.red)
					end
					if isItForNorth then
						if victim.force.name ~= 'north' then
							return playerOfCommand.print("You cant elect a player as a captain if he is not in the team of the captain ! What are you even doing !",Color.red)
						end
						game.print(playerOfCommand.name .. " has decided that " .. victim.name .. " will be the new captain instead of " .. global.special_games_variables["captain_mode"]["captainList"][1],Color.cyan)
						local oldCaptain = game.get_player(global.special_games_variables["captain_mode"]["captainList"][1])
						if oldCaptain.gui.center["captain_manager_gui"] then oldCaptain.gui.center["captain_manager_gui"].destroy() end
						if oldCaptain.gui.top["captain_manager_toggle_button"] then oldCaptain.gui.top["captain_manager_toggle_button"].destroy() end
						global.special_games_variables["captain_mode"]["captainList"][1] = victim.name
						Public.draw_captain_manager_button(game.get_player(victim.name))
						generate_vs_text_rendering()
					else
						if victim.force.name ~= 'south' then
							return playerOfCommand.print("You cant elect a player as a captain if he is not in the team of the captain ! What are you even doing !",Color.red)
						end
						game.print(playerOfCommand.name .. " has decided that " .. victim.name .. " will be the new captain instead of " .. global.special_games_variables["captain_mode"]["captainList"][2],Color.cyan)
						local oldCaptain = game.get_player(global.special_games_variables["captain_mode"]["captainList"][2])
						if oldCaptain.gui.center["captain_manager_gui"] then oldCaptain.gui.center["captain_manager_gui"].destroy() end
						if oldCaptain.gui.top["captain_manager_toggle_button"] then oldCaptain.gui.top["captain_manager_toggle_button"].destroy() end
						global.special_games_variables["captain_mode"]["captainList"][2] = victim.name
						Public.draw_captain_manager_button(game.get_player(victim.name))
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
		local playerOfCommand = game.get_player(cmd.player_index)
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
			local victim = game.get_player(cmd.parameter)
			if victim and victim.valid then
			if not victim.connected then
				return playerOfCommand.print('You can only use this command on a connected player.',Color.red)
			end

			local refPlayer = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
			if refPlayer.gui.top["captain_referee_toggle_button"] then refPlayer.gui.top["captain_referee_toggle_button"].destroy() end
			if refPlayer.gui.center["captain_referee_gui"] then refPlayer.gui.center["captain_referee_gui"].destroy() end
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
		local playerOfCommand = game.get_player(cmd.player_index)
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
    local player = game.players[event.player_index]
	if player.force.name == "spectator" then
		Public.captain_log_end_time_player(player)
	else
		captain_log_start_time_player(player)
	end
	Public.update_all_captain_player_guis()
end

local function on_player_left_game(event)
    local player = game.players[event.player_index]
	Public.captain_log_end_time_player(player)
	Public.update_all_captain_player_guis()
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
	if global.special_games_variables["captain_mode"] ~=nil and player.gui.center["bb_captain_countdown"] then player.gui.center["bb_captain_countdown"].destroy() end
	captain_log_start_time_player(player)
	if global.special_games_variables["captain_mode"] then
		Public.draw_captain_player_button(player)
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
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game,on_player_left_game)
Event.add(defines.events.on_player_changed_force,on_player_changed_force)
return Public
