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

## Reporting a crash

**Double-click `Report a problem.bat` in your Mod Menu folder.** Every Goobies mod needs Mod Menu, so the report tool comes with it: it is in your Goobies folder under `Shooter\Binaries\Win64\Mods\mod_menu\` (in Steam: right-click Goobies > **Manage** > **Browse local files**; if you see `Goobies_DX11` or `Goobies_Vulkan`, open the one you play).

1. Double-click `Report a problem.bat`. It works without a window, so give it a few seconds. It reports on the game copy it sits in, saves `Goobies_crash_report_<date>.zip` in your **Downloads** folder, opens the crash-report page in your browser and tells you in a small popup where the zip is. If Windows warns about the file, choose **More info > Run anyway**.
2. Fill in the [Crash report issue](https://github.com/gregfesta-create/goobies-mod-menu/issues/new?template=crash_report.yml) form on that page and drag the zip into it.

Older Mod Menu without the tool? Download [`Report a problem.bat`](https://raw.githubusercontent.com/gregfesta-create/goobies-mod-menu/main/Tools/Report%20a%20problem.bat) and [`CollectCrashReport.ps1`](https://raw.githubusercontent.com/gregfesta-create/goobies-mod-menu/main/Tools/CollectCrashReport.ps1) into the **same folder** (right-click each link > **Save link as**). From outside the game folder it finds the game through Steam (the DX11 or Vulkan copy you played last).

Nothing is uploaded automatically. Only developer test builds that include a private `report_webhook.txt` next to the .bat can send the report straight to the developers: a popup asks first, and only **Yes** sends it. A sent report is deleted from your PC afterwards; a report that is not sent stays in your Downloads folder.

From a console: `powershell -NoProfile -ExecutionPolicy Bypass -File .\CollectCrashReport.ps1 -GameDir "<Goobies folder>" [-NoDump]`. If it fails, it leaves `Goobies_crash_report_FAILED.txt` in your Downloads folder with the reason and the retry steps, and opens it.

Included: UE4SS logs, `UE4SS-settings.ini`, `Configs/ModList.ini`, `Mods/mods.txt`, each mod's `mod_menu.ini`, the list of mod folders, the newest crash's `CrashContext.runtime-xml` and `CrashReportClient.ini`, a `summary.txt`, and the newest crash dump (`.dmp`) if it is 20 MB or less.

Removed from text files: your user name and profile folder, computer name, Steam and lobby IDs, IP and e-mail addresses, network host names, and the account/machine fields in the crash context. `summary.txt` warns if the newest crash looks older or newer than your last session, or came from a different Goobies copy; mention that in the issue.

**The `.dmp` file cannot be cleaned:** it is a snapshot of the game's memory and may contain personal information. To leave it out, run the script with `-NoDump`.

If the tool cannot run, zip these by hand (open them first and remove anything personal): `Shooter/Binaries/Win64/UE4SS.log`, `Shooter/Binaries/Win64/Mods/mods.txt`, `Shooter/Binaries/Win64/Configs/ModList.ini`, and the newest folder in `%LOCALAPPDATA%\Shooter\Saved\Crashes\`.
