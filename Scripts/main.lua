local UEHelpers = require("UEHelpers")
print("[FastTravelAnywhere] Mod loaded\n")

local function file_exists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

-- Load options.lua from ue4ss subfolder if it exists (IT SHOULDNT :angry_face:)
if (file_exists([[ue4ss\Mods\FastTravelAnywhere\options.lua]])) then
    print("[FastTravelAnywhere] Loading options from ue4ss subfolder\n")
    dofile([[ue4ss\Mods\FastTravelAnywhere\options.lua]])
else -- Load options.lua from the standard location (:happy_face:)
    print("[FastTravelAnywhere] Loading options from standard location\n")
    dofile([[Mods\FastTravelAnywhere\options.lua]])
end

-- Ensure options are valid
if (not FastTravelKey) then
    print("[FastTravelAnywhere] No fast travel key set, check options.lua\n")
    return
end

FastTravelModifierKeys = (type(FastTravelModifierKeys) == "table") and FastTravelModifierKeys or {}

-- Declare some thingies
local HoveredMarker = nil
local isTeleporting = false

local WorldMapActualWidth = 816000.0
local WorldMapActualHeight = 816000.0
local PDAMapWidth = 32640.0
local PDAMapHeight = 32640.0

local TELEPORT_FINAL_Z_OFFSET = 3

local FALLING_TERMINAL_VELOCITY = 333
local DEFAULT_TERMINAL_VELOCITY = 4000

-- Maffs
local function remap(x, imin, imax, omin, omax)
    return (x - imin) * (omax - omin) / (imax - imin) + omin
end

function SetupResetTrigger(physicsVolume)
    if (not physicsVolume) or (not physicsVolume:IsValid()) then return true end

    -- Grab the local player controller and pawn
    local FirstPlayerController = UEHelpers:GetPlayerController()

    if (FirstPlayerController) and (FirstPlayerController:IsValid()) then
        local PlayerCameraManager = FirstPlayerController.PlayerCameraManager
        if (not PlayerCameraManager) or (not PlayerCameraManager:IsValid()) then return end
        PlayerCameraManager:SetManualCameraFade(0, {R=0, G=0, B=0, A=255}, true)
    end

    -- Reset terminal velocity
    physicsVolume.TerminalVelocity = DEFAULT_TERMINAL_VELOCITY

    -- Flush level streaming and force garbage collection
    FirstPlayerController:ClientForceGarbageCollection()
    FirstPlayerController:ClientFlushLevelStreaming()

    print("[FastTravelAnywhere] Player has teleported\n")
end

-- Teleport({X=0, Y=0})
-- Floor (Z) is found automatically, so you don't need to provide it
function Teleport(location)
    -- Ensure valid location provided
    if (not location) or (type(location) ~= "table") or (not location.X or not tonumber(location.X)) or (not location.Y or not tonumber(location.Y)) then return end
    if (isTeleporting) then return end

    -- Get our movement component
    ---@class ModelCharacterMovementComponent : UObject
    ---@field RequestedVelocity table
    local ModelCharacterMovementComponent = FindFirstOf("ModelCharacterMovementComponent")

    if (not ModelCharacterMovementComponent) or (not ModelCharacterMovementComponent:IsValid()) then
        print("[FastTravelAnywhere] ModelCharacterMovementComponent not found\n")
        return
    end

    local PhysicsVolume = ModelCharacterMovementComponent:GetPhysicsVolume()

    if (not PhysicsVolume) or (not PhysicsVolume:IsValid()) then
        print("[FastTravelAnywhere] PhysicsVolume not found\n")
        return
    end

    -- Grab the local player controller and pawn
    local FirstPlayerController = UEHelpers:GetPlayerController()

    if (not FirstPlayerController) or (not FirstPlayerController:IsValid()) then
        print("[FastTravelAnywhere] FirstPlayerController not found\n")
        return
    end

    local Pawn = FirstPlayerController.Pawn

    if (not Pawn) or (not Pawn:IsValid()) then
        print("[FastTravelAnywhere] Pawn not found\n")
        return
    end

    isTeleporting = true

    -- Get our original location
    local originalLocation = Pawn:K2_GetActorLocation()

    -- Remap the location from PDA map to world map
    location = {X=remap(location.X, 0, PDAMapWidth, 0, WorldMapActualWidth), Y=remap(location.Y, 0, PDAMapHeight, 0, WorldMapActualHeight), Z=PDAMapHeight }
    print("[FastTravelAnywhere] Remapped location: " .. location.X .. ", " .. location.Y .. "\n")

    local CustomConsoleManagerRK = FindFirstOf("CustomConsoleManagerRK")

    -- Set the actor location to a place high above the map, so we can compute the floor Z
    -- Ideally we want to use XTeleportTo, if we can't then use K2_TeleportTo
    if (not CustomConsoleManagerRK) or (not CustomConsoleManagerRK:IsValid()) then
        Pawn:K2_TeleportTo({X=location.X, Y=location.Y, Z=location.Z}, {X=0, Y=0, Z=0})
    else
        CustomConsoleManagerRK:XTeleportTo(location.X, location.Y, location.Z)
    end

    -- Set max velocity to 0 temporarily, so we can't fall at all
    PhysicsVolume.TerminalVelocity = 0

    local PlayerCameraManager = FirstPlayerController.PlayerCameraManager

    if (PlayerCameraManager) and (PlayerCameraManager:IsValid()) then
        PlayerCameraManager:StartCameraFade(0, 255, 1, {R=0, G=0, B=0, A=255}, true, true)
    end

    ExecuteWithDelay(FAST_TRAVEL_DELAY, function()
        ExecuteInGameThread(function()
            -- Try to get the floor Z position
            local floorResult = {}
            local lineDistance = location.Z * 2
            local sweepDistance = location.Z * 2
            local sweepRadius = 100

            ModelCharacterMovementComponent:K2_ComputeFloorDist({X=location.X, Y=location.Y, Z=location.Z}, lineDistance, sweepDistance, sweepRadius, floorResult)

            -- No hit result? Return to original location
            if (not floorResult) or (not floorResult.HitResult) then
                print("[FastTravelAnywhere] No floor hit result found\n")
                DoTeleport(Pawn, CustomConsoleManagerRK, PhysicsVolume, originalLocation)
                return
            end

            local floorHitResult = floorResult.HitResult

            -- No location found? Return to original location
            if (not floorHitResult.Location) then
                print("[FastTravelAnywhere] No floor location found \n")
                DoTeleport(Pawn, CustomConsoleManagerRK, PhysicsVolume, originalLocation)
                return
            end

            local x, y, z = floorHitResult.Location.X, floorHitResult.Location.Y, floorHitResult.Location.Z
            print("[FastTravelAnywhere] Floor hit location: " .. x .. ", " .. y .. ", " .. z .. "\n")

            -- Floor Z is nil or 0? Return to original location
            if (not z) or (z == 0) then
                print("[FastTravelAnywhere] Floor Z is nil or 0\n")
                DoTeleport(Pawn, CustomConsoleManagerRK, PhysicsVolume, originalLocation)
                return
            end

            -- Set the floor Z location
            location.Z = z

            -- Teleport the player to the final location
            print("[FastTravelAnywhere] Teleporting based on floor hit result\n")
            DoTeleport(Pawn, CustomConsoleManagerRK, PhysicsVolume, location)
        end)
    end)
end

function DoTeleport(Pawn, CustomConsoleManagerRK, PhysicsVolume, location)
    -- Teleport the player to the final location
    -- Ideally we want to use CustomConsoleManagerRK:XTeleportTo, if we can't then use K2_TeleportTo
    -- TELEPORT_FINAL_Z_OFFSET offset is to ensure we don't get stuck in the floor or clip through it
    local didTeleport = false
    isTeleporting = false

    -- Reset changed properties when player lands
    SetupResetTrigger(PhysicsVolume)

    -- Attempt to teleport the player
    if (not CustomConsoleManagerRK) or (not CustomConsoleManagerRK:IsValid()) then
        Pawn:K2_TeleportTo({X=location.X, Y=location.Y, Z=location.Z + TELEPORT_FINAL_Z_OFFSET}, {X=0, Y=0, Z=0})
        didTeleport = true
    else
        CustomConsoleManagerRK:XTeleportTo(location.X, location.Y, location.Z + TELEPORT_FINAL_Z_OFFSET)
        didTeleport = true
    end

    if (not didTeleport) then
        print("[FastTravelAnywhere] Failed to teleport\n")
        return
    end

    print("[FastTravelAnywhere] Teleported to location: " .. location.X .. ", " .. location.Y .. ", " .. location.Z .. "\n")
end

RegisterHook("/Script/Stalker2.WorldMapMarker:OnMouseHover", function(WorldMapMarker)
    if (isTeleporting) then return end

    HoveredMarker = WorldMapMarker:get()
    print("[FastTravelAnywhere] Hovered marker\n")
end)

RegisterHook("/Script/Stalker2.WorldMapMarker:OnMouseUnhover", function()
    if (isTeleporting) then return end

    HoveredMarker = nil
    print("[FastTravelAnywhere] Unhovered marker\n")
end)

-- Teleport to hovered PDA marker location
RegisterKeyBind(FastTravelKey, FastTravelModifierKeys, function()
    if (not HoveredMarker) or (not HoveredMarker:IsValid()) then return end
    if (isTeleporting) then return end

    -- Get the marker's canvas panel slot
    local CanvasPanelSlot = HoveredMarker.Slot
    if not CanvasPanelSlot then return end

    -- Get the marker's location
    local LayoutData = CanvasPanelSlot.LayoutData
    if not LayoutData then return end

    local Offsets = LayoutData.Offsets
    if not Offsets then return end

    local X, Y = Offsets.Left, Offsets.Top
    HoveredMarker = nil

    if not tonumber(X) or not tonumber(Y) then
        return
    end

    -- Teleport the player to the marker's location
    print("[FastTravelAnywhere] Attempting teleport to hovered marker\n")
    print ("[FastTravelAnywhere] Marker PDA location: " .. X .. ", " .. Y .. "\n")

    ExecuteInGameThread(function()
        Teleport({X=X, Y=Y})
    end)
end)
