-- Surface day/night presets for the BB map (always day, cycle, always night).

local Public = {}

---Values stored in storage.bb_settings.daytime_cycle and matched in apply.
---@alias DaytimeCycleKey "always_day"|"day_night_cycle"|"always_night"

---One comfy-panel preset: label for UI plus surface fields to copy on apply.
---@class DaytimeCycleOption
---@field key DaytimeCycleKey
---@field label string
---@field always_day boolean
---@field freeze_daytime boolean
---@field daytime number

---@type DaytimeCycleOption[]
Public.daytime_cycle_options = {
    {
        key = 'always_day',
        label = 'Always Day',
        always_day = true,
        freeze_daytime = true,
        daytime = 0,
    },
    {
        key = 'day_night_cycle',
        label = 'Day-Night',
        always_day = false,
        freeze_daytime = false,
        daytime = 0,
    },
    {
        key = 'always_night',
        label = 'Always Night',
        always_day = false,
        freeze_daytime = true,
        daytime = 0.5,
    },
}

---Get labels in option order
---@return string[]
function Public.get_daytime_cycle_labels()
    local labels = {}
    for _, opt in ipairs(Public.daytime_cycle_options) do
        labels[#labels + 1] = opt.label
    end
    return labels
end

---Looks up the caption for a stored cycle key.
---@param key string?
---@return string?
function Public.get_daytime_cycle_label(key)
    if not key then
        return nil
    end
    for _, opt in ipairs(Public.daytime_cycle_options) do
        if opt.key == key then
            return opt.label
        end
    end
    return nil
end

---Applies daytime settings from storage.bb_settings.daytime_cycle.
---@param surface LuaSurface
function Public.apply_daytime_settings(surface)
    local setting = storage.bb_settings.daytime_cycle or 'always_day'
    for _, opt in ipairs(Public.daytime_cycle_options) do
        if opt.key == setting then
            surface.always_day = opt.always_day
            surface.daytime = opt.daytime
            surface.freeze_daytime = opt.freeze_daytime
            return
        end
    end
    surface.always_day = true
end

return Public
