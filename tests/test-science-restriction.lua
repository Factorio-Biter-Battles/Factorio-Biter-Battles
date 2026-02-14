---@diagnostic disable
local lunatest = require('lunatest')

-- Mock the storage to prevent Factorio API calls
storage = { ['_TEST'] = true }

local FeedingRestriction = require('maps.biter_battles_v2.feeding_restriction')
local Tables = require('maps.biter_battles_v2.tables')

-- Test each difficulty level using the actual module function
function test_build_score_itytd()
    local diff = Tables.difficulties[1] -- ITYTD
    lunatest.assert_equal(240, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_hand()
    local diff = Tables.difficulties[2] -- HaND
    lunatest.assert_equal(138, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_poc()
    local diff = Tables.difficulties[3] -- PoC
    lunatest.assert_equal(96, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_easy()
    local diff = Tables.difficulties[4] -- Easy
    lunatest.assert_equal(64, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_normal()
    local diff = Tables.difficulties[5] -- Normal
    lunatest.assert_equal(48, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_hard()
    local diff = Tables.difficulties[6] -- Hard
    lunatest.assert_equal(24, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_fnf()
    local diff = Tables.difficulties[7] -- FnF
    lunatest.assert_equal(10, FeedingRestriction.calc_required_score(diff.value))
end

function test_build_score_inverse_relationship()
    -- Verify higher difficulty = lower requirement (iterate through all difficulties)
    local prev_score = FeedingRestriction.calc_required_score(Tables.difficulties[1].value)
    for i = 2, #Tables.difficulties do
        local diff = Tables.difficulties[i]
        local score = FeedingRestriction.calc_required_score(diff.value)
        lunatest.assert_true(score < prev_score, diff.name .. ': Expected ' .. score .. ' < ' .. prev_score)
        prev_score = score
    end
end

function test_build_score_all_positive_and_bounded()
    -- All difficulties should produce positive requirements <= 240
    for _, diff in ipairs(Tables.difficulties) do
        local required = FeedingRestriction.calc_required_score(diff.value)
        lunatest.assert_true(required > 0, diff.name .. ' should have positive requirement')
        lunatest.assert_true(required <= 240, diff.name .. ' should not exceed 240')
    end
end

lunatest.run()
