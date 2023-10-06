local Global = require 'utils.global'
local Session = require 'utils.datastore.session_data'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Event = require 'utils.event'
local Server = require 'utils.server'

local vote_duration = 30 ---@type uint in seconds

--- @type { LuaPlayer.name: {admin: boolean, action: "jail"|"free", initiator: string, reason: string, voters?: {yes: string[], no: string[]} } }
local history = {}

local vote_frame_size = {x = 250, y = 50}
local Public = {}

--- @type {[PlayerName]: {permission_group_id: uint, fallback_position: MapPosition}}
Public.player_data = {}

---Get jailed players by translating permission group members into table
---@return {string : true}
function Public.get_jailed_table()
    local players = game.permissions.get_group("gulag").players
    local t = {}
    for _, p in pairs(players) do
        t[p.name] = true
    end
    return t
end


---@param griefer LuaPlayer whose history to print
---@param player? LuaPlayer to whom print
local function print_history(griefer, player)
    local data = history[griefer.name]
	local message
    if data then
        message = {
            griefer.name, " has been ", data.action, " by ", data.initiator, "(", (data.admin and "admin") or ("vote"),
            ")\n",
            "Reason:\n",
            data.reason or "-"
        }
        if not data.admin then
            table.insert(message, {
                "For:\n",
                table.concat(data.voters.yes, ", "),
                "\nAgainst:\n",
                table.concat(data.voters.no, ", ")
            })
        end
    else
        message = { griefer.name, " has clear in-game record. Check discord for " }
    end
	message = table.concat(message)
	if player then
		player.print(message)
	else
    	game.print(message)
		Server.to_discord_embed(message)
	end
end

---@param player LuaPlayer player to be jailed
---@param initiator LuaPlayer player initiating the action
---@param reason string reason for jail
---@param voters? {yes:table<string>, no:table<string>} players who voted for and against
function Public.jail(player, initiator, reason, voters)
    local gulag = game.get_surface("gulag")
    player.teleport(gulag.find_non_colliding_position("character", {0, 0}, 128, 1), gulag)
    game.permissions.get_group("gulag").add_player(player)
	history[player.name] = { admin = initiator.admin, action = "jail", initiator = initiator.name, reason = reason, voters = voters }
	print_history(player)
end

---@param player LuaPlayer player to be freed
---@param initiator LuaPlayer player initiating the action
---@param reason string reason for free
---@param voters? {yes:table<string>, no:table<string>} players who voted for and against
 function Public.free(player, initiator, reason, voters)
    local data = Public.player_data[player.name]
    local surface = game.get_surface(global.bb_surface_name)
    player.teleport(surface.find_non_colliding_position("character", data.fallback_position, 128, 1), surface)
    game.permissions.get_group(data.permission_group_id).add_player(player)
    history[player.name] = { admin = initiator.admin, action = "free", initiator = initiator.name, reason = reason, voters = voters }
	print_history(player)
end
local valid_commands = { jail = Public.jail, free = Public.free }

local function on_console_command(event)
	if not valid_commands[event.command] then return end

	local player = game.get_player(event.player_index)
	if not player or not player.valid then return end

    if not player.admin then
		if not Session.get_trusted_table()[player.name] then
            player.print("Only trusted players can run this command.")
            return
        end

        if vote.active then
            player.print("Wait for the current vote to finish.")
            return
        end

		if global.server_restart_timer and global.server_restart_timer <= vote_duration then
			player.print("Wait for map restart.")
		end
    end

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

	if player.admin then
		valid_commands[event.command](suspect, player, reason)
	else
		start_vote(event.command, player, suspect, reason)
	end
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
	print_history(griefer, player)
end

--- Create surface and permission group
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

return Public