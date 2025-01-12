local lunatest = require('lunatest')

storage = {
    ['_TEST'] = true,
}
local Functions = require('maps.biter_battles_v2.functions')

function test_format_ticks_primary()
    local format_ticks_as_time = Functions.format_ticks_as_time
    lunatest.assert_equal('0:00:00', format_ticks_as_time(0))
    lunatest.assert_equal('0:00:00', format_ticks_as_time(1))
    lunatest.assert_equal('0:00:00', format_ticks_as_time(30))
    lunatest.assert_equal('0:00:00', format_ticks_as_time(59))
    lunatest.assert_equal('0:00:01', format_ticks_as_time(60))
    lunatest.assert_equal('0:00:01', format_ticks_as_time(119))
    lunatest.assert_equal('0:00:02', format_ticks_as_time(120))
    lunatest.assert_equal('0:00:59', format_ticks_as_time(60 * 59))
    lunatest.assert_equal('0:01:00', format_ticks_as_time(60 * 60))
    lunatest.assert_equal('0:01:59', format_ticks_as_time(60 * 119))
    lunatest.assert_equal('0:59:00', format_ticks_as_time(60 * 60 * 59))
    lunatest.assert_equal('1:00:00', format_ticks_as_time(60 * 60 * 60))
    lunatest.assert_equal('1:01:00', format_ticks_as_time(60 * 60 * 61))
    lunatest.assert_equal('1:59:01', format_ticks_as_time(60 * 60 * 119 + 70))
    lunatest.assert_equal('2:00:01', format_ticks_as_time(60 * 60 * 120 + 70))
end

lunatest.run()
