local normalize_amp_of = { 'mixed_ore', 'vertical_lines_ore' }

local noise = {
    mixed_ore = {
        { freq = 0.0042, amp = 1 },
        { freq = 0.031, amp = 0.08 },
        { freq = 0.1, amp = 0.025 },
    },

    vertical_lines_ore = {
        { freq = 0.0005, amp = 1000 },
        { freq = 0.22, amp = 10 },
        { freq = 0.6, amp = 1 },
    },

    spawn_wall = {
        { freq = 0.011, amp = 1 },
        { freq = 0.08, amp = 0.2 },
    },

    spawn_wall_2 = {
        { freq = 0.005, amp = 1 },
        { freq = 0.02, amp = 0.3 },
        { freq = 0.15, amp = 0.025 },
    },

    biter_area_border = {
        { freq = 0.005, amp = 1 },
        { freq = 0.02, amp = 0.3 },
        { freq = 0.15, amp = 0.025 },
    },

    spawn_ore = {
        { freq = 0.0125, amp = 1 },
        { freq = 0.1, amp = 0.12 },
    },
}

for _, name in ipairs(normalize_amp_of) do
    local total = 0
    for _, octave in ipairs(noise[name]) do
        total = total + octave.amp
    end
    for _, octave in ipairs(noise[name]) do
        octave.amp = octave.amp / total
    end
end

return noise
