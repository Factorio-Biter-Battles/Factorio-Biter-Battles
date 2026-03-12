-- Control-stage require override.
--
-- Wraps the built-in require to support directory-style modules whose entry
-- point is an init.lua file (e.g. requiring 'comfy_panel.special_games.multi_silo'
-- when only comfy_panel/special_games/multi_silo/init.lua exists).
--
-- Resolution order:
--   1. Return immediately if the module is already in package.loaded.
--   2. Try the built-in require (handles normal 'path/to/module.lua' files).
--   3. Fallback: try requiring modname .. '.init' (handles 'path/to/module/init.lua').
--      On success, caches the result under the original modname so that subsequent
--      require(modname) calls hit the cache in step 1 without re-executing.
--
-- This override is active only during the control stage (lines below).
-- After all modules are loaded, it is replaced by the runtime lockdown version.
local _base_require = require
---@param modname string Module path in dot notation (e.g. 'comfy_panel.special_games.multi_silo').
---@return unknown result The loaded module's return value.
function require(modname)
    if package.loaded[modname] ~= nil then
        return package.loaded[modname]
    end
    -- pcall is needed because Factorio's require throws for both "file not found"
    -- and "file has errors", and there is no other way to test file existence.
    -- We only want to fall through to the init.lua fallback on "not found";
    -- real errors (syntax/runtime bugs in the module) must be re-raised.
    local ok, result = pcall(_base_require, modname)
    if ok then
        return result
    end
    if type(result) == 'string' and not result:find('not found') then
        error(result, 2)
    end
    local init_result = _base_require(modname .. '.init')
    -- Cache under the original modname: _base_require above cached it under
    -- modname..'.init', but callers use the short name.  Without this, the
    -- next require(modname) would miss the cache, fall through, and re-execute
    -- the module file with all its side effects.
    package.loaded[modname] = init_result
    return init_result
end

require('utils.data_stages')
_LIFECYCLE = _STAGE.control -- Control stage

require('utils.server')
require('utils.server_commands')
require('utils.utils')
require('utils.table')
require('utils.admin')
require('utils.sounds')
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

-- Runtime require lockdown.
--
-- Replaces the control-stage require above so that no new code can be loaded
-- after the control stage finishes.  Instead of invoking the Lua loader, this
-- version only looks up modules that were already loaded and registered in
-- _G.package.loaded by Factorio's internal loader.
--
-- Factorio stores loaded modules under keys prefixed with '__level__/':
--   - Direct files:     __level__/path/to/module.lua
--   - Directory modules: __level__/path/to/module/init.lua
--
-- Resolution order:
--   1. Convert the dot-notation path to the __level__/ prefix format.
--   2. Try the '.lua' key first (normal file).
--   3. Fallback: try the '/init.lua' key (directory module with init.lua).
--   4. Error if neither key exists -- the module was not loaded in the control stage.
--
-- This function is used both immediately after the control stage (lines below)
-- and by any event handler that calls require() at runtime.
local loaded = _G.package.loaded
---@param path string Module path in dot notation (e.g. 'utils.event').
---@return unknown result The previously loaded module's return value.
function require(path)
    local path = '__level__/' .. path:gsub('%.', '/')
    return loaded[path .. '.lua']
        or loaded[path .. '/init.lua']
        or error('Can only require files at runtime that have been required in the control stage.', 2)
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
