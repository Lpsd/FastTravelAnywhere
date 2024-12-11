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