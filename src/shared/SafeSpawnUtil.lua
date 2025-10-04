--[[
    SafeSpawnUtil.lua

    This module provides a utility function to find a safe, collision-free
    spawn point for an object within the boundaries of a given map. It is used
    by various managers to prevent objects from spawning inside walls or other
    obstacles.
]]

local Workspace = game:GetService("Workspace")

local SafeSpawnUtil = {}

local MAX_ATTEMPTS = 50 -- The number of times to try finding a spot before giving up.

--[[
    Finds a safe, collision-free CFrame for a given object within the map's bounds.

    @param objectToSpawn (Instance): The object (e.g., a machine, a coin stash) that needs a spawn point.
                                     It must be a Model with a PrimaryPart or a BasePart.
    @param mapBounds (BasePart): The floor or primary part of the map, used to determine the spawning area.
    @return CFrame: A valid, collision-free CFrame for the object, or nil if no spot could be found.
]]
function SafeSpawnUtil.findSafeSpawnPoint(objectToSpawn, mapBounds)
    if not objectToSpawn or not mapBounds then
        warn("[SafeSpawnUtil] Invalid arguments: objectToSpawn and mapBounds must be provided.")
        return nil
    end

    local objectSize
    if objectToSpawn:IsA("Model") and objectToSpawn.PrimaryPart then
        objectSize = objectToSpawn.PrimaryPart.Size
    elseif objectToSpawn:IsA("BasePart") then
        objectSize = objectToSpawn.Size
    else
        warn("[SafeSpawnUtil] objectToSpawn must be a Model with a PrimaryPart or a BasePart.")
        return nil
    end

    local mapSize = mapBounds.Size
    local mapPosition = mapBounds.Position

    local halfMapX = mapSize.X / 2 - objectSize.X / 2
    local halfMapZ = mapSize.Z / 2 - objectSize.Z / 2
    local spawnY = mapPosition.Y + mapBounds.Size.Y / 2 + objectSize.Y / 2 -- Place it on top of the floor

    local overlapParams = OverlapParams.new()
    overlapParams.FilterDescendantsInstances = {objectToSpawn} -- Ignore the object itself
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    for i = 1, MAX_ATTEMPTS do
        local randomX = mapPosition.X + math.random(-halfMapX, halfMapX)
        local randomZ = mapPosition.Z + math.random(-halfMapZ, halfMapZ)
        local potentialCFrame = CFrame.new(randomX, spawnY, randomZ)

        -- Use GetPartsInPart to check for collisions at the potential spawn point
        local collidingParts = Workspace:GetPartsInPart(objectToSpawn.PrimaryPart or objectToSpawn, overlapParams)

        if #collidingParts == 0 then
            -- No collisions detected, this is a safe spot.
            return potentialCFrame
        end
    end

    warn("[SafeSpawnUtil] Could not find a collision-free spawn point for " .. objectToSpawn.Name .. " after " .. MAX_ATTEMPTS .. " attempts.")
    -- Fallback: return a random position anyway, but log a warning.
    local randomX = mapPosition.X + math.random(-halfMapX, halfMapX)
    local randomZ = mapPosition.Z + math.random(-halfMapZ, halfMapZ)
    return CFrame.new(randomX, spawnY, randomZ)
end

return SafeSpawnUtil