local Event = require 'utils.event'
local Color = require 'utils.color_presets'

local function generate_disabled_entities(team, eq)
	if not global.special_games_variables["disabled_entities"] then
		global.special_games_variables["disabled_entities"] = {["north"] = {}, ["south"] = {}}
	end
	local tab = {}
	for k, v in pairs(eq) do
		if v then
			tab[v] = true
		end
	end
	if team == "left" then
		global.special_games_variables["disabled_entities"]["north"] = tab
		game.print("Special game Disabled entities: ".. table.concat(eq, ", ") .. " for team North is being generated!", Color.warning)
	elseif team == "right" then
		global.special_games_variables["disabled_entities"]["south"] = tab
		game.print("Special game Disabled entities: ".. table.concat(eq, ", ") .. " for team South is being generated!", Color.warning)
	else
		global.special_games_variables["disabled_entities"]["south"] = tab
		global.special_games_variables["disabled_entities"]["north"] = tab
		game.print("Special game Disabled entities: ".. table.concat(eq, ", ") .. " for both teams is being generated!", Color.warning)
	end
	global.active_special_games["disabled_entities"] = true
end

local function on_built_entity(event)
	if not global.active_special_games["disabled_entities"] then return end
	local entity = event.created_entity
	if not entity then return end
	if not entity.valid then return end

	local player = game.get_player(event.player_index)
	local force = player.force
	if global.special_games_variables["disabled_entities"][force.name][entity.name] then
		player.create_local_flying_text({text = "Disabled by special game", position = entity.position})
		player.get_inventory(defines.inventory.character_main).insert({name = entity.name, count = 1})
		entity.destroy()
	end
end

local Public = {
    name = {type = "label", caption = "Disabled entities", tooltip = "Disables chosen entities from being placed"},
    config = {
        [1] = {name = "eq1", type = "choose-elem-button", elem_type = "item"},
        [2] = {name = "eq2", type = "choose-elem-button", elem_type = "item"},
        [3] = {name = "eq3", type = "choose-elem-button", elem_type = "item"},
        [4] = {name = "eq4", type = "choose-elem-button", elem_type = "item"},
        [5] = {name = "eq5", type = "choose-elem-button", elem_type = "item"},
        [6] = {name = "eq6", type = "choose-elem-button", elem_type = "item"},
        [7] = {name = "eq7", type = "choose-elem-button", elem_type = "item"},
        [8] = {name = "team", type = "switch", switch_state = "none", allow_none_state = true, tooltip = "North / Both / South"},
    },
    button = {name = "apply", type = "button", caption = "Apply"},
    generate = function (config, player)
		local team = config["team"].switch_state
		local eq = {}
		for v = 1, 1, 7 do
			if config["eq"..v].elem_value then
				eq[config["eq"..v].elem_value] = true
			end
		end
		eq = {
			config["eq1"].elem_value,
			config["eq2"].elem_value,
			config["eq3"].elem_value,
			config["eq4"].elem_value,
			config["eq5"].elem_value,
			config["eq6"].elem_value,
			config["eq7"].elem_value
		}
		generate_disabled_entities(team, eq)
    end,
}

Event.add(defines.events.on_built_entity, on_built_entity)

return Public
