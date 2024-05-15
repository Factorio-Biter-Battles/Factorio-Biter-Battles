local Server = require "utils.server"
local Color = require "utils.color_presets"
local Public = {}

---@param cmd CustomCommandData
---@param player LuaPlayer|nil
function Public.instant_map_reset(cmd, player)
	if player then
		if not player.admin then
			log("not admin player exists")
			player.print("[ERROR] You're not admin!", Color.fail)
			return
		end
	end
	--- This is a bit hacky. but In cases where we want to call this code from lua
	--- when we don't have a player (benchmarking) we don't want the call to crash
	--- if no player exists.
	if player == nil then
		player = {
			print = game.print,
			name = "unknown_server_god",
		}
	end
	-- Safely convert cmd.parameter to a number if given
	local param = cmd.parameter
	local next_map_seed
	local seed_source
	if param == "current" then
		next_map_seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
		seed_source = "current"
	elseif param then
		next_map_seed = (tonumber(param) or -1)
		if next_map_seed == nil or next_map_seed < 341 or next_map_seed > 4294967294 then
			player.print("Error: Seed must be between 341 and 4294967294 (inclusive).", Color.warning)
			return
		end
		seed_source = "specified"
	else
		next_map_seed = global.random_generator(341, 4294967294)
		seed_source = "autopicked"
	end
	global.next_map_seed = next_map_seed
	game.print("Restarting with " .. seed_source .. " map seed: " .. next_map_seed, Color.warning)
	Server.to_discord_bold("[Map Reset] " .. player.name .. " has reset the map! seed: " .. next_map_seed )
	global.server_restart_timer = 0
	require "maps.biter_battles_v2.game_over".server_restart()
end

commands.add_command(
	"instant-map-reset",
	"Force the map reset immediately and optionally set the seed (a number).  Should be between 341 - 4294967294 (inclusive). Running `/instant-map-reset seed` will give you the current seed",
	Public.instant_map_reset
)
return Public
