local Color = require('utils.color_presets')
local Event = require('utils.event')
local Token = require('utils.token')

local send_to_external_server_handler = Token.register(function(event)
    game.get_player(event.player_index).connect_to_server(storage.special_games_variables.send_to_external_server)
end)

local function generate_send_to_external_server(player, address, name, description)
    if address == '' or name == '' or description == '' then
        Event.remove_removable(defines.events.on_player_joined_game, send_to_external_server_handler)
        player.print('Stopped sending players to external server', { color = Color.warning })
        return
    end

    player.print('Sending players (other than host) to the specified server', { color = Color.warning })
    for _, connected_player in pairs(game.connected_players) do
        connected_player.connect_to_server({
            address = address,
            name = name,
            description = description,
        })
    end
    storage.special_games_variables.send_to_external_server =
        { address = address, name = name, description = description }
    Event.add_removable(defines.events.on_player_joined_game, send_to_external_server_handler)
end

local Public = {
    name = {
        type = 'label',
        caption = 'Send to external server',
        tooltip = 'Sends all online players an invite to an external server.\nLeave empty to disable',
    },
    config = {
        [1] = { name = 'label1', type = 'label', caption = 'IP address' },
        [2] = { name = 'address', type = 'textfield', width = 90 },
        [3] = { name = 'label2', type = 'label', caption = 'Server name' },
        [4] = { name = 'server_name', type = 'textfield', width = 100 },
        [5] = { name = 'label3', type = 'label', caption = 'Message' },
        [6] = { name = 'description', type = 'textfield', width = 100 },
    },
    button = { name = 'apply_and_confirm', type = 'button', caption = 'Apply & Confirm' },
    gui_click = function(element, config, player)
        if element.name ~= 'apply_and_confirm' then
            return
        end

        local address = config['address'].text
        local name = config['server_name'].text
        local description = config['description'].text

        generate_send_to_external_server(player, address, name, description)
    end,
}

return Public
