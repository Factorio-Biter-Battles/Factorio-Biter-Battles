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
        [-500] = { [1] = 1875, [2] = 0, [3] = 0, [4] = 0 },
        [0] = { [1] = 1000, [2] = 0, [3] = 0, [4] = 0 },
        [10] = { [1] = 982.5, [2] = 0, [3] = 0, [4] = 0 },
        [100] = { [1] = 825, [2] = 0, [3] = 0, [4] = 0 },
        [500] = { [1] = 125, [2] = 500, [3] = 0, [4] = 0 },
        [900] = { [1] = 0, [2] = 100, [3] = 800, [4] = 0 },
        [1000] = { [1] = 0, [2] = 0, [3] = 1000, [4] = 800 },
        [1500] = { [1] = 0, [2] = 0, [3] = 2000, [4] = 4800 },
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
