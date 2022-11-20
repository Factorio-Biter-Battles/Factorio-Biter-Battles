require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

require 'utils.server'
require 'utils.server_commands'
require 'utils.utils'
require 'utils.table'
require 'utils.freeplay'
--require 'utils.datastore.server_ups'
require 'utils.datastore.color_data'
require 'utils.datastore.session_data'
require 'utils.datastore.jail_data'
require 'utils.datastore.quickbar_data'
require 'utils.datastore.message_on_join_data'
require 'utils.datastore.player_tag_data'
require 'utils.muted'
require 'chatbot'
require 'commands'
require 'antigrief'
require 'modules.corpse_markers'
require 'modules.floaty_chat'
require 'modules.show_inventory'
require 'utils.debug.command'

require 'comfy_panel.main'
require 'comfy_panel.player_list'
require 'comfy_panel.admin'
require 'comfy_panel.histories'
require 'comfy_panel.group'
require 'comfy_panel.poll'
require 'comfy_panel.score'
require 'comfy_panel.config'
require 'comfy_panel.special_games'

--require 'modules.autostash'

---------------- !ENABLE MODULES HERE ----------------
--require 'modules.admins_operate_biters'
--require 'modules.the_floor_is_lava'
--require 'modules.biters_landfill_on_death'
--require 'modules.autodecon_when_depleted'
--require 'modules.biter_noms_you'
--require 'modules.biters_avoid_damage'
--require 'modules.biters_double_damage'
--require 'modules.burden'
--require 'modules.comfylatron'
--require 'modules.dangerous_goods'
--require 'modules.explosive_biters'
--require 'modules.explosive_player_respawn'
--require 'modules.explosives_are_explosive'
--require 'modules.fish_respawner'
--require 'modules.fluids_are_explosive'
--require 'modules.hunger'
--require 'modules.hunger_games'
--require 'modules.pistol_buffs'
--require 'modules.players_trample_paths'
--require 'modules.railgun_enhancer'
--require 'modules.restrictive_fluid_mining'
--require 'modules.satellite_score'
--require 'modules.show_health'
--require 'modules.splice_double'
--require 'modules.ores_are_mixed'
--require 'modules.team_teleport'
--require 'modules.surrounded_by_worms'
--require 'modules.no_blueprint_library'
--require 'modules.explosives'
--require 'modules.biter_pets'
--require 'modules.no_solar'
--require 'modules.biter_reanimator'
--require 'modules.force_health_booster'
--require 'modules.immersive_cargo_wagons.main'
--require 'modules.wave_defense.main'
--require 'modules.fjei.main'
--require 'modules.charging_station'
--require 'modules.nuclear_landmines'
--require 'modules.crawl_into_pipes'
--require 'modules.no_acid_puddles'
--require 'modules.simple_tags'
---------------------------------------------------------------

---------------- ENABLE MAPS HERE ----------------
--![[North VS South Survival PVP, feed the opposing team's biters with science flasks. Disable Autostash, Group and Poll modules.]]--
require 'maps.biter_battles_v2.main'

---------------------------------------------------------------

---------------- MORE MODULES HERE ----------------
--require 'modules.hidden_dimension.main'
--require 'modules.towny.main'
--require 'modules.rpg.main'
--require 'modules.rpg'
--require 'modules.trees_grow'
--require 'modules.trees_randomly_die'
---------------------------------------------------------------

---------------- MOSTLY TERRAIN LAYOUTS HERE ----------------
--require 'terrain_layouts.caves'
--require 'terrain_layouts.cone_to_east'
--require 'terrain_layouts.biters_and_resources_east'
--require 'terrain_layouts.scrap_01'
--require 'terrain_layouts.watery_world'
--require 'terrain_layouts.tree_01'
---------------------------------------------------------------

if _DUMP_ENV then
    require 'utils.dump_env'
end

local function on_player_created(event)
    local player = game.players[event.player_index]
    player.gui.top.style = 'slot_table_spacing_horizontal_flow'
    player.gui.left.style = 'slot_table_spacing_vertical_flow'
end

local loaded = _G.package.loaded
function require(path)
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end

local Event = require 'utils.event'
Event.add(defines.events.on_player_created, on_player_created)
