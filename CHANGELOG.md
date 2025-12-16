# FarmHud Changelog

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
