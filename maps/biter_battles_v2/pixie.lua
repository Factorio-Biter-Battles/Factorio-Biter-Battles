local Pixie = {}

Pixie.base_pixie_dust = 100 -- Starting pixie dust
Pixie.base_item_pixie_dust = 5 -- if no value supplied, this will be the pixie value
Pixie.base_biter_pixie_dust = 5 -- if no value supplied, this will be the pixie value

-- Spitter/biters/spawner only. Didn't include worms
Pixie.biter_pixie_dust_values = {
    ["small-spitter"] = 1,
    ["small-biter"] = 2,
    ["biter-spawner"] = 10,
    ["spitter-spawner"] = 10
}

-- see factorio wiki for item names
Pixie.item_pixie_dust_values = {
    ["stone-furnace"] = 1,
    ["burner-mining-drill"] = 1
}

local function pixie_balance_message(position, pixie_result)
    return {
        name = "flying-text",
        position = position,
        text = "Pixie Balance ♥: " .. pixie_result,
        color = {r = 255, g = 255, b = 0}
    }
end
local function not_enough_pixie_message(position)
    return {
        name = "flying-text",
        position = position,
        text = "Not enough Pixie Dust",
        color = {r = 255, g = 99, b = 71}
    }
end

function Pixie.register_player(force_name, player_name)
    if not global.player_pixie_dust[force_name] then
        global.player_pixie_dust[force_name] = {}
    end

    if not global.player_pixie_dust[force_name][player_name] then
        global.player_pixie_dust[force_name][player_name] =
            Pixie.base_pixie_dust
    end
end

function Pixie.get_player_pixie_payment(event)
    if not event.player_index then
        return -- bot event
    end

    local entity = event.created_entity
    if not entity.valid or entity.name == 'entity-ghost' then return end

    local player = game.get_player(event.player_index)
    if not player.valid then return end

    local surface = player.surface

    local required_pixie_dust_amount = Pixie.base_item_pixie_dust
    if Pixie.item_pixie_dust_values[entity.name] then
        required_pixie_dust_amount = Pixie.item_pixie_dust_values[entity.name]
    end
    if not global.player_pixie_dust[force_name] or
        not global.player_pixie_dust[force_name][player.name] then
        Pixie.register_player(player.force.name, player.name)
    end
    local player_pixie_dust_stash =
        global.player_pixie_dust[player.force.name][player.name]
    local pixie_result = player_pixie_dust_stash - required_pixie_dust_amount
    if pixie_result >= 0 then
        global.player_pixie_dust[player.force.name][player.name] = pixie_result
        surface.create_entity(pixie_balance_message(entity.position,
                                                    pixie_result))
    else
        player.insert({name = entity.name, count = 1})
        surface.create_entity(not_enough_pixie_message(entity.position))
        entity.destroy()
    end
end

function Pixie.refund_player_pixie_payment(event)
    if not event.player_index then
        return -- bot event
    end

    local entity = event.entity
    if not entity.valid or entity.name == 'entity-ghost' then return end

    local player = game.get_player(event.player_index)
    if not player.valid then return end

    local surface = player.surface

    local item_pixie_amount = Pixie.base_item_pixie_dust
    if Pixie.item_pixie_dust_values[entity.name] then
        item_pixie_amount = Pixie.item_pixie_dust_values[entity.name]
    end

    if not global.player_pixie_dust[force_name] or
        not global.player_pixie_dust[force_name][player.name] then
        Pixie.register_player(player.force.name, player.name)
    end

    local player_pixie_dust_stash =
        global.player_pixie_dust[player.force.name][player.name]

    local pixie_result = player_pixie_dust_stash + item_pixie_amount
    global.player_pixie_dust[player.force.name][player.name] = pixie_result
    surface.create_entity(pixie_balance_message(entity.position, pixie_result))
end

function Pixie.reward_pixie_dust(event)
    if not event.entity or not event.entity.valid or not event.entity.type ==
        "unit" or not event.entity.type == "unit-spawner" then return end
    if not event.cause and not event.cause.player then return end

    local player = event.cause.player
    if not player.valid then return end

    local entity = event.entity
    local surface = player.surface

    local biter_pixie_dust = Pixie.base_biter_pixie_dust
    if Pixie.biter_pixie_dust_values[entity.name] then
        biter_pixie_dust = Pixie.biter_pixie_dust_values[entity.name]
    end

    if not global.player_pixie_dust[force_name] or
        not global.player_pixie_dust[force_name][player.name] then
        Pixie.register_player(player.force.name, player.name)
    end

    local player_pixie_dust_stash =
        global.player_pixie_dust[player.force.name][player.name]

    local pixie_result = player_pixie_dust_stash + biter_pixie_dust
    global.player_pixie_dust[player.force.name][player.name] = pixie_result
    surface.create_entity(pixie_balance_message(entity.position, pixie_result))
end

commands.add_command('pixie-balance', 'Check your Pixie Balance', function(cmd)
    local player = game.player
    if global.player_pixie_dust[player.force.name] and
        global.player_pixie_dust[player.force.name][player.name] then
        game.print("Pixie Balance for " .. player.name .. " is " ..
                       global.player_pixie_dust[player.force.name][player.name],
                   {r = 255, g = 255, b = 0})
    else
        game.print("Join the game to get Pixie Dust", {r = 255, g = 255, b = 0})
    end
end)

return Pixie
