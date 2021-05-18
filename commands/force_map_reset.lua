local Server = require 'utils.server'
local Color = require 'utils.color_presets'

local function force_map_reset(reason)
    local player = game.player

    if player and player ~= nil then
        if not player.admin then
            player.print("[ERROR] Command is admin-only. Please ask an admin.",
                         Color.warning)
            return
        elseif not reason or string.len(reason) <= 5 then
            player.print("[ERROR] Please enter reason, min length of 5")
        else
	    if not global.rocket_silo["north"].valid then
		game.print("[ERROR] Map is during reset already")
		return
	    end

            msg ="Admin " .. player.name .. " initiated map reset. Reason: " .. reason
            game.print(msg, Color.warning)
            Server.to_discord_embed(msg)
            local p = global.rocket_silo["north"].position
            global.rocket_silo["north"].die("south_biters")
        end
    end
end

commands.add_command('force-map-reset',
                     'force map reset by killing north silo: /force-map-reset <reason> ',
                     function(cmd) force_map_reset(cmd.parameter); end)
