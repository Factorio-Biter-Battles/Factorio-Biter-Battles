local Functions_clear_corpses = require('maps.biter_battles_v2.functions').clear_corpses
local Utils_safe_wrap_cmd = require('utils.utils').safe_wrap_cmd
local Session = require('utils.datastore.session_data')
local Color_fail = require('utils.color_presets').fail
local Color_warning = require('utils.color_presets').warning

local trusted_max_radius = 500

local function clear_corpses(cmd)
    local player = game.get_player(cmd.player_index)
    local trusted = Session.get_trusted_table()
    local param = tonumber(cmd.parameter) or storage.default_clear_corpses_radius

    if not player or not player.valid then
        return
    end

    if not trusted[player.name] and not is_admin(player) and param > storage.default_clear_corpses_radius then
        player.print(
            '[INFO] Replaced radius with max allowable value for untrusted players: '
                .. storage.default_clear_corpses_radius,
            { color = Color_warning }
        )
        param = storage.default_clear_corpses_radius
    end
    if param < 0 then
        player.print('[ERROR] Value must be positive.', { color = Color_fail })
        return
    end
    if param > 500 then
        player.print(
            '[INFO] Replaced radius with max allowable value:  ' .. trusted_max_radius,
            { color = Color_warning }
        )
        param = trusted_max_radius
    end

    Functions_clear_corpses(player, param)
end

commands.add_command('clear-corpses', 'Clears all the biter corpses..', function(cmd)
    Utils_safe_wrap_cmd(cmd, clear_corpses, cmd)
end)
