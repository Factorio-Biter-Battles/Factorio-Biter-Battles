local Public = {}

local AiTargets = require('maps.biter_battles_v2.ai_targets')
local table_insert = table.insert

local direction_translation = {
    [defines.direction.north] = defines.direction.south,
    [defines.direction.northeast] = defines.direction.southeast,
    [defines.direction.east] = defines.direction.east,
    [defines.direction.southeast] = defines.direction.northeast,
    [defines.direction.south] = defines.direction.north,
    [defines.direction.southwest] = defines.direction.northwest,
    [defines.direction.west] = defines.direction.west,
    [defines.direction.northwest] = defines.direction.southwest,
}

local function clear_entities(surface, bb)
    local objects = surface.find_entities_filtered({
        area = bb,
        name = 'character',
        invert = true,
    })

    for _, object in pairs(objects) do
        object.destroy()
    end
end

function Public.clone(event)
    local surface = event.surface
    local source_bb = event.area
    local destination_bb = {
        left_top = { x = source_bb.left_top.x, y = source_bb.left_top.y },
        right_bottom = { x = source_bb.right_bottom.x, y = source_bb.right_bottom.y },
    }

    -- Clone entities. This will trigger on_entity_cloned where
    -- we'll adjust positions, orientations etc. It will also
    -- trigger on_area_cloned where we can clone tiles at inverted positions.
    local request = {
        source_area = source_bb,
        destination_area = destination_bb,
        destination_surface = surface,
        clone_tiles = false,
        clone_entities = true,
        clone_decoratives = false,
        clear_destination_entities = false,
        clear_destination_decoratives = true,
        create_build_effect_smoke = false,
        expand_map = true,
    }

    if source_bb.left_top.y < 0 then
        destination_bb.left_top.y = -source_bb.right_bottom.y
        destination_bb.right_bottom.y = -source_bb.left_top.y
    else
        source_bb.left_top.y = -destination_bb.right_bottom.y
        source_bb.right_bottom.y = -destination_bb.left_top.y
    end

    -- Workaround for what I assume is bug in game engine.
    -- "Source entities overlap with destination entities."
    -- Seems like clear_destination_entities flag is ignored in some edge
    -- cases for x > 3000, y = 0, seed = 2018927096
    clear_entities(surface, destination_bb)
    surface.clone_area(request)
end

---@param event EventData.on_entity_cloned
function Public.invert_entity(event)
    local destination = event.destination

    -- Don't allow soulless characters to be cloned on spawn platform.
    if destination.name == 'character' then
        destination.destroy()
        return
    end

    if destination.force.name == 'north' then
        destination.force = 'south'
    elseif destination.force.name == 'north_biters' then
        destination.force = 'south_biters'
    end

    if destination.supports_direction then
        destination.direction = direction_translation[destination.direction]
    end

    -- Invert entity position to south in relation to source entity.
    local dest_pos = event.source.position
    -- Check if there are no overlaps.
    if dest_pos.y == 0 then
        destination.destroy()
        return
    end
    dest_pos.y = -dest_pos.y

    -- It's safe to use teleport() even if final position is on top
    -- of lake.
    destination.teleport(dest_pos)

    if
        destination.name == 'rocket-silo'
        and math.abs(destination.position.y) < 150
        and math.abs(destination.position.x) < 100
    then
        -- NOTE: Silo is mirrored several times to south.
        -- Likely if silo is on top of chunk border.
        storage.rocket_silo[destination.force.name] = { destination }
        AiTargets.start_tracking(destination)
    elseif destination.name == 'gun-turret' then
        AiTargets.start_tracking(destination)
    elseif destination.name == 'spitter-spawner' or destination.name == 'biter-spawner' then
        table_insert(storage.unit_spawners[destination.force.name], destination)
    end
end

function Public.remove_hidden_tiles(event)
    local bb = event.destination_area
    local surface = event.destination_surface
    local to_remove = surface.find_tiles_filtered({
        area = bb,
        has_hidden_tile = true,
        name = 'refined-concrete',
    })

    for i, tile in pairs(to_remove) do
        local pos = { tile.position.x, -tile.position.y - 1 }
        surface.set_hidden_tile(tile.position, surface.get_hidden_tile(pos))
    end
end

local tiles = {}
for i = 1, 32 * 32 do
    tiles[i] = {
        position = { 0, 0 },
        name = '',
    }
end

function Public.invert_tiles(event)
    local surface = event.destination_surface
    local to_emplace = surface.find_tiles_filtered({
        area = event.source_area,
    })

    assert(#to_emplace == #tiles)
    for i, src_tile in pairs(to_emplace) do
        local tile = tiles[i]
        local pos = src_tile.position
        tile.position[1], tile.position[2] = pos.x, -pos.y - 1
        tile.name = src_tile.name
    end

    surface.set_tiles(tiles)
end

function Public.invert_decoratives(event)
    local surface = event.destination_surface
    local src_decoratives = surface.find_decoratives_filtered({
        area = event.source_area,
    })

    local dest_decoratives = {}
    for i, d in pairs(src_decoratives) do
        local pos = d.position
        pos.y = -pos.y - 1
        dest_decoratives[i] = {
            amount = d.amount,
            position = pos,
            name = d.decorative.name,
        }
    end

    surface.create_decoratives({ check_collision = false, decoratives = dest_decoratives })
end

return Public
