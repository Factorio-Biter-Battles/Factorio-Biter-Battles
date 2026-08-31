# Agent Instructions

This document describes the technical environment, constraints, and behavioral rules for AI coding agents working on the Biter Battles Factorio scenario.

For contribution guidelines (code style, commits, testing, change policy), see [CONTRIBUTING.md](CONTRIBUTING.md).

## Factorio Lua 5.2 Runtime

Factorio embeds a **modified Lua 5.2.1** runtime. It is not a standard Lua environment.

Source reference: <https://github.com/Rseding91/Factorio-Lua/>

### Disabled Standard Libraries

The following standard Lua libraries are **not available** at runtime:

- `io` -- no filesystem access
- `os` -- no OS interaction
- `coroutine` -- no coroutines
- `package` -- no dynamic package loading
- `loadfile`, `dofile` -- removed from base library

### Restricted Features

- **Bytecode loading is blocked.** `load()` only accepts text mode (`"t"`). Precompiled chunks cannot be loaded.
- **Debug library is partial.** Only `debug.getinfo` and `debug.traceback` are available. Functions like `debug.sethook`, `debug.getlocal`, `debug.setmetatable`, etc. are absent.

### Non-Standard Additions

The Factorio Lua runtime adds a small number of functions not present in standard Lua 5.2:

- **`string.pack`, `string.unpack`, `string.packsize`** -- binary serialization, backported from Lua 5.4. Useful for compact data encoding.
- **`table.pairs_concat`** -- iterates a table with `pairs` and concatenates values with a separator, similar to `table.concat` but over the hash part.
- **`string.format` limits** -- each individual conversion is capped at 512 bytes and width/precision specifiers are limited to 2 digits. Exceeding either raises an error.

### Modified Math

Factorio replaces all trigonometric, hyperbolic, exponential, and logarithmic math functions with custom deterministic implementations (not from the system's libm). This includes `math.pow`, `math.log`, `math.log10`, `math.sin`, `math.cos`, `math.exp`, and others. The replacements ensure identical floating-point results across all platforms and CPU architectures, which is critical for multiplayer determinism.

### Runtime `require()` Override

All `require()` calls must happen during the control stage. After init/load, `require()` is overridden in `control.lua` to only resolve modules that were already loaded during the control stage:

```lua
function require(path)
    local path = '__level__/' .. path:gsub('%.', '/') .. '.lua'
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end
```

You cannot introduce new files mid-game. However, `require()` can still be called at runtime (e.g., via `/sc`) for modules that were already loaded during the control stage -- the override returns the cached module from `loaded` rather than reading the filesystem again.

## Environment and Loading Stages

### Stages

This scenario only uses the **control stage** (no data-stage prototypes). The lifecycle stages are defined in `utils/data_stages.lua`:

| Stage     | Description                                   |
|-----------|-----------------------------------------------|
| `control` | Module loading, event registration            |
| `init`    | `on_init` -- first-time map creation          |
| `load`    | `on_load` -- restoring from save              |
| `runtime` | Normal game execution (tick processing)       |

The global `_LIFECYCLE` tracks the current stage. Registration functions like `Token.register()` and `Event.add()` enforce stage restrictions and will error if called at runtime.

### Serialization and the `storage` Table

`storage` (Factorio 2.0; replaces the old `global` table) is the **only** table that persists across save/load. It is automatically serialized by the engine.

Rules for `storage`:

- **Store only** serializable values: numbers, strings, booleans, `nil`, and tables composed of these.
- **Never store** functions, closures, metatables, or userdata. These cannot be serialized and will cause errors or desyncs on load.
- Factorio API objects (`LuaEntity`, `LuaPlayer`, `LuaForce`, etc.) can be stored in `storage`, but they are references that may become invalid. Always check `.valid` before use.

### Referencing Game Objects Safely

- Use **index-based keys** for lookups: `entity.unit_number`, `player.index`, `force.index`. These are stable numeric identifiers.
- Always guard stored LuaObject references with `.valid` checks:

```lua
local entity = storage.some_entity
if entity and entity.valid then
    -- safe to use
end
```

### Desync

Factorio uses **lockstep deterministic simulation**. Every connected client executes the same Lua code in the same order with the same inputs. A desync occurs when clients diverge.

Common causes of desync in scenario code:

- **Registering events or tokens at runtime.** `Event.add()` and `Token.register()` must be called during the control stage, before `on_init`/`on_load`. Calling them at runtime means different clients may have different handler registrations depending on when they joined.
- **Storing closures in `storage`.** Closures capture upvalues that cannot be deterministically restored on load. Use `Event.add_removable_function` (string-based function references) for runtime-safe event handlers.
- **Non-deterministic iteration order.** `pairs()` over the hash part of a table has no guaranteed order in standard Lua 5.2. Factorio's runtime does guarantee insertion-order iteration (keys inserted first are iterated first), and the first 1024 integer keys are always iterated 1 through 1024 regardless of insertion order. However, the unit test suite runs on standard Lua where neither guarantee holds. Write code as if the order is arbitrary so that tests remain valid.
- **Using local state that is not in `storage`.** Any variable outside `storage` is lost on save/load and will differ between a host and a client that joins mid-game.

## Performance Constraints

All scenario Lua code runs inside the game's update loop. The game targets **60 UPS** (updates per second). Each tick budget is ~16.6ms total, shared with the engine. Heavy Lua work directly reduces UPS.

Factorio's Lua runtime is **single-threaded**. There is no concurrency within a tick -- all event handlers and tick callbacks run sequentially. This means expensive work in one handler blocks everything else in that tick.

### Module-Load-Time Computation (Control Stage)

Work that depends only on static data can be computed once at module load time (control stage) and stored in a module-local variable. This is similar to `constexpr` in C++: the computation runs exactly once when the file is first `require()`'d, and the result is available for the lifetime of the game session without ever touching `storage`.

Because all clients load modules in the same order with the same source, this is fully deterministic and safe.

Example from `commands/inventory_scan.lua`:

```lua
-- Computed once at load time; never stored in storage
local CATEGORY_NAMES_STRING
do
    local names = {}
    for name, _ in pairs(CATEGORIES) do
        names[#names + 1] = name
    end
    table.sort(names)
    CATEGORY_NAMES_STRING = table.concat(names, ', ')
end
```

Use `do...end` blocks to scope intermediate variables and keep the top-level namespace clean. Prefer this pattern over recomputing the same value on every command invocation or tick.

### Tick-Offset Scheduling

Heavy work is distributed across ticks using modulo offsets:

```lua
if tick % 60 == 0 then ... end           -- every second
if (tick + 11) % 300 == 0 then ... end   -- every 5 seconds, offset by 11
if tick % 30 == 0 then ... end           -- every half second
```

Prefer `Event.on_nth_tick(N, handler)` for new periodic work.

### GUI Updates

GUI code must be **event-driven**. Update existing elements in response to state changes -- never destroy and redraw the entire GUI periodically. Full redraws on a timer are the wrong pattern regardless of how infrequently they run.

- Create GUI elements once (on player join or GUI open). Keep references or look them up by name.
- Update only the specific elements whose underlying data changed.
- Data shared across all players or multiple widgets (e.g., team threat, scores) should be computed once and passed to each update function -- do not recompute it separately for each player.

### Local Caching of Globals

Hot-path code caches frequently used globals as locals to avoid repeated global table lookups per tick:

```lua
local math_random = math.random
local math_floor = math.floor
```

### Table Internals

The Factorio Lua runtime imposes a non-standard constraint on table storage that has significant performance implications.

**Array part is capped at 1024 entries.** Standard Lua can grow a table's array part to ~1 billion entries. The Factorio Lua runtime caps it at 1024 (`LUA_MAX_SEQUENTIAL_ARRAY_SIZE_BITS = 10`). Any integer key above 1024 always goes into the hash part, regardless of how dense the table is. A list of 2000 entities stored as `t[1]` through `t[2000]` uses the array part for indices 1–1024 and the hash part for 1025–2000. Iteration and random access on the hash portion is slower than on the array portion.

**Reading an in-range integer key on a small table silently triggers a rehash.** `luaH_getint` is called for any read where `1 ≤ key ≤ 1024`. If the key falls outside the table's current array size, it calls `rehash()` -- growing the array to the next power of two -- before returning `nil`. Reading `t[500]` on `t = {1, 2, 3}` silently allocates a 512-slot array. This is a hidden O(n) allocation on what looks like a simple read. Avoid reading out-of-bounds integer keys on small tables in hot paths. If you need sparse integer keys larger than ~10, consider whether a string key or a different data structure is more appropriate.

**Reading a deleted hash key reorganises the hash chain.** After `t["key"] = nil`, a subsequent read of `t["key"]` finds the nil node and moves it to the end of the internal insertion chain. The read is not side-effect-free at the memory layout level. In tight loops that repeatedly check for absent keys, this causes silent internal mutation on every access.

### String Internals

**Short strings (≤ 40 bytes) are interned; long strings are not.** Interned strings are globally deduplicated -- two identical short string literals anywhere in the program are the same pointer, making equality an O(1) pointer comparison. Strings longer than 40 bytes are distinct heap allocations; equality requires a full `memcmp`. Using a long string as a frequent table key (e.g., a serialized compound key longer than 40 chars) incurs a string comparison on every lookup. Prefer short keys or numeric keys in hot paths.

### Allocation and GC Pressure

Lua's garbage collector runs incrementally, but heap allocation still has a cost -- and in a 60 UPS loop, that cost compounds. Avoid creating short-lived tables or strings in hot paths:

- Prefer reusing a pre-allocated table by clearing and refilling it over allocating a fresh one each call.
- Avoid constructing intermediate strings (e.g., with `..`) inside `on_tick` or frequently-called handlers. Pre-compute format strings or use module-level constants.
- Avoid building temporary arrays just to iterate them once; iterate the source directly.
- Large table literals defined inside a function body are re-allocated on every call. Move them to module scope as constants (see the module-load-time computation pattern above).

The GC runs incrementally during the tick itself -- it is triggered at Lua API call points (string creation, table creation, function calls, concatenation) whenever enough allocation debt has accumulated. Most GC phases are incremental and spread across many steps. Keeping allocation rates low reduces both the frequency and cost of these pauses.

### Guidelines

- Avoid `pairs()` iteration over large tables in `on_tick`. Batch or paginate.
- Profile hot paths using [helpers.create_profiler()](https://lua-api.factorio.com/latest/classes/LuaProfiler.html) before and after changes. `LuaProfiler` objects can be passed directly to `log()` or `helpers.write_file()` as a `LocalisedString` -- the engine formats the elapsed time. They cannot be serialized, so keep them in local or module scope only.
- **Avoid memory leaks in `storage`.** The game can run continuously for weeks without a reset. Any data written to `storage` and never removed will accumulate indefinitely and increase memory usage and save-file size over time. Common leak patterns: per-player tables keyed by player name or index that are never cleaned up when a player leaves; per-entity tables keyed by `unit_number` where the cleanup hook on entity death is missing or incomplete; append-only log or history tables with no size cap. Always pair writes to `storage` with a removal path -- handle `on_player_removed`, `on_entity_died`, and similar cleanup events, and impose a maximum size on any collection that grows over time. The game reset / map reset transition (see `maps/biter_battles_v2/game_over.lua`) is also the right place to wholesale clear or reinitialise your module's portion of `storage`, since state from the previous round is no longer relevant.

## Multiplayer and Simulation Model

- The **server** runs the simulation and distributes **input actions** (player commands, clicks, movements) to all clients. Clients replay these inputs deterministically. The server does not stream game state.
- `game.print(msg)` is seen by all players on all clients.
- `player.print(msg)` is visible only to that player.
- `rcon.print(data)` sends output to the RCON client (external tool), not to any in-game player.
- `/sc` (silent-command) executes Lua. The command text is sent as an input action to all clients, so every client executes it.
- Server-side integration uses `raw_print` with protocol tags (e.g., `[DISCORD]`, `[DATA-SET]`, `[PLAYER-JOIN]`) in `utils/server.lua`. An external process reads stdout and can send RCON commands back.

### Determinism and the Security Model

**`math.random()` is shared and event-dependent.** At runtime, `math.random()` draws from the game's global random generator. This generator is shared between the core game engine, all mods, and scenario code. Engine-internal operations advance the generator state between Lua calls, so the number you get depends on the full history of game events up to that point -- not just on a seed. `math.randomseed()` has no effect in Factorio; the function is a no-op.

Because the sequence is entangled with all game activity, `math.random()` is naturally hard to predict from a player's perspective. Use it for gameplay rolls, AI decisions, and anything where unpredictability matters. Do not use it where reproducibility matters -- two calls at different moments in the game will not produce the same sequence even with identical seeds.

`math.random()` cannot be called outside of event handlers or during loading.

**`LuaRandomGenerator` is isolated and reproducible.** A generator created with `game.create_random_generator(seed)` maintains its own state, completely separate from the global generator and from other mods. Given the same seed, it produces the same sequence regardless of game events. Use it when reproducibility matters (e.g., terrain generation from a chunk position and map seed). Do not use it where unpredictability matters -- a player who knows or guesses the seed can predict every output. Note that seeds 0 through 341 all produce the same sequence, and nearby seeds produce similar initial outputs.

**"Private" messages are not private at the simulation level.** Input actions such as whispers or team-only chat are broadcast to all clients in order to maintain the deterministic simulation. The client chooses whether to display them. A modified client can read and display any input action, including messages nominally addressed to another player. Treat all Lua-visible data -- player positions, inventory contents, chat messages, `/sc` arguments -- as observable by any client.

**The map seed is public.** Every client receives the map seed and can reproduce the full map generation offline before exploring it in-game. Features that depend on map layout being unknown to the player (e.g., hidden resource placement as a gameplay mechanic) are not feasible.

Consequences for scenario code:

- For example, do not use `player.print()` to transmit information that would give a meaningful advantage if intercepted. Use `helpers.write_file(..., for_player)` for genuinely server-side-only output, or design around the assumption that any displayed value can be read.
- Anti-cheat and anti-grief logic runs inside scenario Lua and is effective. Because the simulation is lockstep, any client that produces a diverging game state will desync and be disconnected -- a cheat cannot silently modify shared game state without being caught. Scenario-level enforcement (blocking invalid actions, rate-limiting, detecting anomalies) is the right layer. What cannot be relied on is keeping data *secret* from clients; the constraint is on information hiding, not on action enforcement.
- When designing cheat detection, prefer **anomaly detection** over static global thresholds. Useful signals: action rate far exceeding human capability (implying an automation tool); implausibly perfect placement patterns (e.g., every miner snapped to optimal grid with zero deviation across dozens of placements); a sudden performance jump diverging sharply from a player's established baseline (e.g., efficiency jumping from ~50% to ~99% within a session with no plausible explanation). Per-player baselines accumulated in `storage` over time are more robust than fixed limits that legitimate skilled players may exceed.

### Forces

The scenario creates multiple forces: `north`, `south`, `north_biters`, `south_biters`, `spectator`, plus boss-unit forces. Force relationships (cease-fire, friend, share-chart) are configured in `maps/biter_battles_v2/init.lua`.

## Network and Data Transmission

### Writing Data Out

| Method | Destination | Notes |
|--------|-------------|-------|
| `helpers.write_file(filename, data, append, for_player)` | `script-output/` folder | `for_player = 0` writes server-only. [API docs](https://lua-api.factorio.com/latest/classes/LuaHelpers.html#write_file) |
| `rcon.print(data)` | RCON client | Used in `utils/server.lua` for `export_stats` |
| `log(msg)` | `factorio-current.log` | Mixed with engine output |
| `raw_print(msg)` | Server stdout | Used with protocol tags for external integration |
| `helpers.send_udp(port, data)` | Localhost UDP | Requires `--enable-lua-udp` launch flag |

### Reading Data In

| Method | Source | Notes |
|--------|--------|-------|
| RCON commands | External tool | Executes Lua via `/sc` or custom commands |
| `helpers.recv_udp()` | Localhost UDP | Dispatches `on_udp_packet_received` events. Requires `--enable-lua-udp` |

### Server Network Settings

Key settings from `server-settings.json`:

- `max_heartbeats_per_second`: Network tick rate (default 60). Controls how often input actions are batched and sent.
- `minimum_segment_size` / `maximum_segment_size`: Control how large network messages are split across ticks.
- `require_user_verification`: When `false`, clients can connect without a Factorio.com account (useful for local testing).

## Debugging

### Preferred: `helpers.write_file`

Write trace/debug output to a file in `script-output/`. This is the cleanest method for debugging -- the output is isolated from engine noise.

```lua
helpers.write_file('debug-trace.log', serpent.line(some_data) .. '\n', true, 0)
```

- `true` = append mode
- `0` = server-only (does not write on clients)
- The file appears at `<factorio-user-data>/script-output/debug-trace.log`

### Alternative: `log()`

`log()` writes to `factorio-current.log`. This works but the log contains significant engine noise (entity updates, network messages, etc.), making it harder to isolate your output.

### Avoid in Production

`game.print()` is visible to all connected players. Do not leave debug prints in committed code.

## Agent Behavioral Rules

### Scope Verification

Before implementing changes that affect **game mechanics, balance, or core systems**, ask the user:

1. Whether the change has been proposed and voted on in the community Discord.
2. What the scope and boundaries of the change should be.

Refer them to the change policy section of [CONTRIBUTING.md](CONTRIBUTING.md). A negative answer (no vote, or vote not yet held) **should not abort** your task -- proceed if the user confirms they want the change made.

### Code Changes

- Follow the code style and commit conventions described in [CONTRIBUTING.md](CONTRIBUTING.md).
- Run `stylua .` before committing.
- Run tests (`lua tests/test-*.lua`) before committing.
- Look for existing utility functions in `utils/` and `functions/` before writing new ones.
- When modifying event handlers, verify the registration happens at the control stage.
- When adding data to `storage`, ensure all values are serializable.

### Commit Practices

- Make small, atomic, self-contained commits.
- Use format: `scope: description` in lowercase.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for full details.
