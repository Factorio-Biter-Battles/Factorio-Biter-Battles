local biter_raffle = require('maps.biter_battles_v2.biter_raffle')
local math_random = math.random
local lunatest = require('lunatest')

local Public = {}

---@param type 'spitter'|'biter'|'mixed'|'worm'
---@param n integer number of calls to make
---@return string
function Public.benchmark_performance(type, n)
    local t1 = os.clock()
    for i = 1, n, 1 do
        biter_raffle.roll(type, math_random())
    end
    local t2 = os.clock()
    return (string.format('%s:\tn=%d\ttotal=%dms\tavg=%fms', type, n, (t2 - t1) * 1e3, (t2 - t1) * 1e3 / n))
end

--- Test if roll() returns string
--- @diagnostic disable-next-line
function test_roll()
    local types = { 'spitter', 'biter', 'mixed', 'worm' }
    local evo_values = { -0.5, 0, 0.01, 0.1, 0.5, 0.9, 1, 1.5 }
    for _, t in pairs(types) do
        for _, evo in pairs(evo_values) do
            lunatest.assert_string(biter_raffle.roll(t, evo))
        end
    end
end

--- Test if get_raffle_table() returns table
--- Compare the results with reference values based on de118e2eb4c32577ec3d988170de6e029af58834 comit
---@diagnostic disable-next-line
function test_get_raffle_table()
    local levels = { -500, 0, 10, 100, 500, 900, 1000, 1500 }
    local expected_raffle_tables = {
        [-500] = { ['small-'] = 1875, ['medium-'] = 0, ['big-'] = 0, ['behemoth-'] = 0 },
        [0] = { ['small-'] = 1000, ['medium-'] = 0, ['big-'] = 0, ['behemoth-'] = 0 },
        [10] = { ['small-'] = 982.5, ['medium-'] = 0, ['big-'] = 0, ['behemoth-'] = 0 },
        [100] = { ['small-'] = 825, ['medium-'] = 0, ['big-'] = 0, ['behemoth-'] = 0 },
        [500] = { ['small-'] = 125, ['medium-'] = 500, ['big-'] = 0, ['behemoth-'] = 0 },
        [900] = { ['small-'] = 0, ['medium-'] = 100, ['big-'] = 800, ['behemoth-'] = 0 },
        [1000] = { ['small-'] = 0, ['medium-'] = 0, ['big-'] = 1000, ['behemoth-'] = 800 },
        [1500] = { ['small-'] = 0, ['medium-'] = 0, ['big-'] = 2000, ['behemoth-'] = 4800 },
    }
    for _, level in pairs(levels) do
        local expected_raffle_table = expected_raffle_tables[level]
        ---@diagnostic disable-next-line
        local raffle_table = biter_raffle._test_get_raffle_table(level)
        lunatest.assert_table(raffle_table, 'get_raffle_table(' .. level .. ') failed to return a table')

        for name, value in pairs(raffle_table) do
            lunatest.assert_equal(expected_raffle_table[name], value)
        end
    end
end

lunatest.run()
return Public
