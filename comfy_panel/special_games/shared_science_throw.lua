local Color = require('utils.color_presets')

local function generate_shared_science_throw()
    game.print(
        '[SPECIAL GAMES] All science throws are shared (if you send, both team gets +threat and +evo !)',
        Color.warning
    )
    game.print(
        '[SPECIAL GAMES] Evo and threat and threat income were reset to same value for both teams !',
        Color.warning
    )
    global.active_special_games['shared_science_throw'] = true
    if not global.special_games_variables['shared_science_throw'] then
        global.special_games_variables['shared_science_throw'] = {}
    end
    if global.special_games_variables['shared_science_throw']['text_id'] then
        rendering.destroy(global.special_games_variables['shared_science_throw']['text_id'])
    end
    local special_game_description = 'All science throws are shared (if you send, both teams gets +threat and +evo)'
    global.special_games_variables['shared_science_throw']['text_id'] = rendering.draw_text({
        text = special_game_description,
        surface = game.surfaces[global.bb_surface_name],
        target = { -0, 12 },
        color = Color.warning,
        scale = 3,
        alignment = 'center',
        scale_with_zoom = false,
    })
    local maxEvoFactor =
        math.max(game.forces['north_biters'].evolution_factor, game.forces['south_biters'].evolution_factor)
    game.forces['north_biters'].evolution_factor = maxEvoFactor
    game.forces['south_biters'].evolution_factor = maxEvoFactor
    local maxBbEvo = math.max(global.bb_evolution['north_biters'], global.bb_evolution['south_biters'])
    global.bb_evolution['north_biters'] = maxBbEvo
    global.bb_evolution['south_biters'] = maxBbEvo
    local maxThreatIncome = math.max(global.bb_threat_income['north_biters'], global.bb_threat_income['south_biters'])
    global.bb_threat_income['north_biters'] = maxThreatIncome
    global.bb_threat_income['south_biters'] = maxThreatIncome
    local maxThreat = math.max(global.bb_threat['north_biters'], global.bb_threat['south_biters'])
    global.bb_threat['north_biters'] = maxThreat
    global.bb_threat['south_biters'] = maxThreat
end

local Public = {
    name = {
        type = 'label',
        caption = 'Shared throws of science',
        tooltip = 'Science throws are shared between both teams',
    },
    config = {},
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        generate_shared_science_throw()
    end,
}

return Public
