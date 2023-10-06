local Global = require 'utils.global'
local Session = require 'utils.datastore.session_data'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Event = require 'utils.event'
local Server = require 'utils.server'
local Jail = require 'maps.biter_battles_v2.jail'

local vote_frame_size = {x = 250, y = 50}
local vote_duration = 30 ---@type uint in seconds

---@type {active: boolean, action: string, initiator: string, target: string, reason: string, yes: {string: true}, no: {string: true}, timer: uint, result: string }
local vote = {}

---@type {[string]: {pre_function?: function, post_function: function, pass_cond: function, duration: uint}}
local valid_votes = {}


valid_votes["jail"] = {
	---Freeze potential griefer for the duration of jail vote
	---@param player LuaPlayer
	pre_function = function(player)
		Jail.player_data[player.name] = {
			permission_group_id = player.permission_group.group_id,
			fallback_position = player.position
		}
		game.permissions.get_group("frozen").add_player(player)
		rendering.draw_text{
			text = "Please wait while players decide your fate.",
			surface = player.surface,
			target = player.position,
			players = {player},
			scale_with_zoom = true,
			time_to_live = vote_duration * 60,
			color = {1, 0, 0}
		}
    end,
	post_function = function(player)
		Jail.jail(player, )
	end
}


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
	t.add{type = "label", caption = "Target:"}
	t.add{type = "label", caption = vote.target}

	frame.add{type = "label", caption = vote.reason}

	t = frame.add{type = "table", column_count = 2}
	t.add{type = "sprite-button", caption = "Yes (0)", name = "vote_yes"}
	t.add{type = "sprite-button", caption = "No (0)", name = "vote_no"}
end

--- Updates counters on the vote buttons
local function update_buttons()
    local yes_caption = { "", "Yes (", table.size(vote.yes), ")" }
    local no_caption = { "", "No (", table.size(vote.no), ")" }
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
    local player = game.get_player(vote.target)
    local initiator = game.get_player(vote.initiator)
    -- tables to arrays
    local yes = {}
    local no = {}
    for p, _ in pairs(vote.yes) do
        yes[#yes + 1] = p
    end
    for p, _ in pairs(vote.no) do
        no[#no + 1] = p
    end
    if #yes > #no then
        vote.result = "succeded"
        valid_votes[vote.action](player, initiator, vote.reason, { yes, no })
    else
        vote.result = "failed"
        game.permissions.get_group(Jail.player_data[player.name].permission_group_id).add_player(player)
    end
    game.print("Vote " .. vote.result)
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

---commented
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
        vote_yes = {},
        vote_no = {},
        timer = vote_duration
    }
	for _, p in pairs(game.connected_players) do
		draw_vote_gui(p)
	end

    Task.set_timeout_in_ticks(60, decrement_timer_token)
    Event.add_removable(defines.events.on_gui_click, on_gui_click_token)
end

--- Validate parameters from a command before starting a vote
local function on_console_command(event)
	local command = event.command
	if not valid_votes[command] then return end

	if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then return end

    if not Session.get_trusted_table()[player.name] then
		player.print("Only trusted players can run this command.")
		return
	end

    local parameters = {}
	for i in string.gmatch(event.parameters, '%S+') do
		parameters[#parameters + 1] = i
	end
    if command == "vote" then
        command = table.remove(parameters, 1)
		if not valid_votes[command] then
            player.print("Invalid command.")
			return
		end
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

    local reason = table.concat(parameters)
    if #reason <= 10 then
        player.print("Reason is too short.")
        return
    end

    if vote.active then
		player.print("Wait for the current vote to finish.")
		return
	end

	if global.server_restart_timer and global.server_restart_timer <= vote_duration then
        player.print("Wait for map restart.")
		return
	end
	valid_votes[command].pre_function({player, target, reason})
	start_vote(command, player, target, reason)
end

Event.add(defines.events.on_console_command, on_console_command)
commands.add_command(
    'vote',
    'Start a vote.',
    function()
        return
    end
)