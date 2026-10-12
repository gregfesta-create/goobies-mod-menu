# Mod_Menu Provider API

This document describes the API available to managed Lua packages running under Mod_Menu. It is the contract for package authors and should remain consistent with the manager implementation.

## Package structure

A managed package uses the following structure:

* `mod_menu.ini` — package metadata and configuration.
* `Package/main.lua` — the package's Lua entry point.

Packages must follow the manager's package-discovery and configuration conventions. The manager owns its internal package ID, `ModMenu`, and that package cannot be disabled through the normal package controls.

## Package context API

Managed packages receive a context object that exposes the supported manager functions:

* `readConfig` — reads package configuration.
* `writeConfig` — writes package configuration.
* `query` — queries the manager for supported information.
* `requestMenuBack` — queues a back request for the game-thread UI loop; closes the current dialog first, otherwise the manager overlay. Does nothing outside the open manager and preserves committed restart handling. Optional packages own any key binding and preference.
* `registerSettings` — registers the package's settings with the manager UI.
* `invalidate` — invalidates cached state so it can be refreshed.
* `log` — writes messages through the manager's logging facility.

Packages should use these functions instead of directly manipulating manager-owned state or configuration files. Providers should handle errors returned by manager operations and avoid allowing an individual provider failure to interrupt the manager UI.

## Package enablement and lifecycle

The manager controls whether a managed package is enabled.

* Disabled package entries are not executed.
* A disabled package's Lua code cannot register its settings provider until the package is enabled and executed.
* Changes that require a package to be loaded again may require a game restart.
* The manager does not provide native module loading or unloading.

Enabling or disabling a managed package does not automatically enable or disable ordinary UE4SS mods, native modules, or GoobiesMP. Those systems remain outside this API's management scope.

## Settings providers

Packages can register settings through `registerSettings`. The manager uses the registered settings to construct the package's settings interface.

Supported setting types include:

* `ui.label` — informational text.
* `boolean` — a true/false setting.
* `number` — a numeric setting.
* `swatches` — a selectable set of color or value choices.
* `widgets` — supported custom widget content.

Providers must supply values in the format expected by the manager. They should validate configuration values and tolerate missing, malformed, or outdated configuration where practical.

Provider functions may fail. The manager must handle provider errors and invalid return values without allowing one provider to crash the settings interface or stop the rest of the UI from updating.

## Build, information, and control boundaries

`build(ui, panel)` is required; `buildInfo(ui, panel)` is optional. Both render through the supplied API; their return values are ignored, including false or tables. Field lookup and invocation share a protected boundary, so throwing table accessors and non-callable fields are reported locally. Missing providers show the existing selection prompt; absent information callbacks are valid.

Failed builds clear only their affected panel content, callbacks and animations. Information callbacks have a separate ownership set: refreshing or removing information prunes its prior callbacks and animations without accumulating them or removing list/settings controls. Closing releases the information-panel reference. Callbacks registered during a build through custom widget primitives are protected when dispatched; exceptions report a settings-provider error and leave the menu loop available. These boundaries contain ordinary provider failures; they are not a sandbox against code that directly mutates shared widget/manager state or registers callbacks later outside the build.

The supplied primitive contracts are:

| Primitive | Arguments and behavior |
| --- | --- |
| `label(parent, text)` | Preserves existing text conversion and returns its row. Conversion errors are contained by the build boundary. |
| `boolean(parent, label, value, set, warning)` | Value is a boolean; editable controls require a function setter. Read-only controls require no setter. |
| `number(parent, label, value, min, max, step, set, warning)` | Numeric arguments must be finite, bounds ordered and step positive. Editable controls require a function setter. Existing clamped button behavior is retained; package validation remains responsible for stored values. |
| `swatches(parent, controls)` | Controls form a dense array; an empty array is valid. Existing swatch/color/callback contracts below apply. |
| `widgets` | Existing widget primitives remain available in the allocated panel. Authors remain responsible for read-only information and avoiding unrelated UI/state mutation. |

Setters receive the requested value. Existing compatibility is retained: a truthy first result indicates success; false/nil indicates rejection with an optional diagnostic second result. Exceptions and diagnostics that cannot be converted to text are reported safely. Failed setters do not advance the Boolean toggle target or report success. A callback may have changed its own persistent state before failing; the framework cannot undo arbitrary provider side effects. Setter success alone does not prove real-game application.

## Swatches

Swatch settings must provide valid choices and a valid selected value. The selected value should correspond to an available choice whenever possible.

Providers should handle missing or invalid selections safely. The manager should avoid crashing if a provider returns malformed swatch data.

Swatch controls supply a string `label`, a `#RRGGBB` `value`, callable `options` and `set`, and optionally a callable `current` returning the selected `#RRGGBB` value. `options()` returns a dense array (an empty array is valid) of tables with unique case-insensitive `#RRGGBB` colors and optional boolean `available` values. `available` defaults to true; the currently selected choice remains selectable as before. The provider setter remains responsible for validating reservations again when a selection is made.

The manager validates callbacks and option data inside one protected boundary at popup opening and each live refresh. It copies validated choices before rendering. A callback error, non-array return, gap, malformed entry/color/availability, or duplicate color produces a settings-provider error and closes only the affected popup, removing its callbacks. The list/detail screen and UI polling remain available. Unrelated engine/rendering failures still reach the existing UI cleanup boundary. These behaviors have offline mock coverage; real-engine acceptance remains unverified.

## Restart-required settings

Some settings cannot take effect until the relevant package or game is restarted.

For the first release, restart handling is **manual**. The manager must not rely on automatic restart helpers, receipts, cancellation callbacks, or timeout-based restart recovery.

When a setting requires a restart, the UI should communicate that requirement clearly. The user can then restart the game manually for the change to take effect.

Setting setters run immediately through the existing provider interface. Writing configuration does not itself create a restart requirement. A provider may supply `restartRequired = function() return pendingBoolean end`; it must return a boolean describing a known pending change relative to its applied state. Return false after a live application or reversion; omit the callback when there is no restart requirement. The framework does not infer this from a setting's type or assume a successful setter proves real-game application.

A failed callback, non-callable field or non-boolean result produces an explicit "restart requirement unknown" status. Known pending package/provider changes still show the indicator even when another provider fails. Clicking the indicator shows manual exit/relaunch instructions and Close only. The normal entry point has no restart service/helper/exit wiring.

## Error handling and UI resilience

Provider code is external to the manager and must be treated as potentially unreliable.

The manager should:

* Catch errors raised by provider functions.
* Validate returned values before using them to render controls.
* Handle errors from restart-requirement checks without silently assuming that a restart is unnecessary.
* Keep the UI responsive if one provider fails.
* Avoid removing or permanently detaching existing menu controls when a UI modification fails.
* Restore original menu controls when closing or abandoning a modified menu, where applicable.

A failure in one package should not prevent other packages or the manager interface from functioning.

## Configuration and package IDs

Package IDs must be unique without regard to letter case. Windows reserved device names and manager-owned configuration names must be rejected to prevent configuration-path aliases.

The manager's internal ID is `ModMenu`. It is permanently owned by the manager and cannot be disabled through normal package controls.

The authoritative manager registry for this release is build-local `Win64/Configs/ModList.ini`, resolved from the installed `Win64/Mods/mod_menu/Scripts/main.lua` location. Only if it is absent, the prior `Configs/mods.ini` registry is copied without modifying the legacy file. Existing canonical contents take precedence; defaults apply only when both registries are absent. This does not touch `Configs/<PackageId>.ini` settings.

Native modules and ordinary UE4SS packages remain unmanaged. This API does not enable or disable their loader entries and does not modify the loader configuration.

## Dependency metadata and managed startup

Dependency sections in `mod_menu.ini` are optional and case-sensitive:

```ini
[Dependencies]
Library=1.2.0
Utilities=*
[OptionalDependencies]
OptionalCompanion=*
```

IDs resolve case-insensitively, including through `query(id)`. Values support an exact installed manifest version or `*`; ranges and comparison operators are rejected. Empty sections are valid. Invalid/reserved IDs, malformed rows and repeated IDs across either section reject the manifest with a diagnostic. These sections are metadata, not ModList.ini fields; packages with no declarations remain compatible.

Required dependencies must be installed, enabled for the relevant startup/requested state, controlled by managed startup (or the locked manager), version-compatible and acyclic. The manager starts required packages first, then runs the dependent only if their startup succeeded. External/native state is unknown and cannot satisfy a required edge. Missing, disabled, incompatible, cyclic and failed-startup requirements leave the dependent inactive, preserve requested choices and expose `error`/`dependencyError` through query and UI. Optional declarations are advisory: absence, disablement or version mismatch never blocks startup or promises ordering. Providers can use query to inspect availability/version/active state themselves.

Enabling with unmet requirements or disabling a dependency needed by an otherwise valid enabled package is rejected before saving, with a named diagnostic. Disable affected dependents first; there is no automatic cascade, enablement, download or replacement. Disable All stages all eligible packages OFF together and leaves ModMenu ON. Pre-existing unrelated dependency failures do not prevent unrelated repairs. Changes remain staged for manual restart; required startup checks use the original startup snapshot, not subsequently edited choices.

Startup exceptions remain isolated. Safe diagnostic conversion and logging preserve error state if formatting/logging fails. A failing entry's partial provider and invalidation registration are removed; other providers and disk settings are preserved. This does not undo arbitrary package side effects or manage native loader activation.

## Compatibility expectations

The provider API is a contract between managed packages and Mod_Menu. Changes to function names, configuration formats, accepted setting types, package lifecycle behavior, or error-handling expectations should be reflected in this document.

The implementation and this document should agree. Do not document unimplemented functionality as available, and do not claim that restart handling, game integration, or other runtime behavior has been verified unless it has actually been tested.

Enable All stages all managed optional packages ON as one dependency-validated, non-destructive registry update. Invalid dependencies reject the entire action; external/native packages are unchanged. ModMenu remains enabled. Manual restart applies package enablement.

Restart UI update (2026-10-10): the framework now offers an explicit Restart button beside Close, using a bounded normal-exit/relaunch handshake. This supersedes the earlier manual-only UI restriction; provider restartRequired boolean semantics are unchanged. Settings still apply immediately when their provider supports them.

## Registry dates and settings upgrade policy — 2026-10-10

Canonical Win64/Configs/ModList.ini rows use:
`PackageId=true|Ver:1.0.0|Inst:2026-10-10|Upd:?`.
Legacy `version:` entries remain readable. Existing enablement, valid installation dates, unknown extension fields, comments and unrelated entries are preserved. Missing installation dates become the current local date when tracking begins; this is not proof of an older historical installation. `Upd` comes only from `[Package] Updated=YYYY-MM-DD` in mod_menu.ini; missing/invalid values become `?`. No filesystem date fallback. Installed/Updated sorts keep unknown dates last.

Every discovered package gets a registry entry, including disabled packages. Only enabled package startup prepares Configs/<PackageId>.ini. It copies package-owned Defaults/Configs/<PackageId>.ini when absent, or creates an empty [Settings] section if defaults are absent. Existing settings receive only missing default keys, preserving original bytes as a prefix, user values, obsolete keys, comments and unknown entries. Before a changed merge, an exact verified .before-defaults-<timestamp>-<index>.bak is retained beside the settings file; stale contents prevent promotion. Repeated merges do not rewrite unchanged files. Disabled package settings are neither created nor merged.

The Settings Info panel is built by the current provider, never by enumerating all INI keys. Removed feature keys may remain for downgrade recovery but do not appear unless the current provider exposes them. Renames, incompatible values and semantic migrations remain the author's responsibility; do not guess or delete old values. The optional Examples/ExampleMod template demonstrates this contract and is packaged under examples/, outside active runtime Mods.

LiveToggle package contract (2026-10-10): [Package] LiveToggle=true explicitly opts a managed entry into late game-thread activation through Refresh. The entry must be safe to initialize while the menu is open, and every ongoing effect must check ctx.query(ctx.id).enabled and active. Off does not unload Lua or undo arbitrary native hooks; the package is responsible for suppressing its behavior. Already loaded entries never execute twice, failed attempts require process restart before retry, and dependencies must be enabled and active (live-capable dependencies activate first). Current MenuOptions implements this contract; ordinary packages retain startup-only behavior. Refresh loads registry choices and eligible entries, not arbitrary mod-settings INI reload.


Fixture live toggling (2026-10-10): all four UI/configuration-only development fixtures and optional author example now declare LiveToggle=true. Framework hides disabled live-package provider controls/details and suppresses their provider restart requirements; bulk actions refresh selected details. Live disabled entries remain loaded but have no non-panel effects in these fixtures; enabling uses existing safe Refresh activation. Separate StartupSample changes still intentionally require process restart. Full offline suite passed, including disabled-provider restart gating. Backed-up test deployment: fixture_live_toggle_20261010T093916Z_7c0a27cc; full inventory verified. No gameplay/native/guard or ZIP changes. Actual Disable All/Enable All→Refresh acceptance pending.

