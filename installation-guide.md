This guide will walk you through the process of setting up the Biter Battles scenario for development purposes in Factorio.

## Prerequisites

- Factorio game installed on your system
- Git installed on your system
- Basic knowledge of using the command line

## Installation Steps

1. **Navigate to Factorio Scenarios Directory**
   
   Open a terminal or command prompt and navigate to your Factorio scenarios directory. The location may vary depending on your operating system:
   
   - Windows: `%AppData%\Factorio\scenarios`
   - macOS: `~/Library/Application Support/factorio/scenarios`
   - Linux: `~/.factorio/scenarios`

2. **Clone the Biter Battles Repository**
   
   Clone the Biter Battles repository directly into the scenarios directory:

   ```
   git clone https://github.com/Factorio-Biter-Battles/Factorio-Biter-Battles.git biter_battles
   ```

   This will create a new directory named `biter_battles` in your scenarios folder.

3. **Alternative: Use a Symlink**
   
   If you prefer to keep the repository elsewhere, you can clone it to another location and create a symbolic link:

   ```
   git clone https://github.com/Factorio-Biter-Battles/Factorio-Biter-Battles.git ~/path/to/repo
   ln -s ~/path/to/repo/biter_battles /path/to/factorio/scenarios/biter_battles
   ```

   Replace `/path/to/factorio` with the actual path to your Factorio directory.

4. **Verify Installation**
   
   Launch Factorio and check if "Biter Battles" appears in the list of available scenarios when creating a new game.

## Development Workflow

1. **Make Changes**
   
   Edit the files in the `biter_battles` directory using your preferred text editor or IDE.

2. **Testing**
   
   To test your changes:
   - Launch Factorio
   - Start a new game
   - Select "Biter Battles" from the scenarios list
   - Play and verify your changes

3. **Version Control**
   
   Use Git to manage your changes:
   ```
   git add .
   git commit -m "Description of your changes"
   git push origin main
   ```

4. **Contributing**
   
   To contribute your changes to the main project:
   - Fork the original repository on GitHub
   - Push your changes to your fork
   - Create a Pull Request from your fork to the main repository

## Updating

To update your local copy of Biter Battles:

```
cd /path/to/factorio/scenarios/biter_battles
git pull origin main
```

## Troubleshooting

- If the scenario doesn't appear in Factorio, ensure you've cloned it to the correct directory.
- If you encounter errors, check the Factorio log file for more information.

For more help, refer to the [Factorio modding wiki](https://wiki.factorio.com/Modding) or the Biter Battles [discord](https://discord.gg/ZsNNTcPfXm).
