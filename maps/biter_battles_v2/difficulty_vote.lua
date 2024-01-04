local bb_config = require "maps.biter_battles_v2.config"
local ai = require "maps.biter_battles_v2.ai"
local event = require 'utils.event'
local Server = require 'utils.server'
local Tables = require "maps.biter_battles_v2.tables"
local gui_style = require 'utils.utils'.gui_style

local difficulties = Tables.difficulties

local function difficulty_gui(player)
	local value = math.floor(global.difficulty_vote_value*100)
	if player.gui.top["difficulty_gui"] then player.gui.top["difficulty_gui"].destroy() end
	local str = table.concat({"Global map difficulty is ", difficulties[global.difficulty_vote_index].name, ". Mutagen has ", value, "% effectiveness."})
	local b = player.gui.top.add { type = "sprite-button", caption = difficulties[global.difficulty_vote_index].name, tooltip = str, name = "difficulty_gui" }
	b.style.font = "heading-2"
	b.style.font_color = difficulties[global.difficulty_vote_index].print_color
	gui_style(b, {width = 114, height = 38, padding = -2})
end

local function difficulty_gui_all()
	for _, player in pairs(game.connected_players) do
		difficulty_gui(player)
	end
end

local function poll_difficulty(player)
	if player.gui.center["difficulty_poll"] then player.gui.center["difficulty_poll"].destroy() return end
	if global.bb_settings.only_admins_vote or global.tournament_mode then
		if global.active_special_games["captain_mode"] then
			if global.bb_settings.only_admins_vote and not player.admin then return end
			if player.spectator and not global.bb_settings.only_admins_vote then return end
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
	
	local frame = player.gui.center.add { type = "frame", caption = "Vote global difficulty:", name = "difficulty_poll", direction = "vertical" }
	local vote_amounts = {}
	for k, v in pairs(global.difficulty_player_votes) do
		vote_amounts[v] = (vote_amounts[v] or 0) + 1
	end
	
	for key, difficulty in pairs(difficulties) do
		local caption = table.concat({difficulty.name, " (", difficulty.str, ")", " : ", (vote_amounts[key] or 0)})
		local b = frame.add{type = "button", name = tostring(key), caption = caption}
		b.style.font_color = difficulty.color
		b.style.font = "heading-2"
		b.style.minimal_width = 180
	end
	local b = frame.add({type = "label", caption = "- - - - - - - - - - - - - - - - - - - -"})
	local b = frame.add({type = "button", name = "close", caption = "Close (" .. math.floor((global.difficulty_votes_timeout - tick) / 3600) .. " minutes left)"})
	b.style.font_color = {r=0.66, g=0.0, b=0.66}
	b.style.font = "heading-3"
	b.style.minimal_width = 96
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
	if not global.difficulty_vote_value then global.difficulty_vote_value = 1 end
	if not global.difficulty_vote_index then global.difficulty_vote_index = 4 end
	if not global.difficulty_player_votes then global.difficulty_player_votes = {} end
	
	local player = game.players[event.player_index]
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
		if player.gui.center["difficulty_poll"] then player.gui.center["difficulty_poll"].destroy() end
	end
	
	difficulty_gui_all()
end

local function on_player_left_game(event)
	if game.ticks_played > global.difficulty_votes_timeout then return end
	local player = game.players[event.player_index]
	if not global.difficulty_player_votes[player.name] then return end
	global.difficulty_player_votes[player.name] = nil
	set_difficulty()
end

local function on_gui_click(event)
	if not event then return end
	if not event.element then return end
	if not event.element.valid then return end

	local player = game.players[event.element.player_index]

	if event.element.name == "difficulty_gui" then
		poll_difficulty(player)
		return
	end
	if event.element.type ~= "button" then return end
	if event.element.parent.name ~= "difficulty_poll" then return end
	if event.element.name == "close" then event.element.parent.destroy() return end
	if game.ticks_played > global.difficulty_votes_timeout then event.element.parent.destroy() return end
	local i = tonumber(event.element.name)
	
	if global.bb_settings.only_admins_vote or global.tournament_mode then
			if global.bb_settings.only_admins_vote or global.tournament_mode then
				if global.active_special_games["captain_mode"] then
					if global.bb_settings.only_admins_vote then
						if player.admin then
							game.print(player.name .. " has voted for " .. difficulties[i].name .. " difficulty!", difficulties[i].print_color)
							global.difficulty_player_votes[player.name] = i
							set_difficulty()
							difficulty_gui(player)
						end
					else
						if not player.spectator then
							game.print(player.name .. " has voted for " .. difficulties[i].name .. " difficulty!", difficulties[i].print_color)
							global.difficulty_player_votes[player.name] = i
							set_difficulty()
							difficulty_gui(player)
						end
					end
				else
					if player.admin then
						game.print(player.name .. " has voted for " .. difficulties[i].name .. " difficulty!", difficulties[i].print_color)
						global.difficulty_player_votes[player.name] = i
						set_difficulty()
						difficulty_gui(player)
					end
				end
			end
		event.element.parent.destroy()
		return
	end

    if player.spectator then
        player.print("spectators can't vote for difficulty")
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
	
	if global.difficulty_player_votes[player.name] ~= i then
		game.print(player.name .. " has voted for " .. difficulties[i].name .. " difficulty!", difficulties[i].print_color)
		global.difficulty_player_votes[player.name] = i	
		set_difficulty()	
		difficulty_gui_all()
	else
		player.print("You already voted for this difficulty", {r = 0.98, g = 0.66, b = 0.22})
	end
	event.element.parent.destroy()
end
	
event.add(defines.events.on_gui_click, on_gui_click)
event.add(defines.events.on_player_left_game, on_player_left_game)
event.add(defines.events.on_player_joined_game, on_player_joined_game)

local Public = {}
Public.difficulties = difficulties
Public.difficulty_gui = difficulty_gui
Public.difficulty_gui_all = difficulty_gui_all

return Public
