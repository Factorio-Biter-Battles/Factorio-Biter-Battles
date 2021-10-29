local Global = require "utils.global"
local Color = require "utils.color_presets"
local Server = require 'utils.server'
local Public = {}
local this = {muted = {}}

Global.register(this, function(t) this = t end)

function Public.is_muted(player_name) 
	return this.muted[player_name] == true 
end

function Public.print_muted_message(player)
    player.print(
        "Did you spam pings or verbally grief? You seem to have been muted." ..
        "\nAppeal on Discord, link at biterbattles.org\nHave a break, have a KitKat.",
        Color.warning)
end

local function on_player_muted(event)
    if event.player_index then
        local player = game.get_player(event.player_index)
        this.muted[player.name] = true
        local message = "[MUTED] " .. player.name .. " has been muted" 
        game.print(message, Color.white)
        Server.to_discord_embed(message)
    end
end

local function on_player_unmuted(event)
    if event.player_index then
        local player = game.get_player(event.player_index)
        this.muted[player.name] = nil
        local message = "[UNMUTED] " .. player.name .. " has been unmuted" 
        game.print(message, Color.white)
        Server.to_discord_embed(message)
    end

end
local Event = require 'utils.event'
Event.add(defines.events.on_player_muted, on_player_muted)
Event.add(defines.events.on_player_unmuted, on_player_unmuted)

return Public
