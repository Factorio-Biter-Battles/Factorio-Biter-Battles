--- Biter AI for multi-silo: keeps unit-group attack
--- targets in sync with the current set of live silos.

local Event = require('utils.event')
local Force = require('utils.force')
local Shared = require('comfy_panel.special_games.multi_silo.shared')

local Public = {}

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

--- Re-command a single biter group, appending an attack_area entry for the
--- newly placed silo.  Falls back to a fresh silo-only chain when the group
--- has no existing compound command.
---@param group LuaCommandable The group to update.
---@param silo LuaEntity The silo that was just placed.
local function recommand_group(group, silo)
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
    local tail = find_tail_commands(cmd) or cmd.commands
    tail[#tail + 1] = {
        type = defines.command.attack_area,
        destination = silo.position,
        radius = 32,
        distraction = defines.distraction.by_enemy,
    }

    group.set_command(cmd)
end

---@return LuaUnitGroup[] Active biter groups tracked for multi-silo re-commanding.
local function get_biter_groups()
    return storage.active_special_games.multi_silo.biter_groups
end

--- Re-command all tracked multi-silo biter groups to include the newly placed silo.
---@param silo LuaEntity The silo that was just placed.
function Public.on_silo_added(silo)
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
        recommand_group(group, silo)
    end
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
