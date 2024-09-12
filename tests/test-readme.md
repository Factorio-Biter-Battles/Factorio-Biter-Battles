# Biter Battles Test Suite

This folder contains the test suite for the Biter Battles scenario, a popular multiplayer map in Factorio. We use Lunatest, a unit testing framework for Lua, to ensure the reliability and correctness of our scenario code.

## Table of Contents

1. [Installing Lua](#installing-lua)
2. [Setting Up Lunatest](#setting-up-lunatest)
3. [Writing Tests](#writing-tests)
4. [Running Tests](#running-tests)
5. [Best Practices](#best-practices)

## Installing Lua

Before we can run our tests, we need to install Lua on your system. Here are instructions for different operating systems:

## Windows
The easiest way to install Lua on Windows is by using WinGet:

Open a command prompt or PowerShell window.
Run the following command:
```
winget install "Lua for Windows"
```

Follow any prompts that appear during the installation.

Note: WinGet is included by default in Windows 11. For earlier Windows versions, you can install it from the Microsoft Store.

### Linux

On most Linux distributions, you can install Lua using the package manager:

For Ubuntu or Debian:
```
sudo apt-get update
sudo apt-get install lua5.3
```

For Fedora:
```
sudo dnf install lua
```

For Arch Linux:
```
sudo pacman -S lua
```

Verify the installation by running `lua -v` in the terminal.

### macOS

The easiest way to install Lua on macOS is using Homebrew:

1. If you don't have Homebrew installed, install it first:
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
2. Install Lua:
   ```
   brew install lua
   ```
3. Verify the installation by running `lua -v` in the terminal.

## Setting Up Lunatest

After installing Lua, we need to set up Lunatest:

1. Install LuaRocks, a package manager for Lua:
   - Windows: Download and run the installer from the [LuaRocks website](https://github.com/luarocks/luarocks/wiki/Download).
   - Linux: Use your distribution's package manager (e.g., `sudo apt-get install luarocks` for Ubuntu).
   - macOS: Use Homebrew: `brew install luarocks`.

2. Install Lunatest using LuaRocks:
   ```
   luarocks install lunatest
   ```

## Writing Tests

Here's a basic structure for writing tests using Lunatest:

```lua
local lunatest = require("lunatest")
local CaptainCommunityPick = require("comfy_panel.special_games.captain_community_pick")

-- Test case
function test_pick_order()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player1", "player3", "player4"},
        player3 = {"player3", "player1", "player2", "player4"},
        player4 = {"player4", "player1", "player2", "player3"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equals(4, #result, "Pick order should contain 4 players")
    -- Add more assertions as needed
end

-- Run the tests
lunatest.run()
```

Place your test files in the `tests` directory of your scenario.

## Running Tests

To run the tests:

1. Open a terminal or command prompt.
2. Navigate to your scenario's directory.
3. Run the following command:
   ```
   lua tests/test_file_name.lua
   ```
   Replace `test_file_name.lua` with the name of your test file.

## Best Practices

1. Name your test files with a `test_` prefix (e.g., `test_community_picks.lua`).
2. Write descriptive test function names (e.g., `test_pick_order_with_ties()`).
3. Use Lunatest's assertion functions like `assert_equals`, `assert_true`, etc.
4. Mock Factorio's global functions and objects that your code depends on.
5. Keep tests isolated and independent of each other.
6. Regularly run your test suite, especially before committing changes.

Remember, these tests run outside of Factorio, so you'll need to mock any Factorio-specific functions or objects that your code uses. This allows you to test your Lua logic independently of the game environment.

For more information on Lunatest, refer to the [Lunatest documentation](https://lunarmodules.github.io/lunatest/).

Happy testing!
