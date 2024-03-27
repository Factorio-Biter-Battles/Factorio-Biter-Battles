-- simply use /where ::LuaPlayerName to locate them

local Color = require 'utils.color_presets'
local Event = require 'utils.event'

local Public = {
	WHERE_CAMERA_ELEMENT_NAME = 'where_camera'
}

local function validate_player(player)
    if not player then
        return false
    end
    if not player.valid then
        return false
    end
    if not player.character then
        return false
    end
    if not player.connected then
        return false
    end
    if not game.players[player.index] then
        return false
    end
    return true
end

local function create_mini_camera_gui(player, caption, position, surface)
    if player.gui.center[Public.WHERE_CAMERA_ELEMENT_NAME] then
        player.gui.center[Public.WHERE_CAMERA_ELEMENT_NAME].destroy()
    end
    local frame = player.gui.center.add({type = 'frame', name = Public.WHERE_CAMERA_ELEMENT_NAME, caption = caption})
    surface = tonumber(surface)
    local camera =
        frame.add(
        {
            type = 'camera',
            name = Public.WHERE_CAMERA_ELEMENT_NAME,
            position = position,
            zoom = 0.4,
            surface_index = surface
        }
    )
    camera.style.minimal_width = 740
    camera.style.minimal_height = 580
end

commands.add_command(
    'where',
    'Locates a player',
    function(cmd)
        local player = game.player

        if validate_player(player) then
            if not cmd.parameter then
                return
            end
            local target_player = game.players[cmd.parameter]

            if validate_player(target_player) then
                create_mini_camera_gui(player, target_player.name, target_player.position, target_player.surface.index)
            else
                player.print('Please type a name of a player who is connected.', Color.warning)
            end
        else
            return
        end
    end
)

Public.create_mini_camera_gui = create_mini_camera_gui

return Public
