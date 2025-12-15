# FarmHud

## Known Issues / To-Do

- [ ] **TrailPath Zone Scaling** - Adjust scaling factors for all zones to ensure trail path pins display correctly on both minimap and HUD
- [ ] Verify trail path behavior in dungeons and instances
- [ ] Test trail path in Outland and Northrend zones

---

## [1.0.1] (2025-12-14)

**Taint Fix Update**

### Critical Bug Fixes

- **Fixed action bar taint issue** - Action bars now work correctly when entering combat with FarmHud open
- Added `InCombatLockdown()` check to `Toggle()` preventing taint spread during combat
- Added `InCombatLockdown()` check to `OnShow()` deferring HUD display until combat ends
- Wrapped `EnableMouse()` calls with combat lockdown checks to protect action bar state
- Deferred combat hide/show using `C_Timer.After(0, ...)` to avoid tainting during combat transitions
- Updated combat event handlers (`PLAYER_REGEN_DISABLED`/`ENABLED`) to use deferred UI updates

### User Experience

- FarmHud now displays a warning message if you try to toggle during combat
- "Hide in Combat" setting now works without causing taint

---

## [3.3.5a-backport] (2025-12-07)

**Complete backport to WoW 3.3.5a (Project Ascension)**

### Core API Polyfills

- Added `C_Minimap` polyfill wrapping `GetNumTrackingTypes()`, `GetTrackingInfo()`, `SetTracking()`
- Added `C_Timer` polyfill with `After()` and `NewTicker()` implementations using OnUpdate frames
- Added `C_Map` polyfill for `GetBestMapForUnit()`, `GetPlayerMapPosition()`, `GetMapInfo()`
- Added `C_AddOns` polyfill wrapping `IsAddOnLoaded()`
- Added `C_CVar` polyfill wrapping `SetCVar()`, `GetCVar()`, `GetCVarBool()`
- Added `ns.SetShown()` and `ns.Mixin()` helper functions

### Version Detection

- Removed `WOW_PROJECT_ID` checks (not available in 3.3.5a)
- Added `ns.IsClassic()`, `ns.IsClassicBC()`, `ns.IsRetail()`, `ns.IsDragonFlight()` all returning false

### XML Refactoring (FarmHud.xml)

- Replaced modern `mixin` XML attributes with classic `OnLoad` script handlers
- Removed `method` script handlers, replaced with standard Lua event handlers
- Updated all frame definitions to use WoW 3.3.5a compatible syntax

### Coordinates & Time Display

- Replaced `C_Timer` tickers with OnUpdate frame-based timers for coordinates display
- Replaced `C_Timer` tickers with OnUpdate frame-based timers for time display
- Fixed coordinate updates using `GetPlayerMapPosition("player")` directly

### HUD Scaling & Sizing

- Fixed `SetScales()` to clamp size to screen height preventing oversized HUD issues
- Added fallback sizing when WorldFrame returns invalid dimensions
- Extended hit rect insets to cover full screen for better interaction

### Player Arrow/Dot

- Added custom player arrow rendering system for HUD display
- Fixed player dot texture switching between custom and Blizzard default
- Added recursion prevention for texture updates

### Modules

#### CardinalPoints.lua

- Fixed cardinal direction positioning and rotation for 3.3.5a

#### TrailPath.lua  

- Complete rewrite of trail path pin system
- Fixed pins to remain static at world positions
- Implemented proper minimap and HUD positioning
- Added correct scaling based on zone size
- Fixed fade timer functionality

#### RangeCircles.lua

- Adapted for 3.3.5a API compatibility

### TOC Updates

- Changed Interface to 30300 (WoW 3.3.5a)
- Updated title to "FarmHud (Ascension)"
- Updated version to "3.3.5a-backport"
- Updated author to include backport credits

### Library Dependencies

- Using bundled HereBeDragons-2.0 with 3.3.5a compatibility layer
- Using bundled LibStub, CallbackHandler-1.0, AceGUI-3.0, AceConfig-3.0

---
 All credit to Hizuro and any other authors that may have added commits.

## [10.1.6-release](https://github.com/HizurosWoWAddOns/FarmHud/tree/10.1.6-release) (2025-08-09)

[Full Changelog](https://github.com/HizurosWoWAddOns/FarmHud/commits/10.1.6-release) [Previous Releases](https://github.com/HizurosWoWAddOns/FarmHud/releases)

- Update toc file  
