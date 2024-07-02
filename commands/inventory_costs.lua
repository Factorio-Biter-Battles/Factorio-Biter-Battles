local ItemCosts = require 'maps.biter_battles_v2.item_costs'

local function inventory_cost(player)
    local inventory = player.get_inventory(defines.inventory.character_main)
    local cost = 0
    for name, count in pairs(inventory.get_contents()) do
        cost = cost + ItemCosts.get_cost(name) * count
    end
    return cost
end

local function inventory_costs_for_force(force)
    local players = {}
    for _, player in pairs(force.players) do
        table.insert(players, {player = player, cost = inventory_cost(player)})
    end
    table.sort(players, function(a, b) return a.cost > b.cost end)
    return players
end

local function inventory_costs(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then return end
    local forces
    if player.force.name == "spectator" or cmd.parameter == "all" then
        forces = {game.forces.north, game.forces.south}
    else
        forces = {player.force}
    end
    for _, force in ipairs({game.forces.north, game.forces.south}) do
        local players = inventory_costs_for_force(force)
        if #forces > 1 then
            player.print(force.name)
        end
        for index, entry in ipairs(players) do
            if index > 10 then break end
            player.print(string.format("%s: %.0f", entry.player.name, entry.cost / 10))
        end
    end
end

commands.add_command(
	"inventory-costs",
	"Print out the top players by inventory values. Pass 'all' to see it for both forces.",
	inventory_costs
)
