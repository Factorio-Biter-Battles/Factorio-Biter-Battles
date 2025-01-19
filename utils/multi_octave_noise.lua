local simplex_noise = require('utils.simplex_noise').d2

return {
    --- Accumulates values of multiple octaves (layers) of simplex noise at the specified position
    ---@param octaves [{amp: number, freq: number}]
    ---@param pos {x: number, y: number}
    ---@param seed number
    ---@param offset number offset of the seed between each octave. Providing low value will result at interference near origin point
    ---@return number # of the range [-1; 1] * (sum of modules of all amplitudes)
    get = function(octaves, pos, seed, offset)
        local noise = 0
        for _, octave in ipairs(octaves) do
            noise = noise + simplex_noise(pos.x * octave.freq, pos.y * octave.freq, seed) * octave.amp
            seed = seed + offset
        end
        return noise
    end,
}
