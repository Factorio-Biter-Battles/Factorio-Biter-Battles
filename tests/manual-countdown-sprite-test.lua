--[[
What for? To show the captain games countdown images 1 through 9.
Go to your surface's 0,0 point to see them.

You can run this as in-game command /c ... all this code ]]

local available_surfaces = {}
table.insert(available_surfaces, global.bb_surface_name and game.get_surface(global.bb_surface_name))
if #available_surfaces == 0 then
    for _, surface in pairs(game.surfaces) do
        table.insert(available_surfaces, surface)
    end
end

local pos = {0, 0}
for num = 1, 9 do
    pos[1] = num * 12 - 12*5 --[[ make 4 or 5 appear at 0,0 ]]
    for _, surface in pairs(available_surfaces) do
        local id = rendering.draw_sprite{
            --[[ path in comfy_panel/special_games/captain.lua ]]
            sprite = string.format("file/png/%1d.png", num),
            surface = surface,
            time_to_live = 1200, --[[ ticks ]]
            target = pos
        }
    end
end
