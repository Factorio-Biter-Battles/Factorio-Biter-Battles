local Gui = require('utils.gui')

local Public = {}

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

    for _, flag in pairs(storage.feature_flags) do
        if flag.enabled then
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

local function evaluate_all()
    for _, p in pairs(game.players) do
        if p.connected then
            Public.evaluate_feature_flags(p)
        end
    end
end

---Registers a feature flag. All players are updated following registration.
---It is safe to register the same flag multiple times.
---@param name string the feature name
---@param sprite_path string
---@param tooltip string
---@param enabled boolean
function Public.register_feature_flag(name, sprite_path, tooltip, enabled)
    if enabled == nil then
        enabled = true
    end
    if storage.feature_flags[name] == nil then
        local feature_flag = {
            name = name,
            sprite_path = sprite_path,
            tooltip = tooltip,
            enabled = enabled,
        }
        storage.feature_flags[name] = feature_flag
    end

    evaluate_all()
end

---Turns on a feature flag which has already been registered
---@param name string
function Public.enable_feature_flag(name)
    if storage.feature_flags[name] ~= nil then
        storage.feature_flags[name].enabled = true
    end

    evaluate_all()
end

---Turns off a feature flag which has already been registered
---@param name string
function Public.disable_feature_flag(name)
    if storage.feature_flags[name] ~= nil then
        storage.feature_flags[name].enabled = false
    end

    evaluate_all()
end

return Public
