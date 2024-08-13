local Color = require('utils.color_presets')
local Tables = require('maps.biter_battles_v2.tables')

local function generate_disable_sciences(packs)
    local disabled_food = {
        ['automation-science-pack'] = packs[1],
        ['logistic-science-pack'] = packs[2],
        ['military-science-pack'] = packs[3],
        ['chemical-science-pack'] = packs[4],
        ['production-science-pack'] = packs[5],
        ['utility-science-pack'] = packs[6],
        ['space-science-pack'] = packs[7],
    }
    local message = { 'Special game generated. Disabled science:' }
    for k, v in pairs(disabled_food) do
        if v then
            table.insert(message, Tables.food_long_to_short[k].short_name)
        end
    end
    if table_size(message) > 1 then
        global.active_special_games['disable_sciences'] = true
        global.special_games_variables['disabled_food'] = disabled_food
        game.print(table.concat(message, ' '), Color.warning)
    else
        global.active_special_games['disable_sciences'] = false
        global.special_games_variables['disabled_food'] = nil
        game.print('Special game ended. All science enabled', Color.warning)
    end
end

local Public = {
    name = {
        type = 'label',
        caption = 'Disable sciences',
        tooltip = 'disable sciences that players wont be able to send.',
    },
    config = {
        [1] = { name = '1', type = 'sprite', sprite = 'item/automation-science-pack' },
        [2] = { name = 'red', type = 'checkbox', state = false },
        [3] = { name = '2', type = 'sprite', sprite = 'item/logistic-science-pack' },
        [4] = { name = 'green', type = 'checkbox', state = false },
        [5] = { name = '3', type = 'sprite', sprite = 'item/military-science-pack' },
        [6] = { name = 'gray', type = 'checkbox', state = false },
        [7] = { name = '4', type = 'sprite', sprite = 'item/chemical-science-pack' },
        [8] = { name = 'blue', type = 'checkbox', state = false },
        [9] = { name = '5', type = 'sprite', sprite = 'item/production-science-pack' },
        [10] = { name = 'purple', type = 'checkbox', state = false },
        [11] = { name = '6', type = 'sprite', sprite = 'item/utility-science-pack' },
        [12] = { name = 'yellow', type = 'checkbox', state = false },
        [13] = { name = '7', type = 'sprite', sprite = 'item/space-science-pack' },
        [14] = { name = 'white', type = 'checkbox', state = false },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        local packs = {
            config['red'].state,
            config['green'].state,
            config['gray'].state,
            config['blue'].state,
            config['purple'].state,
            config['yellow'].state,
            config['white'].state,
        }

        generate_disable_sciences(packs)
    end,
}

return Public
