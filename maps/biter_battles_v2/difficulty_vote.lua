local bb_config = require "maps.biter_battles_v2.config"
local ai = require "maps.biter_battles_v2.ai"
local event = require 'utils.event'
local Server = require 'utils.server'
local Tables = require "maps.biter_battles_v2.tables"
local gui_style = require 'utils.utils'.gui_style
local closable_frame = require "utils.ui.closable_frame"
local Public = {}

local difficulties = Tables.difficulties

function Public.difficulty_name()
	local index = global.difficulty_vote_index
	if index then
		return difficulties[global.difficulty_vote_index].name
	else
		return string.format("Custom (%d%%)", global.difficulty_vote_value * 100)
	end
end

function Public.short_difficulty_name()
	local index = global.difficulty_vote_index
	if index then
		return difficulties[global.difficulty_vote_index].short_name
	else
		return "Custom"
	end
end

function Public.difficulty_print_color()
	return difficulties[global.difficulty_vote_index or 3].print_color
end

local function difficulty_gui(player)
	local b = player.gui.top["difficulty_gui"]
	if not b then return end
	b.style.font_color = Public.difficulty_print_color()
	local value = math.floor(global.difficulty_vote_value*100)
	local name = Public.difficulty_name()
	local str = table.concat({"Global map difficulty is ", name, ". Mutagen has ", value, "% effectiveness."})
	b.caption = name
	b.tooltip = str
end

local function difficulty_gui_all()
	for _, player in pairs(game.connected_players) do
		difficulty_gui(player)
	end
end

---@param player LuaPlayer
local function add_difficulty_gui_top_button(player)
	local b = player.gui.top["difficulty_gui"]
	if not b then
		b = player.gui.top.add { type = "sprite-button", name = "difficulty_gui" }
		b.style.font = "heading-2"
		gui_style(b, {width = 114, height = 38, padding = -2})
	end
	difficulty_gui(player)
end

local function is_captain_enabled()
	return global.special_games_variables["captain_mode"] ~= nil
end

local function isStringInTable(tab, str)
    for _, entry in ipairs(tab) do
        if entry == str then
            return true
        end
    end
    return false
end

local function is_vote_allowed_in_captain(playerName)
    local special = global.special_games_variables["captain_mode"]
    return special and special["prepaPhase"] and (isStringInTable(special["listPlayers"], playerName) or isStringInTable(special["captainList"], playerName))
end

local function poll_difficulty(player)
	if player.gui.screen["difficulty_poll"] then player.gui.screen["difficulty_poll"].destroy() return end
	if global.bb_settings.only_admins_vote or global.tournament_mode then
		if global.active_special_games["captain_mode"] then
			if global.bb_settings.only_admins_vote and not player.admin then return end
			if is_captain_enabled() and not global.bb_settings.only_admins_vote and not is_vote_allowed_in_captain(player.name) then return end 
			if not is_captain_enabled() and player.spectator and not global.bb_settings.only_admins_vote then return end
		else
			if not player.admin then return end
		end
	end
	
	local tick = game.ticks_played
	if tick > global.difficulty_votes_timeout then
		if player.online_time ~= 0 then
			local t = math.abs(math.floor((global.difficulty_votes_timeout - tick) / 3600))
			local str = "Votes have closed " .. t
			str = str .. " minute"
			if t > 1 then str = str .. "s" end
			str = str .. " ago."
			player.print(str)
		end
		return 
	end
	
	local frame = closable_frame.create_main_closable_frame(
		player,
		"difficulty_poll",
		"Vote global difficulty:",
		{
			no_dragger = true
		}
	)

	local time_left = frame.add{type = "label", caption = math.floor((global.difficulty_votes_timeout - tick) / 3600) .. " minutes left."}
	time_left.style.font = "heading-2"
	local separator = frame.add{type = "line", direction = "horizontal"}
	separator.style.bottom_margin = 6

	local vote_amounts = {}
	for k, v in pairs(global.difficulty_player_votes) do
		vote_amounts[v] = (vote_amounts[v] or 0) + 1
	end
	
	for key, difficulty in pairs(difficulties) do
		local caption = table.concat({difficulty.name, " (", difficulty.str, ")", " : ", (vote_amounts[key] or 0)})
		local b = frame.add{type = "button", name = tostring(key), caption = caption}
		b.style.font_color = difficulty.color
		b.style.font = "heading-2"
		b.style.minimal_width = 211
	end
end

local function set_difficulty()
	local a = {}
	local vote_count = 0
	local c = 0
	local v = 0
	for _, d in pairs(global.difficulty_player_votes) do
		c = c + 1
		a[c] = d
		vote_count = vote_count + 1
	end
	if vote_count == 0 then return end
	v= math.floor(vote_count/2)+1
	table.sort(a)
	local new_index = a[v]
	if global.difficulty_vote_index ~= new_index then
		local message = table.concat({">> Map difficulty has changed to ", difficulties[new_index].name, " difficulty!"})
		game.print(message, difficulties[new_index].print_color)
		Server.to_discord_embed(message)
	end
	 global.difficulty_vote_index = new_index
	 global.difficulty_vote_value = difficulties[new_index].value
	 ai.reset_evo()
end

local function on_player_joined_game(event)
	local player = game.get_player(event.player_index)
	if game.ticks_played < global.difficulty_votes_timeout then
		if not global.difficulty_player_votes[player.name] then
			if global.bb_settings.only_admins_vote or global.tournament_mode then
				if global.active_special_games["captain_mode"] then
					if player.admin then
						if global.bb_settings.only_admins_vote then poll_difficulty(player) end
					else
						if not global.bb_settings.only_admins_vote and not player.spectator then poll_difficulty(player) end
					end
				else
					if player.admin then poll_difficulty(player) end
				end
			end
		end
	else
		if player.gui.screen["difficulty_poll"] then player.gui.screen["difficulty_poll"].destroy() end
	end
	
	difficulty_gui_all()
end

function Public.remove_player_from_difficulty_vote(player)
	if game.ticks_played > global.difficulty_votes_timeout then return end
	if not global.difficulty_player_votes[player.name] then return end
	global.difficulty_player_votes[player.name] = nil
	set_difficulty()
end

local function on_player_left_game(event)
	Public.remove_player_from_difficulty_vote(game.get_player(event.player_index))
end

local function difficulty_voted(player, i)
	if global.difficulty_player_votes[player.name] ~= i then
		game.print(player.name .. " has voted for " .. difficulties[i].name .. " difficulty!", difficulties[i].print_color)
		global.difficulty_player_votes[player.name] = i	
		set_difficulty()	
		difficulty_gui_all()
	else
		player.print("You already voted for this difficulty", {r = 0.98, g = 0.66, b = 0.22})
	end
end

local function on_gui_click(event)
	if not event then return end
	if not event.element then return end
	if not event.element.valid then return end

	local player = game.get_player(event.element.player_index)

	if event.element.name == "difficulty_gui" then
		poll_difficulty(player)
		return
	end
	if event.element.type ~= "button" then return end
	if event.element.parent.name ~= "difficulty_poll" then return end
	if game.ticks_played > global.difficulty_votes_timeout then event.element.parent.destroy() return end
	local i = tonumber(event.element.name)
	
	if global.bb_settings.only_admins_vote or global.tournament_mode then
			if global.bb_settings.only_admins_vote or global.tournament_mode then
				if global.active_special_games["captain_mode"] then
					if global.bb_settings.only_admins_vote then
						if player.admin then
							difficulty_voted(player, i)
						end
					else
						if not player.spectator or is_vote_allowed_in_captain(player.name) then
							difficulty_voted(player, i)
						end
					end
				else
					if player.admin then
						difficulty_voted(player, i)
					end
				end
			end
		event.element.parent.destroy()
		return
	end

    if player.spectator and not is_captain_enabled() then
        player.print("spectators can't vote for difficulty")
		event.element.parent.destroy()
        return
    end
    if player.spectator and is_captain_enabled() and not is_vote_allowed_in_captain(player.name) then
        player.print("You must first sign up to play in order to vote in captain game")
		event.element.parent.destroy()
        return
    end

	if game.tick - global.spectator_rejoin_delay[player.name] < 3600 then
        player.print(
            "Not ready to vote. Please wait " .. 60-(math.floor((game.tick - global.spectator_rejoin_delay[player.name])/60)) .. " seconds.",
            {r = 0.98, g = 0.66, b = 0.22}
        )
		event.element.parent.destroy()
        return
    end
	
	difficulty_voted(player, i)	
	event.element.parent.destroy()
end
	
event.add(defines.events.on_gui_click, on_gui_click)
event.add(defines.events.on_player_left_game, on_player_left_game)
event.add(defines.events.on_player_joined_game, on_player_joined_game)

Public.difficulties = difficulties
Public.difficulty_gui = difficulty_gui
Public.difficulty_gui_all = difficulty_gui_all
Public.add_difficulty_gui_top_button = add_difficulty_gui_top_button

return Public
