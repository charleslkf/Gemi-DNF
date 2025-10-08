--[[
    SpawnPointManager.module.lua
    by Jules

    This is an authoritative, server-side module that solves the spawning problem
    deterministically. Instead of guessing random locations, this manager scans the
    map once when it loads and generates a list of all possible, valid spawn points.

    Other systems can then request a guaranteed-safe point from this manager,
    eliminating collisions and ensuring objects never spawn inside walls.
]]

local Workspace = game:GetService("Workspace")

local SpawnPointManager = {}

-- Configuration
local GRID_STEP = 5 -- How far apart to check for open spaces. A smaller number is more accurate but slower.
local CHECK_SIZE = Vector3.new(3, 6, 3) -- The size of the volume to check, should be big enough for a player.
local Y_OFFSET = 3 -- How high above the floor to center the check volume.

-- Module State
local safeSpawnPoints = {}
local currentMapBounds = nil -- Store the map bounds for use in the final check
local playableArea = Workspace:FindFirstChild("PlayableArea")

--[[
    Scans the provided map model and populates the list of potential safe spawn points.
    This should be called once per round, after the map has been loaded.
]]
function SpawnPointManager.buildSpawnPoints(mapModel)
    if not mapModel or not mapModel.PrimaryPart then
        warn("[SpawnPointManager] Cannot build spawn points: invalid map model provided.")
        return
    end

    -- Clear any points from a previous round and store the new map bounds.
    table.clear(safeSpawnPoints)
    currentMapBounds = mapModel.PrimaryPart
    print("[SpawnPointManager] Building spawn point list...")

    local mapSize = currentMapBounds.Size
    local mapPos = currentMapBounds.Position

    local startX = mapPos.X - mapSize.X / 2
    local endX = mapPos.X + mapSize.X / 2
    local startZ = mapPos.Z - mapSize.Z / 2
    local endZ = mapPos.Z + mapSize.Z / 2
    local spawnY = mapPos.Y + currentMapBounds.Size.Y / 2

    local overlapParams = OverlapParams.new()
    -- Ignore the main floor and the bot navigation area during the initial broad-phase scan.
    overlapParams.FilterDescendantsInstances = {currentMapBounds, playableArea}
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Iterate over the map area in a grid pattern.
    for x = startX, endX, GRID_STEP do
        for z = startZ, endZ, GRID_STEP do
            local checkPos = Vector3.new(x, spawnY + Y_OFFSET, z)
            local collidingParts = Workspace:GetPartBoundsInBox(CFrame.new(checkPos), CHECK_SIZE, overlapParams)

            -- Manually remove the map's floor and the bot navigation area from the list of collisions.
            -- This is necessary because the filter only applies to descendants, not the parts themselves.
            local floorIndex = table.find(collidingParts, currentMapBounds)
            if floorIndex then
                table.remove(collidingParts, floorIndex)
            end
            if playableArea then
                local playableAreaIndex = table.find(collidingParts, playableArea)
                if playableAreaIndex then
                    table.remove(collidingParts, playableAreaIndex)
                end
            end

            -- If no other parts are detected in this volume, it's a potential spawn point.
            if #collidingParts == 0 then
                table.insert(safeSpawnPoints, Vector3.new(x, spawnY, z))
            end
        end
    end

    print("[SpawnPointManager] Finished building. Found " .. #safeSpawnPoints .. " potential spawn points.")
end

--[[
    Finds and returns a guaranteed safe spawn point for a specific object.
    It iterates through the potential points and performs a final, precise collision check.
]]
function SpawnPointManager.getSafeSpawnPoint(objectToSpawn)
    if #safeSpawnPoints == 0 then
        warn("[SpawnPointManager] No safe spawn points are available!")
        return nil
    end

    if not objectToSpawn or not (objectToSpawn:IsA("Model") and objectToSpawn.PrimaryPart or objectToSpawn:IsA("BasePart")) then
        warn("[SpawnPointManager] Invalid object provided to getSafeSpawnPoint.")
        return nil
    end

    local objectSize = objectToSpawn.PrimaryPart and objectToSpawn.PrimaryPart.Size or objectToSpawn.Size
    local objectYOffset = objectToSpawn.PrimaryPart and objectToSpawn.PrimaryPart.Size.Y / 2 or objectToSpawn.Size.Y / 2

    local finalCheckParams = OverlapParams.new()
    -- Ignore the object to be spawned and the bot area. The floor is checked manually.
    finalCheckParams.FilterDescendantsInstances = {objectToSpawn, playableArea}
    finalCheckParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Iterate through the general safe points to find one that fits this specific object.
    for i = #safeSpawnPoints, 1, -1 do
        local point = safeSpawnPoints[i]
        local checkPos = point + Vector3.new(0, objectYOffset, 0)
        local checkCFrame = CFrame.new(checkPos)

        local collidingParts = Workspace:GetPartBoundsInBox(checkCFrame, objectSize, finalCheckParams)

        -- Manually remove the map's floor from the list of collisions.
        if currentMapBounds then
            local floorIndex = table.find(collidingParts, currentMapBounds)
            if floorIndex then
                table.remove(collidingParts, floorIndex)
            end
        end

        if #collidingParts == 0 then
            -- This point is confirmed to be safe for this specific object.
            table.remove(safeSpawnPoints, i) -- Remove it so it's not used again
            return checkPos
        end
    end

    warn("[SpawnPointManager] Could not find a suitable point for " .. objectToSpawn.Name .. " from the available list.")
    return nil
end

--[[
    Clears the list of spawn points. Should be called when a round ends.
]]
function SpawnPointManager.cleanupSpawnPoints()
    table.clear(safeSpawnPoints)
    currentMapBounds = nil -- Also clear the stored map bounds
end

return SpawnPointManager