local Gui = require('utils.gui')

local Public = {}
local feature_flags = {}

---@return boolean True when the map is resetting.
local function is_disabled()
    -- storage.server_restart_timer indicates if map is scheduled for a reset.
    return storage.server_restart_timer ~= nil and storage.server_restart_timer > 0
end

---Updates the GUI with all feature flags that are enabled
---@param player LuaPlayer 
function Public.evaluate_feature_flags(player)
    if is_disabled() then
        return
    end

    local t = Gui.get_top_element(player, 'bb_feature_flags')
    t.clear()

    for _, flag in pairs(feature_flags) do
        if flag.active_fn() then
            local button = t.add({
                type = 'sprite',
                name = flag.name,
                resize_to_sprite = false,
                sprite = flag.sprite_path,
            })

            button.style.height = 15
            button.style.width = 15
            button.tooltip = flag.tooltip
        end
    end
end

---Registers a feature flag. All players are updated following registration. 
---It is safe to register the same flag multiple times.
---@param name string the feature name
---@param sprite_path string
---@param tooltip string
---@param active_fn function evaluated to determine whether or not the flag should be rendered
function Public.register_feature_flag(name, sprite_path, tooltip, active_fn)
    local existing_flag = nil
    for _, flag in pairs(feature_flags) do
        if flag.name == name then
            existing_flag = flag
        end
    end

    if existing_flag == nil then
        local feature_flag = {
            name = name,
            sprite_path = sprite_path,
            tooltip = tooltip,
            active_fn = active_fn,
        }

        table.insert(feature_flags, feature_flag)
    end

    for _, p in pairs(game.players) do
        if p.connected then
            Public.evaluate_feature_flags(p)
        end
    end
end

return Public
