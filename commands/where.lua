-- simply use /where ::LuaPlayerName to locate them

local Color = require('utils.color_presets')
local closable_frame = require('utils.ui.closable_frame')
local safe_wrap_cmd = require('utils.utils').safe_wrap_cmd

local Public = {}

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
    if not game.get_player(player.index) then
        return false
    end
    return true
end

local function create_mini_camera_gui(player, caption, position, surface)
    if player.gui.screen['where_camera'] then
        player.gui.screen['where_camera'].destroy()
    end
    local frame = closable_frame.create_main_closable_frame(player, 'where_camera', caption)
    surface = tonumber(surface)
    local camera = frame.add({
        type = 'camera',
        name = 'where_camera',
        position = position,
        zoom = 0.4,
        surface_index = surface,
    })
    camera.style.minimal_width = 740
    camera.style.minimal_height = 580
end

commands.add_command('where', 'Locates a player', function(cmd)
    local player = game.player

    if player and validate_player(player) then
        if not cmd.parameter then
            return
        end
        local target_player = game.get_player(cmd.parameter)

        if target_player and validate_player(target_player) then
            Sounds.notify_player(player, 'utility/smart_pipette')
            create_mini_camera_gui(player, target_player.name, target_player.position, target_player.surface.index)
        else
            player.print('Please type a name of a player who is connected.', Color.warning)
        end
    else
        return
    end
end)

local function do_follow(cmd)
    local player = game.player
    if not player or not validate_player(player) then
        return
    end
    if player.force.name ~= 'spectator' then
        player.print('You must be a spectator to use this command.', Color.warning)
        return
    end

    if not cmd.parameter then
        return
    end
    local target_player = game.get_player(cmd.parameter)

    if not target_player or not validate_player(target_player) then
        return
    end
    player.zoom_to_world(target_player.position, nil, target_player.character)
end

commands.add_command('follow', 'Follows a player', function(cmd)
    safe_wrap_cmd(cmd, do_follow, cmd)
end)

Public.create_mini_camera_gui = create_mini_camera_gui

return Public
