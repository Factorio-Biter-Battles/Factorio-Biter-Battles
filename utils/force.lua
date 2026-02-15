--- Shared utilities for biter/player force name translation.
local Public = {}

--- Derive the target player force name from any biter force name.
--- Works for regular (`north_biters`) and boss (`north_biters_boss`) forces.
---@param force_name string  A biter force name, e.g. 'south_biters_boss'.
---@return string|nil        'north' or 'south', or nil if the name doesn't match.
function Public.get_player_force_name(force_name)
    return force_name:match('^(.-)_biters')
end

return Public
