---Deals with all things related to rich text handling.

local table_concat = table.concat

local Public = {}

---Emit [color] text tag
---@param text string|number Text to embed
---@param color number[] RGB channels
---@return string
function Public.colored(text, color)
    if type(text) == 'number' then
        text = tostring(text)
    end

    return table_concat({
        '[color=',
        color[1],
        ',',
        color[2],
        ',',
        color[3],
        ']',
        text,
        '[/color]',
    })
end

---Emit [img] text tag
---@param name string Specification/Name
---@return string
function Public.img(name)
    return table_concat({
        '[img=',
        name,
        ']',
    })
end

---Emit [img] text quality tag
---@param name string Name
---@return string
function Public.quality(name)
    return Public.font(
        table_concat({
            '[img=quality/',
            name,
            ']',
        }),
        'var'
    )
end

---Emit [font] text tag
---@param text string Text to embed
---@param font string Font name
---@return string
function Public.font(text, font)
    return table_concat({
        '[font=',
        font,
        ']',
        text,
        '[/font]',
    })
end

return Public
