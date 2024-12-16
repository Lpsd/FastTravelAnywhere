--------------------------------------------------------------------
------------------- [FastTravelAnywhere] OPTIONS -------------------
--------------------------------------------------------------------
-- FastTravelKey must be defined, FastTravelModifierKeys is optional

--[[ 
    https://docs.ue4ss.com/dev/lua-api/table-definitions/key.html
    e.g: Key.Z, Key.F3, Key.BACKSPACE, Key.TAB, etc
--]]
FastTravelKey = Key.Z

--[[ 
    https://docs.ue4ss.com/dev/lua-api/table-definitions/modifierkey.html
    e.g: {ModifierKey.CONTROL}
         {ModifierKey.CONTROL, ModifierKey.SHIFT}

    Leave empty {} for no modifier keys
--]]
FastTravelModifierKeys = {}

--[[
    Frequency of certain script operations in milliseconds (1000 = 1 second)
    Affects teleport processing speed. May cause performance issues and crashing if set too low.
    If experiencing regular crashes, try increasing this value incrementally until stable.

    Default: 333
--]]
FAST_TRAVEL_TICK_RATE = 333