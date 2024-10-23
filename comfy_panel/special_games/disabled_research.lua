local Color = require('utils.color_presets')

local function generate_disabled_research(team, eq)
    if not storage.special_games_variables['disabled_research'] then
        storage.special_games_variables['disabled_research'] = { ['north'] = {}, ['south'] = {} }
    end
    storage.active_special_games['disabled_research'] = true
    local tab = {
        ['left'] = 'north',
        ['right'] = 'south',
    }
    if tab[team] then
        for k, v in pairs(eq) do
            table.insert(storage.special_games_variables['disabled_research'][tab[team]], v)
            game.forces[tab[team]].technologies[v].enabled = false
        end
        game.print(
            'Special game Disabled research: '
                .. table.concat(eq, ', ')
                .. ' for team '
                .. tab[team]
                .. ' is being generated!',
            { color = Color.warning }
        )
        return
    end

    for k, v in pairs(eq) do
        table.insert(storage.special_games_variables['disabled_research']['south'], v)
        table.insert(storage.special_games_variables['disabled_research']['north'], v)
        game.forces['north'].technologies[v].enabled = false
        game.forces['south'].technologies[v].enabled = false
    end
    game.print(
        'Special game Disabled research: ' .. table.concat(eq, ', ') .. ' for both teams is being generated!',
        { color = Color.warning }
    )
end

local function reset_disabled_research(team)
    if not storage.active_special_games['disabled_research'] then
        return
    end
    local tab = {
        ['left'] = 'north',
        ['right'] = 'south',
    }
    if tab[team] then
        for k, v in pairs(storage.special_games_variables['disabled_research'][tab[team]]) do
            game.forces[tab[team]].technologies[v].enabled = true
        end
        storage.special_games_variables['disabled_research'][tab[team]] = {}
        game.print('All disabled research has been enabled again for team ' .. tab[team], { color = Color.warning })
        return
    else
        for k, v in pairs(storage.special_games_variables['disabled_research']['north']) do
            game.forces['north'].technologies[v].enabled = true
        end
        for k, v in pairs(storage.special_games_variables['disabled_research']['south']) do
            game.forces['south'].technologies[v].enabled = true
        end
        storage.special_games_variables['disabled_research']['north'] = {}
        storage.special_games_variables['disabled_research']['south'] = {}
        game.print('All disabled research has been enabled again for both teams', { color = Color.warning })
    end
end

local Public = {
    name = {
        type = 'label',
        caption = 'Disabled research',
        tooltip = 'Disables chosen technologies from being researched',
    },
    config = {
        [1] = { name = 'eq1', type = 'choose-elem-button', elem_type = 'technology' },
        [2] = { name = 'eq2', type = 'choose-elem-button', elem_type = 'technology' },
        [3] = { name = 'eq3', type = 'choose-elem-button', elem_type = 'technology' },
        [4] = { name = 'eq4', type = 'choose-elem-button', elem_type = 'technology' },
        [5] = { name = 'eq5', type = 'choose-elem-button', elem_type = 'technology' },
        [6] = { name = 'eq6', type = 'choose-elem-button', elem_type = 'technology' },
        [7] = { name = 'eq7', type = 'choose-elem-button', elem_type = 'technology' },
        [8] = {
            name = 'team',
            type = 'switch',
            switch_state = 'none',
            allow_none_state = true,
            tooltip = 'North / Both / South',
        },
        [9] = {
            name = 'reset_disabled_research',
            type = 'button',
            caption = 'Reset',
            tooltip = 'Enable all the disabled research again',
        },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        local team = config['team'].switch_state
        local eq = {
            config['eq1'].elem_value,
            config['eq2'].elem_value,
            config['eq3'].elem_value,
            config['eq4'].elem_value,
            config['eq5'].elem_value,
            config['eq6'].elem_value,
            config['eq7'].elem_value,
        }

        generate_disabled_research(team, eq)
    end,
    gui_click = function(element, config, player)
        if element.name == 'reset_disabled_research' then
            config = element.parent.parent.children[2]
            local team = config['team'].switch_state
            reset_disabled_research(team)
        end
    end,
}

return Public
