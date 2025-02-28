require('utils.data_stages')
_LIFECYCLE = _STAGE.control -- Control stage

require('utils.server')
require('utils.server_commands')
require('utils.utils')
require('utils.table')
require('utils.sounds')
--require 'utils.datastore.server_ups'
require('utils.datastore.color_data')
require('utils.datastore.session_data')
require('utils.datastore.jail_data')
require('utils.datastore.quickbar_data')
require('utils.datastore.message_on_join_data')
require('utils.datastore.player_tag_data')
require('utils.muted')

require('chatbot')
require('commands')
require('antigrief')
require('modules.corpse_markers')
require('modules.floaty_chat')
require('modules.show_inventory')

require('comfy_panel.main')
require('comfy_panel.player_list')
require('comfy_panel.admin')
require('comfy_panel.histories')
require('comfy_panel.group')
require('comfy_panel.poll')
require('comfy_panel.score')
require('comfy_panel.config')
require('comfy_panel.special_games')

---------------- ENABLE MAPS HERE ----------------
--![[North VS South Survival PVP, feed the opposing team's biters with science flasks. Disable Autostash, Group and Poll modules.]]--
require('maps.biter_battles_v2.main')
---------------------------------------------------------------

-- Controlled via external script
local BENCHMARKING_ENABLED = false
if BENCHMARKING_ENABLED then
    require('benchmarking.main')
end

local loaded = _G.package.loaded
function require(path)
    local path = '__level__/' .. path:gsub('%.', '/') .. '.lua'
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end

---------------- Central Dispatch of Events ----------------
local Event = require('utils.event')

-- Try to keep events and requires alphabetized

local AiTargets = require('maps.biter_battles_v2.ai_targets')
local Antigrief = require('antigrief')
local ComfyPanelScore = require('comfy_panel.score')
local Functions = require('maps.biter_battles_v2.functions')
local Terrain = require('maps.biter_battles_v2.terrain')

Event.add(defines.events.on_player_mined_entity, function(event)
    Functions.maybe_set_game_start_tick(event)
    local entity = event.entity
    if not entity.valid then
        return
    end

    local player = game.get_player(event.player_index)
    if player and player.valid then
        Antigrief.on_player_mined_entity(entity, player)
        ComfyPanelScore.on_player_mined_entity(entity, player)
        Terrain.minable_wrecks(entity, player)
    end
end)

Event.add(defines.events.on_player_mined_item, function(event)
    Functions.maybe_set_game_start_tick(event)
end)

Event.add(defines.events.on_pre_player_crafted_item, function(event)
    Functions.maybe_set_game_start_tick(event)
end)
