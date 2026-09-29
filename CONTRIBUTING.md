# Contributing Guide

## Table of Contents

- [Getting Started](#getting-started)
- [Code Style](#code-style)
- [Running Tests and Style Checks](#running-tests-and-style-checks)
- [Commit Conventions](#commit-conventions)
- [Testing in Multiplayer Locally](#testing-in-multiplayer-locally)
- [Change Policy](#change-policy)

## Getting Started

### First-time setup

1. **Fork** the repository at <https://github.com/Factorio-Biter-Battles/Factorio-Biter-Battles> by clicking **Fork** on GitHub.

2. **Clone** your fork into your [Factorio scenarios folder](https://wiki.factorio.com/Application_directory#User_data_directory):

```bash
git clone <your-fork-url>
```

The folder name produced by `git clone` becomes the in-game scenario name. Rename it if you want a shorter or clearer name before opening Factorio.

3. **Verify your remote URLs** with:

```bash
git remote show origin
```

You should see your fork as the push and fetch URL. Point remote fetch origin at upstream project and push at your work.

```bash
# Set fetch URL to the upstream repo
git remote set-url origin git@github.com:Factorio-Biter-Battles/Factorio-Biter-Battles.git

# Set push URL to your fork
git remote set-url --push origin git@github.com:<your-username>/Factorio-Biter-Battles.git
```

4. **Open the scenario in Factorio** to verify it loads. In the main menu, choose **Single Player → New Game → User Scenarios** (or **Multiplayer → Host New Game**) and select the folder you cloned.

### Working on a change

**If you have contributed before**, sync your local `master` with the upstream before branching:

```bash
git fetch
git checkout master
git pull
```

**Create a branch** for your change:

```bash
git checkout -b my-feature
```

**Make your changes**, then inspect them before staging:

```bash
git status          # list changed files
git diff            # show unstaged changes
```

**Stage and commit:**

```bash
git add <file>      # or: git add . to stage everything
git commit -m "scope: description of change"
```

**Push** your branch:

```bash
git push
```

If this is the first push for the branch, Git will print an error asking you to set the upstream. Run the command it suggests:

```bash
git push --set-upstream origin my-feature
```

When in doubt add `--dry-run` to e.g. `push` command to see the effect of the command without causing any changes. The push command will output similar text to this:
```
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
remote:
remote: Create a pull request for 'my-feature' on GitHub by visiting:
remote:      https://github.com/<your-username>/Factorio-Biter-Battles/pull/new/my-feature
remote:
To github.com:<your-username>/Factorio-Biter-Battles.git
 * [new branch]        my-feature -> my-feature
```
Paste the link into your web browser and proceed with the pull request.

**Open a pull request** on GitHub. Set the base to `Factorio-Biter-Battles/Factorio-Biter-Battles` / `master` and the compare branch to your branch. Add a short description of what the change does and why.

**Incorporating review feedback** — when a reviewer asks for changes, fold them into the relevant existing commit rather than adding new "fix review" commits on top. Amend the commit directly:

```bash
git add <file>
git commit --amend --no-edit   # keeps the existing commit message
git push --force-with-lease    # safe force-push; fails if someone else pushed
```

For multi-commit branches, use interactive rebase to edit the right commit:

```bash
git rebase -i origin/master
# Mark the target commit as 'edit', save, make changes, then:
git add <file>
git commit --amend --no-edit
git rebase --continue
git push --force-with-lease
```

If you add fix-up commits instead, the person merging your change may squash all commits into one to keep the history clean — meaning your individual commit messages are lost.

## Code Style

### Formatting

Code is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua). The project configuration lives in `.stylua.toml`:

- 120 character column width
- 4-space indentation (no tabs)
- Single quotes preferred
- Unix line endings
- Parentheses always required on function calls

Run `stylua .` from the project root to format all Lua files.

### Naming Conventions

- **Imports**: `local ModuleName = require('path.to.module')` -- the local variable starts with a capital letter.
- **Everything else**: `snake_case` for functions, local variables, table keys, and file names.
- **Module pattern**: files export a table named `Public`:

```lua
local Public = {}

---@param force_name string
---@return number
function Public.get_threat(force_name)
    return storage.bb_threat[force_name] or 0
end

return Public
```

### Annotations

Use [LuaLS](https://luals.github.io/) annotations on every function and on variables where the type is not obvious:

```lua
---@param player LuaPlayer
---@param message string
---@return boolean success
---@return string? error_message
local function send_warning(player, message)
    ...
end
```

Common annotations: `---@param`, `---@return`, `---@class`, `---@field`, `---@type`, `---@alias`.

### Structure

- **Keep code flat.** Prefer early returns over deeply nested `if/else` chains. Extract logic into small, focused helper functions that serve as building blocks.
- **Avoid duplication.** Before writing a utility function, check `utils/` and `functions/` for existing implementations.
- **Minimize scope.** Keep variables as local as possible. Avoid polluting the module table with internal helpers -- only expose what other modules need.
- **One concern per function.** Each function should do one thing. If a function needs a comment explaining "this part does X, and this part does Y", split it.
- **Split large modules.** A module that grows beyond a single clear responsibility should be broken into smaller focused files. Prefer many small modules over one large file that handles multiple concerns. The captain special game is a good example: rather than one monolithic file it is split into `captain.lua` (entry point and coordination), `captain_ui.lua` (GUI code), `captain_states.lua` (state machine), `captain_utils.lua` (shared helpers), `captain_community_pick.lua` (community pick logic), and `captain_task_group.lua` (task group management).

## Running Tests and Style Checks

Both checks must pass before every commit.

### Tests

The test suite uses [Lunatest](https://lunarmodules.github.io/lunatest/). Tests run outside Factorio with a standalone Lua interpreter.

**Prerequisites:**

```bash
# Install Lua 5.2 and LuaRocks, then:
luarocks install lunatest
luarocks install serpent
```

**Run all tests:**

```bash
lua tests/test-feeding.lua
lua tests/test-functions.lua
lua tests/test-biter_raffle.lua
lua tests/test-utils.lua
```

Tests mock Factorio-specific globals.

### Style Check

```bash
stylua --check .
```

This will report any formatting issues without modifying files. To auto-fix, run `stylua .` instead.

CI runs both tests and StyLua checks on every push and pull request.

## Commit Conventions
### Guidelines

- **Atomic commits.** Each commit should be a single, self-contained logical change. This makes reviewing easier and keeps `git bisect` useful.
- **Scope prefix.** Use the module or area name as scope (e.g., `ai:`, `captain:`, `chatbot:`, `jail:`, `antigrief:`). Omit scope for cross-cutting changes.
- **Lowercase descriptions.** Start the description with a lowercase verb (e.g., `fix`, `add`, `remove`, `extract`, `refactor`, `improve`).
- **No trailing period** in the subject line.
- **Separate subject from body** with a blank line if a longer explanation is needed.

Examples from the project history:

```
ai: use swap-and-pop for O(1) spawner removal
jail: make reason argument optional
chatbot: (un)trust: add support for multiple players
captain: relocate picking UI code to separate module
fix tag spacing in chat messages
```

## Testing in Multiplayer Locally

Many bugs only surface in multiplayer (desync, UI state per player, force assignment). You can test multiplayer locally with a single machine.

### 1. Disable Account Verification

If you do not already have a `server-settings.json`, create one by
copying the example shipped with Factorio:

```bash
cp <factorio-install>/data/server-settings.example.json server-settings.json
```

Edit your `server-settings.json` and set:

```json
"visibility": {
    "public": false,
    "lan": true
},
"require_user_verification": false
```

This allows clients to connect without a Factorio.com account, which is necessary for running multiple local clients.

### 2. Host a Server

```bash
./factorio --start-server-load-scenario <scenario-folder-name>
```

where `<scenario-folder-name>` is the name of the folder in your scenarios directory.

### 3. Launch Multiple Clients

Each client needs its own player data directory for a separate identity. The simplest approach is to copy the entire Factorio installation directory (e.g., `cp -r ~/factorio ~/factorio-client2`). Each copy maintains its own player data, settings, and saves.

In each client, set a unique player name: **Settings > Other > LAN Player Name** (e.g., `TestPlayer1`, `TestPlayer2`).

### 4. Connect

In each client: **Multiplayer > Connect to address** and enter `localhost`.

You now have multiple players in the same game and can test team joining, spectating, force interactions, GUI behavior, and desync scenarios.

## Change Policy

### Changes Allowed Without a Vote

The following types of changes can be submitted directly via pull request:

- Bug fixes
- Performance optimizations
- Logging and diagnostics improvements
- New or improved tests
- Code refactoring and cleanup
- Quality of life improvements (e.g., better error messages, UI polish)
- New minor commands
- Special game modes (must be **disabled by default**)
- Documentation updates
- Other non-functional changes

### Changes Requiring a Discord Vote

Changes that affect **game meta, core mechanics, or balance** require a community vote on the [Discord server](https://discord.com/invite/hAYW3K7J2A) before they will be merged.

Rules for vote propositions:

- Propositions must aim to **improve the game experience for the majority** of players. Proposals targeted at harming specific players or groups will be removed.
- Propositions must be **reasonable**. Extreme changes to the game core may be rejected by admins, even if the vote is popular.
- Propositions that introduce **exploitable griefing vectors** may be rejected.
- Propositions should not **restrict strategies without other benefits** (e.g., "disable red belts", "forbid outposting").

If you are unsure whether your change requires a vote, ask in Discord or note it in your pull request.
