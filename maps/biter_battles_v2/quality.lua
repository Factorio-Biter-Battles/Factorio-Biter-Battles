local _TEST = storage['_TEST'] or false

local gui = nil
local gui_style = nil
if not _TEST then
    gui = require('utils.gui')
    gui_style = require('utils.utils').gui_style
end

local color = require('utils.color_presets')
local food_values = require('maps.biter_battles_v2.tables').food_values
local math_log = math.log
local math_random = math.random
local string_find = string.find
local string_sub = string.sub
local mod = {}

if not _TEST then
    ---Adds quality icon into GUI.
    function mod.update_feature_flag(player)
        if not mod.enabled() then
            return
        end

        local t = gui.get_top_element(player, 'bb_feature_flags')
        local button = t.add({
            type = 'sprite',
            name = 'quality_gui',
            sprite = 'utility/any_quality',
        })
        button.style.maximal_height = 25
        button.tooltip = 'Quality enabled!'
    end

    ---Handles state when player toggles quality mod in comfy panel.
    function mod.on_gui_switch_state_changed(event)
        local p = game.get_player(event.player_index)
        local s = game.surfaces[storage.bb_surface_name]
        if event.element.switch_state == 'left' then
            storage.comfy_panel_config.quality_scheduled = true
            s.print('Quality mod enabled by ' .. p.name, { color = color.yellow })
        else
            storage.comfy_panel_config.quality_scheduled = false
            s.print('Quality mod disabled by ' .. p.name, { color = color.yellow })
        end
    end
end

---@class TierEntry
---@field name string Name of quality.
---@field multiplier number Multiplier associated with given quality which impacts chance calculation
---@field level number Integer that directly maps to LuaQualityPrototype.

---@type TierEntry[]
mod.TIERS = {
    {
        name = 'normal',
        multiplier = 1,
        level = 0,
    },
    {
        name = 'uncommon',
        multiplier = 1.5,
        level = 1,
    },
    {
        name = 'rare',
        multiplier = 2.25,
        level = 2,
    },
    {
        name = 'epic',
        multiplier = 3.5,
        level = 3,
    },
    {
        name = 'legendary',
        multiplier = 5,
        level = 5,
    },
}

---Maps to normal quality tier. Useful when trying to write code that is both
---compatible with vanilla and quality mod.
mod.TIER_DEFAULT = 1

---Utility function to find entry position in mod.TIERS by level.
---@param level number
---@return number?
function mod.tier_index_by_level(level)
    for i, v in ipairs(mod.TIERS) do
        if v.level == level then
            return i
        end
    end

    return nil
end

---Utility function to find entry position in mod.TIERS by name.
---@param name string
---@return number?
function mod.tier_index_by_name(name)
    for i, v in ipairs(mod.TIERS) do
        if v.name == name then
            return i
        end
    end

    return nil
end

---Get numbers of available quality tiers. In base game, only normal quality is available.
---@return number Number of quality tiers
function mod.available_tiers()
    if mod.enabled() then
        return #mod.TIERS
    end

    return 1
end

---Generate tooltip for quality selection button.
---@param tier number Quality tier
---@return string
local function button_tooltip(tier)
    local tooltip = 'Quality of food\nMutagen multiplier ' .. mod.TIERS[tier].multiplier .. 'x'
    if tier > 1 then
        tooltip = tooltip .. '\nBoosts chance of ' .. mod.TIERS[tier].name .. ' biters'
    end

    return tooltip .. '\nLMB - Increase quality, RMB - Lower quality'
end

---Handle clicks of quality button in feeding menu.
function mod.on_gui_click(event)
    local player = game.players[event.player_index]
    local tier = storage.quality_feed_selected[player.index]
    if event.button == defines.mouse_button_type.left then
        if tier == #mod.TIERS then
            return
        end

        tier = tier + 1
    elseif event.button == defines.mouse_button_type.right then
        if tier == 1 then
            return
        end

        tier = tier - 1
    end

    storage.quality_feed_selected[player.index] = tier
    local sprite = 'quality/' .. mod.TIERS[tier].name
    event.element.sprite = sprite
    event.element.tooltip = button_tooltip(tier)
end

---Generate button in feeding menu for quality selection.
---@param player LuaPlayer
---@param parent LuaGuiElement
function mod.add_feeding_button(player, parent)
    if not mod.enabled() then
        return
    end

    local tier = storage.quality_feed_selected[player.index]
    if not tier then
        tier = 1
        storage.quality_feed_selected[player.index] = tier
    end

    local f = parent.add({
        type = 'sprite-button',
        name = 'quality_feed',
        sprite = 'quality/' .. mod.TIERS[tier].name,
        style = 'slot_button',
        tooltip = button_tooltip(tier),
    })
    gui_style(f, {
        padding = 0,
    })
end

---Return multiplier for selected quality by given player in feeding menu.
---@return number
function mod.multiplier(player)
    local id = storage.quality_feed_selected[player.index]
    return mod.TIERS[id].multiplier
end

---Check which quality is selected by given player in feeding menu.
---@param player LuaPlayer
---@return number Position number
function mod.selected_by(player)
    -- If we're just starting, return default value.
    local id = storage.quality_feed_selected[player.index]
    if not id then
        return mod.TIER_DEFAULT
    end

    return id
end

---Roll a dice for selected biter quality and force.
---@param tier number Selected quality of biter.
---@param force string Biter force name.
---@return boolean If quality biter was rolled or not.
function mod.roll(tier, force)
    local c = mod.chance(tier, force)
    local r = math_random(0, 100)
    return r <= (c * 100)
end

---Applies scaling formula on accumulated value of fed flasks so far.
---@param value number Accumulated value from past feeding.
---@return number Chance to roll biter in range of [0.0 - 1.0]
local function compute_chance(value)
    local chance = math_log(1.1 * value + 1) / math_log(100)
    if chance > 1.0 then
        chance = 1.0
    end

    return chance
end

---Roll chance of selected biter quality within given force.
---@param tier number Selected quality of biter.
---@param force string Biter force name.
---@return number Chance to roll biter in range of [0.0 - 1.0]
function mod.chance(tier, force)
    if string_find(force, '_boss') then
        force = string_sub(force, 1, -6)
    end

    return compute_chance(storage.quality_value[force][tier])
end

---Does the same as feed_flasks, but result is not stored anywhere.
---@param value number Accumulated value from past feeding.
---@param name string Name of the flask.
---@param amount number Amount of flasks.
---@param diff_value number Difficulty modifier.
---@return number New update value
function mod.dry_feed_flasks(value, name, amount, diff_value)
    return value + (food_values[name].value * diff_value * amount)
end

---Calculate impact of value on chance for given biter force and tier quality.
---@param value number Value added to current chance.
---@param tier number Tier quality.
---@param force string Name of biter force.
---@return number Difference between old and new expected chance.
function mod.chance_difference(value, tier, force)
    value = compute_chance(value + storage.quality_value[force][tier])
    local curr = compute_chance(storage.quality_value[force][tier])
    if value > 1.0 then
        value = 1.0 - curr
    else
        value = value - curr
    end

    return value
end

---Updates the permament chance of rolling quality biters.
---@param name string Name of the flask.
---@param amount number Amount of flasks.
---@param tier number Quality of flasks.
---@param force string Name of biter force to which new chance is applied.
function mod.feed_flasks(name, amount, tier, force)
    local value = storage.quality_value[force][tier]
    storage.quality_value[force][tier] = mod.dry_feed_flasks(value, name, amount, storage.difficulty_vote_value)
end

---Initialize data related to quality mod. Meant to be called on each map reset.
function mod.init()
    storage.quality_enabled = storage.comfy_panel_config.quality_scheduled
    ---Currently selected quality by player within feeding menu.
    ---@type { [number]: number }
    storage.quality_feed_selected = {}
    ---Stores basic accumulated value of all feed flasks. This value is used
    ---later to calculate roll chance of higher quality biters on-demand.
    ---@type { [string]: number[] }
    storage.quality_value = {
        ['north_biters'] = {},
        ['south_biters'] = {},
    }

    for i = 1, #mod.TIERS do
        storage.quality_value['north_biters'][i] = 0.0
        storage.quality_value['south_biters'][i] = 0.0
    end

    -- 100% chance to get common biters
    storage.quality_value['north_biters'][1] = 999999
    storage.quality_value['south_biters'][1] = 999999
end

---Setup technology tree. Meant to be called on each map reset.
---@param force LuaForce
function mod.set_technologies(force)
    local technologies = force.technologies
    if mod.enabled() then
        technologies['quality-module'].enabled = true
        technologies['quality-module-2'].enabled = true
        technologies['quality-module-3'].enabled = true
        technologies['recycling'].enabled = true
        technologies['epic-quality'].enabled = true
        technologies['legendary-quality'].enabled = true
    elseif mod.installed() then
        technologies['quality-module'].enabled = false
        technologies['quality-module-2'].enabled = false
        technologies['quality-module-3'].enabled = false
        technologies['recycling'].enabled = false
        technologies['epic-quality'].enabled = false
        technologies['legendary-quality'].enabled = false
    end
end

---@return boolean
function mod.installed()
    return script.feature_flags.quality
end

---@return boolean
function mod.scheduled()
    return storage.comfy_panel_config.quality_scheduled
end

---@return boolean
function mod.enabled()
    return storage.quality_enabled
end

return mod
