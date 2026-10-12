# Goobies Mod Menu

A mod manager for **Goobies** (Steam, DirectX 11 build). It adds a **Mods** button to the main menu where you can turn mods on or off and change their settings. Other Goobies mods (Menu Options, Goobies Multiplayer) are built on it.

**Version:** 1.0.1 (see `Mods/mod_menu/CHANGELOG.md`).

## Install
1. Find your game's `Shooter/Binaries/Win64` folder: Steam → right-click Goobies → Manage → Browse local files.
2. Copy everything in this repository into that `Win64` folder, keeping the folder structure.
3. Start the game. A **Mods** button appears on the main menu.

This package includes [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (`UE4SS.dll`, `dwmapi.dll`, `UE4SS-settings.ini`), the Lua mod loader Mod Menu runs on. Its license is in `Mods/mod_menu/ThirdParty/UE4SS-LICENSE.txt`.

Full details: `Mods/mod_menu/INSTALL.txt`.

## Note about the achievement guard
The 1.0.1 release candidate also shipped an optional native achievement guard (`native/achievement_guard_candidate.dll`), which had to be installed by hand outside `Win64`. It is **not included here**: Mod Menu works without it, and the guard is being replaced by a new version. Skip the "Achievement guard setup" section of `INSTALL.txt`.

## For mod authors
See `Mods/mod_menu/PROVIDER_API.md` and the example in `examples/`.
