local Event = require('utils.event')
local Color = require('utils.color_presets')

local function on_player_died(event)
    if not storage.active_special_games['limited_lives'] then
        return
    end

    local player = game.get_player(event.player_index)
    local player_lives = storage.special_games_variables['limited_lives']['player_lives'][player.name]
    if player_lives == nil then
        player_lives = storage.special_games_variables['limited_lives']['lives_limit']
    end
    player_lives = player_lives - 1
    storage.special_games_variables['limited_lives']['player_lives'][player.name] = player_lives

    if player_lives == 0 then
        spectate(player)
    end

    player.print(
        table.concat({ 'You have', player_lives, ((player_lives == 1) and 'life' or 'lives'), 'left.' }, ' '),
        { color = Color.warning }
    )
end

local function generate_limited_lives(lives_limit)
    if storage.special_games_variables['limited_lives'] then
        rendering.destroy(storage.special_games_variables['limited_lives']['text_id'])
    end

    if lives_limit == 0 then
        -- reset special game
        storage.active_special_games['limited_lives'] = false
        storage.special_games_variables['limited_lives'] = nil
        return
    end

    storage.active_special_games['limited_lives'] = true
    storage.special_games_variables['limited_lives'] = {
        lives_limit = lives_limit,
        player_lives = {},
    }
    local special_game_description = table.concat({
        'Each player has only',
        lives_limit,
        ((lives_limit == 1) and 'life' or 'lives'),
        'until the end of the game.',
    }, ' ')
    storage.special_games_variables['limited_lives']['text_id'] = rendering.draw_text({
        text = special_game_description,
        surface = game.surfaces[storage.bb_surface_name],
        target = { -0, -12 },
        color = Color.warning,
        scale = 3,
        alignment = 'center',
        scale_with_zoom = false,
    })
    game.print('Special game Limited lives: ' .. special_game_description, { color = Color.warning })
end

local Public = {
    name = { type = 'label', caption = 'Limited lives', tooltip = 'Limits the number of player lives per game' },
    config = {
        [1] = { name = 'label1', type = 'label', caption = 'Number of lives' },
        [2] = { name = 'lives_limit', type = 'textfield', text = '1', numeric = true, width = 40 },
        [3] = { name = 'label2', type = 'label', caption = '(0 to reset)' },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        local lives_limit = tonumber(config['lives_limit'].text)

        generate_limited_lives(lives_limit)
    end,
}

function Public.has_life(player_name)
    local player_lives = storage.special_games_variables['limited_lives']['player_lives'][player_name]
    return player_lives == nil or player_lives > 0
end

Event.add(defines.events.on_player_died, on_player_died)

return Public
