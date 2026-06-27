--- Shared utilities for multi-silo;
--- currently exposes is_disabled() to guard against
--- inactive or resetting maps.

local Public = {}

---@return boolean True when multi-silo is not active or the map is resetting.
function Public.is_disabled()
    -- storage.active_special_games.multi_silo can only be set by clicking a button in admin panel.
    -- storage.server_restart_timer indicates if map is scheduled for a reset.
    return storage.active_special_games.multi_silo == nil or storage.server_restart_timer
end

return Public
