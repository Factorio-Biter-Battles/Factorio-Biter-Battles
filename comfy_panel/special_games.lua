local Event = require 'utils.event'
local Color = require 'utils.color_presets'
local Team_manager = require "maps.biter_battles_v2.team_manager"
local math_random = math.random
local Public = {}
global.active_special_games = {}
global.special_games_variables = {}
local valid_special_games = {
	--[[ 
	Add your special game here.
	Syntax:
	<game_name> = {
		name = {type = "label", caption = "<Name displayed in gui>", tooltip = "<Short description of the mode"
		config = {
			list of all knobs, leavers and dials used to config your game
			[1] = {name = "<name of this element>" called in on_gui_click to set variables, type = "<type of this element>", any other parameters needed to define this element},
			[2] = {name = "example_1", type = "textfield", text = "200", numeric = true, width = 40},
			[3] = {name = "example_2", type = "checkbox", caption = "Some checkbox", state = false}
			NOTE all names should be unique in the scope of the game mode
		},
		button = {name = "<name of this button>" called in on_gui_clicked , type = "button", caption = "Apply"}
	}
	]]
	turtle = {
		name = {type = "label", caption = "Turtle", tooltip = "Generate moat with given dimensions around the spawn"},
		config = {
			[1] = {name = "label1", type = "label", caption = "moat width"},
			[2] = {name = 'moat_width', type = "textfield", text = "5", numeric = true, width = 40},
			[3] = {name = "label2", type = "label", caption = "entrance width"},
			[4] = {name = 'entrance_width', type = "textfield", text = "20", numeric = true, width = 40},
			[5] = {name = "label3", type = "label", caption = "size x"},
			[6] = {name = 'size_x', type = "textfield", text = "200", numeric = true, width = 40},
			[7] = {name = "label4", type = "label", caption = "size y"},
			[8] = {name = 'size_y', type = "textfield", text = "200", numeric = true, width = 40},
			[9] = {name = "chart_turtle", type = "button", caption = "Chart", width = 60}
		},
		button = {name = "turtle_apply", type = "button", caption = "Apply"}
	},

	infinity_chest = {
		name = {type = "label", caption = "Infinity chest", tooltip = "Spawn infinity chests with given filters"},
		config = {
			[1] = {name = "eq1", type = "choose-elem-button", elem_type = "item"},
			[2] = {name = "eq2", type = "choose-elem-button", elem_type = "item"},
			[3] = {name = "eq3", type = "choose-elem-button", elem_type = "item"},
			[4] = {name = "eq4", type = "choose-elem-button", elem_type = "item"},
			[5] = {name = "eq5", type = "choose-elem-button", elem_type = "item"},
			[6] = {name = "eq6", type = "choose-elem-button", elem_type = "item"},
			[7] = {name = "eq7", type = "choose-elem-button", elem_type = "item"},
			[8] = {name = "separate_chests", type = "switch", switch_state = "left", tooltip = "Single chest / Multiple chests"},
			[9] = {name = "operable", type = "switch", switch_state = "right", tooltip = "Operable? Y / N"},
			[10] = {name = "label1", type = "label", caption = "Gap size"},
			[11] = {name = "gap", type = "textfield", text = "3", numeric = true, width = 40},
		},
		button = {name = "infinity_chest_apply", type = "button", caption = "Apply"}
	},
  
	disabled_research = {
		name = {type = "label", caption = "Disabled research", tooltip = "Disables choosen technologies from being researched"},
		config = {
			[1] = {name = "eq1", type = "choose-elem-button", elem_type = "technology"},
			[2] = {name = "eq2", type = "choose-elem-button", elem_type = "technology"},
			[3] = {name = "eq3", type = "choose-elem-button", elem_type = "technology"},
			[4] = {name = "eq4", type = "choose-elem-button", elem_type = "technology"},
			[5] = {name = "eq5", type = "choose-elem-button", elem_type = "technology"},
			[6] = {name = "eq6", type = "choose-elem-button", elem_type = "technology"},
			[7] = {name = "eq7", type = "choose-elem-button", elem_type = "technology"}, 
			[8] = {name = "team", type = "switch", switch_state = "none", allow_none_state = true, tooltip = "North / Both / South"},
			[9] = {name = "reset_disabled_research", type = "button", caption = "Reset", tooltip = "Enable all the disabled research again"}
		},
		button = {name = "disabled_research_apply", type = "button", caption = "Apply"}
	},

	disabled_entities = {
		name = {type = "label", caption = "Disabled entities", tooltip = "Disables choosen entities from being placed"},
		config = {
			[1] = {name = "eq1", type = "choose-elem-button", elem_type = "item"},
			[2] = {name = "eq2", type = "choose-elem-button", elem_type = "item"},
			[3] = {name = "eq3", type = "choose-elem-button", elem_type = "item"},
			[4] = {name = "eq4", type = "choose-elem-button", elem_type = "item"},
			[5] = {name = "eq5", type = "choose-elem-button", elem_type = "item"},
			[6] = {name = "eq6", type = "choose-elem-button", elem_type = "item"},
			[7] = {name = "eq7", type = "choose-elem-button", elem_type = "item"},
			[8] = {name = "team", type = "switch", switch_state = "none", allow_none_state = true, tooltip = "North / Both / South"},
		},
		button = {name = "disabled_entities_apply", type = "button", caption = "Apply"}
	},

	limited_lives = {
		name = {type = "label", caption = "Limited lives", tooltip = "Limits the number of player lives per game"},
		config = {
			[1] = {name = "label1", type = "label", caption = "Number of lives"},
			[2] = {name = "lives_limit", type = "textfield", text = "1", numeric = true, width = 40},
			[3] = {name = "label2", type = "label", caption = "(0 to reset)"},
		},
		button = {name = "limited_lives_apply", type = "button", caption = "Apply"}
	},

	captain_mode = {
		name = {type = "label", caption = "Captain mode", tooltip = "Captain mode"},
		config = {
			[1] = {name = "label4", type = "label", caption = "Referee"},
			[2] = {name = 'refereeName', type = "textfield", text = "ReplaceMe", numeric = false, width = 240}
		},
		button = {name = "captain_mode_apply", type = "button", caption = "Apply"}
	}
}

function Public.reset_active_special_games()
	if global.active_special_games["captain_mode"] then
		global.tournament_mode = false
	end
	for _, i in ipairs(global.active_special_games) do i = false end
end
function Public.reset_special_games_variables() global.special_games_variables = {} end

local function generate_turtle(moat_width, entrance_width, size_x, size_y)
	game.print("Special game turtle is being generated!", Color.warning)
	local surface = game.surfaces[global.bb_surface_name]
	local water_positions = {}
	local concrete_positions = {}
	local landfill_positions = {}

	for i = 0, size_y + moat_width do -- veritcal canals
		for a = 1, moat_width do
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) + a, y = i}})
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) - size_x - a, y = i}})
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) + a, y = -i - 1}})
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) - size_x - a, y = -i - 1}})
		end
	end
	for i = 0, size_x do -- horizontal canals
		for a = 1, moat_width do
			table.insert(water_positions, {name = "deepwater", position = {x = i - (size_x / 2), y = size_y + a}})
			table.insert(water_positions, {name = "deepwater", position = {x = i - (size_x / 2), y = -size_y - 1 - a}})
		end
	end

	for i = 0, entrance_width - 1 do
		for a = 1, moat_width + 6 do
			table.insert(concrete_positions,
			             {name = "refined-concrete", position = {x = -entrance_width / 2 + i, y = size_y - 3 + a}})
			table.insert(concrete_positions,
			             {name = "refined-concrete", position = {x = -entrance_width / 2 + i, y = -size_y + 2 - a}})
			table.insert(landfill_positions, {name = "landfill", position = {x = -entrance_width / 2 + i, y = size_y - 3 + a}})
			table.insert(landfill_positions, {name = "landfill", position = {x = -entrance_width / 2 + i, y = -size_y + 2 - a}})
		end
	end

	surface.set_tiles(water_positions)
	surface.set_tiles(landfill_positions)
	surface.set_tiles(concrete_positions)
	global.active_special_games["turtle"] = true
end

local function generate_infinity_chest(separate_chests, operable, gap, eq)
	local surface = game.surfaces[global.bb_surface_name]
	local position_0 = {x = 0, y = -42}

	local objects = surface.find_entities_filtered {name = 'infinity-chest'}
	for _, object in pairs(objects) do object.destroy() end

	game.print("Special game Infinity chest is being generated!", Color.warning)
	if operable == "left" then
		operable = true
	else
		operable = false
	end

	if separate_chests == "left" then
		local chest = surface.create_entity {
			name = "infinity-chest",
			position = position_0,
			force = "neutral",
			fast_replace = true
		}
		chest.minable = false
		chest.operable = operable
		chest.destructible = false
		for i, v in ipairs(eq) do
			chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
		end
		chest.clone {position = {position_0.x, -position_0.y}}

	elseif separate_chests == "right" then
		local k = gap + 1
		for i, v in ipairs(eq) do
			local chest = surface.create_entity {
				name = "infinity-chest",
				position = position_0,
				force = "neutral",
				fast_replace = true
			}
			chest.minable = false
			chest.operable = operable
			chest.destructible = false
			chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
			chest.clone {position = {position_0.x, -position_0.y}}
			position_0.x = position_0.x + (i * k)
			k = k * -1
		end
	end
	global.active_special_games["infinity_chest"] = true
end

local function generate_disabled_research(team, eq)
	if not global.special_games_variables["disabled_research"] then
		global.special_games_variables["disabled_research"] = {["north"] = {}, ["south"] = {}}
	end
	global.active_special_games["disabled_research"] = true
	local tab = {
		["left"] = "north",
		["right"] = "south"
	}
	if tab[team] then
		for k, v in pairs(eq) do
			table.insert(global.special_games_variables["disabled_research"][tab[team]], v)
			game.forces[tab[team]].technologies[v].enabled = false
		end
		game.print("Special game Disabled research: ".. table.concat(eq, ", ") .. " for team " .. tab[team] .. " is being generated!", Color.warning)
		return
	end
	
	for k, v in pairs(eq) do
		table.insert(global.special_games_variables["disabled_research"]["south"], v)
		table.insert(global.special_games_variables["disabled_research"]["north"], v)
		game.forces["north"].technologies[v].enabled = false
		game.forces["south"].technologies[v].enabled = false
	end
	game.print("Special game Disabled research: ".. table.concat(eq, ", ") .. " for both teams is being generated!", Color.warning)
end

local function reset_disabled_research(team)
	if not global.active_special_games["disabled_research"] then return end
	local tab = {
		["left"] = "north",
		["right"] = "south"
	}
	if tab[team] then
		for k, v in pairs(global.special_games_variables["disabled_research"][tab[team]]) do
			game.forces[tab[team]].technologies[v].enabled = true
		end
		global.special_games_variables["disabled_research"][tab[team]] = {}
		game.print("All disabled research has been enabled again for team " .. tab[team], Color.warning)
		return
	else
		for k, v in pairs(global.special_games_variables["disabled_research"]["north"]) do
			game.forces["north"].technologies[v].enabled = true
		end
		for k, v in pairs(global.special_games_variables["disabled_research"]["south"]) do
			game.forces["south"].technologies[v].enabled = true
		end
		global.special_games_variables["disabled_research"]["north"] = {}
		global.special_games_variables["disabled_research"]["south"] = {}
		game.print("All disabled research has been enabled again for both teams", Color.warning)
  end
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
	end
end

function Public.clear_gui_special_events()
	clear_gui_captain_mode()
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
	rendering.clear()
	Public.clear_gui_special_events()
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

local function poll_alternate_picking(player)
	pollGenerator(player,false,global.special_games_variables["captain_mode"]["listPlayers"],
	"captain_poll_alternate_pick_choice_frame","Who do you want to pick ?",
	"Magical1@StringHere","captain_player_picked_Magical1@StringHere",nil,nil,nil,nil)
end


local function poll_captain_late_joiners(player)
	pollGenerator(player,false,nil,
	"captain_poll_latejoiner_question","Do you want to play?","Yes","captain_late_joiner_yes","No","captain_late_joiner_no","No and please dont ask me again for the event (you will be blacklisted from any other late joiners poll for the current captain match only)","captain_late_joiner_no_blacklist")
end

local function generateRendering(textChosen, xPos, yPos, rColor,gColor,bColor,aColor, scaleChosen,fontChosen)
	rendering.draw_text{
		text = textChosen,
		surface = game.surfaces[global.bb_surface_name],
		target = {xPos,yPos},
		color = {
			r = rColor,
			g = gColor,
			b = bColor,
			a = aColor
		},
		scale = scaleChosen,
		font = fontChosen,
		alignment = "center",
		scale_with_zoom = false
	}
end

local function generateGenericRenderingCaptain()
	local y = -14
	generateRendering("Special event rule only : ",-65,y,1,1,1,1,3,"heading-1")
	y = y + 2
	generateRendering("-Use of /nth /sth /north-chat /south-chat /s /shout by spectator can be punished (warn-tempban event)",-65,y,0.87,0.13,0.5,1,3,"heading-1")
	y = y + 2
	generateRendering("-Captain is allowed to ask referee to send a player of his team not cooperating back to spectator",-65,y,0.87,0.13,0.5,1,3,"heading-1")
	y = y + 4
	generateRendering("Notes : ",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-Chat of spectator can only be seen by spectators for players",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-For admins, as spectator, use ping to talk only to spectators",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-Joining team late : Team with lowest amount of players gets the new player that arrived (might change up to referee)",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-Joining team late : A new player is allowed to join a random team even if teams have even amount of players (might change up to referee)",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-Joining team late : Exception for players that could break balance (up to referee)",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-Teams are locked, if you want to play, ask to be moved to a team",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-We are using discord bb for coms (not required), feel free to join to listen ,even if no mic",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-If you are not playing, you can listen to any team, but your mic must be off",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	generateRendering("-No sign up required, anyone can play the event !",-65,y,1,1,1,1,2.5,"heading-1")
	y = y + 2
	
	y = -8
	generateRendering("Organization of event :",66,-8,1,1,1,1,3,"heading-1")
	y = y + 2
	generateRendering("2 Team pickers/captains are chosen (one north, one south)",66,y,1,1,1,1,3,"heading-1")
	y = y + 2
	generateRendering("-Each captain picks one player at a time",66,y,1,1,1,1,3,"heading-1")
	y = y + 2
	generateRendering("-Teams can come to discord voice channel of bb to have easier communication (not required, can just listen too)",66,y,1,1,1,1,3,"heading-1")
	y = y + 2
	generateRendering("-Vote/poll for difficulty and strategy talk in each team for few minutes until both captains say team is ready",66,y,1,1,1,1,3,"heading-1")
	y = y + 2
	generateRendering("-Game starts, GL HF. Late joiners players can still join a team by asking",66,y,1,1,1,1,3,"heading-1")
	y = y + 2
end

local function generate_captain_mode(refereeName)
	global.special_games_variables["captain_mode"] = {["captainList"] = {}, ["refereeName"] = refereeName, ["listPlayers"] = {}, ["listSpectators"] = {}, ["listOfPlayersWhoDidntVoteForRoleYet"]={},["listTeamReadyToPlay"] = {}, ["lateJoiners"] = false, ["prepaPhase"] = true, ["blacklistLateJoin"]={}, ["listPlayersWhoAreNotNewToCurrentMatch"]={}}
	global.active_special_games["captain_mode"] = true
	if game.get_player(global.special_games_variables["captain_mode"]["refereeName"]) == nil then
		game.print("Event captain aborted, referee is not a player connected.. Referee name of player was : ".. global.special_games_variables["captain_mode"]["refereeName"])
		global.special_games_variables["captain_mode"] = nil
		global.active_special_games["captain_mode"] = false
		return
	end
	Public.clear_gui_special_events()
	for _, pl in pairs(game.connected_players) do
		if pl.force.name ~= "spectator" then
			pl.print('Captain event is on the way, switched you to spectator')
			Team_manager.switch_force(pl.name,"spectator")
		end
	end
	global.chosen_team = {}
	clear_character_corpses()
	game.print('Captain mode started !! Have fun ! Referee will be '.. global.special_games_variables["captain_mode"]["refereeName"])
	global.tournament_mode = true
	if global.freeze_players == false then
		global.freeze_players = true
		Team_manager.freeze_players()
		game.print(">>> Players have been frozen!", {r = 111, g = 111, b = 255})
	end
	show_captain_question()
		
	local y = 0
	rendering.clear()
	generateRendering("Special Captain's tournament mode enabled",0,-16,1,0,0,1,5,"heading-1")
	generateRendering("team xx vs team yy. Referee: " .. refereeName .. ". Teams on VC",0,10,0.87,0.13,0.5,1,1.5,"heading-1")
	generateGenericRenderingCaptain()
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {-9, -2}, to = {-9,3}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {0, 9}, to = {0,4}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {0, -4}, to = {0,-9}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {-9, 0}, to = {-4,0}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_line{surface = game.surfaces[global.bb_surface_name], from = {4, 0}, to = {9,0}, color = {r = 1},draw_on_ground = true, width = 3, gap_length = 0, dash_length = 1} 
	rendering.draw_circle{surface = game.surfaces[global.bb_surface_name], target = {0, 0}, radius = 4, filled= false,draw_on_ground = true, color = {r = 1}, width = 3} 

	generateRendering("Speedrunners",6,-5,1,1,1,1,2,"heading-1")
	generateRendering("BB veteran players",-6,-5,1,1,1,1,2,"heading-1")
	generateRendering("New players",6,5,1,1,1,1,2,"heading-1")
	generateRendering("Not veteran but not new players",-6,5,1,1,1,1,2,"heading-1")
	generateRendering("Spectators",-12,0,1,1,1,1,2,"heading-1")

	for i=-9,-16,-1 do
		for k=2,-2,-1 do
			game.surfaces[global.bb_surface_name].set_tiles({{name = "green-refined-concrete", position = {x=i,y=k}}}, true)
		end
	end 
end

local function generate_disabled_entities(team, eq)
	if not global.special_games_variables["disabled_entities"] then
		global.special_games_variables["disabled_entities"] = {["north"] = {}, ["south"] = {}}
	end
	local tab = {}
	for k, v in pairs(eq) do
		if v then
			tab[v] = true
		end
	end
	if team == "left" then
		global.special_games_variables["disabled_entities"]["north"] = tab
		game.print("Special game Disabled entities: ".. table.concat(eq, ", ") .. " for team North is being generated!", Color.warning)
	elseif team == "right" then
		global.special_games_variables["disabled_entities"]["south"] = tab
		game.print("Special game Disabled entities: ".. table.concat(eq, ", ") .. " for team South is being generated!", Color.warning)
	else
		global.special_games_variables["disabled_entities"]["south"] = tab
		global.special_games_variables["disabled_entities"]["north"] = tab
		game.print("Special game Disabled entities: ".. table.concat(eq, ", ") .. " for both teams is being generated!", Color.warning)
	end
	global.active_special_games["disabled_entities"] = true
end

local function generate_limited_lives(lives_limit)
	if global.special_games_variables["limited_lives"] then
		rendering.destroy(global.special_games_variables["limited_lives"]["text_id"])
	end

	if lives_limit == 0 then
		-- reset special game
		global.active_special_games["limited_lives"] = false
		global.special_games_variables["limited_lives"] = nil
		return
	end

	global.active_special_games["limited_lives"] = true
	global.special_games_variables["limited_lives"] = {
		lives_limit = lives_limit,
		player_lives = {},
	}
	local special_game_description = table.concat({"Each player has only", lives_limit, ((lives_limit == 1) and "life" or "lives"), "until the end of the game."}, " ")
	global.special_games_variables["limited_lives"]["text_id"] = rendering.draw_text{
		text = special_game_description,
		surface = game.surfaces[global.bb_surface_name],
		target = {-0,-12},
		color = Color.warning,
		scale = 3,
		alignment = "center",
		scale_with_zoom = false
	}
	game.print("Special game Limited lives: " .. special_game_description)
end

function Public.has_life(player_name)
	local player_lives = global.special_games_variables["limited_lives"]["player_lives"][player_name]
	return player_lives == nil or player_lives > 0
end

local function on_built_entity(event)
	if not global.active_special_games["disabled_entities"] then return end
	local entity = event.created_entity
	if not entity then return end
	if not entity.valid then return end
	
	local player = game.get_player(event.player_index)
	local force = player.force	
	if global.special_games_variables["disabled_entities"][force.name][entity.name] then
		player.create_local_flying_text({text = "Disabled by special game", position = entity.position})
		player.get_inventory(defines.inventory.character_main).insert({name = entity.name, count = 1})
		entity.destroy()
	end
end

local create_special_games_panel = (function(player, frame)
	frame.clear()
	frame.add{type = "label", caption = "Configure and apply special games here"}.style.single_line = false

	for k, v in pairs(valid_special_games) do
		local a = frame.add {type = "frame"}
		a.style.width = 750
		local table = a.add {name = k, type = "table", column_count = 3, draw_vertical_lines = true}
		table.add(v.name).style.width = 100
		local config = table.add {name = k .. "_config", type = "flow", direction = "horizontal"}
		config.style.width = 500
		for _, i in ipairs(v.config) do
			config.add(i)
			config[i.name].style.width = i.width
		end
		table.add {name = v.button.name, type = v.button.type, caption = v.button.caption}
		table[k .. "_config"].style.vertical_align = "center"
	end
end)

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

local function start_captain_event()
	game.print('[font=default-large-bold]Time to start the game!! Good luck and have fun everyone ![/font]', Color.cyan)
	if global.freeze_players == true then
		global.freeze_players = false
		Team_manager.unfreeze_players()
		game.print(">>> Players have been unfrozen!", {r = 255, g = 77, b = 77})
	end
	global.special_games_variables["captain_mode"]["prepaPhase"] = false
	
	local playerToClear = game.get_player(global.special_games_variables["captain_mode"]["captainList"][1])
	if playerToClear.gui.top["captain_poll_team_ready_frame"] then playerToClear.gui.top["captain_poll_team_ready_frame"].destroy() end
	playerToClear = game.get_player(global.special_games_variables["captain_mode"]["captainList"][2])
	if playerToClear.gui.top["captain_poll_team_ready_frame"] then playerToClear.gui.top["captain_poll_team_ready_frame"].destroy() end
	playerToClear = game.get_player(global.special_games_variables["captain_mode"]["refereeName"])
	if playerToClear.gui.top["captain_poll_team_ready_frame"] then playerToClear.gui.top["captain_poll_team_ready_frame"].destroy() end
	local y = 0
	rendering.clear()
	generateRendering("Special Captain's tournament mode enabled",0,-16,1,0,0,1,5,"heading-1")
	generateRendering("team " .. global.special_games_variables["captain_mode"]["captainList"][1] .. " vs team " .. global.special_games_variables["captain_mode"]["captainList"][2] .. ". Referee: " .. global.special_games_variables["captain_mode"]["refereeName"]  .. ". Teams on VC",0,10,0.87,0.13,0.5,1,1.5,"heading-1")
	generateGenericRenderingCaptain()
	generateRendering("Want to play ? Ask to join a team!",0,-9,1,1,1,1,3,"heading-1")
end

local function allow_vote()
            local tick = game.ticks_played
            global.difficulty_votes_timeout = tick + 10800
            global.difficulty_player_votes = {}
			game.print('[font=default-large-bold]Difficulty voting is opened for 3 minutes![/font]', Color.cyan)
end

local function on_gui_click(event)
	local element = event.element
	if not element then return end
	if not element.valid then return end
	
	local player = game.get_player(event.player_index)	
	if not element.type == "button" then return end
	local config = element.parent.children[2]

	if string.find(element.name, "_apply") then
		local flow = element.parent.add {type = "flow", direction = "vertical"}
		flow.add {type = "button", name = string.gsub(element.name, "_apply", "_confirm"), caption = "Confirm"}
		flow.add {type = "button", name = "cancel", caption = "Cancel"}
		element.visible = false -- hides Apply button	
		player.print("[SPECIAL GAMES] Are you sure? This change will be reversed only on map restart!", Color.cyan)

	elseif string.find(element.name, "_confirm") then
		config = element.parent.parent.children[2]

	end
	-- Insert logic for apply button here
	if element.name == "turtle_confirm" then

		local moat_width = config["moat_width"].text
		local entrance_width = config["entrance_width"].text
		local size_x = config["size_x"].text
		local size_y = config["size_y"].text

		generate_turtle(moat_width, entrance_width, size_x, size_y)
	elseif element.name == "chart_turtle" then
		config = element.parent.parent.children[2]
		local moat_width = config["moat_width"].text
		local entrance_width = config["entrance_width"].text
		local size_x = config["size_x"].text
		local size_y = config["size_y"].text

		game.forces["spectator"].chart(game.surfaces[global.bb_surface_name], {
			{-size_x / 2 - moat_width, -size_y - moat_width}, {size_x / 2 + moat_width, size_y + moat_width}
		})

	elseif element.name == "infinity_chest_confirm" then

		local separate_chests = config["separate_chests"].switch_state
		local operable = config["operable"].switch_state
		local gap = config["gap"].text
		local eq = {
			config["eq1"].elem_value, 
			config["eq2"].elem_value, 
			config["eq3"].elem_value, 
			config["eq4"].elem_value,
			config["eq5"].elem_value,
			config["eq6"].elem_value,
			config["eq7"].elem_value
		}

		generate_infinity_chest(separate_chests, operable, gap, eq)
	
	elseif element.name == "captain_mode_confirm" then
		local refereeName = config["refereeName"].text
		generate_captain_mode(refereeName)
	elseif element.name == "disabled_research_confirm" then
		local team = config["team"].switch_state
		local eq = {
			config["eq1"].elem_value, 
			config["eq2"].elem_value, 
			config["eq3"].elem_value, 
			config["eq4"].elem_value,
			config["eq5"].elem_value,
			config["eq6"].elem_value,
			config["eq7"].elem_value
		}

		generate_disabled_research(team, eq)

	elseif element.name == "reset_disabled_research" then
		config = element.parent.parent.children[2]
		local team = config["team"].switch_state
		reset_disabled_research(team)

	elseif element.name == "disabled_entities_confirm" then
		local team = config["team"].switch_state
		local eq = {}
		for v = 1, 1, 7 do
			if config["eq"..v].elem_value then
				eq[config["eq"..v].elem_value] = true
			end
		end
		eq = {
			config["eq1"].elem_value, 
			config["eq2"].elem_value, 
			config["eq3"].elem_value, 
			config["eq4"].elem_value,
			config["eq5"].elem_value,
			config["eq6"].elem_value,
			config["eq7"].elem_value
		}
		generate_disabled_entities(team, eq)
	elseif element.name == "captain_yes_choice" then
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
		game.print(player.name .. ' will be a spectator')
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
			Team_manager.switch_force(global.special_games_variables["captain_mode"]["captainList"][2],"south")
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
			Team_manager.switch_force(global.special_games_variables["captain_mode"]["captainList"][2],"south")
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
			game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
			
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 and global.special_games_variables["captain_mode"]["lateJoiners"] == true then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local captainForceName = game.get_player(global.special_games_variables["captain_mode"]["captainList"][1]).force.name
				game.print(lastPlayerToSend.name .. " was automatically picked")
				Team_manager.switch_force(lastPlayerToSend.name,captainForceName)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
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
			game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 and global.special_games_variables["captain_mode"]["lateJoiners"] == true then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local captainForceName = game.get_player(global.special_games_variables["captain_mode"]["captainList"][2]).force.name
				game.print(lastPlayerToSend.name .. " was automatically picked")
				Team_manager.switch_force(lastPlayerToSend.name,captainForceName)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
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
			game.get_player(global.special_games_variables["captain_mode"]["refereeName"]).gui.center["captain_poll_firstpicker_choice_frame"].destroy()
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 and global.special_games_variables["captain_mode"]["lateJoiners"] == true then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local captainForceName = game.get_player(global.special_games_variables["captain_mode"]["captainList"][captainChosen]).force.name
				game.print(lastPlayerToSend.name .. " was automatically picked")
				Team_manager.switch_force(lastPlayerToSend.name,captainForceName)
				lastPlayerToSend.print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
				local index={}
				for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
				   index[v]=k
				end
				local indexPlayer = index[lastPlayerToSend.name]
				table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
				game.print('[font=default-large-bold]All late joiners were picked by captains[/font]', Color.cyan)
			else
				poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][captainChosen]))
			end
		end
	elseif string.find(element.name, "captain_player_picked_") then
		local playerPicked = element.name:gsub("^captain_player_picked_", "")
		if player.gui.center["captain_poll_alternate_pick_choice_frame"] then player.gui.center["captain_poll_alternate_pick_choice_frame"].destroy() end
		game.print(playerPicked .. " was picked by Captain " .. player.name)
		Team_manager.switch_force(playerPicked,player.force.name)
		game.get_player(playerPicked).print("Remember to join your team channel voice on discord of free biterbattles (discord link can be found on biterbattles.org website) if possible (even if no mic, it's fine, to just listen, it's not required though but better if you do !)", Color.cyan)
		
		local index={}
		for k,v in pairs(global.special_games_variables["captain_mode"]["listPlayers"]) do
		   index[v]=k
		end
		local indexPlayer = index[playerPicked]
		table.remove(global.special_games_variables["captain_mode"]["listPlayers"],indexPlayer)
		
		if are_all_players_picked() then
			if #global.special_games_variables["captain_mode"]["listPlayers"] == 1 then
				local lastPlayerToSend = game.get_player(global.special_games_variables["captain_mode"]["listPlayers"][1])
				local oppositeForce = "north"
				if player.force.name == "north" then
					oppositeForce = "south"
				end
				game.print(lastPlayerToSend.name .. " was automatically picked")
				Team_manager.switch_force(lastPlayerToSend.name,oppositeForce)
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
			end
		else
			if player.name == game.get_player(global.special_games_variables["captain_mode"]["captainList"][1]).name then
				poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][2]))
			else
				poll_alternate_picking(game.get_player(global.special_games_variables["captain_mode"]["captainList"][1]))
			end
		end
	elseif string.find(element.name, "ready_captain_") then
		if game.tick < global.difficulty_votes_timeout then 
			player.print('[font=default-large-bold]Wait for end of difficulty vote poll before telling your team is ready (meanwhile, your team should strategize!)[/font]', Color.red)
			return
		end
	
		if player.gui.top["captain_poll_team_ready_frame"] then player.gui.top["captain_poll_team_ready_frame"].destroy() end
		local refereeName = global.special_games_variables["captain_mode"]["refereeName"]
		if player.name == refereeName and not isRefereeACaptain() then
			game.print('[font=default-large-bold]Referee ' .. refereeName .. ' force started the game ![/font]', Color.cyan)
			start_captain_event()
		else 
			game.print('[font=default-large-bold]Team of captain ' .. player.name .. ' is ready ![/font]', Color.cyan)
			table.insert(global.special_games_variables["captain_mode"]["listTeamReadyToPlay"],player.force.name)
			if #global.special_games_variables["captain_mode"]["listTeamReadyToPlay"] >= 2 then
				if game.get_player(refereeName).gui.top["captain_poll_team_ready_frame"] then game.get_player(refereeName).gui.top["captain_poll_team_ready_frame"].destroy() end
				start_captain_event()
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
	elseif element.name == "limited_lives_confirm" then
		local lives_limit = tonumber(config["lives_limit"].text)
		generate_limited_lives(lives_limit)
	end

	if element.valid then
		if string.find(element.name, "_confirm") or element.name == "cancel" then
			element.parent.parent.children[3].visible = true -- shows back Apply button
			element.parent.destroy() -- removes confirm/Cancel buttons
		end
	end
end

local function on_player_died(event)
	if not global.active_special_games["limited_lives"] then return end

    local player = game.get_player(event.player_index)
	local player_lives = global.special_games_variables["limited_lives"]["player_lives"][player.name]
	if player_lives == nil then
		player_lives = global.special_games_variables["limited_lives"]["lives_limit"]
	end
	player_lives = player_lives - 1
	global.special_games_variables["limited_lives"]["player_lives"][player.name] = player_lives

	if player_lives == 0 then
		spectate(player)
	end

	player.print(
		table.concat({"You have", player_lives, ((player_lives == 1) and "life" or "lives"), "left."}, " "),
		Color.warning
	)
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
end
comfy_panel_tabs['Special games'] = {gui = create_special_games_panel, admin = true}

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_player_died, on_player_died)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
return Public

