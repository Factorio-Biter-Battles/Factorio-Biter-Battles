---@alias PlayerName string The player's username

local Global = require 'utils.global'
local Event = require 'utils.event'
local Server = require 'utils.server'
local Functions = require 'maps.biter_battles_v2.functions'
local Blueprint = require 'maps.biter_battles_v2.blueprints'

local Public = {}

--- @class PlayerData
--- @field jailed boolean
--- @field permission_group_id? uint
--- @field fallback_position? MapPosition
--- @field force? string
--- @field initiator? PlayerName
--- @field reason? string

--- @type {[PlayerName]: PlayerData}
local jail_data = {}

--- Reset fallback data of jailed players,
--- so that they fall into spectator when freed after map restart
Public.reset_fallback_data = function()
	for _, v in pairs(jail_data) do
		v.permission_group_id = nil
		v.fallback_position = nil
		v.force = nil
	end
end

---Get jailed players by translating force members into table
---@return {[PlayerName] : true}
function Public.get_jailed_table()
    local players = game.forces["jailed"]
    local t = {}
    for _, p in pairs(players) do
        t[p.name] = true
    end
    return t
end

---@param player LuaPlayer player to be jailed
---@param initiator LuaPlayer player initiating the action
---@param reason string reason for jail
function Public.jail(player, initiator, reason)
	if player.force == "jailed" then
		initiator.print(player.name .. " is already jailed.")
		return
	end
	if global.player_vote.active and global.player_vote.target == player.name and global.player_vote.action == "jail" then
		initiator.print("Please wait for the vote to finish.")
		return
	end
	jail_data[player.name] = {
		jailed = true,
		fallback_position = player.position,
		permission_group_id = player.permission_group.group_id,
		force = player.force.name,
		initiator = initiator.name,
		reason = reason
	}
    local gulag = game.get_surface("gulag")
    player.teleport(gulag.find_non_colliding_position("character", {0, 0}, 128, 1), gulag)
    game.permissions.get_group("gulag").add_player(player)
	player.force = "jailed"
	local message = table.concat({player.name, " has been jailed by ", initiator.name, ". Reason: ", reason})
	game.print(message)
	Server.to_discord_embed(message)
end

---@param player LuaPlayer player to be freed
---@param initiator LuaPlayer player initiating the action
---@param reason string reason for free
function Public.free(player, initiator, reason)
	if not player.force == "jailed" then
		initiator.print(player.name .. " isn't jailed.")
		return
	end
	local data = jail_data[player.name]
	if global.player_vote.active and global.player_vote.target == player.name and global.player_vote.action == "free" then
		initiator.print("Please wait for the vote to finish.")
		return
	end
    local surface = game.get_surface(global.bb_surface_name)
	if data.fallback_position then
		player.teleport(surface.find_non_colliding_position("character", data.fallback_position, 128, 1), surface)
		game.permissions.get_group(data.permission_group_id).add_player(player)
		player.force = data.force
	else
		Functions.init_player(player)
	end
	local message = table.concat({"", player.name, " has been freed by ", initiator.name, ". Reason: ", reason})
	game.print(message)
	Server.to_discord_embed(message)
	jail_data[player.name] = nil
end

local valid_commands = { jail = Public.jail, free = Public.free }

local function on_console_command(event)
	if not valid_commands[event.command] then return end

	local player = game.get_player(event.player_index)
	if not player or not player.valid then return end

    if not player.admin then return end -- non-admin votes to be processed in player_vote.lua

	if #event.parameters <= 0 then
		player.print("Invalid parameters.")
		return
	end
	local t = {}
	for i in string.gmatch(event.parameters, '%S+') do
		t[#t + 1] = i
	end

	local suspect = game.get_player(t[1])
	if not suspect or not suspect.valid then
		player.print("Invalid suspect name.")
		return
	end
	table.remove(t, 1)

	local reason = table.concat(t, " ")
	if not reason then
		player.print("No valid reason was given.")
		return
	end
	if string.len(reason) <= 10 then
		player.print("Reason is too short.")
		return
	end

	valid_commands[event.command](suspect, player, reason)
end

local function info(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end
    
	if not event.parameters then
        player.print("Invalid parameters.")
        return
    end
    local griefer = game.get_player(event.parameters)
    if not griefer or not griefer.valid then
        player.print("Invalid name.")
        return
    end
	local message = {}
	local data = jail_data[griefer.name]
	if data then
		message = {"", "---JAIL DATA---\n", griefer.name, " is jailed by ", data.initiator " for ", data.reason, "\n---JAIL DATA---"}
	else
		message = {"", "---JAIL DATA---\n", griefer.name, " isn't jailed", "\n---JAIL DATA---"}
	end
	player.print(message)
end

---@param surface LuaSurface
local function createTrollSong(surface)
	local position = {x=6, y=0}
	local bp_entity = surface.create_entity{name = 'item-on-ground', position= position, stack = 'blueprint'}
	bp_entity.stack.import_stack(Blueprint.get_blueprint("jail_song"))
	local bpInfo = {surface = surface, force = "jailed", position = position, force_build = 'true'}
	local bpResult = bp_entity.stack.build_blueprint(bpInfo)
	bp_entity.destroy()
	for k, v in pairs(bpResult) do
		if k == 27 then
			v.get_control_behavior().enabled = false
		end
		if k == 28 then
			v.get_control_behavior().enabled = true
		end
		v.revive()
	end
	local songBuildings = surface.find_entities_filtered{area={{position.x-11, position.y-23}, {position.x+12, position.y+25}}, name = {
		"constant-combinator",
		"decider-combinator", 
		"substation",
		"programmable-speaker",
		"arithmetic-combinator",
		"electric-energy-interface"
	}}
	for _, v in pairs(songBuildings) do
		v.minable = false
		v.destructible = false
		v.operable = false
	end
end

--- Create surface, permission group, force, and song
local function on_init()
	local walls = {}
    local tiles = {}
	local surface
	pcall(
        function()
            local settings = {
				autoplace_controls = {
					['coal'] = {frequency = 23, size = 3, richness = 3},
					['stone'] = {frequency = 20, size = 3, richness = 3},
					['copper-ore'] = {frequency = 25, size = 3, richness = 3},
					['iron-ore'] = {frequency = 35, size = 3, richness = 3},
					['uranium-ore'] = {frequency = 20, size = 3, richness = 3},
					['crude-oil'] = {frequency = 80, size = 3, richness = 1},
					['trees'] = {frequency = 0.75, size = 2, richness = 0.1},
					['enemy-base'] = {frequency = 15, size = 0, richness = 1}
				},
				cliff_settings = {cliff_elevation_0 = 1024, cliff_elevation_interval = 10, name = 'cliff'},
				height = 64,
				width = 256,
				peaceful_mode = false,
				seed = 1337,
				starting_area = 'very-low',
				starting_points = {{x = 0, y = 0}},
				terrain_segmentation = 'normal',
				water = 'normal'
			}
			surface = game.create_surface('gulag',settings)
		end
	)
	if not surface then
		surface = game.create_surface('gulag', {width = 40, height = 40})
	end
	surface.always_day = true
	surface.request_to_generate_chunks({0, 0}, 9)
	surface.force_generate_chunk_requests()
	local area = {left_top = {x = -128, y = -32}, right_bottom = {x = 128, y = 32}}
	for x = area.left_top.x, area.right_bottom.x, 1 do
		for y = area.left_top.y, area.right_bottom.y, 1 do
			tiles[#tiles + 1] = {name = 'black-refined-concrete', position = {x = x, y = y}}
			if x == area.left_top.x or x == area.right_bottom.x or y == area.left_top.y or y == area.right_bottom.y then
				walls[#walls + 1] = {name = 'stone-wall', force = 'neutral', position = {x = x, y = y}}
			end
		end
	end
	surface.set_tiles(tiles)
	for _, entity in pairs(walls) do
		local e = surface.create_entity(entity)
		e.destructible = false
		e.minable = false
	end

	rendering.draw_text{
		text = 'The pit of despair ☹',
		surface = surface,
		target = {0, -50},
		color = {r = 0.98, g = 0.66, b = 0.22},
		scale = 10,
		font = 'heading-1',
		alignment = 'center',
		scale_with_zoom = false
    }
	
	local p = game.permissions.create_group("gulag")
	for k, v in pairs(defines.input_action) do
		p.set_allows_action(v, false)
	end
	p.set_allows_action(defines.input_action.write_to_console, true)

	game.create_force("jailed")

	createTrollSong(surface)
end

commands.add_command(
    'jail',
    'Sends the player to jail! Valid arguments are:\n/jail <LuaPlayer> <reason>',
    function()
        return
    end
)

commands.add_command(
    'free',
    'Brings back the player from jail.',
    function()
        return
    end
)

commands.add_command(
    'info',
    'Displays jail info about the player',
	function(event)
		info(event)
	end
)
Event.add(defines.events.on_console_command, on_console_command)
Event.on_init(on_init)

global.jail_data = jail_data 
return Public