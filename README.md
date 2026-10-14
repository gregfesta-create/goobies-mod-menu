# Mod Menu for Goobies

The mod manager every Goobies mod uses: it lists your mods, turns them on and off, holds their settings and brings the
UE4SS mod loader. **Version 1.1.0-test.1 is a test build** (pre-release).

## Requirements

- Goobies on Steam (Windows). Nothing else: the UE4SS loader is in the zip.

## Install

1. Find the game folder: in Steam, right-click Goobies, *Manage > Browse local files*. Open `Shooter\Binaries\Win64`
   (the folder with `Shooter-Win64-Shipping.exe`); below this is called `Win64`.
2. If you already use other UE4SS mods, back up `UE4SS.dll`, `dwmapi.dll` and `UE4SS-settings.ini` in `Win64`.
3. If Windows marks the zip as blocked: right-click it, *Properties*, tick **Unblock**.
4. Put `goobies_mod_menu_1.1.0-test.1.zip` into `Win64` and extract it there (*right-click > Extract All*, target `Win64` itself).
5. Start Goobies through Steam. *Mods* is in the main menu.

## Mods that use Mod Menu

- Goobies Multiplayer: [goobies-mp](https://github.com/gregfesta-create/goobies-mp/releases) (requires Mod Menu; install both, in any order).
- Menu Options: [goobies-menu-options](https://github.com/gregfesta-create/goobies-menu-options/releases).

## Known limits

- The achievement guard is not in this build yet: the main menu shows a notice that achievements are not blocked, and play stays allowed. Built-in blocking is coming in a later Mod Menu update.
- The bundled UE4SS loader is an experimental build (v3.0.1-1164); it replaces an older UE4SS in the same folder.

## Reporting a problem

`Report a problem.bat` ships inside the Mod Menu mod folder, `Win64\Mods\mod_menu`.

**Easiest way: double-click `Report a problem.bat` in your Mod Menu folder.**

Every Goobies mod needs Mod Menu, so the report tool comes with it. It is in your Goobies folder under `Shooter\Binaries\Win64\Mods\mod_menu\` (in Steam: right-click Goobies > **Manage** > **Browse local files**; if you see `Goobies_DX11` or `Goobies_Vulkan`, open the one you play).

1. Double-click `Report a problem.bat`. It works without a window, so give it a few seconds: it reports on the game copy it sits in, saves `Goobies_crash_report_<date>.zip` in your Downloads folder, opens the crash-report page in your browser and tells you in a small popup where the zip is. If Windows warns about the file, choose **More info > Run anyway**.
2. Fill in the form on that page and drag the zip into it.

## Uninstall

Delete `Win64\Mods\mod_menu`, `UE4SS.dll`, `dwmapi.dll` and `UE4SS-settings.ini` (the mods that need Mod Menu stop
working). Your save is not changed.

## License

See `LICENSE`. UE4SS is MIT-licensed (`Mods\mod_menu\ThirdParty\UE4SS-LICENSE.txt`).
