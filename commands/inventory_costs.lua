local ItemCosts = require('maps.biter_battles_v2.item_costs')
local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print

local function inventory_cost(player)
    local inventory = player.character.get_inventory(defines.inventory.character_main)
    if not inventory then
        return 0
    end
    local cost = 0
    local freebies
    if storage.special_games_variables['infinity_chest'] then
        freebies = storage.special_games_variables['infinity_chest'].freebies
    end
    for name, count in pairs(inventory.get_contents()) do
        local item_cost
        if freebies and freebies[name] then
            item_cost = 0
        else
            item_cost = ItemCosts.get_cost(name)
        end
        cost = cost + item_cost * count
    end
    return cost
end

local function inventory_costs_for_force(force)
    local players = {}
    for _, player in pairs(force.players) do
        table.insert(players, { player = player, cost = inventory_cost(player) })
    end
    table.sort(players, function(a, b)
        return a.cost > b.cost
    end)
    return players
end

local function inventory_costs(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then
        return
    end
    local forces
    if player.force.name == 'spectator' or cmd.parameter == 'all' then
        forces = { game.forces.north, game.forces.south }
    else
        forces = { player.force }
    end
    for _, force in ipairs({ game.forces.north, game.forces.south }) do
        local players = inventory_costs_for_force(force)
        if #forces > 1 then
            player.print(force.name)
        end
        for index, entry in ipairs(players) do
            if index > 10 then
                break
            end
            player.print(string.format('%s: %.0f', entry.player.name, entry.cost / 10))
        end
    end
end

local function inventory_costs_command(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then
        return
    end
    safe_wrap_with_player_print(player, inventory_costs, cmd)
end

commands.add_command(
    'inventory-costs',
    "Print out the top players by inventory values. Pass 'all' to see it for both forces.",
    inventory_costs_command
)
