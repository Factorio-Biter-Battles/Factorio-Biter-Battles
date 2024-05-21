-- Biter Battles v2 -- by MewMew

local Ai = require "maps.biter_battles_v2.ai"
local AiStrikes = require "maps.biter_battles_v2.ai_strikes"
local AiTargets = require "maps.biter_battles_v2.ai_targets"
local bb_config = require "maps.biter_battles_v2.config"
local Functions = require "maps.biter_battles_v2.functions"
local Game_over = require "maps.biter_battles_v2.game_over"
local Gui = require "maps.biter_battles_v2.gui"
local Init = require "maps.biter_battles_v2.init"
local Mirror_terrain = require "maps.biter_battles_v2.mirror_terrain"
local Muted = require "utils.muted"
require 'modules.simple_tags'
local Team_manager = require "maps.biter_battles_v2.team_manager"
local Terrain = require "maps.biter_battles_v2.terrain"
local Session = require 'utils.datastore.session_data'
local Server = require 'utils.server'
local Task = require 'utils.task'
local Token = require 'utils.token'
local Color = require 'utils.color_presets'
local ResearchInfo = require 'maps.biter_battles_v2.research_info'
local autoTagWestOutpost = "[West]"
local autoTagEastOutpost = "[East]"
local autoTagDistance = 600
local antiAfkTimeBeforeEnabled = 60 * 60 * 5 -- in tick : 5 minutes
local antiAfkTimeBeforeWarning = 60 * 60 * 3 + 60*40 -- in tick : 3 minutes 40s
require "maps.biter_battles_v2.sciencelogs_tab"
require "maps.biter_battles_v2.feed_values_tab"
require "maps.biter_battles_v2.changelog_tab"
require 'maps.biter_battles_v2.commands'
require "modules.spawners_contain_biters"

local function on_player_joined_game(event)
	local surface = game.surfaces[global.bb_surface_name]
	local player = game.players[event.player_index]
	if player.online_time == 0 or player.force.name == "player" then
		Functions.init_player(player)
	end
	Gui.clear_copy_history(player)
	Functions.create_map_intro_button(player)
	--ResearchInfo.create_research_info_button(player)
	Team_manager.draw_top_toggle_button(player)
end

local function on_gui_click(event)
	local player = game.players[event.player_index]
	local element = event.element
	if not element then return end
	if not element.valid then return end

	if Functions.map_intro_click(player, element) then return end
	if ResearchInfo.research_info_click(player, element) then return end
	Team_manager.gui_click(event)
end

local function on_research_finished(event)
	Functions.combat_balance(event)

	local name = event.research.name
	local force = event.research.force
	if name == 'uranium-processing' then
		force.technologies["uranium-ammo"].researched = true
		force.technologies["kovarex-enrichment-process"].researched = true
	elseif name == 'stone-wall' then
		force.technologies["gate"].researched = true
	elseif name == 'rocket-silo' then
		force.technologies['space-science-pack'].researched = true
	end
	game.forces.spectator.print(Functions.team_name_with_color(force.name) .. " completed research [technology=" .. name .. "]")
	ResearchInfo.research_finished(name, force)
end

local function on_research_started(event)
	local name = event.research.name
	local force = event.research.force
	ResearchInfo.research_started(name, force)
end

local function on_research_reversed(event)
	-- Note that this will not really work for Functions.combat_balance, so don't go reversing technologies.
	local name = event.research.name
	local force = event.research.force
	ResearchInfo.research_reversed(name, force)
end

local clear_pings_token = Token.register(
	function()
		local tick = game.tick
		while #global.pings_to_remove > 0 do
			local ping = global.pings_to_remove[1]
			if ping.tick <= tick then
				if ping.label.valid then
					if #ping.label.parent.children == 1 then
						ping.label.gui.screen["ping_header"].destroy()
						ping.label.parent.destroy()
					else
						ping.label.destroy()
					end
				end
				table.remove(global.pings_to_remove, 1)
			else
				break
			end
		end
	end)

---@param from_player_name string
---@param to_player_name string
---@return boolean
local function ignore_message(from_player_name, to_player_name)
	local ignore_list = global.ignore_lists[from_player_name]
	return ignore_list and ignore_list[to_player_name]
end

---@param from_player_name string
---@param to_player LuaPlayer
---@param message string
function do_ping(from_player_name, to_player, message)
	local to_player_name = to_player.name
	if ignore_message(from_player_name, to_player_name) then return end
	if not global.want_pings[to_player_name] then return end
	if to_player.character and to_player.character.get_health_ratio() > 0.99 then
		to_player.character.damage(0.001, "player")
	end
	-- to_player.play_sound({path = "utility/new_objective", volume_modifier = 0.6})
	-- to_player.surface.create_entity({name = 'big-explosion', position = to_player.position})
	local ping_header = to_player.gui.screen["ping_header"]
	if not ping_header then
		ping_header = to_player.gui.screen.add({type = "frame", caption = "Message", name = "ping_header", direction = "vertical"})
		ping_header.style.width = 105
		ping_header.style.height = 38

		local line = ping_header.add({type="line"})
		line.style.width = 400
		line.style.right_margin = -400
		line.style.left_margin = -12
		line.style.top_margin = -5

		if global.ping_gui_locations[to_player.name] then
			ping_header.location = global.ping_gui_locations[to_player.name]
		else
			local res = to_player.display_resolution
			local uis = to_player.display_scale
			ping_header.location = {x = res.width/2 - 200 * uis, y = 100 * uis}
		end
	end

	local ping_messages = to_player.gui.screen["ping_messages"]
	if not ping_messages then
		ping_messages = to_player.gui.screen.add({type = "flow", name = "ping_messages", direction = "vertical"})
		ping_messages.style.width = 400
		ping_messages.location = {x = ping_header.location.x, y = ping_header.location.y + 42}
	end

	local label = ping_messages.add({type = "label", caption = message})
	label.style.single_line = false
	label.style.font = "default-large-semibold"

	local remove_delay = 600
	table.insert(global.pings_to_remove, {player = to_player, label = label, tick = game.tick + remove_delay})
	Task.set_timeout_in_ticks(remove_delay, clear_pings_token)
end


local function on_gui_location_changed(event)
	local element = event.element
	if not element.valid then return end
	if element.name == "ping_header" then
		local player = game.get_player(event.player_index)
		if not player then return end
		global.ping_gui_locations[player.name] = element.location

		player.gui.screen["ping_messages"].location = {x = element.location.x, y = element.location.y + 42}
	end
end

---@param message string
---@param from_player_name string
---@param filter_fn fun(player: LuaPlayer): boolean
local function possibly_do_pings(message, from_player_name, filter_fn)
	for name, _ in pairs(Functions.extract_possible_pings(message)) do
		local player = game.get_player(name)
		if player and filter_fn(player) then
			do_ping(from_player_name, player, message)
		end
	end
end

local function on_console_chat(event)
	--Share chat with spectator force
	if not event.message or not event.player_index then return end
	local player = game.players[event.player_index]
	local player_name = player.name
	local player_force_name = player.force.name
	local tag = player.tag
	if not tag then tag = "" end
	local color = player.chat_color

	local muted = Muted.is_muted(player_name)
	local mute_tag = ""
	if muted then
		mute_tag = "[muted] "
	end

	local msg = player_name .. tag .. " (" .. player_force_name .. "): ".. event.message
	possibly_do_pings(msg, player_name, function(ping_player) return player_force_name == ping_player.force.name end)
	if not muted and (player_force_name == "north" or player_force_name == "south") then
		Functions.print_message_to_players(game.forces.spectator.players, player_name, msg, color, do_ping)
	end

	if global.tournament_mode then return end

	--Skip messages that would spoil coordinates from spectators and don't send gps coord to discord
	local a, b = string.find(event.message, "gps=", 1, false)
	if a then return end

	local discord_msg = ""
	if muted then
		discord_msg = mute_tag
		Muted.print_muted_message(player)
	end
	if not muted and player_force_name == "spectator" then
		Functions.print_message_to_players(game.forces.north.players, player_name, msg, nil, do_ping)
		Functions.print_message_to_players(game.forces.south.players, player_name, msg, nil, do_ping)
	end

	discord_msg = discord_msg .. player_name .. " (" .. player_force_name .. "): ".. event.message
	Server.to_discord_player_chat(discord_msg)
end

local function on_console_command(event)
	local cmd = event.command
    if not event.player_index then return end
    local player = game.players[event.player_index]
    local param = event.parameters
    if cmd == "ignore" then
		-- verify in argument of command that there is no space, quote, semicolon, backtick, and that it's not just whitespace
		if param and not string.match(param, "[ '\";`]") and not param:match("^%s*$") then 
			if not global.ignore_lists[player.name] then
				global.ignore_lists[player.name] = {}
			end
			if not global.ignore_lists[player.name][param] then
				global.ignore_lists[player.name][param] = true
				player.print("You have ignored " .. param, {r = 0, g = 1, b = 1})
			else
				player.print("You are already ignoring " .. param, {r = 0, g = 1, b = 1})
			end
		else
			player.print("Invalid input. Make sure the name contains no spaces, quotes, semicolons, backticks, or any spaces.", {r = 1, g = 0, b = 0})
		end
    elseif cmd == "unignore" then 
		-- verify in argument of command that there is no space, quote, semicolon, backtick, and that it's not just whitespace, and that the player was someone ignored
		if param and not string.match(param, "[ '\";`]") and not param:match("^%s*$") and global.ignore_lists[player.name] then
			if global.ignore_lists[player.name][param] then
                global.ignore_lists[player.name][param] = nil
                player.print("You have unignored " .. param, {r = 0, g = 1, b = 1})
            else
                player.print("You are not currently ignoring " .. param, {r = 0, g = 1, b = 1})
            end
		else
			player.print("Invalid input. Make sure the name contains no spaces, quotes, semicolons, backticks, or any spaces.", {r = 1, g = 0, b = 0})
		end
	elseif cmd == "w" or cmd == "whisper" then
		-- split param into first word and rest of the message
		local to_player_name, rest_of_message = string.match(param, "^%s*(%S+)%s*(.*)")
		local to_player = game.get_player(to_player_name)
		if to_player then
			do_ping(player.name, to_player, player.name .. " (wisper): " .. rest_of_message)
			global.reply_target[to_player_name] = player.name
		end
	elseif cmd == "r" or cmd == "reply" then
		local to_player_name = global.reply_target[player.name]
		if to_player_name then
			local to_player = game.get_player(to_player_name)
			if to_player then
				do_ping(player.name, to_player, player.name .. " (wisper): " .. param)
			end
		end
	elseif cmd == "s" or cmd == "shout" then
		chatmsg = "[shout] " .. player.name .. " (" .. player.force.name .. "): " .. param
		possibly_do_pings(chatmsg, player.name, function(ping_player) return true end)
	end
end

local function on_built_entity(event)
	Functions.maybe_set_game_start_tick(event)
	Functions.no_landfill_by_untrusted_user(event, Session.get_trusted_table())
	Functions.no_turret_creep(event)
	Terrain.deny_enemy_side_ghosts(event)
	AiTargets.start_tracking(event.created_entity)
end

local function on_robot_built_entity(event)
	Functions.no_turret_creep(event)
	Terrain.deny_construction_bots(event)
	AiTargets.start_tracking(event.created_entity)
end

local function on_robot_built_tile(event)
	Terrain.deny_bot_landfill(event)
end

local function on_entity_died(event)
	local entity = event.entity
	if not entity.valid then return end
	if Ai.subtract_threat(entity) then Gui.refresh_threat() end
	if Functions.biters_landfill(entity) then return end
	Game_over.silo_death(event)
end

local function on_ai_command_completed(event)
	if not event.was_distracted then AiStrikes.step(event.unit_number, event.result) end
end

local function getTagOutpostName(pos)
	if pos < 0 then
		return autoTagWestOutpost
	else
		return autoTagEastOutpost
	end
end

local function hasOutpostTag(tagName)
	return (string.find(tagName, '%'..autoTagWestOutpost) or string.find(tagName, '%'..autoTagEastOutpost))
end

local function autotagging_outposters()
    for _, p in pairs(game.connected_players) do
		if (p.force.name == "north" or p.force.name == "south") then
			if math.abs(p.position.x) < autoTagDistance then
				if hasOutpostTag(p.tag) then
					p.tag = p.tag:gsub("%"..autoTagWestOutpost, "")
					p.tag = p.tag:gsub("%"..autoTagEastOutpost, "")
				end
			else
				if not hasOutpostTag(p.tag) then
					p.tag = p.tag .. getTagOutpostName(p.position.x)
				end
			end
		end
		
		if p.force.name == "spectator" and hasOutpostTag(p.tag) then
				p.tag = p.tag:gsub("%"..autoTagWestOutpost, "")
				p.tag = p.tag:gsub("%"..autoTagEastOutpost, "")
		end
	end
end

local function afk_kick(player)
	if player.afk_time > antiAfkTimeBeforeWarning and player.afk_time < antiAfkTimeBeforeEnabled then
		player.print('Please move within the next minute or you will be sent back to spectator island ! But even if you keep staying afk and sent back to spectator island, you will be able to join back to your position with your equipment')
	end
	if player.afk_time > antiAfkTimeBeforeEnabled then
		player.print('You were sent back to spectator island as you were afk for too long, you can still join to come back at your position with all your equipment')
		spectate(player,false,true)
	end
end

local function anti_afk_system()
    for _, player in pairs(game.forces.north.connected_players) do
		afk_kick(player)
	end
    for _, player in pairs(game.forces.south.connected_players) do
		afk_kick(player)
	end
end

local tick_minute_functions = {
	[300 * 1] = Ai.raise_evo,
	[300 * 3 + 30 * 0] = Ai.pre_main_attack,		-- setup for main_attack
	[300 * 3 + 30 * 1] = Ai.perform_main_attack,	-- call perform_main_attack 7 times on different ticks
	[300 * 3 + 30 * 2] = Ai.perform_main_attack,	-- some of these might do nothing (if there are no wave left)
	[300 * 3 + 30 * 3] = Ai.perform_main_attack,
	[300 * 3 + 30 * 4] = Ai.perform_main_attack,
	[300 * 3 + 30 * 5] = Ai.perform_main_attack,
	[300 * 3 + 30 * 6] = Ai.perform_main_attack,
	[300 * 3 + 30 * 7] = Ai.perform_main_attack,
	[300 * 3 + 30 * 8] = Ai.post_main_attack,
	[300 * 3 + 30 * 9] = autotagging_outposters,
	[300 * 4] = Ai.send_near_biters_to_silo,
	[300 * 4 + 30 * 1] = anti_afk_system,
}

local function on_tick()
	local tick = game.tick

	if tick % 60 == 0 then 
		global.bb_threat["north_biters"] = global.bb_threat["north_biters"] + global.bb_threat_income["north_biters"]
		global.bb_threat["south_biters"] = global.bb_threat["south_biters"] + global.bb_threat_income["south_biters"]
	end

	if (tick+11) % 300 == 0 then
		Gui.spy_fish()

		if global.bb_game_won_by_team then
			Game_over.reveal_map()
			Game_over.server_restart()
		end
	end

	if tick % 30 == 0 then	
		local key = tick % 3600
		if tick_minute_functions[key] then
			tick_minute_functions[key]()
		end
	end

	if (tick+5) % 180 == 0 then
		Gui.refresh()
		ResearchInfo.update_research_info_ui()
	end
end

local function on_marked_for_deconstruction(event)
	if not event.entity.valid then return end
	if not event.player_index then return end
	local force_name = game.get_player(event.player_index).force.name
	if event.entity.name == "fish" then event.entity.cancel_deconstruction(force_name) return end
	local half_river_width = bb_config.border_river_width / 2
	if (force_name == "north" and event.entity.position.y > half_river_width) or (force_name == "south" and event.entity.position.y < -half_river_width) then
		event.entity.cancel_deconstruction(force_name)
	end
end

local function on_player_built_tile(event)
	local player = game.players[event.player_index]
	if event.item ~= nil and event.item.name == "landfill" then
		Terrain.restrict_landfill(player.surface, player, event.tiles)
	end
end

local function on_chunk_generated(event)
	local surface = event.surface

	-- Check if we're out of init.
	if not surface or not surface.valid then return end

	-- Necessary check to ignore nauvis surface.
	if surface.name ~= global.bb_surface_name then return end

	-- Generate structures for north only.
	local pos = event.area.left_top
	if pos.y < 0 then
		Terrain.generate(event)
	end

	-- Request chunk for opposite side, maintain the lockstep.
	-- NOTE: There is still a window where user can place down a structure
	-- and it will be mirrored. However this window is so tiny - user would
	-- need to fly in god mode and spam entities in partially generated
	-- chunks.
	local req_pos = { pos.x + 16, -pos.y + 16 }
	surface.request_to_generate_chunks(req_pos, 0)

	-- Clone from north and south. NOTE: This WILL fire 2 times
	-- for each chunk due to asynchronus nature of this event.
	-- Both sides contain arbitary amount of chunks, some positions
	-- when inverted will be still in process of generation or not
	-- generated at all. It is important to perform 2 passes to make
	-- sure everything is cloned properly. Normally we would use mutex
	-- but this is not reliable in this environment.
	Mirror_terrain.clone(event)

	-- The game pregenerate tiles within a radius of 3 chunks from the generated chunk.
	-- Bites can use these tiles for pathing.
	-- This creates a problem that bites pathfinder can cross the river at the edge of the map.
	-- To prevent this, divide the north and south land by drawing a strip of water on these pregenerated tiles.
	if event.position.y >= 0 and event.position.y <= 3 then
		for x = -3, 3 do
			local chunk_pos = { x = event.position.x + x, y = 0 }
			if not surface.is_chunk_generated(chunk_pos) then
				Terrain.draw_water_for_river_ends(surface, chunk_pos)
			end
		end
	end

	-- add decorations only after the south part of the island is generated
	if event.position.y == 0 and event.position.x == 1 and global.bb_settings['new_year_island'] then
		Terrain.add_new_year_island_decorations(surface)
	end
end

local function on_entity_cloned(event)
	local source = event.source
	local destination = event.destination

	-- In case entity dies between clone and this event we
	-- have to ensure south doesn't get additional objects.
	if not source.valid then
		if destination.valid then
			destination.destroy()
		end

		return
	end

	Mirror_terrain.invert_entity(event)
end

local function on_area_cloned(event)
	local surface = event.destination_surface

	-- Check if we're out of init and not between surface hot-swap.
	if not surface or not surface.valid then return end

	-- Event is fired only for south side.
	Mirror_terrain.invert_tiles(event)
	Mirror_terrain.invert_decoratives(event)

	-- Check chunks around southen silo to remove water tiles under refined-concrete.
	-- Silo can be removed by picking bricks from under it in a situation where
	-- refined-concrete tiles were placed directly onto water tiles. This scenario does
	-- not appear for north as water is removed during silo generation.
	local position = event.destination_area.left_top
	if position.y >= 0 and position.y <= 192 and math.abs(position.x) <= 192 then
		Mirror_terrain.remove_hidden_tiles(event)
	end
end

local function on_rocket_launch_ordered(event)
	local vehicles = {
		["car"] = true,
		["tank"] = true,
		["locomotive"] = true,
		["cargo-wagon"] = true,
		["fluid-wagon"] = true,
		["spidertron"] = true,
	}
	local inventory = event.rocket.get_inventory(defines.inventory.fuel)
	local contents = inventory.get_contents()
	for name, _ in pairs(contents) do
		if vehicles[name] then
			inventory.clear()
		end
	end
end

local function clear_corpses(cmd)
	local player = game.player
        local trusted = Session.get_trusted_table()
        local param = tonumber(cmd.parameter)

        if not player or not player.valid then
            return
        end
        if param == nil then
            player.print('[ERROR] Must specify radius!', Color.fail)
            return
        end
        if not trusted[player.name] and not player.admin and param > 100 then
				player.print('[ERROR] Value is too big. Max radius is 100', Color.fail)
				return
        end
        if param < 0 then
            player.print('[ERROR] Value is too low.', Color.fail)
            return
        end
        if param > 500 then
            player.print('[ERROR] Value is too big.', Color.fail)
            return
        end

        local pos = player.position
        local radius = {{x = (pos.x + -param), y = (pos.y + -param)}, {x = (pos.x + param), y = (pos.y + param)}}
        for _, entity in pairs(player.surface.find_entities_filtered {area = radius, type = 'corpse'}) do
            if entity.corpse_expires then
                entity.destroy()
            end
        end
        player.print('Cleared biter-corpses.', Color.success)
end

local function on_init()
	Init.tables()
	Init.initial_setup()
	Init.playground_surface()
	Init.forces()
	Init.draw_structures()
	Init.load_spawn()
	Init.reveal_map()
end


local Event = require 'utils.event'
Event.add(defines.events.on_rocket_launch_ordered, on_rocket_launch_ordered)
Event.add(defines.events.on_area_cloned, on_area_cloned)
Event.add(defines.events.on_entity_cloned, on_entity_cloned)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_console_command, on_console_command)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_ai_command_completed, on_ai_command_completed)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_location_changed, on_gui_location_changed)
Event.add(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
Event.add(defines.events.on_player_built_tile, on_player_built_tile)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_research_finished, on_research_finished)
Event.add(defines.events.on_research_started, on_research_started)
Event.add(defines.events.on_research_reversed, on_research_reversed)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_robot_built_tile, on_robot_built_tile)
Event.add(defines.events.on_tick, on_tick)
Event.on_init(on_init)

commands.add_command('clear-corpses', 'Clears all the biter corpses..',
		     clear_corpses)
