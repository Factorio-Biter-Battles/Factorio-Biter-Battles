local biter_raffle = require('maps.biter_battles_v2.biter_raffle')
local math_random = math.random
local lunatest = require('lunatest')

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


function Public.test_is_string()
    local types = {'spitter','biter','mixed','worm'}
    local evo_values = {-0.5, 0, 0.01, 0.1, 0.5, 0.9, 1, 1.5}
    for _, t in pairs(types) do
        for _, evo in pairs(evo_values) do
            lunatest.assert_string(biter_raffle.roll(t, evo))
        end
    end
end

-- test if rolled values approach expected values for large set 
function Public.test_chances()
    local n = 1e5
    -- 10% evo
    local count = {
        ['small-'] = 0,
        ['medium-'] = 0,
        ['big-'] = 0,
        ['behemoth-'] = 0,
    }
    for i=1, n, 1 do
        local result = biter_raffle._test_roll(0.1)
        count[result] = count[result] + 1
    end
    lunatest.assert_equal(n * 1, count['small-'], 1)
    lunatest.assert_equal(0, count['medium-'], 1)
    lunatest.assert_equal(0, count['big-'], 1)
    lunatest.assert_equal(0, count['behemoth-'], 1)

    -- 30% evo
    count = {
        ['small-'] = 0,
        ['medium-'] = 0,
        ['big-'] = 0,
        ['behemoth-'] = 0,
    }
    for i=1, n, 1 do
        local result = biter_raffle._test_roll(0.3)
        count[result] = count[result] + 1
    end
    lunatest.assert_equal(n * ??, count['small-'], 1)
    lunatest.assert_equal(n * ??, count['medium-'], 1)
    lunatest.assert_equal(0, count['big-'], 1)
    lunatest.assert_equal(0, count['behemoth-'], 1)

    -- 60% evo
    count = {
        ['small-'] = 0,
        ['medium-'] = 0,
        ['big-'] = 0,
        ['behemoth-'] = 0,
    }
    for i=1, n, 1 do
        local result = biter_raffle._test_roll(0.6)
        count[result] = count[result] + 1
    end
    lunatest.assert_equal(n * ??, count['small-'], 1)
    lunatest.assert_equal(n * ??, count['medium-'], 1)
    lunatest.assert_equal(n * ??, count['big-'], 1)
    lunatest.assert_equal(0, count['behemoth-'], 1)

    -- 95% evo
    count = {
        ['small-'] = 0,
        ['medium-'] = 0,
        ['big-'] = 0,
        ['behemoth-'] = 0,
    }
    for i=1, n, 1 do
        local result = biter_raffle._test_roll(0.95)
        count[result] = count[result] + 1
    end
    lunatest.assert_equal(n * ??, count['small-'], 1)
    lunatest.assert_equal(n * ??, count['medium-'], 1)
    lunatest.assert_equal(n * ??, count['big-'], 1)
    lunatest.assert_equal(n * ??, count['behemoth-'], 1)
end

return Public
-- sample usage
-- print(Public.test_biter_raffle_performance('biter', 1e5))

