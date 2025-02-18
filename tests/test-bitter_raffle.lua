local biter_raffle = require('maps.biter_battles_v2.biter_raffle')
local math_random = math.random

local function test_biter_raffle_performance(n)
    local t1 = os.clock()
    for i = 1, n, 1 do
        biter_raffle.roll('biter', math_random())
    end
    local t2 = os.clock()
    print(string.format('biter:\tn=%d\ttotal=%dms\tavg=%fms', n, (t2 - t1) * 1e3, (t2 - t1) * 1e3 / n))
end

local function test_spitter_raffle_performance(n)
    local t1 = os.clock()
    for i = 1, n, 1 do
        biter_raffle.roll('spitter', math_random())
    end
    local t2 = os.clock()
    print(string.format('spitter:\tn=%d\ttotal=%dms\tavg=%fms', n, (t2 - t1) * 1e3, (t2 - t1) * 1e3 / n))
end
local function test_worm_raffle_performance(n)
    local t1 = os.clock()
    for i = 1, n, 1 do
        biter_raffle.roll('worm', math_random())
    end
    local t2 = os.clock()
    print(string.format('worm:\tn=%d\ttotal=%dms\tavg=%fms', n, (t2 - t1) * 1e3, (t2 - t1) * 1e3 / n))
end
local function test_mixed_raffle_performance(n)
    local t1 = os.clock()
    for i = 1, n, 1 do
        biter_raffle.roll('mixed', math_random())
    end
    local t2 = os.clock()
    print(string.format('mixed:\tn=%d\ttotal=%dms\tavg=%fms', n, (t2 - t1) * 1e3, (t2 - t1) * 1e3 / n))
end
test_biter_raffle_performance(1e5)
test_spitter_raffle_performance(1e5)
test_worm_raffle_performance(1e5)
test_mixed_raffle_performance(1e5)
