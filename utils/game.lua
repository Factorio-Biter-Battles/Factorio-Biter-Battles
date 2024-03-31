local Game = {}

--- Prints to player or console.
function Game.player_print(str)
    if game.player then
        game.player.print(str)
    else
        print(str)
    end
end

function Game.get_player(mixed)
    if type(mixed) == "table" then
        if mixed.__self then
            return mixed and mixed.valid and mixed
        elseif mixed.player_index then
            local player = game.players[mixed.player_index]
            return player and player.valid and player
        end
    elseif mixed then
        local player = game.players[mixed]
        return player and player.valid and player
    end
end

--[[
    @param Position String to display at
    @param text String to display
    @param color table in {r = 0~1, g = 0~1, b = 0~1}, defaults to white.
    @param surface LuaSurface

    @return the created entity
]]
function Game.print_floating_text(surface, position, text, color)
    color = color

    return surface.create_entity {
        name = 'tutorial-flying-text',
        color = color,
        text = text,
        position = position
    }
end

--[[
    Creates a floating text entity at the player location with the specified color in {r, g, b} format.
    Example: "+10 iron" or "-10 coins"

    @param text String to display
    @param color table in {r = 0~1, g = 0~1, b = 0~1}, defaults to white.

    @return the created entity
]]
function Game.print_player_floating_text_position(player_index, text, color, x_offset, y_offset)
    local player = game.get_player(player_index)
    if not player or not player.valid then
        return
    end

    local position = player.position
    return Game.print_floating_text(player.surface, {x = position.x + x_offset, y = position.y + y_offset}, text, color)
end

function Game.print_player_floating_text(player_index, text, color)
    Game.print_player_floating_text_position(player_index, text, color, 0, -1.5)
end

return Game
