local Server = require 'utils.server'
local Color = require 'utils.color_presets'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Event = require 'utils.event'
local gui_style = require 'utils.utils'.gui_style

local function draw_suspend_gui(player)
	if player.gui.top.suspend_frame then return end
	if global.suspend_target == nil then return end
	local f = player.gui.top.add{type = "frame", name = "suspend_frame"}
	gui_style(f, {height = 38, padding = 0})

	local t = f.add{type = "table", name = "suspend_table", column_count = 3, vertical_centering = true}
	local l = t.add{type = "label", caption = "Suspend "..global.suspend_target.." ?\t" .. global.suspend_time_left .. "s"}
	gui_style(l, {font = "heading-2", font_color = {r = 0.88, g = 0.55, b = 0.11}, width = 210})

	local b = t.add { type = "sprite-button", caption = "Yes", name = "suspend_yes" }
	gui_style(b, {width = 50, height = 28 , font = "heading-2", font_color = {r = 0.1, g = 0.9, b = 0.0}} )

	b = t.add { type = "sprite-button", caption = "No", name = "suspend_no" }
	gui_style(b, {width = 50, height = 28 , font = "heading-2", font_color = {r = 0.9, g = 0.1, b = 0.1}} )
end

local suspend_buttons_token = Token.register(
	-- create buttons for joining players
	function(event)
		local player = game.get_player(event.player_index)
		draw_suspend_gui(player)
	end
)

local function leave_corpse(player)
	if not player.character then return end
	
	local inventories = {
		player.get_inventory(defines.inventory.character_main),
		player.get_inventory(defines.inventory.character_guns),
		player.get_inventory(defines.inventory.character_ammo),
		player.get_inventory(defines.inventory.character_armor),
		player.get_inventory(defines.inventory.character_vehicle),
		player.get_inventory(defines.inventory.character_trash),
	}
	
	local corpse = false
	for _, i in pairs(inventories) do
		for index = 1, #i, 1 do
			if not i[index].valid then break end
			corpse = true
			break
		end
		if corpse then
			player.character.die()
			break
		end
	end
	
	if player.character then player.character.destroy() end	
	player.character = nil
	player.set_controller({type=defines.controllers.god})
	player.create_character()	
end

local function punish_player(playerSuspended)
	if playerSuspended.controller_type ~= defines.controllers.character then
		playerSuspended.set_controller{type=defines.controllers.character,character=playerSuspended.surface.create_entity{name='character',force=playerSuspended.force,position=playerSuspended.position}}	
	end
	if playerSuspended.controller_type == defines.controllers.character then
		leave_corpse(playerSuspended)
	end
	spectate(playerSuspended, false, false)
end

local suspend_token = Token.register(
	function()
		global.suspend_token_running = false
		-- disable suspend buttons creation for joining players
		Event.remove_removable(defines.events.on_player_joined_game, suspend_buttons_token)
		-- remove existing buttons
		for _, player in pairs(game.players) do
			if player.gui.top["suspend_frame"] then 
				player.gui.top["suspend_frame"].destroy()
			end
		end
		-- count votes
		local total_votes = table.size(global.suspend_voting)
		local result = 0
		if global.suspend_target ~= nil then
			if total_votes > 0 then
				for _, vote in pairs(global.suspend_voting) do
					result = result + vote
				end
				result = math.floor( 100*result / total_votes )
				if result >= 75 and total_votes > 1 then
					game.print(global.suspend_target .." suspended... (" .. result .. "%)")
					Server.to_banned_embed(table.concat {global.suspend_target .. ' was suspended ( ' .. result .. ' %)' .. ', vote started by ' .. global.suspend_playerName_who_started_vote})
					global.suspended_players[global.suspend_target] = game.ticks_played
					local playerSuspended = game.get_player(global.suspend_target)
					global.suspend_target = nil
					global.suspend_playerName_who_started_vote = nil
					global.suspend_voting = {}
					if playerSuspended and playerSuspended.valid and playerSuspended.surface.name ~= "gulag" then
						punish_player(playerSuspended)
					end
					return
				end
			end
			if total_votes == 1 and result == 100 then
				game.print("Vote to suspend "..global.suspend_target.." has failed because only 1 player voted, need at least 2 votes")
				Server.to_banned_embed(table.concat {global.suspend_target .. ' was not suspended and vote failed, only 1 player voted, need at least 2 votes, vote started by ' .. global.suspend_playerName_who_started_vote})
			else
				game.print("Vote to suspend "..global.suspend_target.." has failed (" .. result .. "%)")
				Server.to_banned_embed(table.concat {global.suspend_target .. ' was not suspended and vote failed ( ' .. result .. ' %)' .. ', vote started by ' .. global.suspend_playerName_who_started_vote})
			end
			global.suspend_target = nil
		end
		global.suspend_voting = {}
		global.suspend_playerName_who_started_vote = nil
	end
)

local decrement_timer_token = Token.get_counter() + 1 -- predict what the token will look like
decrement_timer_token = Token.register(
    function()
        local suspend_time_left = global.suspend_time_left - 1
        for _, player in pairs(game.connected_players) do
			if player.gui.top.suspend_frame and global.suspend_target ~= nil then
				player.gui.top.suspend_frame.suspend_table.children[1].caption = "Suspend ".. global.suspend_target .." ?\t" .. suspend_time_left .. "s"
			end
        end
        if suspend_time_left > 0 and global.suspend_target ~= nil then
            Task.set_timeout_in_ticks(60, decrement_timer_token)
            global.suspend_time_left = suspend_time_left
        end
    end
)

local function suspend_player(cmd)
	if not cmd.player_index then return end
	local killer = game.get_player(cmd.player_index)
	if not killer then return end
	if global.suspend_target then
		killer.print("You cant suspend 2 players at same time, wait for previous vote to end", Color.warning)
		return
	end
	if cmd.parameter then
		local victim = game.get_player(cmd.parameter)
		if victim and victim.valid then
			if victim.force.name == "spectator" then
				killer.print("You cant suspend a spectator", Color.warning)
				return
			end
			if victim.surface.name == "gulag" then
				killer.print("You cant suspend a player in jail", Color.warning)
				return
			end
			if killer.surface.name == "gulag" then
				killer.print("You cant suspend a player while you are in jail", Color.warning)
				return
			end
			if global.suspend_token_running then
					killer.print("A suspend was just started before restart, please wait 60s maximum to avoid bugs", Color.warning)
				return
			end
			global.suspend_target = victim.name
			game.print(killer.name .. 	" has started a vote to suspend " .. global.suspend_target .. " , vote in top of screen")
			global.suspend_token_running = true
			global.suspend_playerName_who_started_vote = killer.name
			Task.set_timeout_in_ticks(global.suspend_time_limit, suspend_token)
			Event.add_removable(defines.events.on_player_joined_game, suspend_buttons_token)
			global.suspend_time_left = global.suspend_time_limit / 60
			for _, player in pairs(game.connected_players) do
				draw_suspend_gui(player)
			end
			Task.set_timeout_in_ticks(60, decrement_timer_token)
		else
			killer.print("Invalid name", Color.warning)
		end
	else
		killer.print("Usage: /suspend <name>", Color.warning)
	end
end

commands.add_command('suspend',
                     'Force a player to stay in spectator for 10 minutes : /suspend playerName',
                     function(cmd) suspend_player(cmd); end)
					
local function on_player_joined_game(event)
	local player = game.players[event.player_index]
	if global.suspended_players[player.name] and (game.ticks_played - global.suspended_players[player.name]) < global.suspended_time then
		punish_player(player)
	end
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)		 