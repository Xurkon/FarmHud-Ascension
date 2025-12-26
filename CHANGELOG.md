# FarmHud Changelog

## [2.0.6] - 2025-12-25

### Bug Fixes

- **Fixed stack overflow with MinimapButtonFrame** - Added recursion guard to prevent infinite loop when both FarmHud and MBF iterate over `Minimap:GetChildren()` simultaneously

---

## [2.0.5] - 2025-12-15

### Bug Fixes

- **Fixed TrailPath pins not appearing on HUD** - Pins were parented to wrong frame (FarmHud XML frame instead of FarmHudMapCluster container)

---

## [2.0.4] - 2025-12-15

### Bug Fixes

- **Fixed TrailPath module display** - Pins now show on HUD, minimap, and world map
- **Fixed 3.3.5a parentKey incompatibility** - Added SetupPinStructure helper to manually assign pin structure
- **Fixed all TrailPath options** - Scale, icon, color, minimap toggle, count, and timeout now work correctly
- Safe animation access to prevent errors when pin.Facing animation is missing

---

## [2.0.3] - 2025-12-15

### New Features

- **TrailPath module enabled** - Shows a trail of where you've been on the HUD, minimap, and world map

### Technical Changes

- Fixed `C_Timer.NewTicker` → OnUpdate frame pattern (native 3.3.5a)
- Fixed `C_CVar.GetCVarBool` → `GetCVar()` (native 3.3.5a)
- Added module OnShow/OnHide dispatch in FarmHud.lua
- Added module event dispatch (PLAYER_LOGIN, PLAYER_ENTERING_WORLD, etc.)

---

## [2.0.2] - 2025-12-15

### Bug Fixes

- **Fixed ElvUI instances panel appearing in HUD** - Added direct hiding of ElvUI minimap-related frames:
  - `LayerPickerFrame` (instance selector)
  - `RightMiniPanel`, `LeftMiniPanel`
  - `MinimapPanel`, `MinimapButtonFrame`
  - `MiniMapInstanceDifficulty`, `GuildInstanceDifficulty`

---

## [2.0.1] - 2025-12-15

### Bug Fixes

- **Fixed duplicate inner circle** - Removed hardcoded gatherCircle texture (SPELLS\CIRCLE.BLP) that was always visible regardless of Range Circles settings
- **Fixed CardinalPoints module** - Created FarmHud.TextFrame wrapper for 3.3.5a compatibility since XML parentKey/parentArray don't work
- **Fixed ElvUI compatibility** - Wrapped Minimap:SetZoom in pcall to prevent resetZoom nil errors
- **Fixed XML/Lua load order** - Created FarmHud_Mixins.lua to ensure mixin stubs exist before XML loads
- **Fixed nil reference errors** - Added nil checks throughout CardinalPoints module

### Technical Changes

- New file: `FarmHud_Mixins.lua` - Contains mixin stubs for XML scripts
- Updated TOC load order: Mixins → XML → FarmHud.lua
- FarmHud.lua now references XML-defined FarmHud frame instead of creating duplicate
- Added rot/NWSE properties to cardinal direction font strings

---

## [2.0.0] - 2025-12-15

**Complete Rewrite** - Taint-free implementation for Project Ascension

### New Features

- **No action bar taint** - Works correctly when entering combat with HUD open
- **Custom player arrow/dot** - 6 texture options including hide, gold, white, black dots
- **HUD symbol scale** - Scale addon pins (Routes, HandyNotes, etc.)
- **HUD size** - Adjustable HUD diameter
- **Text scale** - Adjustable cardinal direction font size
- **Rotation option** - Enable/disable minimap rotation
- **Hide in instances** - Auto-hide HUD when entering dungeons/raids/battlegrounds
- **Hide in combat** - Auto-hide HUD when entering combat
- **Scroll wheel lock** - Shift+scroll keybinds work while HUD is open
- **Zoom save/restore** - Minimap zoom restored when HUD closes
- **Coordinates display** - Show player coordinates on HUD
- **Time display** - Show server and/or local time on HUD

### Technical Changes

- Complete rewrite using simple, non-tainting approach
- Removed all Minimap method replacements (taint source)
- Removed all Minimap script modifications (taint source)
- Removed all hooksecurefunc on Minimap (taint source)
- Custom player arrow overlay instead of SetPlayerTexture API
- EnableMouseWheel(false) to allow keybinds within HUD area
- Event-based auto-hide using PLAYER_REGEN_DISABLED/ENABLED and ZONE_CHANGED_NEW_AREA

### Work In Progress

- Custom gather circle options
- Range circles module
- TrailPath module
- Tracking type toggles

---

## Previous Version History

Earlier versions were based on HizurosWoWAddOns/FarmHud backport which had taint issues.
This version is a complete rewrite from scratch.
