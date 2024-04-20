local AiTargets = require 'maps.biter_battles_v2.ai_targets'
local Functions = require "maps.biter_battles_v2.functions"
local Gui = require "maps.biter_battles_v2.gui"
local Init = require "maps.biter_battles_v2.init"
local Score = require "comfy_panel.score"
local Server = require 'utils.server'
local Special_games = require 'comfy_panel.special_games'
local Captain_special = require 'comfy_panel.special_games.captain'
local Event = require 'utils.event'
local Tables = require 'maps.biter_battles_v2.tables'
local Token = require 'utils.token'
local Task = require 'utils.task'
local math_random = math.random
local gui_style = require 'utils.utils'.gui_style

local Public = {}

local gui_values = {
    ["north"] = {color1 = {r = 0.55, g = 0.55, b = 0.99}},
    ["south"] = {color1 = {r = 0.99, g = 0.33, b = 0.33}}
}

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math.random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

function Public.reveal_map()
    for _, f in pairs({"north", "south", "player", "spectator"}) do
        local r = 768
        game.forces[f].chart(game.surfaces[global.bb_surface_name],
                             {{r * -1, r * -1}, {r, r}})
    end
end

local function create_victory_gui(player)
    local values = gui_values[global.bb_game_won_by_team]
    local frame = player.gui.left.add {
        type = "frame",
        name = "bb_victory_gui",
        direction = "vertical",
        caption = Functions.team_name(global.bb_game_won_by_team) .. " won!"
    }
    frame.style.font = "heading-1"
    frame.style.font_color = values.color1

    local l = frame.add {type = "label", caption = global.victory_time}
    l.style.font = "heading-2"
    l.style.font_color = {r = 0.77, g = 0.77, b = 0.77}
end

local function silo_kaboom(entity)
    local surface = entity.surface
    local center_position = entity.position
    local force = entity.force
    surface.create_entity({
        name = "atomic-rocket",
        position = center_position,
        force = force,
        source = center_position,
        target = center_position,
        max_range = 1,
        speed = 0.1
    })

    local drops = {}
    for x = -32, 32, 1 do
        for y = -32, 32, 1 do
            local p = {x = center_position.x + x, y = center_position.y + y}
            local distance_to_silo = math.sqrt(
                                         (center_position.x - p.x) ^ 2 +
                                             (center_position.y - p.y) ^ 2)
            local count = math.floor((32 - distance_to_silo * 1.2) * 0.28)
            if distance_to_silo < 32 and count > 0 then
                table.insert(drops, {p, count})
            end
        end
    end
    for _, drop in pairs(drops) do
        for _ = 1, drop[2], 1 do
            entity.surface.spill_item_stack(
                {
                    drop[1].x + math.random(0, 9) * 0.1,
                    drop[1].y + math.random(0, 9) * 0.1
                }, {name = "raw-fish", count = 1}, false, nil, true)
        end
    end
end

local function get_sorted_list(column_name, score_list)
    for _ = 1, #score_list, 1 do
        for y = 1, #score_list, 1 do
            if not score_list[y + 1] then break end
            if score_list[y][column_name] < score_list[y + 1][column_name] then
                local key = score_list[y]
                score_list[y] = score_list[y + 1]
                score_list[y + 1] = key
            end
        end
    end
    return score_list
end

local function get_mvps(force)
    local get_score = Score.get_table().score_table
    if not get_score[force] then return false end
    local score = get_score[force]
    local score_list = {}
    for _, p in pairs(game.players) do
        if score.players[p.name] then
            local killscore = 0
            if score.players[p.name].killscore then
                killscore = score.players[p.name].killscore
            end
            local deaths = 0
            if score.players[p.name].deaths then
                deaths = score.players[p.name].deaths
            end
            local built_entities = 0
            if score.players[p.name].built_entities then
                built_entities = score.players[p.name].built_entities
            end
            local mined_entities = 0
            if score.players[p.name].mined_entities then
                mined_entities = score.players[p.name].mined_entities
            end
            table.insert(score_list, {
                name = p.name,
                killscore = killscore,
                deaths = deaths,
                built_entities = built_entities,
                mined_entities = mined_entities
            })
        end
    end
    local mvp = {}
    score_list = get_sorted_list("killscore", score_list)
    mvp.killscore = {name = score_list[1].name, score = score_list[1].killscore}
    score_list = get_sorted_list("deaths", score_list)
    mvp.deaths = {name = score_list[1].name, score = score_list[1].deaths}
    score_list = get_sorted_list("built_entities", score_list)
    mvp.built_entities = {
        name = score_list[1].name,
        score = score_list[1].built_entities
    }
    return mvp
end

local function show_mvps(player)
    local get_score = Score.get_table().score_table
    if not get_score then return end
    if player.gui.left["mvps"] then return end
    local frame = player.gui.left.add({
        type = "frame",
        name = "mvps",
        direction = "vertical"
    })
    local l = frame.add({type = "label", caption = "MVPs - North:"})
    l.style.font = "default-listbox"
    l.style.font_color = {r = 0.55, g = 0.55, b = 0.99}

    local t = frame.add({type = "table", column_count = 2})
    local mvp = get_mvps("north")
    if mvp then

        local l = t.add({type = "label", caption = "Defender >> "})
        l.style.font = "default-listbox"
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({
            type = "label",
            caption = mvp.killscore.name .. " with a score of " ..
                mvp.killscore.score
        })
        l.style.font = "default-bold"
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = "label", caption = "Builder >> "})
        l.style.font = "default-listbox"
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({
            type = "label",
            caption = mvp.built_entities.name .. " built " ..
                mvp.built_entities.score .. " things"
        })
        l.style.font = "default-bold"
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = "label", caption = "Deaths >> "})
        l.style.font = "default-listbox"
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({
            type = "label",
            caption = mvp.deaths.name .. " died " .. mvp.deaths.score ..
                " times"
        })
        l.style.font = "default-bold"
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        if not global.results_sent_north then
            local result = {}
            table.insert(result, 'NORTH: \\n')
            table.insert(result, 'MVP Defender: \\n')
            table.insert(result, mvp.killscore.name .. " with a score of " ..
                             mvp.killscore.score .. "\\n")
            table.insert(result, '\\n')
            table.insert(result, 'MVP Builder: \\n')
            table.insert(result,
                         mvp.built_entities.name .. " built " ..
                             mvp.built_entities.score .. " things\\n")
            table.insert(result, '\\n')
            table.insert(result, 'MVP Deaths: \\n')
            table.insert(result,
                         mvp.deaths.name .. " died " .. mvp.deaths.score ..
                             " times")
            local message = table.concat(result)
            Server.to_discord_embed(message)
            global.results_sent_north = true
        end
    end

    local l = frame.add({type = "label", caption = "MVPs - South:"})
    l.style.font = "default-listbox"
    l.style.font_color = {r = 0.99, g = 0.33, b = 0.33}

    local t = frame.add({type = "table", column_count = 2})
    local mvp = get_mvps("south")
    if mvp then
        local l = t.add({type = "label", caption = "Defender >> "})
        l.style.font = "default-listbox"
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({
            type = "label",
            caption = mvp.killscore.name .. " with a score of " ..
                mvp.killscore.score
        })
        l.style.font = "default-bold"
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = "label", caption = "Builder >> "})
        l.style.font = "default-listbox"
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({
            type = "label",
            caption = mvp.built_entities.name .. " built " ..
                mvp.built_entities.score .. " things"
        })
        l.style.font = "default-bold"
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        local l = t.add({type = "label", caption = "Deaths >> "})
        l.style.font = "default-listbox"
        l.style.font_color = {r = 0.22, g = 0.77, b = 0.44}
        local l = t.add({
            type = "label",
            caption = mvp.deaths.name .. " died " .. mvp.deaths.score ..
                " times"
        })
        l.style.font = "default-bold"
        l.style.font_color = {r = 0.33, g = 0.66, b = 0.9}

        if not global.results_sent_south then
            local result = {}
            table.insert(result, 'SOUTH: \\n')
            table.insert(result, 'MVP Defender: \\n')
            table.insert(result, mvp.killscore.name .. " with a score of " ..
                             mvp.killscore.score .. "\\n")
            table.insert(result, '\\n')
            table.insert(result, 'MVP Builder: \\n')
            table.insert(result,
                         mvp.built_entities.name .. " built " ..
                             mvp.built_entities.score .. " things\\n")
            table.insert(result, '\\n')
            table.insert(result, 'MVP Deaths: \\n')
            table.insert(result,
                         mvp.deaths.name .. " died " .. mvp.deaths.score ..
                             " times")
            local message = table.concat(result)
            Server.to_discord_embed(message)
            global.results_sent_south = true
        end
    end
end

local enemy_team_of = {["north"] = "south", ["south"] = "north"}

function Public.server_restart()
    if not global.server_restart_timer then return end
    global.server_restart_timer = global.server_restart_timer - 5

    if global.server_restart_timer <= 0 then
        if global.restart then
            if not global.announced_message then
                local message =
                    'Soft-reset is disabled! Server will restart from scenario to load new changes.'
                game.print(message, {r = 0.22, g = 0.88, b = 0.22})
                Server.to_discord_bold(table.concat {'*** ', message, ' ***'})
                Server.start_scenario('Biter_Battles')
                global.announced_message = true
                return
            end
        end
        if global.shutdown then
            if not global.announced_message then
                local message =
                    'Soft-reset is disabled! Server will shutdown. Most likely because of updates.'
                game.print(message, {r = 0.22, g = 0.88, b = 0.22})
                Server.to_discord_bold(table.concat {'*** ', message, ' ***'})
                Server.stop_scenario()
                global.announced_message = true
                return
            end
        end
        game.print("Map is restarting!", {r = 0.22, g = 0.88, b = 0.22})
        local message = 'Map is restarting! '
        Server.to_discord_bold(table.concat {'*** ', message, ' ***'})

        Public.generate_new_map()
        return
    end
    if global.server_restart_timer % 30 == 0 then
        game.print("Map will restart in " .. global.server_restart_timer ..
                       " seconds!", {r = 0.22, g = 0.88, b = 0.22})
        if global.server_restart_timer / 30 == 1 then
            game.print("Good luck with your next match!", {r=0.98, g=0.66, b=0.22})
        end
    end
end

local function set_victory_time()
    local tick = Functions.get_ticks_since_game_start()
    local minutes = tick % 216000
    local hours = tick - minutes
    minutes = math.floor(minutes / 3600)
    hours = math.floor(hours / 216000)
    if hours > 0 then
        hours = hours .. " hours and "
    else
        hours = ""
    end
    global.victory_time = "Time - " .. hours
    global.victory_time = global.victory_time .. minutes
    global.victory_time = global.victory_time .. " minutes"
end

local function freeze_all_biters(surface)
    for _, e in pairs(surface.find_entities_filtered({force = "north_biters"})) do
        e.active = false
    end
    for _, e in pairs(surface.find_entities_filtered({force = "south_biters"})) do
        e.active = false
    end
    for _, e in pairs(surface.find_entities_filtered({force = "north_biters_boss"})) do
        e.active = false
    end
    for _, e in pairs(surface.find_entities_filtered({force = "south_biters_boss"})) do
        e.active = false
    end
end

local function biter_killed_the_silo(event)
	local force = event.force
	if force ~= nil then
		return string.find(event.force.name, "_biters")
	end

	local cause = event.cause
	if cause ~= nil then
		return (cause.valid and cause.type == 'unit')
	end

	log("Could not determine what destroyed the silo")
	return false
end

local function respawn_silo(event)
	local entity = event.entity
	local surface = entity.surface
	if surface == nil or not surface.valid then
		log("Surface " .. global.bb_surface_name .. " invalid - cannot respawn silo")
		return
	end

	local force_name = entity.force.name
	-- Has to be created instead of clone otherwise it will be moved to south.
	entity = surface.create_entity {
		name = entity.name,
		position = entity.position,
		surface = surface,
		force = force_name,
		create_build_effect_smoke = false,
	}
	entity.minable = false
	entity.health = 5
	global.rocket_silo[force_name] = entity
	AiTargets.start_tracking(entity)
end

function log_to_db(message,appendBool)
	game.write_file('logToDBgameResult',message,appendBool,0)
	
end
function Public.silo_death(event)
    local entity = event.entity
    if not entity.valid then return end
    if entity.name ~= "rocket-silo" then return end
    if global.bb_game_won_by_team then return end
    if entity == global.rocket_silo.south or entity == global.rocket_silo.north then

        -- Respawn Silo in case of friendly fire
	if not biter_killed_the_silo(event) then
	    respawn_silo(event)
            return
        end

        global.bb_game_won_by_team = enemy_team_of[entity.force.name]

        set_victory_time()
		north_players = "NORTH PLAYERS: \\n"
		south_players = "SOUTH PLAYERS: \\n"
		
        for _, player in pairs(game.connected_players) do
            player.play_sound {path = "utility/game_won", volume_modifier = 1}
            if player.gui.left["bb_main_gui"] then
                player.gui.left["bb_main_gui"].visible = false
            end
            create_victory_gui(player)
			show_mvps(player)
			if (player.force.name == "south") then
				south_players = south_players .. player.name .. "   "
			elseif (player.force.name == "north") then
				north_players = north_players .. player.name .. "   "
			end
        end

        global.spy_fish_timeout["north"] = game.tick + 999999
        global.spy_fish_timeout["south"] = game.tick + 999999
        global.server_restart_timer = 150

        game.speed = 1
		
        north_evo = math.floor(1000 * global.bb_evolution["north_biters"]) * 0.1
        north_threat = math.floor(global.bb_threat["north_biters"])
        south_evo = math.floor(1000 * global.bb_evolution["south_biters"]) * 0.1
        south_threat = math.floor(global.bb_threat["south_biters"])

		discord_message = "*** Team " .. global.bb_game_won_by_team .. " has won! ***" .. "\\n" ..
							global.victory_time .. "\\n\\n" .. 
							"North Evo: " .. north_evo .. "%\\n" ..
                            "North Threat: " .. north_threat .. "\\n\\n" ..
                            "South Evo: " .. south_evo .. "%\\n" ..
                            "South Threat: " .. south_threat .. "\\n\\n" ..
                            north_players .. "\\n\\n" .. south_players

        Server.to_discord_embed(discord_message)

        global.results_sent_south = false
        global.results_sent_north = false
        silo_kaboom(entity)

        freeze_all_biters(entity.surface)
		if global.active_special_games["captain_mode"] and not global.special_games_variables["captain_mode"]["prepaPhase"] then 
			game.print("Updating logs for the game")
			Server.send_special_game_state('[CAPTAIN-SPECIAL]')
			log_to_db('>Game has ended\n',false)
			log_to_db('[RefereeName]'..global.special_games_variables["captain_mode"]["stats"]["InitialReferee"]..'\n',true)
			log_to_db('[CaptainNorth]'..global.special_games_variables["captain_mode"]["stats"]["NorthInitialCaptain"]..'\n',true)
			log_to_db('[CaptainSouth]'..global.special_games_variables["captain_mode"]["stats"]["SouthInitialCaptain"]..'\n',true)
			local listPicks = table.concat(global.special_games_variables["captain_mode"]["stats"]["northPicks"],";")
			log_to_db('[NorthTeam]'..listPicks..'\n',true)
			listPicks = table.concat(global.special_games_variables["captain_mode"]["stats"]["southPicks"],";")
			log_to_db('[SouthTeam]'..listPicks..'\n',true)
			log_to_db('[Gamelength]'..Functions.get_ticks_since_game_start()..'\n',true)
			log_to_db('[StartTick]'..global.special_games_variables["captain_mode"]["stats"]["tickGameStarting"]..'\n',true)
			log_to_db('[WinnerTeam]'..global.bb_game_won_by_team..'\n',true)
			log_to_db('[ExtraInfo]'..global.special_games_variables["captain_mode"]["stats"]["extrainfo"]..'\n',true)
			log_to_db('[SpecialEnabled]'..global.special_games_variables["captain_mode"]["stats"]["specialEnabled"]..'\n',true)
			for _, player in pairs(game.players) do
				if player.connected and (player.force.name == "north" or player.force.name == "south") then
					Captain_special.captain_log_end_time_player(player)
				end
				if global.special_games_variables["captain_mode"]["stats"]["playerPlaytimes"][player.name] ~= nil then
					log_to_db('[Playtime]['..player.name..']'..global.special_games_variables["captain_mode"]["stats"]["playerPlaytimes"][player.name]..'\n',true)
				end
			end
			log_to_db('>End of log',true)
		end
    end
end

local function chat_with_everyone(event)
    if not global.server_restart_timer then return end
    if not event.message then return end
    if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    local enemy = Tables.enemy_team_of[player.force.name]
    if not enemy then return end
    local message = player.name .."[auto-shout]: " .. event.message
    game.forces[enemy].print(message, player.chat_color)
end

local function draw_reroll_gui(player)
    if player.gui.top.reroll_frame then return end
    local f = player.gui.top.add{type = "frame", name = "reroll_frame"}
    gui_style(f, {height = 38, padding = 0})

    local t = f.add{type = "table", name = "reroll_table", column_count = 3, vertical_centering = true}
    local l = t.add{type = "label", caption = "Reroll map?\t" .. global.reroll_time_left .. "s"}
    gui_style(l, {font = "heading-2", font_color = {r = 0.88, g = 0.55, b = 0.11}, width = 105})

    local b = t.add { type = "sprite-button", caption = "Yes", name = "reroll_yes" }
    gui_style(b, {width = 50, height = 28 , font = "heading-2", font_color = {r = 0.1, g = 0.9, b = 0.0}} )

    b = t.add { type = "sprite-button", caption = "No", name = "reroll_no" }
    gui_style(b, {width = 50, height = 28 , font = "heading-2", font_color = {r = 0.9, g = 0.1, b = 0.1}} )
end

local reroll_buttons_token = Token.register(
    -- create buttons for joining players
    function(event)
        local player = game.get_player(event.player_index)
        draw_reroll_gui(player)
    end
)

local function stop_map_reroll()
    global.reroll_time_left = 0
    -- disable reroll buttons creation for joining players
    Event.remove_removable(defines.events.on_player_joined_game, reroll_buttons_token)
    -- remove existing buttons
    for _, player in pairs(game.players) do
        if player.gui.top.reroll_frame then
            player.gui.top.reroll_frame.destroy()
        end
    end
end

local decrement_timer_token = Token.get_counter() + 1 -- predict what the token will look like
decrement_timer_token = Token.register(
    function()
        if not global.bb_settings.map_reroll then
            stop_map_reroll()
            return
        end

        global.reroll_time_left = global.reroll_time_left - 1
        if global.reroll_time_left > 0 then
            for _, player in pairs(game.connected_players) do
                if player.gui.top.reroll_frame ~= nil then
                    player.gui.top.reroll_frame.reroll_table.children[1].caption = "Reroll map?\t" .. global.reroll_time_left .. "s"
                end
            end

            Task.set_timeout_in_ticks(60, decrement_timer_token)
        else
            stop_map_reroll()
            -- count votes
            local total_votes = table.size(global.reroll_map_voting)
            local result = 0
            if total_votes > 0 then
                for _, vote in pairs(global.reroll_map_voting) do
                    result = result + vote
                end
                result = math.floor( 100*result / total_votes )
                if result >= 75 then
                    game.print("Vote to reload the map has succeeded (" .. result .. "%)")
                    game.print("Map is being rerolled!", {r = 0.22, g = 0.88, b = 0.22})
                    Public.generate_new_map()
                    return
                end
            end
            game.print("Vote to reload the map has failed (" .. result .. "%)")
        end
    end
)

local function start_map_reroll()
    if global.bb_settings.map_reroll then
        if not global.reroll_time_left or global.reroll_time_left <= 0 then
            Task.set_timeout_in_ticks(60, decrement_timer_token)
            Event.add_removable(defines.events.on_player_joined_game, reroll_buttons_token)
        end
        global.reroll_time_left = global.reroll_time_limit / 60
        for _, player in pairs(game.connected_players) do
            draw_reroll_gui(player)
        end
    end
end

function Public.generate_new_map()
    game.speed = 1
    local prev_surface = global.bb_surface_name
    Special_games.reset_special_games()
    Init.tables()
    Init.playground_surface()
    Init.forces()
    Init.draw_structures()
    Gui.reset_tables_gui()
    Init.load_spawn()
    Init.reveal_map()
    for _, player in pairs(game.players) do
        Functions.init_player(player)
        for _, e in pairs(player.gui.left.children) do
            e.destroy()
        end
        if player.gui.top.suspend_frame then player.gui.top.suspend_frame.destroy() end
        Gui.create_main_gui(player)
    end
    game.reset_time_played()
    global.server_restart_timer = nil
    game.delete_surface(prev_surface)
    start_map_reroll()
end

Event.add(defines.events.on_console_chat, chat_with_everyone)
return Public
