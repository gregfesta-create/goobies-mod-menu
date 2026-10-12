MOD_MENU AUTHOR EXAMPLE

The final distributable includes this folder as examples/, separate from runtime
mods. This is an optional template; it is not installed automatically.

To try it after installing Mod_Menu, copy ExampleMod to:
  <game>/Shooter/Binaries/Win64/Mods/ExampleMod/
Open Mod Menu, enable Example Settings Mod, and click Refresh. The framework
creates Win64/Configs/ExampleMod.ini when the enabled package first starts.
Use its cog to change the two demonstration settings. They affect only the panel.
Do not add this managed package to UE4SS mods.txt: Mod_Menu loads Package/main.lua.

This example declares LiveToggle=true because it only draws settings controls.
Off hides those controls immediately; On resumes them if the entry is already
loaded. Refresh loads the entry on its first activation in the current session.
For a gameplay mod, opt in only after implementing safe late initialization and
gating every ongoing effect on ctx.query(ctx.id).enabled and active. Otherwise
omit LiveToggle and use startup-only activation. Refresh does not unload code.

To create your mod, rename the folder and Package Id, Name, and default INI filename.
Keep Entry=Package/main.lua. Set Version to your mod version. Updated is an
author-supplied YYYY-MM-DD date; omit it if unknown. Never fabricate an update date.
Mod_Menu maintains enabled state, Ver, Inst and Upd in Win64/Configs/ModList.ini.
Inst is recorded when tracking begins and remains fixed; it is not historical
installation evidence for pre-existing mods. Missing update metadata becomes ?.

Ship defaults at Defaults/Configs/<PackageId>.ini. On enabled startup, missing
settings get defaults. Existing settings files are preserved; only absent keys
are added, with a verified .before-defaults-*.bak snapshot before merging.
User values, comments, unknown and removed settings remain. Disabled packages
do not get new settings files or default merges. Do not delete their existing INIs.

The current provider explicitly builds the Settings Info controls. INI keys do
not automatically become controls. A removed feature can retain its obsolete
key in the INI while the new provider omits it from the panel and ignores it.
For renamed keys or incompatible types, implement an explicit, backed-up migration;
the framework does not guess which old setting maps to which new setting.

readConfig/writeConfig refer only to your package's build-local config file.
Read again before editing to retain unrelated keys. Commit in-memory settings only
after a successful save. Call invalidate to refresh the information panel.
restartRequired=false is correct here because the example settings apply immediately;
real mods must report restart requirements according to their actual behavior.

For the full provider contract see Mod_Menu/PROVIDER_API.md in the source project.
This example has offline validation; game and cross-computer acceptance are separate.
