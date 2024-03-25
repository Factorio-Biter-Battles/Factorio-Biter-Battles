local Server = require 'utils.server'
local Color = require 'utils.color_presets'

commands.add_command(
    'instant-map-reset',
    'Force the map reset immediately and optionally set the seed (a number).  Should be between 341 - 4294967294 (inclusive). Running `/instant-map-reset seed` will give you the current seed',
    function(cmd)
        local player = game.player
        if player then
            if not player.admin then
                player.print("[ERROR] You're not admin!", Color.fail)
                return
            end
        end

        -- Safely convert cmd.parameter to a number if given
        local param = cmd.parameter
        if param then
            local new_rng_seed = tonumber(param)

            -- Check if conversion was successful and the number is in the correct range
            if new_rng_seed then
                if new_rng_seed < 341 or new_rng_seed > 4294967294 then
                    player.print("Error: Seed must be between 341 and 4294967294 (inclusive).", Color.warning)
                    return
                else
                    global.next_map_seed = new_rng_seed
                    game.print("Restarting with map seed: " .. new_rng_seed, Color.warning)
                    Server.to_discord_bold(table.concat {"[Map Reset] " .. player.name .. " has reset the map! seed: " .. new_rng_seed})
                    global.server_restart_timer = 0
                    require "maps.biter_battles_v2.game_over".server_restart()
                end
            else
                local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
                player.print("Error: The parameter should be a number. Current seed: " ..  seed, Color.warning)
                return
            end
        else
            global.next_map_seed = global.random_generator(341, 4294967294)
            game.print("Restarting with autopicked map seed: " .. global.next_map_seed, Color.warning)
			Server.to_discord_bold(table.concat {"[Map Reset] " .. player.name .. " has reset the map! seed: " .. global.next_map_seed})
            global.server_restart_timer = 0
            require "maps.biter_battles_v2.game_over".server_restart()
        end
    end
)
