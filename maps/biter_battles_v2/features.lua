local gui = require('utils.gui')
local mod = {}

function mod.create_table(player)
    local t = gui.add_top_element(player, {
        type = 'table',
        name = 'bb_feature_flags',
        column_count = 1,
    })

    t.style.style_maximal_width = 25
    t.style.style_maximal_height = 25 * 3
end

return mod
