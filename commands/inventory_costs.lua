local ItemCosts = require('maps.biter_battles_v2.item_costs')
local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print

local function inventory_cost(player)
    local container = nil
    if player.connected then
        container = player.character
    elseif player.controller_type == defines.controllers.character then
        container = player
    end
    local inventory = container and container.get_inventory(defines.inventory.character_main)
    if not inventory then
        return 0
    end
    local cost = 0
    local freebies
    if storage.special_games_variables['infinity_chest'] then
        freebies = storage.special_games_variables['infinity_chest'].freebies
    end
    for _, item in pairs(inventory.get_contents()) do
        local item_cost
        if freebies and freebies[item.name] then
            item_cost = 0
        else
            item_cost = ItemCosts.get_cost(item.name)
        end
        cost = cost + item_cost * item.count
    end
    return cost
end

local function inventory_costs_for_force(force)
    local players = {}
    for name, chosen_force in pairs(storage.chosen_team) do
        if chosen_force == force then
            local player = game.get_player(name)
            if player then
                table.insert(players, { player = player, cost = inventory_cost(player) })
            end
        end
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
        forces = { 'north', 'south' }
    else
        forces = { player.force.name }
    end
    for _, force in ipairs(forces) do
        local players = inventory_costs_for_force(force)
        if #forces > 1 then
            player.print('== ' .. force .. ' ==')
        end
        for index, entry in ipairs(players) do
            if index > 10 then
                break
            end
            local settings = {
                color = entry.player.color,
            }
            local msg = string.format('%s: %.0f', entry.player.name, entry.cost / 10)
            player.print('• ' .. msg, settings)
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
