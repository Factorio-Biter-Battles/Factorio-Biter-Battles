---@diagnostic disable
local lunatest = require('lunatest')
local utils_string = require('utils.string')
local utils_utils = require('utils.utils')

local SANITIZED_TAG = '[gps=redacted]'

function test_gps_sanitize()
    local patterns = {
        '[gps=1,2,bb0]',
        '[gps=1,2,bb1]',
        '[gps=1,2,nauvis]',
        '[gps=1,2,gulag]',
        '[gps=1,2]',
        '[gps=1.0,2.0]',
        '[gps=-1.0,2.0]',
        '[gps=-1.0,-2.0]',
        '[gps=1.0,-2.0]',
        '[gps=1871.0451,-21831.1851,bb0]',
        '[gps=-1871.0451, -21831.1851,bb0]',
        '[gps=-1871.0451, -21831.1851,bb0;extra]',
        '[gps=-1871.0451, -21831.1851,bb0;extra=123]',
    }

    local appendix = {
        ' ',
        '�',
        '',
        '����',
        '􏿿',
        '�����������������������������',
        '﷐﷑﷒﷓﷔﷕﷖﷗﷘﷙﷚﷛﷜﷝﷞﷟﷠﷡﷢﷣﷤﷥﷦﷧﷨﷩﷪﷫﷬﷭﷮﷯',
        'a',
        'a',
        'aaaa',
        '[][][][][[[[[]]]',
        '?[armor=aaaa;',
        '1?  2 3 ] 4  ?656',
    }

    local sanitize_gps_tags = utils_string.sanitize_gps_tags
    for _, p in ipairs(patterns) do
        for _, a in ipairs(appendix) do
            local sanitzed = sanitize_gps_tags(p)
            lunatest.assert_equal(SANITIZED_TAG, sanitzed)
            lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(true, utils_string.only_sanitized_gps_tag(sanitzed))

            sanitzed = sanitize_gps_tags(a .. p)
            lunatest.assert_equal(a .. SANITIZED_TAG, sanitzed)
            lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sanitzed))

            sanitzed = sanitize_gps_tags(p .. a)
            lunatest.assert_equal(SANITIZED_TAG .. a, sanitzed)
            lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sanitzed))

            sanitzed = sanitize_gps_tags(a .. p .. a)
            lunatest.assert_equal(a .. SANITIZED_TAG .. a, sanitzed)
            lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sanitzed))
        end
    end
end

---Checks for exploit that tricks message parser by falsely detecting
---gps tag inside invisible rich text. The message containing it
---should be printed as-is.
function test_gps_exploit()
    local exp = '[img=item/grenade;tint=0,0,0,0;gps=]'
    local sane = utils_string.sanitize_gps_tags(exp)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(false, utils_string.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.has_sanitized_gps_tag(exp))
end

---Check if we're able to cope with multiple tags.
function test_gps_multiple_tags()
    local pattern = '[gps=1,2,bb0]a[gps=1,2,bb0]'
    local exp = SANITIZED_TAG .. 'a' .. SANITIZED_TAG
    local sane = utils_string.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(exp))
end

---A test for abnormal tags, mainly to see if parser crashes.
function test_gps_abormal_tag()
    local pattern = '[gps=1,2,bb0;[gps=1,2,bb0;[gps=1,2,bb0;[gps=1,2,bb0]]]]'
    local exp = '[gps=redacted]]]]'
    local sane = utils_string.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(exp))

    pattern = '[gps=[gps=[gps=[gps=]]]]'
    exp = '[gps=redacted]]]]'
    sane = utils_string.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(exp))

    pattern = '[gps=[gps[gps=[gps]]]]'
    exp = '[gps=redacted]]]]'
    sane = utils_string.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(exp))

    pattern = '[gps[gps=[gps[gps=]]]]'
    exp = '[gps[gps=redacted]]]]'
    sane = utils_string.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils_string.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils_string.has_sanitized_gps_tag(exp))
end

function test_km_below_threshold()
    lunatest.assert_equal('999', utils_utils.with_km_suffix(999))
    lunatest.assert_equal('0', utils_utils.with_km_suffix(0))
    lunatest.assert_equal('1', utils_utils.with_km_suffix(1))
end

function test_km_exact_thousand()
    lunatest.assert_equal('1k', utils_utils.with_km_suffix(1000))
end

function test_km_truncation()
    lunatest.assert_equal('1k', utils_utils.with_km_suffix(1050))
end

function test_km_half_k()
    lunatest.assert_equal('1.5k', utils_utils.with_km_suffix(1500))
end

function test_km_near_next_k()
    lunatest.assert_equal('1.9k', utils_utils.with_km_suffix(1950))
end

function test_km_exact_million()
    lunatest.assert_equal('1M', utils_utils.with_km_suffix(1000000))
end

function test_km_million_truncation()
    lunatest.assert_equal('1M', utils_utils.with_km_suffix(1050000))
end

function test_km_half_million()
    lunatest.assert_equal('1.5M', utils_utils.with_km_suffix(1500000))
end

function test_km_20k()
    lunatest.assert_equal('20k', utils_utils.with_km_suffix(20000))
    lunatest.assert_equal('20.5k', utils_utils.with_km_suffix(20500))
    lunatest.assert_equal('20.9k', utils_utils.with_km_suffix(20999))
end

function test_km_50k()
    lunatest.assert_equal('50k', utils_utils.with_km_suffix(50000))
    lunatest.assert_equal('50.5k', utils_utils.with_km_suffix(50500))
    lunatest.assert_equal('50.9k', utils_utils.with_km_suffix(50999))
end

function test_km_large_k()
    lunatest.assert_equal('100k', utils_utils.with_km_suffix(100000))
    lunatest.assert_equal('999.9k', utils_utils.with_km_suffix(999999))
end

function test_km_large_million()
    lunatest.assert_equal('10M', utils_utils.with_km_suffix(10000000))
    lunatest.assert_equal('99.9M', utils_utils.with_km_suffix(99999999))
end

lunatest.run()
