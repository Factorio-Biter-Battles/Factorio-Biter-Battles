local event = require('utils.event')
local Muted = require('utils.muted')

local function on_console_chat(event)
    if not event.message or not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    if not player.character then
        return
    end

    if Muted and Muted.is_muted(player.name) then
        return
    end

    local y_offset = -4
    if storage.player_floaty_chat[player.index] then
        storage.player_floaty_chat[player.index].destroy()
        storage.player_floaty_chat[player.index] = nil
    end

    local players = {}
    for _, p in pairs(game.connected_players) do
        if player.force.index == p.force.index then
            players[#players + 1] = p
        end
    end
    if #players == 0 then
        return
    end

    storage.player_floaty_chat[player.index] = rendering.draw_text({
        text = event.message,
        surface = player.character.surface,
        target = { entity = player.character, offset = { -0.05, y_offset } },
        color = {
            r = player.color.r * 0.6 + 0.25,
            g = player.color.g * 0.6 + 0.25,
            b = player.color.b * 0.6 + 0.25,
            a = 1,
        },
        players = players,
        time_to_live = 600,
        scale = 1.50,
        font = 'default-game',
        alignment = 'center',
        scale_with_zoom = false,
    })
end

local function on_init(event)
    storage.player_floaty_chat = {}
end

event.on_init(on_init)
event.add(defines.events.on_console_chat, on_console_chat)
