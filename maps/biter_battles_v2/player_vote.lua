local Session = require 'utils.datastore.session_data'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Event = require 'utils.event'
local Server = require 'utils.server'
local Jail = require 'maps.biter_battles_v2.jail'
local gui_style = require 'utils.utils'.gui_style

local frame_size = {x = 400, y = 200}

local Public = {}

---@type {active: boolean, action: string, initiator: PlayerName, target: PlayerName, reason: string, yes: {[PlayerName]: true}, no: {[PlayerName]: true}, timer: uint, succeded: boolean }
local vote = {}

---@type {[string]: {pre_function: (fun(initiator: LuaPlayer, target: LuaPlayer, reason: string): boolean), post_function: function, pass_cond: (fun():boolean), duration: uint}}
local valid_votes = {}


valid_votes["jail"] = {
	---Freeze potential griefer for the duration of jail vote
	pre_function = function(initiator, target, reason)
		if global.jail_data[target.name] and global.jail_data[target.name].jailed then
			initiator.print(target.name .. " is already jailed.")
			return false
		end
		global.jail_data[target.name] = {jailed = false, permission_group_id = target.permission_group.group_id}
		game.permissions.get_group("frozen").add_player(target)
		rendering.draw_text{
			text = "Please wait while players decide your fate.",
			surface = target.surface,
			target = target.position,
			players = {target},
			scale_with_zoom = true,
			time_to_live = valid_votes.jail.duration * 60,	--ugly :/
			color = {1, 0, 0}
		}
		return true
    end,
	post_function = function()
		local p_group_id = global.jail_data[vote.target].permission_group_id
		game.permissions.get_group(p_group_id).add_player(vote.target)
		if vote.succeded then
			local target = game.get_player(vote.target)
			local initiator = game.get_player(vote.initiator)
			Jail.jail(target, initiator, vote.reason)
		end
	end,
	duration = 30,
	pass_cond = function()
		return #vote.yes > #vote.no
	end
}
valid_votes["free"] = {
	pre_function = function(initiator, target, reason)
		-- no need to free player that isn't jailed
		if not Jail.get_jailed_table()[target.name] then 
			initiator.print(target.name .. " isn't  jailed.")
			return false
		end
		return true
	end,
	post_function = function()
		if vote.succeded then
			local target = game.get_player(vote.target)
			local initiator = game.get_player(vote.initiator)
			Jail.free(target, initiator, vote.reason)
		end
	end,
	duration = 30,
	pass_cond = function()
		return #vote.yes > #vote.no
	end
}
valid_votes["trust"] = {
	pre_function = function(initiator, target, reason)
		if Session.get_trusted_table()[target.name] then
			initiator.print(target.name .. " is already trusted.")
			return false
		end
		return true
	end,
	post_function = function()
		if vote.succeded then
			Session.get_tracker_table()[vote.target] = true
			game.print(vote.target .. ' is now a trusted player.', {r = 0.22, g = 0.99, b = 0.99})
		end
	end,
	duration = 30,
	pass_cond = function()
		return #vote.yes > #vote.no
	end
}
valid_votes["untrust"] = {
	pre_function = function(initiator, target, reason)
		if not Session.get_trusted_table()[target.name] then
			initiator.print(target.name .. " isn't trusted.")
			return false
		end
		return true
	end,
	post_function = function()
		if vote.succeded then
			Session.get_trusted_table()[vote.target] = false
			game.print(vote.target .. ' is now untrusted.', {r = 0.22, g = 0.99, b = 0.99})
		end
	end,
	duration = 30,
	pass_cond = function()
		return #vote.yes > #vote.no
	end
}
--- Create vote gui for the player
---@param player LuaPlayer
local function draw_vote_gui(player)
	local scale = player.display_scale
	local resolution = player.display_resolution
	local frame = player.gui.screen.add{
        type = "frame",
		name = "vote_frame",
		direction = "vertical"
	}
	gui_style(frame, {width = frame_size.x,
		height = frame_size.y,
		horizontal_align = "center",
		padding = 0
	})
	frame.location = {resolution.width - frame_size.x*scale, resolution.height - frame_size.y*scale}

	local flow = frame.add{type = "flow", name = "flow", direction = "vertical"}
	gui_style(flow, {horizontal_align = "center", width = frame_size.x, height = frame_size.y, padding = 0})
	
	local l = flow.add{
		type = "label",
		caption = {"", "Vote to ", vote.action, " ", vote.target, " (", vote.timer, ")"}
	}
	gui_style(l, {font = "heading-1"})
	
	flow.add{type = "line"}
	l = flow.add{type = "label", caption = vote.reason}
	gui_style(l, {height = frame_size.y/3, single_line = false, font = "default-game"})
	flow.add{type = "label", caption = "Initiated by " .. vote.initiator}

	flow.add{type = "line"}
	local t = flow.add{type = "table", column_count = 2}
	local b = t.add{type = "sprite-button", caption = "Yes (0)", name = "vote_yes"}
	gui_style(b, {width = frame_size.x/2, font_color = {0, 1,0}})
	b = t.add{type = "sprite-button", caption = "No (0)", name = "vote_no"}
	gui_style(b, {width = frame_size.x/2, font_color = {1, 0,0}})
end

--- Updates counters on the vote buttons
local function update_buttons()
    local yes_caption = { "", "Yes (", table.size(vote.yes), ")" }
    local no_caption = { "", "No (", table.size(vote.no), ")" }
    for _, p in pairs(game.connected_players) do
        if p.gui.screen.vote_frame then
            p.gui.screen.vote_frame.flow.children[6].vote_yes.caption = yes_caption
            p.gui.screen.vote_frame.flow.children[6].vote_no.caption = no_caption
        end
    end
end

local on_gui_click_token = Token.register(
	function(event)
		local element = event.element
		local player = game.get_player(event.player_index)
		if not player or not player.valid then return end
		if element.name == "vote_yes" then
			vote.yes[player.name] = true
			vote.no[player.name] = nil
			player.gui.screen.vote_frame.flow.children[6].vote_yes.enabled = false
			player.gui.screen.vote_frame.flow.children[6].vote_no.enabled = true
		elseif element.name == "vote_no" then
			vote.yes[player.name] = nil
			vote.no[player.name] = true
			player.gui.screen.vote_frame.flow.children[6].vote_yes.enabled = true
			player.gui.screen.vote_frame.flow.children[6].vote_no.enabled = false
		else
			return
		end
		update_buttons()
	end
)

local function process_results()
    vote.active = false
    Event.remove_removable(defines.events.on_gui_click, on_gui_click_token)
	for _, p in pairs(game.connected_players) do
		if p.gui.screen.vote_frame then
			p.gui.screen.vote_frame.destroy()
		end
	end
    -- tables to arrays
    local yes = {}
    local no = {}
    for p, _ in pairs(vote.yes) do
        yes[#yes + 1] = p
    end
    for p, _ in pairs(vote.no) do
        no[#no + 1] = p
    end
	vote.yes = yes
	vote.no = no
	local result
	vote.succeded = valid_votes[vote.action].pass_cond()
	if vote.succeded then result = "succeded!\n" else result = "failed!\n" end
	local message = table.concat({
		"Vote to ", vote.action, " ", vote.target, " has ", result,
		"For (", #yes, "):\n",
		table.concat(yes, ", "),
		"\nAgainst (", #no, "):\n",
		table.concat(no, ", ")
	})
	game.print(message)
	Server.to_discord_embed(message)
    valid_votes[vote.action].post_function()
end

--- Decrements timer every second, ininiates vote counting in the end
local decrement_timer_token = Token.get_counter() + 1
decrement_timer_token = Token.register(
	function()
		if vote.timer > 0 then
			vote.timer = vote.timer - 1
			local caption = {"", "Vote to ", vote.action, " ", vote.target, " (", vote.timer, ")"}
			for _, p in pairs(game.connected_players) do
				if p.gui.screen.vote_frame then
					p.gui.screen.vote_frame.flow.children[1].caption = caption
				end
			end
			Task.set_timeout_in_ticks(60, decrement_timer_token)
        else
			process_results()
		end
	end
)

--- Fill `vote` table, draw_gui, start timer
---@param action string
---@param initiator LuaPlayer
---@param target LuaPlayer
---@param reason string
local function start_vote(action, initiator, target, reason)
    vote = {
        active = true,
        action = action,
        initiator = initiator.name,
        target = target.name,
        reason = reason,
        yes = {},
        no = {},
        timer = valid_votes[action].duration
    }
	for _, p in pairs(game.connected_players) do
		draw_vote_gui(p)
	end

    Task.set_timeout_in_ticks(60, decrement_timer_token)
    Event.add_removable(defines.events.on_gui_click, on_gui_click_token)
end

local function proceess_command(event)
	local command = event.command

	if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

	if not valid_votes[command] then
		player.print("Invalid action.")
		return 
	end

    if not Session.get_trusted_table()[player.name] then
		player.print("Only trusted players can run this command.")
		return
	end

    local parameters = {}
	for i in string.gmatch(event.parameters, '%S+') do
		parameters[#parameters + 1] = i
	end

    local target = table.remove(parameters, 1)
    if not target or #target <= 0 then
        player.print("Missing suspect name.")
        return
	end
	target = game.get_player(target)
    if not target or not target.valid then
        player.print("Invalid suspect.")
        return
    end

    local reason = table.concat(parameters, " ")
    if #reason <= 10 then
        player.print("Reason is too short.")
        return
    end

    if vote.active then
		player.print("Wait for the current vote to finish.")
		return
	end

	if global.server_restart_timer and global.server_restart_timer <= valid_votes[command].duration then
        player.print("Wait for map restart.")
		return
	end
	local ready_to_start = valid_votes[command].pre_function(player, target, reason)
	if ready_to_start then
		start_vote(command, player, target, reason)
	end
end

--- Translate `/vote jail ...` to `/jail ...` and call `process_command()`
--- Call `process_command()` for non-admin direct commands (etc. `/jail`) 
local function on_console_command(event)
	if event.command == "vote" then
		local parameters = {}
		for i in string.gmatch(event.parameters, '%S+') do
			parameters[#parameters + 1] = i
		end
		event.command = table.remove(parameters, 1)
		event.parameters = table.concat(parameters, " ")
	else
		if not valid_votes[event.command] then return end
		-- skip direct admin functions
		local player = game.get_player(event.player_index)
		if not player or not player.valid then return end
		if player.admin then return end
	end
	proceess_command(event)
end

Event.add(defines.events.on_console_command, on_console_command)
commands.add_command(
    'vote',
    'Start a vote.',
    function()
        return
    end
)

global.player_vote = vote
return Public