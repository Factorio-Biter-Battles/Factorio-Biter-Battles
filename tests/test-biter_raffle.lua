local biter_raffle = require('maps.biter_battles_v2.biter_raffle')
local math_random = math.random
local Public = {}

---@param type 'spitter'|'biter'|'mixed'|'worm'
---@param n integer number of calls to make
---@return string
function Public.test_performance(type, n)
    local t1 = os.clock()
    for i = 1, n, 1 do
        biter_raffle.roll(type, math_random())
    end
    local t2 = os.clock()
    return(string.format('%s:\tn=%d\ttotal=%dms\tavg=%fms', type, n, (t2 - t1) * 1e3, (t2 - t1) * 1e3 / n))
end

return Public
-- sample usage
-- print(Public.test_biter_raffle_performance('biter', 1e5))

