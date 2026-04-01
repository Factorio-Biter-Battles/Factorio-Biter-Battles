local Gui = require('utils.gui')

--- Shared utilities for feature flags;
--- currently exposes is_disabled() to guard against
--- inactive or resetting maps.

local Public = {}

---@return boolean True when multi-silo is not active, classic pathfinding is disabled, or the map is resetting.
function Public.is_disabled()
    -- storage.active_special_games.multi_silo can only be set by clicking a button in admin panel.
    -- storage.server_restart_timer indicates if map is scheduled for a reset.
    return storage.active_special_games.multi_silo == nil
        and not storage.bb_settings.classic_pathfinding
        and storage.server_restart_timer ~= nil
        and storage.server_restart_timer > 0
end

---Adds feature flag icons to the GUI to indicate whether multisilo or classic pathfinding are enabled.
---@param player LuaPlayer
function Public.update_feature_flag(player)
    if Public.is_disabled() then
        return
    end

    local t = Gui.get_top_element(player, 'bb_feature_flags')
    t.clear()
    
    if storage.active_special_games.multi_silo ~= nil then
        local button = t.add({
            type = 'sprite',
            name = 'multisilo_flag',
            resize_to_sprite = false,
            sprite = 'technology/rocket-silo',
        })
        
        button.style.height = 15
        button.style.width = 15
        button.tooltip = 'Multisilo enabled!\n' .. 'You spawn with one free rocket silo, the game ends when all silos on a team are destroyed'
    end
    
    if storage.bb_settings.classic_pathfinding then
        local button = t.add({
            type = 'sprite',
            name = 'classic_pathfinding_flag',
            resize_to_sprite = false,
            sprite = 'item/stone-wall',
        })
        
        button.style.height = 15
        button.style.width = 15
        button.tooltip = 'Classic pathfinding enabled!\n' .. 'Classic pathfinding gives attacks simpler paths coming from nests'
    end
end

return Public
