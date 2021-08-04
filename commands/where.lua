-- simply use /where ::LuaPlayerName to locate them

local Color = require 'utils.color_presets'
local Event = require 'utils.event'

local Public = {}
local spectactor_cameras = 4
local player_cameras = 1
local where_camera_prefix = 'where_camera_'
local resize_prefix = 'resize_'

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

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

local function destroy_camera(player, where_camera_name)
    if player.gui.screen[where_camera_name] then
        player.gui.screen[where_camera_name].destroy()
    end

    local resize_where_camera_name = resize_prefix .. where_camera_name
    if player.gui.screen[resize_where_camera_name] then
        player.gui.screen[resize_where_camera_name].destroy()
    end
end

local function is_spectator(player)
    return player.force == game.forces.spectator
end

local function get_max_cameras(player)
    if is_spectator(player) then
        return spectactor_cameras
    else
        return player_cameras
    end
end

local function get_where_camera_name(player, caption)
    local where_camera_name
    for index=1,get_max_cameras(player) do
        where_camera_name = where_camera_prefix .. index
        if player.gui.screen[where_camera_name] then
            if player.gui.screen[where_camera_name].caption == caption then
                return
            end
        else
            return where_camera_name
        end
    end

    destroy_camera(player, where_camera_name)

    return where_camera_name
end

local function create_mini_camera_gui(player, caption, position, surface)
    local where_camera_name = get_where_camera_name(player, caption)
    if not where_camera_name then
        return
    end

    local resize_where_camera_name = resize_prefix .. where_camera_name

    local frame = player.gui.screen.add({type = 'frame', name = where_camera_name, caption = caption})
    surface = tonumber(surface)
    local camera =
        frame.add(
        {
            type = 'camera',
            name = 'where_camera',
            position = position,
            zoom = 0.4,
            surface_index = surface
        }
    )

    camera.style.horizontally_stretchable = true
    camera.style.vertically_stretchable = true
    camera.style.horizontally_squashable = true
    camera.style.vertically_squashable = true

    frame.style.minimal_width  = 200
    frame.style.minimal_height = 200
    frame.style.natural_width  = 740
    frame.style.natural_height = 580

    if is_spectator(player) then
        local resize_frame =
            player.gui.screen.add(
            {
                type = 'frame',
                name = resize_where_camera_name,
                caption = ' ',
                location= frame.location
            }
        )
        resize_frame.style.natural_width  = 24
        resize_frame.style.natural_height = 24
        resize_frame.style.top_padding = -4 * player.display_scale
        resize_frame.style.left_padding = -20 * player.display_scale
        resize_frame.style.right_padding = -8 * player.display_scale
        resize_frame.style.bottom_padding = -16 * player.display_scale

        resize_frame.location = {
            frame.location.x + player.display_scale * (frame.style.natural_width - resize_frame.style.natural_width),
            frame.location.y + player.display_scale * (frame.style.natural_height - resize_frame.style.natural_height)
        }
    end

    frame.force_auto_center()

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

local function on_gui_click(event)
    local player = game.players[event.player_index]

    if not (event.element and event.element.valid) then
        return
    end

    local name = event.element.name

    -- click on camera image
    if name == 'where_camera' then
        destroy_camera(player, event.element.parent.name)
        return
    end

    -- click on camera frame
    if string.starts(name, where_camera_prefix) then
        local resize_where_camera_name = resize_prefix .. name
        if player.gui.screen[resize_where_camera_name] then
            player.gui.screen[resize_where_camera_name].bring_to_front()
            return
        end
    end
end

local function on_tick(event)
    for _, player in pairs(game.connected_players) do
        for _, child in pairs(player.gui.screen.children) do
            if string.starts(child.name, where_camera_prefix) then
                local target_name = child.caption
                child.where_camera.position = game.players[target_name].position
            end
        end
    end
end

local function on_where_camera_resize(player, resize_frame, where_camera_name)
    if not player.gui.screen[where_camera_name] then
        return
    end

    local where_camera = player.gui.screen[where_camera_name]
    local scale = player.display_scale

    where_camera.style.natural_width = math.max(
        where_camera.style.minimal_width,
        (resize_frame.location.x - where_camera.location.x) / scale + resize_frame.style.natural_width
    )
    where_camera.style.natural_height = math.max(
        where_camera.style.minimal_height,
        (resize_frame.location.y - where_camera.location.y) / scale + resize_frame.style.natural_height
    )

    -- limit resize_frame location to where_camera boundaries
    if where_camera.style.natural_width <= where_camera.style.minimal_width then
        resize_frame.location = {
            where_camera.location.x + scale * (where_camera.style.minimal_width - resize_frame.style.natural_width),
            resize_frame.location.y
        }
    end

    if where_camera.style.natural_height <= where_camera.style.minimal_height then
        resize_frame.location = {
            resize_frame.location.x,
            where_camera.location.y + scale * (where_camera.style.minimal_height - resize_frame.style.natural_height)
        }
    end
end

local function on_where_camera_move(player, where_camera, resize_where_camera_name)
    local scale = player.display_scale
    local resize_frame = player.gui.screen[resize_where_camera_name]
    resize_frame.location = {
        where_camera.location.x + scale * (math.max(where_camera.style.minimal_width, where_camera.style.natural_width) - resize_frame.style.natural_width),
        where_camera.location.y + scale * (math.max(where_camera.style.minimal_height, where_camera.style.natural_height) - resize_frame.style.natural_height)
    }
    resize_frame.bring_to_front()
end

local function on_gui_location_changed(event)
    local player = game.players[event.player_index]

    if not is_spectator(player) then
        return
    end

    local name = event.element.name

    if string.starts(name, where_camera_prefix) then
        local resize_where_camera_name = resize_prefix .. name
        on_where_camera_move(player, event.element, resize_where_camera_name)
        return
    end

    if string.starts(name, resize_prefix) then
        local where_camera_name = string.gsub(name, resize_prefix, '')
        on_where_camera_resize(player, event.element, where_camera_name)
        return
    end
end

local function on_player_changed_force(event)
    local player = game.players[event.player_index]
    for _, child in pairs(player.gui.screen.children) do
        child.destroy()
    end
end

Public.create_mini_camera_gui = create_mini_camera_gui

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_gui_location_changed, on_gui_location_changed)
Event.add(defines.events.on_player_changed_force, on_player_changed_force)

return Public
