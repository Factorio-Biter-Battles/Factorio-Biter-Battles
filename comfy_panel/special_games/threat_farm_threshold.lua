local color_presets = require('utils.color_presets')

local Public = {
    name = {
        type = 'label',
        caption = 'threat threshold',
        tooltip = 'threat cant fall below threshold, fraction of excess threat is send to enemy',
    },
    config = {
        [1] = { name = 'l1', type = 'label', caption = 'minimum threat amount' },
        [2] = {
            name = 'threat_threshold',
            type = 'textfield',
            numeric = true,
            allow_negative = true,
            width = 80,
            text = 0,
        },
        [3] = { name = 'l2', type = 'label', caption = 'fraction of excess threat, send to enemy' },
        [4] = {
            name = 'excess_threat_send_fraction',
            type = 'textfield',
            numeric = true,
            allow_decimal = true,
            allow_negative = true,
            width = 40,
            text = 0.5,
        },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
    generate = function(config, player)
        local variables = {
            threat_threshold = tonumber(config['threat_threshold'].text),
            excess_threat_send_fraction = tonumber(config['excess_threat_send_fraction'].text),
        }

        if not (variables.threat_threshold and variables.excess_threat_send_fraction) then
            game.print('invalid configuration, only numbers allowed', color_presets.warning)
            return
        end
        storage.active_special_games['threat_farm_threshold'] = true
        storage.special_games_variables['threat_farm_threshold'] = variables

        game.print(
            'Threat threshold enabled! Excess threat below '
                .. variables.threat_threshold
                .. ' will be added to opponent with a factor of '
                .. variables.excess_threat_send_fraction,
            color_presets.warning
        )
    end,
}
return Public
