---@diagnostic disable
local lunatest = require('lunatest')
local utils = require('utils.string')

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

    local sanitize_gps_tags = utils.sanitize_gps_tags
    for _, p in ipairs(patterns) do
        for _, a in ipairs(appendix) do
            local sanitzed = sanitize_gps_tags(p)
            lunatest.assert_equal(SANITIZED_TAG, sanitzed)
            lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(true, utils.only_sanitized_gps_tag(sanitzed))

            sanitzed = sanitize_gps_tags(a .. p)
            lunatest.assert_equal(a .. SANITIZED_TAG, sanitzed)
            lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sanitzed))

            sanitzed = sanitize_gps_tags(p .. a)
            lunatest.assert_equal(SANITIZED_TAG .. a, sanitzed)
            lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sanitzed))

            sanitzed = sanitize_gps_tags(a .. p .. a)
            lunatest.assert_equal(a .. SANITIZED_TAG .. a, sanitzed)
            lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sanitzed))
            lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sanitzed))
        end
    end
end

---Checks for exploit that tricks message parser by falsely detecting
---gps tag inside invisible rich text. The message containing it
---should be printed as-is.
function test_gps_exploit()
    local exp = '[img=item/grenade;tint=0,0,0,0;gps=]'
    local sane = utils.sanitize_gps_tags(exp)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(false, utils.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.has_sanitized_gps_tag(exp))
end

---Check if we're able to cope with multiple tags.
function test_gps_multiple_tags()
    local pattern = '[gps=1,2,bb0]a[gps=1,2,bb0]'
    local exp = SANITIZED_TAG .. 'a' .. SANITIZED_TAG
    local sane = utils.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(exp))
end

---A test for abnormal tags, mainly to see if parser crashes.
function test_gps_abormal_tag()
    local pattern = '[gps=1,2,bb0;[gps=1,2,bb0;[gps=1,2,bb0;[gps=1,2,bb0]]]]'
    local exp = '[gps=redacted]]]]'
    local sane = utils.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(exp))

    pattern = '[gps=[gps=[gps=[gps=]]]]'
    exp = '[gps=redacted]]]]'
    sane = utils.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(exp))

    pattern = '[gps=[gps[gps=[gps]]]]'
    exp = '[gps=redacted]]]]'
    sane = utils.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(exp))

    pattern = '[gps[gps=[gps[gps=]]]]'
    exp = '[gps[gps=redacted]]]]'
    sane = utils.sanitize_gps_tags(pattern)
    lunatest.assert_equal(exp, sane)
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(sane))
    lunatest.assert_equal(false, utils.only_sanitized_gps_tag(exp))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(sane))
    lunatest.assert_equal(true, utils.has_sanitized_gps_tag(exp))
end

lunatest.run()
