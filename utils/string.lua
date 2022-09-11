local Public = {}

--works only with custom surfaces (requires [gps= x, v, surface] format)
function Public.position_from_gps_tag(text)
    local a, b = string.find(text, "gps=")
    if b then
        local dot = string.find(text, ",", b)
        local ending = string.find(text, ",", dot + 1)
        local pos = {}
        pos.x = tonumber(string.sub(text, b + 1, dot - 1))
	    pos.y = tonumber(string.sub(text, dot + 1, ending - 1))
        return pos
    end
    return nil
end

return Public
