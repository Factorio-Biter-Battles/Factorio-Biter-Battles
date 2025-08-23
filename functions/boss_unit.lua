local draw_text = rendering.draw_text
local draw_sprite = rendering.draw_sprite
local string_format = string.format
local math_floor = math.floor
local math_min = math.min
local tostring = tostring

local HEALTHBAR_SIZE = 15

--adds a health bar and health increase to a unit
local Public = {}

---@class HighHealthUnit
---@field entity LuaEntity
---@field health_factor number
---@field original_health_factor number?
---@field healthbar LuaRenderObject?
---@field text LuaRenderObject?

---@param health_factor number
---@return string
local function health_factor_to_rendered_string(health_factor)
    -- We print the number of revives remaining, so excluding the starting health
    health_factor = health_factor - 1
    if health_factor < 1 then
        return string_format('%.1f', health_factor)
    else
        return tostring(math_floor(health_factor))
    end
end

---@param entity LuaEntity
---@param health_factor number
local function add_health_factor_text(entity, health_factor)
    local text = health_factor_to_rendered_string(health_factor)
    return draw_text({
        text = text,
        draw_on_ground = true,
        surface = entity.surface,
        target = { entity = entity, offset = { 0, -3 } },
        scale = 1.5,
        alignment = 'center',
        color = { 1, 1, 1, 1 },
    })
end

---@param entity LuaEntity
---@param size number
local function create_healthbar(entity, size)
    return draw_sprite({
        sprite = 'virtual-signal/signal-white',
        tint = { 0, 200, 0 },
        x_scale = size * HEALTHBAR_SIZE,
        y_scale = size,
        render_layer = 'light-effect',
        target = { entity = entity, offset = { 0, -2.5 } },
        surface = entity.surface,
    })
end

---@param entity LuaEntity
---@param health_factor number
---@param is_boss boolean
function Public.add_high_health_unit(entity, health_factor, is_boss)
    if health_factor <= 1 then
        return
    end
    ---@type HighHealthUnit
    local unit = { entity = entity, health_factor = health_factor }
    if is_boss then
        unit.healthbar = create_healthbar(entity, 0.55)
        unit.original_health_factor = health_factor
    end
    if storage.bb_draw_health_factor_text then
        unit.text = add_health_factor_text(entity, health_factor)
    end
    storage.high_health_units[entity.unit_number] = unit
end

---@param entity LuaEntity
function Public.on_entity_damaged(entity)
    ---@type HighHealthUnit
    local unit = storage.high_health_units[entity.unit_number]
    if not unit then
        return
    end
    if entity.health == 0 then
        local adjustment = math_min(unit.health_factor - 1, 1)
        entity.health = entity.prototype.get_max_health() * adjustment
        unit.health_factor = unit.health_factor - adjustment
        local healthbar = unit.healthbar
        if healthbar and healthbar.valid then
            local ratio = unit.health_factor / unit.original_health_factor
            healthbar.x_scale = healthbar.y_scale * HEALTHBAR_SIZE * ratio
            healthbar.color = { math_floor(255 - 255 * ratio), math_floor(200 * ratio), 0 }
        end
        -- Slightly over 1 just to deal with weird floating point math possibilities
        if unit.health_factor <= 1.0000001 then
            storage.high_health_units[entity.unit_number] = nil
            -- We do not destroy unit.healthbar here because we want it to
            -- remain visible for the units "last life". It will automatically
            -- be destroyed when "entity" is destroyed.
            if unit.text and unit.text.valid then
                unit.text.destroy()
            end
        else
            if unit.text and unit.text.valid then
                unit.text.text = health_factor_to_rendered_string(unit.health_factor)
            end
        end
    end
end

return Public
