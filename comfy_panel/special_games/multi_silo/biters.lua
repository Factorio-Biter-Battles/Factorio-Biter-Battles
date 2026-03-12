--- Biter AI for multi-silo: keeps unit-group attack
--- targets in sync with the current set of live silos.

local Event = require('utils.event')
local Force = require('utils.force')
local Shared = require('comfy_panel.special_games.multi_silo.shared')

local Public = {}

--- Returns true if two map positions are identical.
--- Attack_area command destinations are stored directly from silo.position,
--- so the values are always bit-for-bit equal to the captured dead silo position.
---@param a MapPosition
---@param b MapPosition
---@return boolean
local function positions_match(a, b)
    return a.x == b.x and a.y == b.y
end

--- Recursively remove attack_area sub-commands whose destination matches
--- `position` and collect the destinations that survived.  Descends into
--- nested compound commands and removes any that become empty after pruning.
--- When position is nil (e.g. called on silo placement), no commands are
--- removed and only the covered positions are collected.
---@param commands defines.command[] Sub-commands to prune (mutated in-place).
---@param position MapPosition? Position of the destroyed silo, or nil to skip pruning.
---@return MapPosition[] valid_positions Destinations of surviving attack_area commands.
local function prune_invalid_targets(commands, position)
    local valid = {}
    local i = 1
    while i <= #commands do
        local cmd = commands[i]

        if cmd.type == defines.command.compound then
            local nested = prune_invalid_targets(cmd.commands, position)
            for _, pos in ipairs(nested) do
                valid[#valid + 1] = pos
            end
            if #cmd.commands == 0 then
                table.remove(commands, i)
                goto prune_continue
            end
            i = i + 1
            goto prune_continue
        end

        if cmd.type == defines.command.attack_area then
            if position and positions_match(cmd.destination, position) then
                table.remove(commands, i)
                goto prune_continue
            end
            valid[#valid + 1] = cmd.destination
        end

        i = i + 1
        ::prune_continue::
    end

    return valid
end

--- Find the innermost commands array at the tail of a compound command tree.
--- Silo attack commands are originally appended at the end of the chain, so
--- after Factorio restructures the compound during execution they end up in
--- the deepest trailing compound.  Returns nil for non-compound commands.
---@param cmd defines.command
---@return defines.command[]?
local function find_tail_commands(cmd)
    if cmd.type ~= defines.command.compound or #cmd.commands == 0 then
        return nil
    end

    local last = cmd.commands[#cmd.commands]
    if last.type == defines.command.compound then
        return find_tail_commands(last) or cmd.commands
    end

    return cmd.commands
end

--- Append attack_area commands for valid silos whose positions are not already covered.
--- Only adds commands when multi-silo mode is active.
---@param commands defines.command[] Sub-commands to append to.
---@param target_force_name string Force whose silos to check ('north' or 'south').
---@param covered_positions MapPosition[] Positions already present in the command chain.
local function append_missing_silos(commands, target_force_name, covered_positions)
    if Shared.is_disabled() then
        return
    end

    local silos = storage.rocket_silo[target_force_name]
    if not silos then
        return
    end

    local indices = table.shuffle_indices(silos)
    for _, i in ipairs(indices) do
        local silo = silos[i]
        if not (silo and silo.valid) then
            goto append_missing_silos_cont
        end

        local already_covered = false
        for _, pos in ipairs(covered_positions) do
            if positions_match(silo.position, pos) then
                already_covered = true
                break
            end
        end

        if not already_covered then
            commands[#commands + 1] = {
                type = defines.command.attack_area,
                destination = silo.position,
                radius = 32,
                distraction = defines.distraction.by_enemy,
            }
        end

        ::append_missing_silos_cont::
    end
end

--- Re-command a single biter group, preserving its existing command chain while
--- removing the destroyed silo's attack_area entry and adding any uncovered silos.
--- Falls back to a fresh silo-only chain when the group has no existing command.
--- When position is nil, no commands are pruned -- only missing silos are appended.
---@param group LuaCommandable The group to update.
---@param position MapPosition? Position of the just-destroyed silo, or nil when appending only.
local function recommand_group(group, position)
    local target = Force.get_player_force_name(group.force.name)

    -- Is there compound command set?
    local command = group.command
    if command.type ~= defines.command.compound then
        local pos = group.position
        log(
            'WARN: recommand_group: unexpected command type '
                .. tostring(command.type)
                .. ' for group force='
                .. tostring(group.force.name)
                .. ' id='
                .. tostring(group.unique_id)
                .. ' pos=('
                .. tostring(pos.x)
                .. ','
                .. tostring(pos.y)
                .. ')'
        )
        return
    end

    local cmd = table.deepcopy(command)
    local valid = prune_invalid_targets(cmd.commands, position)
    local tail = find_tail_commands(cmd) or cmd.commands
    append_missing_silos(tail, target, valid)

    if #cmd.commands == 0 then
        return
    end

    group.set_command(cmd)
end

--- Re-command all tracked multi-silo biter groups.
--- Preserves each group's existing command chain; removes the dead silo entry
--- (if dead_silo_position is given) and appends any silos not yet in the chain.
--- Called with no argument when a new silo is placed so groups pick it up without
--- discarding their current route.
---@param dead_silo_position MapPosition? Position of the just-destroyed silo, or nil when appending only.
function Public.recommand_all_groups(dead_silo_position)
    if Shared.is_disabled() or storage.bb_game_won_by_team then
        return
    end

    local groups = get_biter_groups()
    for i = #groups, 1, -1 do
        local group = groups[i]
        if not group.valid or #group.members == 0 then
            table.remove(groups, i)
        end
    end

    for _, group in ipairs(groups) do
        recommand_group(group, dead_silo_position)
    end
end

---@return LuaUnitGroup[] Active biter groups tracked for multi-silo re-commanding.
local function get_biter_groups()
    return storage.active_special_games.multi_silo.biter_groups
end

---@param group LuaCommandable Unit group to track.
function Public.track_group(group)
    if Shared.is_disabled() then
        return
    end
    table.insert(storage.active_special_games.multi_silo.biter_groups, group)
end

---Removes unit groups that are no longer valid from the tracked biter_groups list.
local function cleanup_biter_groups()
    if Shared.is_disabled() then
        return
    end

    local groups = storage.active_special_games.multi_silo.biter_groups
    for i = #groups, 1, -1 do
        if not groups[i] or not groups[i].valid then
            table.remove(groups, i)
        end
    end
end

Event.on_nth_tick(60 * 60, cleanup_biter_groups)

return Public
