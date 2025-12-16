-------------------------------------------------------------------------------
-- FarmHud Mixin Stubs
-- These must be defined BEFORE FarmHud.xml loads to prevent nil errors
-------------------------------------------------------------------------------

-- FarmHudMixin for XML compatibility (stubs - real functions in FarmHud.lua)
FarmHudMixin = FarmHudMixin or {}
FarmHudMixin.OnLoad = FarmHudMixin.OnLoad or function(self) end
FarmHudMixin.OnEvent = FarmHudMixin.OnEvent or function(self, event, ...) end
FarmHudMixin.OnShow = FarmHudMixin.OnShow or function(self) end
FarmHudMixin.OnHide = FarmHudMixin.OnHide or function(self) end

-- FarmHudMinimapDummyMixin for XML
FarmHudMinimapDummyMixin = FarmHudMinimapDummyMixin or {}
FarmHudMinimapDummyMixin.OnMouseUp = FarmHudMinimapDummyMixin.OnMouseUp or function(self) end
FarmHudMinimapDummyMixin.OnMouseDown = FarmHudMinimapDummyMixin.OnMouseDown or function(self) end
