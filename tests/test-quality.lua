local lunatest = require('lunatest')

storage = {
    ['_TEST'] = true,
}
local Quality = require('maps.biter_battles_v2.quality')
local Tables = require('maps.biter_battles_v2.tables')

local function round(number)
    return string.format('%.2f', number)
end

function test_feed_common()
    -- common always 100%
    storage = {
        difficulty_vote_value = 0.25,
        comfy_panel_config = {
            quality_scheduled = true,
        },
    }
    Quality.init()
    local tier = 1 -- common
    local force = 'north_biters'
    lunatest.assert_equal('1.00', round(Quality.chance(tier, force)))
end

local TIER = {
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
}

local TIER_STR = {
    [2] = 'uncommon',
    [3] = 'rare',
    [4] = 'epic',
    [5] = 'legendary',
}

local DIFF = {
    itytd = 1,
    hand = 2,
    poc = 3,
    easy = 4,
    normal = 5,
}

local DIFF_STR = {
    [1] = 'itytd',
    [2] = 'hand',
    [3] = 'poc',
    [4] = 'easy',
    [5] = 'normal',
}

function verify_chance(config)
    local fail = false
    for _, v in ipairs(config) do
        for t = 2, TIER.legendary do
            for d = 1, DIFF.normal do
                storage = {
                    difficulty_vote_value = Tables.difficulties[d].value,
                    difficulty_vote_index = d,
                    comfy_panel_config = {
                        quality_scheduled = true,
                    },
                }

                Quality.init()
                local force = 'north_biters'
                Quality.feed_flasks(v.name, v.amount, t, force)
                local chance = round(Quality.chance(t, force))
                if v.chance[d] ~= chance then
                    local c = '?'
                    if v.chance[d] then
                        c = v.chance[d]
                    end

                    print(
                        'fail '
                            .. v.name
                            .. ' x'
                            .. v.amount
                            .. ' for '
                            .. TIER_STR[t]
                            .. ' when '
                            .. DIFF_STR[d]
                            .. ' expected='
                            .. c
                            .. ' got='
                            .. chance
                    )
                    fail = true
                end
            end
        end
    end

    lunatest.assert_equal(false, fail)
end

function apply_flasks_oneshot(name, count, tier, diff)
    storage = {
        difficulty_vote_value = Tables.difficulties[diff].value,
        difficulty_vote_index = diff,
        comfy_panel_config = {
            quality_scheduled = true,
        },
    }

    Quality.init()
    local force = 'north_biters'
    Quality.feed_flasks(name, count, tier, force)
    return round(Quality.chance(tier, force))
end

function apply_flasks_batches(name, count, tier, diff, batch_size)
    storage = {
        difficulty_vote_value = Tables.difficulties[diff].value,
        difficulty_vote_index = diff,
        comfy_panel_config = {
            quality_scheduled = true,
        },
    }

    Quality.init()
    local force = 'north_biters'
    local iter = count / batch_size
    for i = 1, iter do
        Quality.feed_flasks(name, batch_size, tier, force)
    end

    return round(Quality.chance(tier, force))
end

function test_feed_values()
    local config = {
        -- AUTOMATION
        {
            amount = 400,
            name = 'automation-science-pack',
            chance = { '0.02', '0.03', '0.04', '0.06', '0.07' },
        },
        {
            amount = 5000,
            name = 'automation-science-pack',
            chance = { '0.17', '0.23', '0.27', '0.34', '0.39' },
        },
        {
            amount = 10000,
            name = 'automation-science-pack',
            chance = { '0.27', '0.34', '0.39', '0.46', '0.52' },
        },
        {
            amount = 100000,
            name = 'automation-science-pack',
            chance = { '0.71', '0.79', '0.85', '0.94', '1.00' },
        },
        --- LOGISTICS
        {
            amount = 200,
            name = 'logistic-science-pack',
            chance = { '0.03', '0.04', '0.05', '0.07', '0.09' },
        },
        {
            amount = 5000,
            name = 'logistic-science-pack',
            chance = { '0.31', '0.38', '0.43', '0.51', '0.57' },
        },
        {
            amount = 10000,
            name = 'logistic-science-pack',
            chance = { '0.43', '0.51', '0.57', '0.65', '0.71' },
        },
        --- MILITARY
        {
            amount = 200,
            name = 'military-science-pack',
            chance = { '0.09', '0.13', '0.16', '0.20', '0.24' },
        },
        {
            amount = 5000,
            name = 'military-science-pack',
            chance = { '0.57', '0.66', '0.72', '0.80', '0.86' },
        },
        {
            amount = 10000,
            name = 'military-science-pack',
            chance = { '0.72', '0.80', '0.86', '0.95', '1.00' },
        },
        --- CHEMICAL
        {
            amount = 200,
            name = 'chemical-science-pack',
            chance = { '0.19', '0.24', '0.29', '0.35', '0.41' },
        },
        {
            amount = 5000,
            name = 'chemical-science-pack',
            chance = { '0.77', '0.86', '0.92', '1.00', '1.00' },
        },
        {
            amount = 10000,
            name = 'chemical-science-pack',
            chance = { '0.92', '1.00', '1.00', '1.00', '1.00' },
        },
        --- PRODUCTION
        {
            amount = 200,
            name = 'production-science-pack',
            chance = { '0.42', '0.50', '0.55', '0.63', '0.69' },
        },
        {
            amount = 1000,
            name = 'production-science-pack',
            chance = { '0.74', '0.83', '0.88', '0.97', '1.00' },
        },
        {
            amount = 5000,
            name = 'production-science-pack',
            chance = { '1.00', '1.00', '1.00', '1.00', '1.00' },
        },
        --- UTILITY
        {
            amount = 200,
            name = 'utility-science-pack',
            chance = { '0.51', '0.59', '0.64', '0.73', '0.79' },
        },
        {
            amount = 1000,
            name = 'utility-science-pack',
            chance = { '0.84', '0.93', '0.99', '1.00', '1.00' },
        },
        --- SPACE
        {
            amount = 1000,
            name = 'space-science-pack',
            chance = { '0.99', '1.00', '1.00', '1.00', '1.00' },
        },
        {
            amount = 2000,
            name = 'space-science-pack',
            chance = { '1.00', '1.00', '1.00', '1.00', '1.00' },
        },
    }

    verify_chance(config)
end

-- Ensures there is no difference when sending at once or in batches
function test_feed_values_batches()
    local expected = apply_flasks_oneshot('utility-science-pack', 200, TIER.rare, DIFF.itytd)
    local got = apply_flasks_batches('utility-science-pack', 200, TIER.rare, DIFF.itytd, 10)
    lunatest.assert_equal(expected, got)
end

lunatest.run()
