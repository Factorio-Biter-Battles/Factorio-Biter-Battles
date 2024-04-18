local Color = require 'utils.color_presets'
local Public = require 'utils.core'
local bb_config = require "maps.biter_battles_v2.config"

local function test_turret_creep()
    local player = game.player
    if not player then return end
    if not player.admin then
        player.print("[ERROR] Command is admin-only.", Color.warning)
        return
    end

    local char = player.character
    if not char then
        player.print("[ERROR] There's no playable character tied to you!", Color.warning)
        return
    end

    local biter_area_dist = (bb_config and math.floor(bb_config.bitera_area_distance * 0.45) or 256)
    if math.abs(char.position.y) <= biter_area_dist then
         -- while 100 is hardcoded in turret creep check, player must also be inside "biter area"
        player.print("[INFO] You are too close to spawn, teleporting away...", Color.info)
        local sign = 1
        if char.position.y < 0 then
            sign = -1
        end

        -- relative tp
        char.teleport(0, sign * (biter_area_dist - math.abs(char.position.y)))
    end

    player.print("[INFO] Creating a spawner next to you...", Color.info)


    -- maps/.../functions.lua lists prototype types:
    -- see current items here: https://wiki.factorio.com/Data.raw#item
    local no_turret_blacklist = {
        "gun-turret", "artillery-turret", "laser-turret", "flamethrower-turret"
    }
    --
    for _, name in pairs(no_turret_blacklist) do
        char.get_main_inventory().insert({name = name, count = 10})
    end



    local surface = char.surface
    local spawner_pos = {x = math.floor(char.position.x - 64), y = math.floor(char.position.y)}
    local spawner = surface.create_entity{name = "biter-spawner", position = spawner_pos}
    if not spawner then
        player.print("[ERROR] Failed to place the spawner!", Color.warning)
        surface.set_tiles{ {name = "acid-refined-concrete", position = spawner_pos } }
        player.open_map(spawner_pos, 4)
        return
    end

    local new_tiles = {}

    -- show range with background
    for y = -64, 64, 1 do
        for x = -64, 64, 1 do
            local tile_pos = {x = spawner_pos.x + x, y = spawner_pos.y + y}
            local dist = Public.distance(tile_pos, spawner_pos)
            -- old circular distance was cut off at 64
            local tile_name = dist <= 64 and "blue-refined-concrete" or "orange-refined-concrete"
            table.insert(new_tiles, {name = tile_name, position = tile_pos})
        end
    end
    surface.set_tiles( new_tiles )

    -- cut off spawner with water
    new_tiles = {}
    for x = -8, 8, 1 do -- horizontal lines
        for y = -8, 8, 16 do
            local tile_pos = {x = spawner_pos.x + x, y = spawner_pos.y + y}
            table.insert(new_tiles, {name = "deepwater", position = tile_pos})
        end
    end
    for y = -8, 8, 1 do -- vertical lines
        for x = -8, 8, 16 do
            local tile_pos = {x = spawner_pos.x + x, y = spawner_pos.y + y}
            table.insert(new_tiles, {name = "deepwater", position = tile_pos})
        end
    end
    surface.set_tiles( new_tiles )

    player.print("[INFO] Spawner created. Now try to place the turret inside and outside the spawner area."
    .."It should only be placeable outside the square", Color.info)
end

commands.add_command('test-turret-creep', 'setup test for turret creep on spawners. It spawns to the left, make sure you are far from spawn on Y axis.', test_turret_creep)
