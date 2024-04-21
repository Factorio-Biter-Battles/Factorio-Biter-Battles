local Color = require 'utils.color_presets'
local Event = require 'utils.event'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Team_manager = require "maps.biter_battles_v2.team_manager"
local session = require 'utils.datastore.session_data'
local Tables = require "maps.biter_battles_v2.tables"
local gui_style = require 'utils.utils'.gui_style
local ComfyPanelGroup = require 'comfy_panel.group'
local math_random = math.random

local function add_to_trust(playerName)
	if global.special_games_variables["captain_mode"]["autoTrust"] then
		local trusted = session.get_trusted_table()
		if not trusted[playerName] then
			trusted[playerName] = true
		end
	end
end

local function switchTeamOfPlayer(playerName,playerForceName)
	Team_manager.switch_force(playerName,playerForceName)
	local forcePickName = playerForceName .. "Picks"
	table.insert(global.special_games_variables["captain_mode"]["stats"][forcePickName],playerName)
	add_to_trust(playerName)
end

local function clear_gui_captain_mode()
	for _, player in pairs(game.players) do
		if player.gui.center["captain_poll_frame"] then player.gui.center["captain_poll_frame"].destroy() end
		if player.gui.center["captain_poll_end_frame"] then player.gui.center["captain_poll_end_frame"].destroy() end
		if player.gui.top["captain_poll_team_ready_frame"] then player.gui.top["captain_poll_team_ready_frame"].destroy() end
		if player.gui.center["captain_poll_chosen_choice_frame"] then player.gui.center["captain_poll_chosen_choice_frame"].destroy() end
		if player.gui.center["captain_poll_firstpicker_choice_frame"] then player.gui.center["captain_poll_firstpicker_choice_frame"].destroy() end
		if player.gui.center["captain_poll_alternate_pick_choice_frame"] then player.gui.center["captain_poll_alternate_pick_choice_frame"].destroy() end
		if player.gui.top["captain_referee_enable_picking_late_joiners"] then player.gui.top["captain_referee_enable_picking_late_joiners"].destroy() end
		if player.gui.center["captain_poll_latejoiner_question"] then player.gui.center["captain_poll_latejoiner_question"].destroy() end
		if player.gui.center["captain_poll_end_latejoiners_referee_frame"] then player.gui.center["captain_poll_end_latejoiners_referee_frame"].destroy() end
		if player.gui.top["captain_poll_new_joiner_to_current_match"] then player.gui.top["captain_poll_new_joiner_to_current_match"].destroy() end
		if player.gui.center["bb_captain_countdown"] then player.gui.center["bb_captain_countdown"].destroy() end
		if player.gui.center["captain_manager_gui"] then player.gui.center["captain_manager_gui"].destroy() end
		if player.gui.top["captain_manager_toggle_button"] then player.gui.top["captain_manager_toggle_button"].destroy() end
	end
end

local function poll_captain_player(player)
	if player.gui.center["captain_poll_frame"] then player.gui.center["captain_poll_frame"].destroy() return end
	local frame = player.gui.center.add { type = "frame", caption = "What do you want to do for the Captain event ?", name = "captain_poll_frame", direction = "vertical" }
		local b = frame.add({type = "button", name = "captain_yes_choice", caption = "I want to be captain and play"})
		b.style.font_color = Color.green
		b.style.font = "heading-2"
		b.style.minimal_width = 540
		local b = frame.add({type = "button", name = "captain_no_but_play", caption = "I don't want to be captain but I want to play"})
		b.style.font_color = Color.green
		b.style.font = "heading-2"
		b.style.minimal_width = 540
		local b = frame.add({type = "button", name = "captain_spectator_only", caption = "I don't want to play but only watch"})
		b.style.font_color = Color.red
		b.style.font = "heading-2"
		b.style.minimal_width = 540
end

local function get_list_of_table(tableName)
	return table.concat(global.special_games_variables["captain_mode"][tableName], " ,")	
end

local function get_player_list()
		return "List of players playing : " .. get_list_of_table("listPlayers")
end

local function get_cpt_list()
		return "List of captains : "  .. get_list_of_table("captainList")
end

local function get_spectator_list()
		return "List of spectators : " .. get_list_of_table("listSpectators")
end

local function get_list_players_who_didnt_vote_yet()
	return "List of players who didnt answer yet : " .. get_list_of_table("listOfPlayersWhoDidntVoteForRoleYet")
end

local function poll_captain_end_captain(player)
	if player.gui.center["captain_poll_end_frame"] then player.gui.center["captain_poll_end_frame"].destroy() return end
	local frame = player.gui.center.add { type = "frame", caption = "End poll for players to become captain (beware, need 2 at least to continue!!)", name = "captain_poll_end_frame", direction = "vertical" }
		local b = frame.add({type = "button", name = "captain_end_captain_choice", caption = "End the poll for players to become captain"})
		b.style.font_color = Color.green
		b.style.font = "heading-2"
		b.style.minimal_width = 540
		local l = frame.add({ type = "label", caption = "-----------------------------------------------------------------"})
		local l = frame.add({ type = "label", name="listCpt" , caption = get_cpt_list()})
		local l = frame.add({ type = "label", name="listPlayers" , caption = get_player_list()})
		local l = frame.add({ type = "label", name="listSpectators" , caption = get_spectator_list()})
		local l = frame.add({ type = "label", name="remainPlayersDidntVote" , caption = get_list_players_who_didnt_vote_yet()})		
end

local function poll_captain_end_late_joiners_referee(player)
	if player.gui.center["captain_poll_end_latejoiners_referee_frame"] then player.gui.center["captain_poll_end_latejoiners_referee_frame"].destroy() return end
	local frame = player.gui.center.add { type = "frame", caption = "End poll for players to join late", name = "captain_poll_end_latejoiners_referee_frame", direction = "vertical" }
		local b = frame.add({type = "button", name = "captain_end_joinlate_choice", caption = "End it"})
		b.style.font_color = Color.green
		b.style.font = "heading-2"
		b.style.minimal_width = 540
		local l = frame.add({ type = "label", caption = "-----------------------------------------------------------------"})
		local l = frame.add({ type = "label", name="listPlayers" , caption = get_player_list()})
		local l = frame.add({ type = "label", name="listSpectators" , caption = get_spectator_list()})
		local l = frame.add({ type = "label", name="remainPlayersDidntVote" , caption = get_list_players_who_didnt_vote_yet()})		
end

local function show_captain_question()
	for _, player in pairs(game.connected_players) do
		table.insert(global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"],player.name)
		table.insert(global.special_games_variables["captain_mode"]["listPlayersWhoAreNotNewToCurrentMatch"],player.name)
		global.special_games_variables["captain_mode"]["listPlayersWhoAreNotNewToCurrentMatch"][player.name] = true
		poll_captain_player(player)
	end
end

local function end_captain_question()
	for _, player in pairs(game.connected_players) do
		if player.gui.center["captain_poll_frame"] then player.gui.center["captain_poll_frame"].destroy() end
	end
end

local function end_captain_latejoiners_question()
	for _, player in pairs(game.connected_players) do
		if player.gui.center["captain_poll_latejoiner_question"] then player.gui.center["captain_poll_latejoiner_question"].destroy() end
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

local function poll_captain_team_ready(player, isRef)
	local textToShow = "Is your team ready ?"
	if isRef then textToShow = "Do you want to force start event without waiting from go from captain?" end
	pollGenerator(player,true,nil,
	"captain_poll_team_ready_frame",textToShow,"Yes","ready_captain_"..player.name,nil,nil,nil,nil)
end

local function poll_captain_picking_first(player)
	pollGenerator(player,false,nil,
	"captain_poll_firstpicker_choice_frame","Who should pick first ?",
	"The player " .. global.special_games_variables["captain_mode"]["captainList"][1] .. " will pick first", "captain_pick_one_in_list_choice",
	"The player " .. global.special_games_variables["captain_mode"]["captainList"][2] .. " will pick first", "captain_pick_second_in_list_choice",
	"The captain that will pick first will be chosen randomly","captain_pick_random_in_list_choice")
end

local function poll_removing_captain(player)
	pollGenerator(player,false,global.special_games_variables["captain_mode"]["captainList"],
	"captain_poll_chosen_choice_frame","Who should be removed from captain list (popup until 2 captains remains)?",
	"The player Magical1@StringHere wont be a captain","removing_captain_in_list_Magical1@StringHere",nil,nil,nil,nil)
end

local function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function pickPlayerGenerator(player,tableBeingLooped,frameName,questionText,button1Text,button1Name)
	local frame = nil
	local finalParentGui = nil
	if player.gui.center[frameName] then player.gui.center[frameName].destroy() return end
	frame = player.gui.center.add { type = "frame", caption = questionText, name = frameName, direction = "vertical" }
	if global.special_games_variables["captain_mode"]["captainGroupAllowed"] then
		finalParentGui = frame.add { type = "table", column_count = 2 }
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
		local listGroupAlreadyDone = {}
		for _,pl in pairs(tableBeingLooped) do
			if button1Text ~= nil then
				local groupCaptionText = ""
				local groupName = ""
				local playerIterated = game.get_player(pl)
				if startswith(playerIterated.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX) then
					if not listGroupAlreadyDone[playerIterated.tag] then
						groupName = playerIterated.tag
						listGroupAlreadyDone[playerIterated.tag] = true
						createButton(finalParentGui,button1Name,button1Text,pl)
						b = finalParentGui.add({type = "label", caption = groupName})
						b.style.font_color = Color.antique_white
						b.style.font = "heading-2"
						b.style.minimal_width = 100
						for _,plOfGroup in pairs(tableBeingLooped) do
							if plOfGroup ~= pl then
								local groupNameOtherPlayer = game.get_player(plOfGroup).tag
								if groupNameOtherPlayer ~= "" and groupName == groupNameOtherPlayer then
									createButton(finalParentGui,button1Name,button1Text,plOfGroup)
									b = finalParentGui.add({type = "label", caption = groupName})
									b.style.font_color = Color.antique_white
									b.style.font = "heading-2"
									b.style.minimal_width = 100
								end
							end
						end
					end
				else
					createButton(finalParentGui,button1Name,button1Text,pl)
					b = finalParentGui.add({type = "label", caption = groupName})
					b.style.font_color = Color.green
					b.style.font = "heading-2"
					b.style.minimal_width = 100
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

local function poll_captain_late_joiners(player)
	pollGenerator(player,false,nil,
	"captain_poll_latejoiner_question","Do you want to play?","Yes","captain_late_joiner_yes","No","captain_late_joiner_no","No and please dont ask me again for the event (you will be blacklisted from any other late joiners poll for the current captain match only)","captain_late_joiner_no_blacklist")
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
	renderText("captainLineFive","-For admins, as spectator, use ping to talk only to spectators",
		{-65,y}, {1,1,1,1}, 2.5, "heading-1")
	y = y + 2
	renderText("captainLineSix","-Teams are locked, if you want to play, ask to be moved to a team",
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

local function generate_captain_mode(refereeName,autoTrust,captainKick,pickingMode,captainGroupAllowed,groupLimit,specialEnabled)
	if captainKick == "left" then
		captainKick = true
	else
		captainKick = false
	end
	if autoTrust == "left" then
		autoTrust = true
	else
		autoTrust = false
	end
	if pickingMode == "left" then
		pickingMode = true
	else
		pickingMode = false
	end
	
	if captainGroupAllowed == "left" then
		captainGroupAllowed = true
	else
		captainGroupAllowed = false
	end
	
	global.special_games_variables["captain_mode"] = {["captainList"] = {}, ["refereeName"] = refereeName, ["listPlayers"] = {}, ["listSpectators"] = {}, ["listOfPlayersWhoDidntVoteForRoleYet"]={},["listTeamReadyToPlay"] = {}, ["lateJoiners"] = false, ["prepaPhase"] = true, ["countdown"] = 9, ["pickingPhase"] = false, ["autoTrust"] = autoTrust,["captainKick"] = captainKick,["northEnabledScienceThrow"] = true,["northThrowPlayersListAllowed"] = {},["southEnabledScienceThrow"] = true,["southThrowPlayersListAllowed"] = {},["pickingModeAlternateBasic"] = pickingMode,["firstPick"] = true, ["blacklistLateJoin"]={}, ["listPlayersWhoAreNotNewToCurrentMatch"]={},["captainGroupAllowed"]=captainGroupAllowed,["groupLimit"]=tonumber(groupLimit),["bonusPickCptOne"]=0,["bonusPickCptTwo"]=0,["stats"]={["northPicks"]={},["southPicks"]={},["tickGameStarting"]=0,["playerPlaytimes"]={},["playerSessionStartTimes"]={}}}
	global.active_special_games["captain_mode"] = true
	if game.get_player(global.special_games_variables["captain_mode"]["refereeName"]) == nil then
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
	end
	global.chosen_team = {}
	clear_character_corpses()
	game.print('Captain mode started !! Have fun ! Referee will be '.. global.special_games_variables["captain_mode"]["refereeName"])
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
	game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).print("Command only allowed for referee to change a captain : /replaceCaptainNorth <playerName> or /replaceCaptainSouth <playerName>", Color.cyan)
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
		if global.special_games_variables["captain_mode"]["groupLimit"] ~= 0 then amountOfPlayers = global.special_games_variables["captain_mode"]["groupLimit"] end
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
	show_captain_question()
		
	local y = 0
	if global.special_games_variables["rendering"] == nil then global.special_games_variables["rendering"] = {} end
	rendering.clear()
	renderText("captainLineTen","Special Captain's tournament mode enabled", {0,-16}, {1,0,0,1}, 5, "heading-1")
	renderText("captainLineEleven","team xx vs team yy. Referee: " .. refereeName .. ". Teams on VC", {0,10}, Color.captain_versus_float, 1.5,"heading-1")
	generateGenericRenderingCaptain()
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {-9, -2}, to = {-9,3}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {0, 9}, to = {0,4}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {0, -4}, to = {0,-9}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {-9, 0}, to = {-4,0}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {4, 0}, to = {9,0}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_circle{surface = game.surfaces[global.bb_surface_name], target = {0, 0}, radius = 4, filled= false,draw_on_ground = true, color = {r = 1}, width = 3} 

	renderText("captainLineTwelve","Speedrunners", {6,-5}, {1,1,1,1}, 2, "heading-1")
	renderText("captainLineThirteen","BB veteran players", {-6, -5}, {1,1,1,1}, 2, "heading-1")
	renderText("captainLineFourteen","New players", {6,5}, {1,1,1,1}, 2, "heading-1")
	renderText("captainLineFifteen","Not veteran but not new players", {-8,5}, {1,1,1,1}, 2, "heading-1")
	renderText("captainLineSixteen","Spectators", {-12,-1}, {1,1,1,1}, 2, "heading-1")

	for i=-9,-16,-1 do
		for k=2,-2,-1 do
			game.surfaces[global.bb_surface_name].set_tiles({{name = "green-refined-concrete", position = {x=i,y=k}}}, true)
		end
	end 
end

local function are_all_players_picked()
	if #global.special_games_variables["captain_mode"]["listPlayers"] > 1 then return false end
	return true
end

local function updateEndPollReferee()
	game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"]["listCpt"].caption = get_cpt_list()
	game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"]["listPlayers"].caption = get_player_list()
	game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"]["listSpectators"].caption = get_spectator_list()
	game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"]["remainPlayersDidntVote"].caption = get_list_players_who_didnt_vote_yet()
end

local function updatePollLateJoinReferee()
	if game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_latejoiners_referee_frame"] then
		game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_latejoiners_referee_frame"]["listPlayers"].caption = get_player_list()
		game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_latejoiners_referee_frame"]["listSpectators"].caption = get_spectator_list()
		game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_latejoiners_referee_frame"]["remainPlayersDidntVote"].caption = get_list_players_who_didnt_vote_yet()
	end
end

local function delete_player_from_novote_list(playerName)
		local index={}
		for k,v in pairs(global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"]) do
		   index[v]=k
		end
		local indexPlayer = index[playerName]
		table.remove(global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"],indexPlayer)
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

local function isRefereeACaptain()
	if global.special_games_variables["captain_mode"]["captainList"][1] == global.special_games_variables["captain_mode"]["refereeName"] or global.special_games_variables["captain_mode"]["captainList"][2] == global.special_games_variables["captain_mode"]["refereeName"] then
		return true
	else
		return false
	end
end

local function poll_pickLateJoiners(player)
	pollGenerator(player,true,nil,
	"captain_referee_enable_picking_late_joiners","Enable picking phase for late joiners ?","Yes","captain_enabled_late_picking_by_ref"..player.name,nil,nil,nil,nil)
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
	
	local playerToClear = game.get_player(global.special_games_variables["captain_mode"]["captainList"][1])
	if playerToClear.gui.top["captain_poll_team_ready_frame"] then playerToClear.gui.top["captain_poll_team_ready_frame"].destroy() end
	playerToClear = game.get_player(global.special_games_variables["captain_mode"]["captainList"][2])
	if playerToClear.gui.top["captain_poll_team_ready_frame"] then playerToClear.gui.top["captain_poll_team_ready_frame"].destroy() end
	playerToClear = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
	if playerToClear.gui.top["captain_poll_team_ready_frame"] then playerToClear.gui.top["captain_poll_team_ready_frame"].destroy() end
	local y = 0
	rendering.clear()
	renderText("captainLineSeventeen","Special Captain's tournament mode enabled", {0, -16}, {1,0,0,1}, 5, "heading-1")
	generate_vs_text_rendering()
	generateGenericRenderingCaptain()
	renderText("captainLineEighteen","Want to play? Ask to join a team!", {0, -9}, {1,1,1,1}, 3, "heading-1")
	
	for _, player in pairs(game.connected_players) do
		if player.force.name == "north" or player.force.name == "south" then
			global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] = game.ticks_played;
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
			global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] = game.ticks_played
		end
	end
end

local function is_captain(playerName)
	if global.special_games_variables["captain_mode"]["captainList"][1] == playerName or global.special_games_variables["captain_mode"]["captainList"][2] == playerName then
		return true
	else
		return false
	end
end

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
    generate = function (config, player)
		local refereeName = config["refereeName"].text
		local autoTrustSystem = config["autoTrust"].switch_state
		local captainCanKick = config["captainKickPower"].switch_state
		local pickingMode = config["pickingMode"].switch_state
		local captainGroupAllowed = config["captainGroupAllowed"].switch_state
		local groupLimit = config["groupLimit"].text
		local specialEnabled = config["specialEnabled"].switch_state
		generate_captain_mode(refereeName,autoTrustSystem,captainCanKick,pickingMode,captainGroupAllowed,groupLimit,specialEnabled)
    end,
}

function Public.draw_captain_manager_gui(player)
	if player.gui.center["captain_manager_gui"] then player.gui.center["captain_manager_gui"].destroy() return end
	local frame = player.gui.center.add({type = "frame", name = "captain_manager_gui", caption = "Manage your team", direction = "vertical"})
	frame.add({type = "label", caption = "[font=heading-1][color=purple]Management for science throwing[/color][/font]"})
	local button = nil
	local throwScienceSetting = global.special_games_variables["captain_mode"]["northEnabledScienceThrow"]
	if global.special_games_variables["captain_mode"]["captainList"][2] == player.name then
		throwScienceSetting = global.special_games_variables["captain_mode"]["southEnabledScienceThrow"]
	end
	if (throwScienceSetting) then
		button = frame.add({
			type = "button",
			name = "captain_toggle_throw_science",
			caption = "Click to disable throwing science for the team",
			tooltip = "Click to disable throwing science for the team."
		})
	else
		button = frame.add({
			type = "button",
			name = "captain_toggle_throw_science",
			caption = "Click to enable throwing science for the team",
			tooltip = "Click to enable throwing science for the team, BEWARE that it can be bypassed with the throw trustlist."
		})
	end
	local t = frame.add({type = "table", name = "captain_manager_root_table", column_count = 2})
	button = t.add({
		type = "button",
		name = "captain_add_someone_to_throw_trustlist",
		caption = "Add someone to throw trustlist",
		tooltip = "Add someone to be able to throw science when captain disabled throwing science from his team"
	})
	local textField = t.add({name = 'captain_add_playerName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140})
	button = t.add({
		type = "button",
		name = "captain_remove_someone_to_throw_trustlist",
		caption = "Remove someone to throw trustlist",
		tooltip = "Remove someone to be able to throw science when captain disabled throwing science from his team"
	})
	textField = t.add({name = 'captain_remove_playerName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140})
	
	if throwScienceSetting then
		frame.add({type = "label", caption = "Can anyone throw science ? : " .. "[color=green]YES[/color]"})
	else
		frame.add({type = "label", caption = "Can anyone throw science ? : " .. "[color=red]NO[/color]"})
	end
	
	local tablePlayerListThrowAllowed = global.special_games_variables["captain_mode"]["northThrowPlayersListAllowed"]
	if player.name == global.special_games_variables["captain_mode"]["captainList"][2] then
		tablePlayerListThrowAllowed = global.special_games_variables["captain_mode"]["southThrowPlayersListAllowed"]
	end
	frame.add({type = "label", caption = "List of players trusted to throw : " .. table.concat(tablePlayerListThrowAllowed, ' | ')})
	frame.add({type = "label", caption = ""})
	frame.add({type = "label", caption = "[font=heading-1][color=purple]Management for your players[/color][/font]"})
	local t2 = frame.add({type = "table", name = "captain_manager_root_table_two", column_count = 3})
	
	if not global.special_games_variables["captain_mode"]["prepaPhase"] and global.special_games_variables["captain_mode"]["captainKick"] then
		button = t2.add({
			type = "button",
			name = "captain_eject_player",
			caption = "Eject a player of your team",
			tooltip = "If you don't want someone to be in your team anymore, use this button (used for griefers, players not listening and so on..)"
		})
		textField = t2.add({name = 'captain_eject_playerName', type = "textfield", text = "ReplaceMe", numeric = false, width = 140})
	end
end
	
function Public.draw_captain_manager_button(player)
	if player.gui.top["captain_manager_toggle_button"] then player.gui.top["captain_manager_toggle_button"].destroy() end	
	local button = player.gui.top.add({type = "sprite-button", name = "captain_manager_toggle_button", caption = "Captain Manager", tooltip = tooltip})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 114, height = 38, padding = -2})
end

local function playerNameInTable(tableName, playerName)
    for _, name in ipairs(tableName) do
        if name == playerName then
            return true
        end
    end
    return false
end

local function removePlayerNameFromTable(playerTable, playerName)
    for i, name in ipairs(playerTable) do
        if name == playerName then
            table.remove(playerTable, i)
            break  -- Stop the loop once the name is found and removed
        end
    end
end

function Public.reset_special_games()
	if global.active_special_games["captain_mode"] then
		global.tournament_mode = false
	end
end

function Public.captain_log_end_time_player(player)
	if global.special_games_variables["captain_mode"] ~=nil and not global.special_games_variables["captain_mode"]["prepaPhase"] then
		if global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] then
			local sessionTime = game.ticks_played - global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name]
			if global.special_games_variables["captain_mode"]["stats"]["playerPlaytimes"][player.name] then
				global.special_games_variables["captain_mode"]["stats"]["playerPlaytimes"][player.name] = global.special_games_variables["captain_mode"]["stats"]["playerPlaytimes"][player.name] + sessionTime
			else
				global.special_games_variables["captain_mode"]["stats"]["playerPlaytimes"][player.name] = sessionTime
			end
			global.special_games_variables["captain_mode"]["stats"]["playerSessionStartTimes"][player.name] = nil
		end
	end
end

function Public.clear_gui_special()
	clear_gui_captain_mode()
end

local function on_gui_click(event)
    local element = event.element
    if not element then return end
    if not element.valid then return end
	local player = game.get_player(event.player_index)	
	if not element.type == "button" then return end
	
	if element.name == "captain_yes_choice" then
		table.insert(global.special_games_variables["captain_mode"]["captainList"],player.name)
		delete_player_from_novote_list(player.name)
		if player.gui.center["captain_poll_frame"] ~= nil then player.gui.center["captain_poll_frame"].destroy() end
		game.print(player.name .. ' wants to become a captain ! ')
		local listCaptains = table.concat(global.special_games_variables["captain_mode"]["captainList"], " ,")	
		
		game.print('[font=default-large-bold]List of volunteers to become a captain/team picker (total : ' .. #global.special_games_variables["captain_mode"]["captainList"] .. ') : ' .. listCaptains .. '[/font]', Color.cyan)
		if player.name == global.special_games_variables["captain_mode"]["refereeName"] then
			poll_captain_end_captain(player)
		elseif game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"] ~=nil then
			updateEndPollReferee()
		end
	elseif element.name == "captain_no_but_play" then
		game.print(player.name .. ' wants to play but not as a captain')
		table.insert(global.special_games_variables["captain_mode"]["listPlayers"],player.name)
		delete_player_from_novote_list(player.name)
		if player.gui.center["captain_poll_frame"] ~= nil then player.gui.center["captain_poll_frame"].destroy() end
		if player.name == global.special_games_variables["captain_mode"]["refereeName"] then
			poll_captain_end_captain(player)
		elseif game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"] ~=nil then
			updateEndPollReferee()
		end
	elseif element.name == "captain_spectator_only" then
		table.insert(global.special_games_variables["captain_mode"]["listSpectators"],player.name)
		delete_player_from_novote_list(player.name)
		if player.gui.center["captain_poll_frame"] ~= nil then player.gui.center["captain_poll_frame"].destroy() end
		if player.name == global.special_games_variables["captain_mode"]["refereeName"] then
			poll_captain_end_captain(player)
		elseif game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_frame"] ~=nil then
			updateEndPollReferee()
		end
	elseif element.name == "captain_end_captain_choice" then
		game.print('The referee ended the poll to get the list of captains and players playing', Color.cyan)
		end_captain_question()
		
		for _,pl in pairs(global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"]) do
			delete_player_from_novote_list(pl)
			table.insert(global.special_games_variables["captain_mode"]["listSpectators"],player.name)
			game.print(pl .. ' didnt pick a role on time, moved to spectator group')
		end
		
		if player.gui.center["captain_poll_end_frame"] ~= nil then player.gui.center["captain_poll_end_frame"].destroy() end
		if #global.special_games_variables["captain_mode"]["captainList"] < 2 then
			game.print('[font=default-large-bold]Not enough captains, event canceled..[/font]', Color.cyan)
			force_end_captain_event()
			return
		elseif #global.special_games_variables["captain_mode"]["captainList"] == 2 then
			game.print('[font=default-large-bold]Switching to picking phase for captains ![/font]', Color.cyan)
			Team_manager.switch_force(global.special_games_variables["captain_mode"]["captainList"][1],"north")
			add_to_trust(global.special_games_variables["captain_mode"]["captainList"][1])
			Team_manager.switch_force(global.special_games_variables["captain_mode"]["captainList"][2],"south")
			add_to_trust(global.special_games_variables["captain_mode"]["captainList"][2])
			poll_captain_picking_first(player)
		else
			game.print('As there are too many players wanting to be captain, referee will pick who will be the 2 captains', Color.cyan)
			poll_removing_captain(player)
		end
	elseif string.find(element.name, "removing_captain_in_list_") then
		local playerPicked = element.name:gsub("^removing_captain_in_list_", "")
		local index={}
		for k,v in pairs(global.special_games_variables["captain_mode"]["captainList"]) do
		   index[v]=k
		end
		local indexPlayer = index[playerPicked]
		table.remove(global.special_games_variables["captain_mode"]["captainList"],indexPlayer)
		table.insert(global.special_games_variables["captain_mode"]["listPlayers"],playerPicked)
		player.gui.center["captain_poll_chosen_choice_frame"].destroy()
			game.print('[font=default-large-bold]' .. playerPicked .. ' was removed in the captains list[/font]', Color.cyan)
		
		if #global.special_games_variables["captain_mode"]["captainList"] > 2 then
			poll_removing_captain(player)
		elseif #global.special_games_variables["captain_mode"]["captainList"] == 2 then
			game.print('[font=default-large-bold]Only 2 volunteers for captain, no vote needed to elect 2 captains, switching to picking phase ![/font]', Color.cyan)
			Team_manager.switch_force(global.special_games_variables["captain_mode"]["captainList"][1],"north")
			add_to_trust(global.special_games_variables["captain_mode"]["captainList"][1])
			Team_manager.switch_force(global.special_games_variables["captain_mode"]["captainList"][2],"south")
			add_to_trust(global.special_games_variables["captain_mode"]["captainList"][2])
			poll_captain_picking_first(player)
		else
			game.print('[font=default-large-bold]Not enough captains case, event canceled..This case should never happen though, report it to bug[/font]', Color.cyan)
			force_end_captain_event()
		end
	elseif element.name == "captain_pick_one_in_list_choice" then
		if #global.special_games_variables["captain_mode"]["listPlayers"] == 0 and global.special_games_variables["captain_mode"]["lateJoiners"] == false then
			game.print('[font=default-large-bold]No one wanna play as a player, aborting event..[/font]', Color.cyan)
			force_end_captain_event()
			player.gui.center["captain_poll_firstpicker_choice_frame"].destroy()
		else
			game.print("The referee chose that " .. global.special_games_variables["captain_mode"]["captainList"][1] .. " will pick first", Color.cyan)
			global.special_games_variables["captain_mode"]["pickingPhase"] = true
			game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
			
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 and global.special_games_variables["captain_mode"]["lateJoiners"] == true then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local captainForceName = "north"
				game.print(lastPlayerToSend.name .. " was automatically picked")
				switchTeamOfPlayer(lastPlayerToSend.name,captainForceName)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
				global.special_games_variables["captain_mode"]["pickingPhase"] = false
			else
				poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][1]))
			end
		end
	elseif element.name == "captain_pick_second_in_list_choice" then
		if #global.special_games_variables["captain_mode"]["listPlayers"] == 0 and global.special_games_variables["captain_mode"]["lateJoiners"] == false then
			game.print('[font=default-large-bold]No one wanna play as a player, aborting event..[/font]', Color.cyan)
			force_end_captain_event()
			player.gui.center["captain_poll_firstpicker_choice_frame"].destroy()
		else
			game.print("The referee chose that " .. global.special_games_variables["captain_mode"]["captainList"][2] .. " will pick first", Color.cyan)
			global.special_games_variables["captain_mode"]["pickingPhase"] = true
			game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 and global.special_games_variables["captain_mode"]["lateJoiners"] == true then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local captainForceName = "south"
				game.print(lastPlayerToSend.name .. " was automatically picked")
				switchTeamOfPlayer(lastPlayerToSend.name,captainForceName)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
				global.special_games_variables["captain_mode"]["pickingPhase"] = false
			else
				poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][2]))
			end
		end
	elseif element.name == "captain_pick_random_in_list_choice" then
		if #global.special_games_variables["captain_mode"]["listPlayers"] == 0 and global.special_games_variables["captain_mode"]["lateJoiners"] == false then
			game.print('[font=default-large-bold]No one wanna play as a player, aborting event..[/font]', Color.cyan)
			force_end_captain_event()
			player.gui.center["captain_poll_firstpicker_choice_frame"].destroy()
		else
			local captainChosen = math_random(1,2)
			game.print("Fortune has chosen that " .. global.special_games_variables["captain_mode"]["captainList"][captainChosen] .. " will pick first", Color.cyan)
			global.special_games_variables["captain_mode"]["pickingPhase"] = true
			game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 and global.special_games_variables["captain_mode"]["lateJoiners"] == true then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local captainForceName = "north"
				if captainChosen == 2 then captainForceName = "south" end
				game.print(lastPlayerToSend.name .. " was automatically picked")
				switchTeamOfPlayer(lastPlayerToSend.name,captainForceName)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
				global.special_games_variables["captain_mode"]["pickingPhase"] = false
			else
				poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][captainChosen]))
			end
		end
	elseif string.find(element.name, "captain_player_picked_") then
		local playerPicked = element.name:gsub("^captain_player_picked_", "")
		if player.gui.center["captain_poll_alternate_pick_choice_frame"] then player.gui.center["captain_poll_alternate_pick_choice_frame"].destroy() end
		game.print(playerPicked .. " was picked by Captain " .. player.name)
		local forceToGo = "north"
		if player.name == global.special_games_variables["captain_mode"]["captainList"][2] then forceToGo = "south" end
		switchTeamOfPlayer(playerPicked,forceToGo)
		game.get_player(playerPicked).print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
		local index={}
		for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
		   index[v]=k
		end
		local indexPlayer = index[playerPicked]
		table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
		
		if are_all_players_picked() then
			global.special_games_variables["captain_mode"]["pickingPhase"] = false
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local oppositeForce = "north"
				local realForceNameOfCaptain = "north"
				if player.name == global.special_games_variables["captain_mode"]["captainList"][2] then realForceNameOfCaptain = "south" end
				if get_bonus_picks_amount(player.name) > 0 then
					oppositeForce = realForceNameOfCaptain
				else
					if realForceNameOfCaptain == "north" then
							oppositeForce = "south"
					end
				end
				game.print(lastPlayerToSend.name .. " was automatically picked")
				switchTeamOfPlayer(lastPlayerToSend.name,oppositeForce)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
			end
			if not global.special_games_variables["captain_mode"]["lateJoiners"] then
				allow_vote()
				game.print('[font=default-large-bold]All players were picked by captains, time to start preparation for each team ! Once your team is ready, captain, click on yes on top popup[/font]', Color.cyan)
				local captainOne = game.get_player(global.special_games_variables["captain_mode"]["captainList"][1])
				local captainTwo = game.get_player(global.special_games_variables["captain_mode"]["captainList"][2])
				poll_captain_team_ready(captainOne,false)
				poll_captain_team_ready(captainTwo,false)
				captainTwo.print("As a captain, you can handle your team by clicking on 'Manage your team' button top of screen",{r=1,g=1,b=0})
				Public.draw_captain_manager_button(captainOne)
				Public.draw_captain_manager_button(captainTwo)
				Public.draw_captain_manager_gui(captainOne)
				Public.draw_captain_manager_gui(captainTwo)
				Team_manager.custom_team_name_gui(captainOne, captainOne.force.name)
				Team_manager.custom_team_name_gui(captainTwo, captainTwo.force.name)
				local refPlayer = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
				if not isRefereeACaptain() then
					poll_captain_team_ready(refPlayer,true)
				end
				global.special_games_variables["captain_mode"]["lateJoiners"] = true
				poll_pickLateJoiners(refPlayer)
			else
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
				global.special_games_variables["captain_mode"]["pickingPhase"] = false
			end
		else
			if player.name == game.get_player(global.special_games_variables["captain_mode"]["captainList"][1]).name then
				if not global.special_games_variables["captain_mode"]["pickingModeAlternateBasic"] and global.special_games_variables["captain_mode"]["firstPick"] then
					update_bonus_picks_enemyCaptain(player.name,1)
					global.special_games_variables["captain_mode"]["firstPick"] = false
				end
				group_system_pick(player,playerPicked,2)
			else
				if not global.special_games_variables["captain_mode"]["pickingModeAlternateBasic"] and global.special_games_variables["captain_mode"]["firstPick"] then
					update_bonus_picks_enemyCaptain(player.name,1)
					global.special_games_variables["captain_mode"]["firstPick"] = false
				end
				group_system_pick(player,playerPicked,1)
			end
		end
	elseif string.find(element.name, "ready_captain_") then
		if game.ticks_played < global.difficulty_votes_timeout then 
			player.print('[font=default-large-bold]Wait for end of difficulty vote poll before telling your team is ready (meanwhile, your team should strategize!)[/font]', Color.red)
			return
		end
	
		if player.gui.top["captain_poll_team_ready_frame"] then player.gui.top["captain_poll_team_ready_frame"].destroy() end
		local refereeName = global.special_games_variables["captain_mode"]["refereeName"]
		if player.name == refereeName and not isRefereeACaptain() then
			game.print('[font=default-large-bold]Referee ' .. refereeName .. ' force started the game ![/font]', Color.cyan)
			prepare_start_captain_event()
		else 
			game.print('[font=default-large-bold]Team of captain ' .. player.name .. ' is ready ![/font]', Color.cyan)
			table.insert(global.special_games_variables["captain_mode"]["listTeamReadyToPlay"],player.force.name)
			if #global.special_games_variables["captain_mode"]["listTeamReadyToPlay"] >= 2 then
				if game.get_player(refereeName).gui.top["captain_poll_team_ready_frame"] then game.get_player(refereeName).gui.top["captain_poll_team_ready_frame"].destroy() end
				prepare_start_captain_event()
			elseif isRefereeACaptain() and not game.get_player(refereeName).gui.top["captain_poll_team_ready_frame"] then
				poll_captain_team_ready(game.get_player(global.special_games_variables["captain_mode"]["refereeName"]),true)
			end
		end
	elseif string.find(element.name, "captain_enabled_late_picking_by_ref") then
		global.special_games_variables["captain_mode"]["listPlayers"] = {}
		global.special_games_variables["captain_mode"]["listSpectators"] = {}
		global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"] = {}
		local refPlayer = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
		if player.gui.center["captain_poll_end_latejoiners_referee_frame"] then player.gui.center["captain_poll_end_latejoiners_referee_frame"].destroy() end
		for _, player in pairs(game.connected_players) do
			if not global.chosen_team[player.name] then
				if player.gui.center["captain_poll_latejoiner_question"] then player.gui.center["captain_poll_latejoiner_question"].destroy() end
				if not global.special_games_variables["captain_mode"]["blacklistLateJoin"][player.name] then
					table.insert(global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"],player.name)
					poll_captain_late_joiners(player)
				else
					if player.name == refPlayer.name then 
						poll_captain_end_late_joiners_referee(player)
					end
				end
			end
		end
		if global.chosen_team[refPlayer.name] then
			poll_captain_end_late_joiners_referee(refPlayer)
		end
		updatePollLateJoinReferee()
	elseif string.find(element.name, "captain_late_joiner_yes") then
		if player.gui.center["captain_poll_latejoiner_question"] then player.gui.center["captain_poll_latejoiner_question"].destroy() end
		table.insert(global.special_games_variables["captain_mode"]["listPlayers"],player.name)
		delete_player_from_novote_list(player.name)
		if player.name == global.special_games_variables["captain_mode"]["refereeName"] then
			poll_captain_end_late_joiners_referee(player)
		elseif game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_latejoiners_referee_frame"] ~=nil then
			updatePollLateJoinReferee()
		end
	elseif string.find(element.name, "captain_late_joiner_no") then
		if element.name == "captain_late_joiner_no_blacklist" then
			table.insert(global.special_games_variables["captain_mode"]["blacklistLateJoin"],player.name)
			global.special_games_variables["captain_mode"]["blacklistLateJoin"][player.name] = true
		end
		if player.gui.center["captain_poll_latejoiner_question"] then player.gui.center["captain_poll_latejoiner_question"].destroy() end
		table.insert(global.special_games_variables["captain_mode"]["listSpectators"],player.name)
		delete_player_from_novote_list(player.name)
		if player.name == global.special_games_variables["captain_mode"]["refereeName"] then
			poll_captain_end_late_joiners_referee(player)
		elseif game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_end_latejoiners_referee_frame"] ~=nil then
			updatePollLateJoinReferee()
		end
	elseif element.name == "captain_end_joinlate_choice" then
		game.print('The referee ended the poll to get late joiners to join a team', Color.cyan)
		end_captain_latejoiners_question()
		if player.gui.center["captain_poll_end_latejoiners_referee_frame"] then player.gui.center["captain_poll_end_latejoiners_referee_frame"].destroy() end
		if #global.special_games_variables["captain_mode"]["listPlayers"] > 0 then
			for _,pl in pairs(global.special_games_variables["captain_mode"]["listOfPlayersWhoDidntVoteForRoleYet"]) do
				delete_player_from_novote_list(pl)
			end
			if #global.special_games_variables["captain_mode"]["captainList"] == 2 then
				game.print('[font=default-large-bold]Switching to picking phase for late joiners ![/font]', Color.cyan)
				global.special_games_variables["captain_mode"]["pickingPhase"] = true
				poll_captain_picking_first(player)
			else
				game.print('Bug, case that should not happen, report it to devs', Color.cyan)
			end
		end
	elseif element.name == "captain_yes_wanna_play_new_to_current_match" then
		local refPlayer = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
		if player.gui.top["captain_poll_new_joiner_to_current_match"] then player.gui.top["captain_poll_new_joiner_to_current_match"].destroy() end
		refPlayer.print("Dear referee, the player " .. player.name .. " would like to play, please send him to a team",Color.red)
		player.print("The message was sent to referee, you should be sent soon to a team",Color.cyan)
	elseif element.name == "captain_no_wanna_play_new_to_current_match" then
		player.print("Enjoy the match then ! Don't hesitate to ask if you want a bit later to join a team and have fun",Color.cyan)
		if player.gui.top["captain_poll_new_joiner_to_current_match"] then player.gui.top["captain_poll_new_joiner_to_current_match"].destroy() end
	elseif element.name == "captain_toggle_throw_science" then
		if global.special_games_variables["captain_mode"]["captainList"][2] == player.name then
			global.special_games_variables["captain_mode"]["southEnabledScienceThrow"] = not global.special_games_variables["captain_mode"]["southEnabledScienceThrow"]
			game.forces["south"].print("Can anyone throw science in your team ? " .. tostring(global.special_games_variables["captain_mode"]["southEnabledScienceThrow"]), {r=1,g=1,b=0})
		else
			global.special_games_variables["captain_mode"]["northEnabledScienceThrow"] = not global.special_games_variables["captain_mode"]["northEnabledScienceThrow"]
			game.forces["north"].print("Can anyone throw science in your team ? " .. tostring(global.special_games_variables["captain_mode"]["northEnabledScienceThrow"]), {r=1,g=1,b=0})
		end
		Public.draw_captain_manager_gui(player)
		Public.draw_captain_manager_gui(player)
	elseif element.name == "captain_manager_toggle_button" then
		Public.draw_captain_manager_gui(player)		
	elseif element.name == "captain_add_someone_to_throw_trustlist" then
		local playerNameUpdateText = player.gui.center["captain_manager_gui"]["captain_manager_root_table"]["captain_add_playerName"].text
		if playerNameUpdateText and playerNameUpdateText ~= "" then
		
			local tableToUpdate = global.special_games_variables["captain_mode"]["northThrowPlayersListAllowed"]
			local forceForPrint = "north"
			if player.name == global.special_games_variables["captain_mode"]["captainList"][2] then
				tableToUpdate = global.special_games_variables["captain_mode"]["southThrowPlayersListAllowed"]
				forceForPrint = "south"
			end
			
			local playerToadd = game.get_player(playerNameUpdateText) 
			if playerToadd ~= nil and playerToadd.valid then
				if not playerNameInTable(tableToUpdate, playerNameUpdateText) then
					table.insert(tableToUpdate, playerNameUpdateText)
					game.forces[forceForPrint].print(playerNameUpdateText .. " added to throw trustlist !", Color.green)
				else
					player.print(playerNameUpdateText .. " was already added to throw trustlist !", Color.red)
				end
				Public.draw_captain_manager_gui(player)
				Public.draw_captain_manager_gui(player)
			else
				player.print(playerNameUpdateText .. "does not even exist or not even valid !", Color.red)
			end
		end
	elseif element.name == "captain_remove_someone_to_throw_trustlist" then
		local playerNameUpdateText = player.gui.center["captain_manager_gui"]["captain_manager_root_table"]["captain_remove_playerName"].text
		if playerNameUpdateText and playerNameUpdateText ~= "" then
		
			local tableToUpdate = global.special_games_variables["captain_mode"]["northThrowPlayersListAllowed"]
			local forceForPrint = "north"
			if player.name == global.special_games_variables["captain_mode"]["captainList"][2] then
				tableToUpdate = global.special_games_variables["captain_mode"]["southThrowPlayersListAllowed"]
				forceForPrint = "south"
			end
			if playerNameInTable(tableToUpdate, playerNameUpdateText) then
				removePlayerNameFromTable(tableToUpdate, playerNameUpdateText)
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
		if throwScienceSetting == false and playerNameInTable(throwList, player.name) == false then
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
			if refPlayer.gui.top["captain_referee_enable_picking_late_joiners"] then refPlayer.gui.top["captain_referee_enable_picking_late_joiners"].destroy() end
			if refPlayer.gui.center["captain_poll_end_latejoiners_referee_frame"] then refPlayer.gui.center["captain_poll_end_latejoiners_referee_frame"].destroy() end
			
			game.print(playerOfCommand.name .. " has decided that " .. victim.name .. " will be the new referee instead of " .. global.special_games_variables["captain_mode"]["refereeName"],Color.cyan)
			global.special_games_variables["captain_mode"]["refereeName"] = victim.name
			refPlayer = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
			generate_vs_text_rendering()
			poll_pickLateJoiners(refPlayer)
			else 
				playerOfCommand.print("Invalid name", Color.warning)
			end
		else
			playerOfCommand.print("Usage: /replaceReferee <playerName>", Color.warning)
		end		 		 
end)

commands.add_command('captainDisablePicking', 'Admin or referee can decide to change the referee',
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
end)

local function on_player_changed_force(event)
    local player = game.players[event.player_index]
	if player.force.name == "spectator" then
		Public.captain_log_end_time_player(player)
	else
		captain_log_start_time_player(player)
	end
end

local function on_player_left_game(event)
    local player = game.players[event.player_index]
	Public.captain_log_end_time_player(player)
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
	if global.special_games_variables["captain_mode"] ~=nil and not global.special_games_variables["captain_mode"]["listPlayersWhoAreNotNewToCurrentMatch"][player.name] then
		table.insert(global.special_games_variables["captain_mode"]["listPlayersWhoAreNotNewToCurrentMatch"],player.name)
		global.special_games_variables["captain_mode"]["listPlayersWhoAreNotNewToCurrentMatch"][player.name] = true
		pollGenerator(player,true,nil,
		"captain_poll_new_joiner_to_current_match","Do you want to play in the current match of captain event (no signup required) ? You can also always ask later to be sent to a team if you prefer.",
		"Yes", "captain_yes_wanna_play_new_to_current_match",
		"No", "captain_no_wanna_play_new_to_current_match",
		nil,nil)
	end
	if global.special_games_variables["captain_mode"] ~=nil and player.gui.center["bb_captain_countdown"] then player.gui.center["bb_captain_countdown"].destroy() end
	captain_log_start_time_player(player)
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game,on_player_left_game)
Event.add(defines.events.on_player_changed_force,on_player_changed_force)
return Public
