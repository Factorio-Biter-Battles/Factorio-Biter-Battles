local Quality = require('maps.biter_battles_v2.quality')
local Tables = require('maps.biter_battles_v2.tables')
local Public = {}

Public.gui_foods = {}
for i = 1, #Quality.TIERS do
    Public.gui_foods[i] = {}
end

for i, t in ipairs(Quality.TIERS) do
    for k, v in pairs(Tables.food_values) do
        Public.gui_foods[i][k] = math.floor(v.value * 10000 * t.multiplier) .. ' Mutagen strength'
    end

    local time = 45 * t.multiplier
    local tooltip = 'Send a fish to spy for '
        .. time
        .. ' seconds.\nLeft Mouse Button: Send one fish.\nRMB: Sends 5 fish.\nShift+LMB: Send all fish.\nShift+RMB: Send half of all fish.'
    Public.gui_foods[i]['raw-fish'] = tooltip
end

return Public
