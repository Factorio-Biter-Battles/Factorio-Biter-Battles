local Public = {}

--works only with custom surfaces (requires [gps= x, v, surface] format)
function Public.position_from_gps_tag(text)
    local a, b = string.find(text, 'gps=')
    if b then
        local dot = string.find(text, ',', b)
        local ending = string.find(text, ',', dot + 1)
        local pos = {}
        pos.x = tonumber(string.sub(text, b + 1, dot - 1))
        pos.y = tonumber(string.sub(text, dot + 1, ending - 1))
        return pos
    end
    return nil
end

---@param s string
---Sanitizes GPS tags, e.g. [gps=xxx]. All the contents inside it
---is going to be substituted with 'redacted'.
function Public.sanitize_gps_tags(s)
    local found = nil
    ---@type integer|nil
    local tag_open = 1
    while true do
        found, tag_open = string.find(s, '%[gps=', tag_open)
        if not found then
            break
        end

        local tag_close, _ = string.find(s, '%]', tag_open)
        if not tag_close then
            break
        end

        s = string.sub(s, 1, tag_open) .. 'redacted' .. string.sub(s, tag_close)
    end

    return s
end

---@param s string
---Checks if the string has gps tag anywhere in the message.
---Must be called after it was it was sanitized.
function Public.has_sanitized_gps_tag(s)
    local found, _ = string.find(s, '%[gps=redacted%]')
    return found ~= nil
end

---@param s string
---Checks if the string contains gps tag only. Must be called after it was
---it was sanitized.
function Public.only_sanitized_gps_tag(s)
    return s == '[gps=redacted]'
end

return Public
