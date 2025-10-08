--[[
    IntelligentSpawnManager.module.lua
    by Jules

    This is the definitive, authoritative, server-side module for finding valid
    spawn locations. It replaces all previous spawning systems.

    It works in two phases:
    1. A broad-phase scan that uses a fine-grained grid to find all potential
       empty spaces on the map.
    2. A narrow-phase check that, when a spawn point is requested, verifies
       that the specific object will fit in a location with an added "padding"
       to prevent it from spawning too close to walls.
]]

local Workspace = game:GetService("Workspace")

local IntelligentSpawnManager = {}

-- Configuration
local GRID_STEP = 4 -- **CRITICAL:** This is now smaller than the check size to ensure we don't miss corridors.
local CHECK_SIZE = Vector3.new(5, 6, 5) -- The general size of an empty space.
local Y_OFFSET = 3 -- How high above the floor to center the check volume.
local PADDING = 2 -- The minimum distance an object must be from a wall.

-- Module State
local potentialSpawnPoints = {}
local currentMapBounds = nil

--[[
    Scans the provided map model and populates the list of potential safe spawn points.
]]
function IntelligentSpawnManager.buildSpawnPoints(mapModel)
    if not mapModel or not mapModel.PrimaryPart then
        warn("[IntelligentSpawnManager] Cannot build spawn points: invalid map model provided.")
        return
    end

    table.clear(potentialSpawnPoints)
    currentMapBounds = mapModel.PrimaryPart
    local playableArea = Workspace:FindFirstChild("PlayableArea")
    print("[IntelligentSpawnManager] Building spawn point list...")

    local mapSize = currentMapBounds.Size
    local mapPos = currentMapBounds.Position
    local startX = mapPos.X - mapSize.X / 2
    local endX = mapPos.X + mapSize.X / 2
    local startZ = mapPos.Z - mapSize.Z / 2
    local endZ = mapPos.Z + mapSize.Z / 2
    local spawnY = mapPos.Y + currentMapBounds.Size.Y / 2

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Iterate over the map area in a grid pattern.
    for x = startX, endX, GRID_STEP do
        for z = startZ, endZ, GRID_STEP do
            local checkPos = Vector3.new(x, spawnY + Y_OFFSET, z)

            -- Set the filter list inside the loop to include the most up-to-date parts.
            overlapParams.FilterDescendantsInstances = {currentMapBounds, playableArea}

            local collidingParts = Workspace:GetPartBoundsInBox(CFrame.new(checkPos), CHECK_SIZE, overlapParams)

            if #collidingParts == 0 then
                table.insert(potentialSpawnPoints, Vector3.new(x, spawnY, z))
            end
        end
    end

    print("[IntelligentSpawnManager] Finished building. Found " .. #potentialSpawnPoints .. " potential spawn points.")
end

--[[
    Finds and returns a guaranteed safe spawn point for a specific object, with padding.
]]
function IntelligentSpawnManager.getSafeSpawnPoint(objectToSpawn)
    if #potentialSpawnPoints == 0 then
        warn("[IntelligentSpawnManager] No potential spawn points are available!")
        return nil
    end

    if not objectToSpawn or not (objectToSpawn:IsA("Model") and objectToSpawn.PrimaryPart or objectToSpawn:IsA("BasePart")) then
        warn("[IntelligentSpawnManager] Invalid object provided to getSafeSpawnPoint.")
        return nil
    end

    local objectSize = objectToSpawn.PrimaryPart and objectToSpawn.PrimaryPart.Size or objectToSpawn.Size
    local paddedSize = objectSize + Vector3.new(PADDING * 2, 0, PADDING * 2) -- Add padding to the X and Z axes.
    local objectYOffset = objectToSpawn.PrimaryPart and objectToSpawn.PrimaryPart.Size.Y / 2 or objectToSpawn.Size.Y / 2

    local playableArea = Workspace:FindFirstChild("PlayableArea")
    local finalCheckParams = OverlapParams.new()
    finalCheckParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Iterate through the potential points to find one that fits this specific object with padding.
    -- We shuffle the list to ensure randomness.
    local shuffledPoints = table.clone(potentialSpawnPoints)
    for i = #shuffledPoints, 1, -1 do
        local j = math.random(i)
        shuffledPoints[i], shuffledPoints[j] = shuffledPoints[j], shuffledPoints[i]
    end

    for _, point in ipairs(shuffledPoints) do
        local checkPos = point + Vector3.new(0, objectYOffset, 0)
        local checkCFrame = CFrame.new(checkPos)

        -- Set the filter list inside the loop.
        finalCheckParams.FilterDescendantsInstances = {objectToSpawn, currentMapBounds, playableArea}

        local collidingParts = Workspace:GetPartBoundsInBox(checkCFrame, paddedSize, finalCheckParams)

        if #collidingParts == 0 then
            -- This point is confirmed to be safe. Remove it from the main list to prevent re-use.
            local originalIndex = table.find(potentialSpawnPoints, point)
            if originalIndex then
                table.remove(potentialSpawnPoints, originalIndex)
            end
            return checkPos
        end
    end

    warn("[IntelligentSpawnManager] Could not find a suitable padded point for " .. objectToSpawn.Name)
    return nil
end

--[[
    Clears the list of spawn points.
]]
function IntelligentSpawnManager.cleanupSpawnPoints()
    table.clear(potentialSpawnPoints)
    currentMapBounds = nil
end

return IntelligentSpawnManager