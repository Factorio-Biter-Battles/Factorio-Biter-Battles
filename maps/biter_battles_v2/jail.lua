local Global = require 'utils.global'
local Session = require 'utils.datastore.session_data'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Event = require 'utils.event'
local Server = require 'utils.server'

local vote_duration = 30 ---@type uint in seconds
---@type {active: boolean, action: "jail"|"free", initiator: string, suspect: string, reason: string, yes: {string: true}, no: {string: true}, timer: uint, result: string }
local vote = {}

--- @type {string: {permission_group_id: uint, fallback_position: MapPosition}}
local player_data = {}

--- @type { LuaPlayer.name: {admin: boolean, action: "jail"|"free", initiator: string, reason: string, voters?: {yes: string[], no: string[]} } }
local history = {}

local vote_frame_size = {x = 250, y = 50}

---comments
---@param griefer LuaPlayer whose history to print
---@param player? LuaPlayer to whom print
local function print_history(griefer, player)
    local data = history[griefer.name]
	local message
	if data then
		message = {
			"",
			griefer.name, "has been ", data.action, "by ", data.initiator, "(", (data.admin and "admin") or ("vote"),")\n"
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
		message = griefer.name .. " has clear in-game record. Check discord for "
	end
	if player then
		player.print(message)
	else
    	game.print(message)
		Server.to_discord_embed(message)
	end
end

---@param player LuaPlayer
---@param initiator LuaPlayer
---@param reason string
---@param voters? {yes:table<string>, no:table<string>}
local function jail(player, initiator, reason, voters)
    local gulag = game.get_surface("gulag")
    player.teleport(gulag.find_non_colliding_position("character", {0, 0}, 128, 1), gulag)
    game.permissions.get_group("gulag").add_player(player)
	history[player.name] = { admin = initiator.admin, action = "jail", initiator = initiator.name, reason = reason, voters = voters }
	print_history(player)
end

---@param player LuaPlayer
---@param initiator LuaPlayer
---@param reason string
---@param voters? {yes:table<string>, no:table<string>}
local function free(player, initiator, reason, voters)
    local data = player_data[player.name]
    local surface = game.get_surface(global.bb_surface_name)
    player.teleport(surface.find_non_colliding_position("character", data.fallback_position, 128, 1), surface)
    game.permissions.get_group(data.permission_group_id).add_player(player)
    history[player.name] = { admin = initiator.admin, action = "free", initiator = initiator.name, reason = reason, voters = voters }
	print_history(player)
end
local valid_commands = { jail = jail, free = free }

--- Updates counters on the vote buttons
local function update_buttons()
	local yes_caption = {"", "Yes (", table.size(vote.yes), ")"}
	local no_caption = {"", "No (", table.size(vote.no), ")"}
	for _, p in pairs(game.connected_players) do
		if p.gui.screen.vote_frame then
			p.gui.screen.vote_frame.children[3].vote_yes.caption = yes_caption
			p.gui.screen.vote_frame.children[3].vote_no.caption = no_caption
		end
	end
end

local on_gui_click_token = Token.register(
	function(event)
		local element = event.element
		local player = game.get_player(event.player_index)
		if element.name == "vote_yes" then
			vote.yes[player.name] = true
			vote.no[player.name] = nil
			player.gui.screen.vote_frame.children[3].vote_yes.enabled = false
			player.gui.screen.vote_frame.children[3].vote_no.enabled = true
		elseif element.name == "vote_no" then
			vote.yes[player.name] = nil
			vote.no[player.name] = true
			player.gui.screen.vote_frame.children[3].vote_yes.enabled = true
			player.gui.screen.vote_frame.children[3].vote_no.enabled = false
		else
			return
		end
		update_buttons()
	end
)

local function process_results()
    vote.active = false
    Event.remove_removable(defines.events.on_gui_click, on_gui_click_token)
    local player = game.get_player(vote.suspect)
	local initiator = game.get_player(vote.initiator)
	-- tables to arrays
    local yes = {}
	local no = {}
    for p, _ in pairs(vote.yes) do
        yes[#yes + 1] = p
    end
	for p, _ in pairs(vote.no) do
		no[#no+1] = p
	end
	if #yes > #no then
        vote.result = "succeded"
        valid_commands[vote.action](player, initiator, vote.reason, {yes, no})
	else
		vote.result = "failed"
		game.permissions.get_group(player_data[player.name].permission_group_id).add_player(player)
	end
	game.print("Vote ".. vote.result)
end

--- Decrements timer every second, ininiates vote counting in the end
local decrement_timer_token = Token.get_counter() + 1
decrement_timer_token = Token.register(
	function()
		if vote.timer > 0 then
			vote.timer = vote.timer - 1
			local caption = {"", "Vote ", vote.action, " (", vote.timer, ")"}
			for _, p in pairs(game.connected_players) do
				if p.gui.screen.vote_frame then
					p.gui.screen.vote_frame.children[1] = caption
				end
			end
			Task.set_timeout_in_ticks(60, decrement_timer_token)
        else
			process_results()
		end
	end
)

---comment
---@param player LuaPlayer
local function draw_vote_gui(player)
	local resolution = player.display_resolution
	local frame = player.gui.screen.add{
        type = "frame",
		name = "vote_frame",
		location = {0, resolution.height - vote_frame_size.y},
		direction = "vertical"
	}
	frame.add{
		type = "label",
		caption = {"", "Vote ", vote.action, " (", vote.timer, ")"}
	}
	local t = frame.add{
		type = "table",
		column_count = 2
	}
	t.style.column_alignments[1] = "left"
	t.style.column_alignments[2] = "right"
    t.add { type = "label", caption = "Initiator:" }
	t.add{type = "label", caption = vote.initiator}
	t.add{type = "label", caption = "Suspect:"}
	t.add{type = "label", caption = vote.suspect}

	frame.add{type = "label", caption = vote.reason}

	t = frame.add{type = "table", column_count = 2}
	t.add{type = "sprite-button", caption = "Yes (0)", name = "vote_yes"}
	t.add{type = "sprite-button", caption = "No (0)", name = "vote_no"}
end

---commented
---@param action "jail"|"free"
---@param initiator LuaPlayer
---@param suspect LuaPlayer
---@param reason string
local function start_vote(action, initiator, suspect, reason)
    player_data[suspect.name] = {
        permission_group_id = suspect.permission_group.group_id,
		fallback_position = suspect.position
    }
    if action == "jail" then
        game.permissions.get_group("frozen").add_player(suspect)
    end
	rendering.draw_text{
		text = "Please wait while players decide your fate.",
		surface = suspect.surface,
		target = suspect.position,
		players = {suspect},
		scale_with_zoom = true,
		time_to_live = vote_duration * 60,
		color = {1, 0, 0}
	}
	vote = {
		active = true,
		action = action,
		initiator = initiator.name,
		suspect = suspect.name,
		reason = reason,
		vote_yes = {},
		vote_no = {},
        timer = vote_duration
	}
	if initiator.force.name == "spectator" or initiator.force.name ~= suspect.force.name then
		for _, p in pairs(game.connected_players) do
			draw_vote_gui(p)
		end
	else
		for _, p in pairs(initiator.force.connected_players) do
			draw_vote_gui(p)
		end
	end
    Task.set_timeout_in_ticks(60, decrement_timer_token)
	Event.add_removable(defines.events.on_gui_click, on_gui_click_token)
end


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

	if not event.parameters then
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