local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print
local Color = require('utils.color_presets')

---Item category name to list of item names
---@type table<string, string[]>
local CATEGORIES = {
    basic = {
        'coal',
        'burner-mining-drill',
        'copper-plate',
        'iron-plate',
        'stone-furnace',
    },
    power = {
        'boiler',
        'burner-inserter',
        'steam-engine',
    },
    mall = {
        'transport-belt',
        'underground-belt',
        'assembling-machine-1',
        'assembling-machine-2',
        'assembling-machine-3',
        'fast-inserter',
        'inserter',
        'long-handed-inserter',
        'splitter',
        'electric-mining-drill',
    },
    belts = {
        'transport-belt',
        'underground-belt',
        'splitter',
    },
    redbelts = {
        'fast-transport-belt',
        'fast-underground-belt',
        'fast-splitter',
    },
    chips = {
        'electronic-circuit',
        'advanced-circuit',
        'processing-unit',
    },
    rocket = {
        'processing-unit',
        'low-density-structure',
        'solar-panel',
        'accumulator',
        'rocket-fuel',
        'satellite',
        'cargo-landing-pad',
    },
    def = {
        'gun-turret',
        'flamethrower-turret',
        'laser-turret',
        'stone-wall',
    },
    tf = {
        'cluster-grenade',
        'defender-capsule',
        'destroyer-capsule',
        'distractor-capsule',
        'flamethrower-ammo',
        'grenade',
        'poison-capsule',
        'slowdown-capsule',
    },
    wood = {
        'wood',
    },
    sci = {
        'automation-science-pack',
        'logistic-science-pack',
        'military-science-pack',
        'chemical-science-pack',
        'production-science-pack',
        'utility-science-pack',
        'space-science-pack',
    },
    bots = {
        'construction-robot',
        'logistic-robot',
        'roboport',
    },
    oil = {
        'pumpjack',
        'oil-refinery',
        'chemical-plant',
    },
    nuke = {
        'nuclear-reactor',
        'heat-exchanger',
        'heat-pipe',
        'steam-turbine',
        'uranium-fuel-cell',
    },
    laser = {
        'laser-turret',
    },
    bc = {
        'processing-unit',
    },
    rc = {
        'advanced-circuit',
    },
    gc = {
        'electronic-circuit',
    },
    lds = {
        'low-density-structure',
    },
    fuel = {
        'rocket-fuel',
    },
    solar = {
        'solar-panel',
    },
    acc = {
        'accumulator',
    },
    beac = {
        'beacon',
    },
    spd = {
        'speed-module',
        'speed-module-2',
        'speed-module-3',
    },
    prod = {
        'productivity-module',
        'productivity-module-2',
        'productivity-module-3',
    },
    eff = {
        'efficiency-module',
        'efficiency-module-2',
        'efficiency-module-3',
    },
    fish = {
        'raw-fish',
    },
    train = {
        'locomotive',
        'cargo-wagon',
        'fluid-wagon',
        'rail',
        'rail-signal',
        'rail-chain-signal',
        'train-stop',
    },
    burners = {
        'burner-mining-drill',
    },
    eminers = {
        'electric-mining-drill',
    },
    packs = {
        'repair-pack',
    },
    poles = {
        'small-electric-pole',
        'medium-electric-pole',
        'big-electric-pole',
        'substation',
    },
    steel = {
        'steel-plate',
    },
    pipes = {
        'pipe',
        'pipe-to-ground',
    },
    gears = {
        'iron-gear-wheel',
    },
    bricks = {
        'stone-brick',
    },
}

---Pre-computed sorted category names for help message
local CATEGORY_NAMES_STRING
do
    local names = {}
    for name, _ in pairs(CATEGORIES) do
        names[#names + 1] = name
    end
    table.sort(names)
    CATEGORY_NAMES_STRING = table.concat(names, ', ')
end

---Get player's inventory contents filtered by category
---@param player LuaPlayer
---@param category_items string[]
---@return table<string, number> # item_name -> count
local function get_player_category_items(player, category_items)
    local container = nil
    if player.connected then
        container = player.character
    elseif player.controller_type == defines.controllers.character then
        container = player
    end
    local inventory = container and container.get_inventory(defines.inventory.character_main)
    if not inventory then
        return {}
    end

    local items = {}
    for _, item_name in ipairs(category_items) do
        local count = inventory.get_item_count(item_name)
        if count > 0 then
            items[item_name] = count
        end
    end
    return items
end

---Format items as a single line string with rich text item images
---@param items table<string, number>
---@param category_items string[]
---@return string
local function format_items_line(items, category_items)
    local parts = {}
    for _, item_name in ipairs(category_items) do
        local count = items[item_name]
        if count then
            table.insert(parts, string.format('[img=item/%s] %d', item_name, count))
        end
    end
    return table.concat(parts, ', ')
end

---Get all players for a given force using storage.chosen_team
---@param force string # force name ('north' or 'south')
---@return LuaPlayer[]
local function get_players_for_force(force)
    local players = {}
    for name, chosen_force in pairs(storage.chosen_team) do
        if chosen_force == force then
            local player = game.get_player(name)
            if player then
                table.insert(players, player)
            end
        end
    end
    return players
end

---Main inventory scan function
---@param cmd CustomCommandData
local function inventory_scan(cmd)
    local player = game.get_player(cmd.player_index)

    -- Validate category argument
    local category = cmd.parameter
    if not category or not CATEGORIES[category] then
        player.print('Usage: /i <category>', { color = Color.warning })
        player.print('Valid categories: ' .. CATEGORY_NAMES_STRING, { color = Color.warning })
        return
    end

    local category_items = CATEGORIES[category]

    -- Determine which forces to scan
    local forces
    if player.force.name == 'spectator' then
        forces = { 'north', 'south' }
    else
        forces = { player.force.name }
    end

    -- Scan and print results
    for _, force in ipairs(forces) do
        local players = get_players_for_force(force)
        if #forces > 1 then
            player.print('== ' .. force .. ' ==')
        end
        for _, target_player in ipairs(players) do
            local items = get_player_category_items(target_player, category_items)
            local items_line = format_items_line(items, category_items)
            if items_line ~= '' then
                local settings = {
                    color = target_player.color,
                }
                player.print('• ' .. target_player.name .. ': ' .. items_line, settings)
            end
        end
    end
end

---Command wrapper with error handling
---@param cmd CustomCommandData
local function inventory_scan_command(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then
        return
    end
    safe_wrap_with_player_print(player, inventory_scan, cmd)
end

-- Register commands
commands.add_command('i', 'Scan inventories for items. Usage: /i <category>', inventory_scan_command)

commands.add_command(
    'inventory-scan',
    'Scan inventories for items. Usage: /inventory-scan <category>',
    inventory_scan_command
)
