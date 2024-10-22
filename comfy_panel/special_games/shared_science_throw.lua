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
    storage.active_special_games['shared_science_throw'] = true
    if not storage.special_games_variables['shared_science_throw'] then
        storage.special_games_variables['shared_science_throw'] = {}
    end
    if storage.special_games_variables['shared_science_throw']['text_id'] then
        rendering.destroy(storage.special_games_variables['shared_science_throw']['text_id'])
    end
    local special_game_description = 'All science throws are shared (if you send, both teams gets +threat and +evo)'
    storage.special_games_variables['shared_science_throw']['text_id'] = rendering.draw_text({
        text = special_game_description,
        surface = game.surfaces[storage.bb_surface_name],
        target = { -0, 12 },
        color = Color.warning,
        scale = 3,
        alignment = 'center',
        scale_with_zoom = false,
    })
    local surf = storage.bb_surface_name
    local maxEvoFactor = math.max(
        game.forces['north_biters'].get_evolution_factor(surf),
        game.forces['south_biters'].get_evolution_factor(surf)
    )
    game.forces['north_biters'].set_evolution_factor(maxEvoFactor, surf)
    game.forces['south_biters'].set_evolution_factor(maxEvoFactor, surf)
    local maxBbEvo = math.max(storage.bb_evolution['north_biters'], storage.bb_evolution['south_biters'])
    storage.bb_evolution['north_biters'] = maxBbEvo
    storage.bb_evolution['south_biters'] = maxBbEvo
    local maxThreatIncome = math.max(storage.bb_threat_income['north_biters'], storage.bb_threat_income['south_biters'])
    storage.bb_threat_income['north_biters'] = maxThreatIncome
    storage.bb_threat_income['south_biters'] = maxThreatIncome
    local maxThreat = math.max(storage.bb_threat['north_biters'], storage.bb_threat['south_biters'])
    storage.bb_threat['north_biters'] = maxThreat
    storage.bb_threat['south_biters'] = maxThreat
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
