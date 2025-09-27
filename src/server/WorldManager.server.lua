--[[
    WorldManager.server.lua

    This module handles the loading, management, and cleanup of pre-made map assets
    from ServerStorage. It is controlled by the GameManager.
]]

-- Services
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- The Module
local WorldManager = {}

-- State
local currentMap = nil
local mapsFolder = ServerStorage:WaitForChild("Maps")

---
-- Removes the currently loaded map from the Workspace.
function WorldManager.cleanupCurrentLevel()
    if currentMap and currentMap.Parent then
        currentMap:Destroy()
        print("[WorldManager] Current map cleaned up.")
    end
    currentMap = nil
end

---
-- Loads a random map from ServerStorage into the Workspace.
-- @returns A reference to the loaded map model, or nil if no maps are available.
function WorldManager.loadRandomLevel()
    WorldManager.cleanupCurrentLevel() -- Ensure no previous map exists

    local availableMaps = mapsFolder:GetChildren()
    if #availableMaps == 0 then
        warn("[WorldManager] No maps found in ServerStorage/Maps folder!")
        return nil
    end

    local randomIndex = math.random(#availableMaps)
    local selectedMapTemplate = availableMaps[randomIndex]

    print(string.format("[WorldManager] Loading map: %s", selectedMapTemplate.Name))
    currentMap = selectedMapTemplate:Clone()
    currentMap.Parent = Workspace

    return currentMap
end

---
-- Loads the dedicated Last Man Standing (LMS) map.
-- @returns A reference to the loaded LMS map model, or nil if not found.
function WorldManager.loadLMSLevel()
    WorldManager.cleanupCurrentLevel() -- Ensure no previous map exists

    local lmsMapTemplate = mapsFolder:FindFirstChild("LMS_Arena")
    if not lmsMapTemplate then
        warn("[WorldManager] LMS_Arena map not found in ServerStorage/Maps folder!")
        return nil
    end

    print("[WorldManager] Loading LMS_Arena map.")
    currentMap = lmsMapTemplate:Clone()
    currentMap.Parent = Workspace

    return currentMap
end

---
-- Spawns two Victory Gates at random locations within the current map.
-- @param mapModel The model of the current map to spawn gates in.
function WorldManager.spawnVictoryGates(mapModel)
    if not mapModel or not mapModel.PrimaryPart then
        warn("[WorldManager] Cannot spawn Victory Gates without a valid map model with a PrimaryPart.")
        return
    end

    print("[WorldManager] Spawning Victory Gates.")
    local mapBounds = mapModel.PrimaryPart

    for i = 1, 2 do
        local gate = Instance.new("Part")
        gate.Name = "VictoryGate" .. i
        gate.Size = Vector3.new(10, 15, 2)
        gate.Anchored = true
        gate.CanCollide = false
        gate.BrickColor = BrickColor.new("Bright green")

        -- Calculate a random position within the map's bounds
        local randomX = mapBounds.Position.X + math.random(-mapBounds.Size.X / 2, mapBounds.Size.X / 2)
        local randomZ = mapBounds.Position.Z + math.random(-mapBounds.Size.Z / 2, mapBounds.Size.Z / 2)
        gate.Position = Vector3.new(randomX, mapBounds.Position.Y + gate.Size.Y / 2, randomZ)

        gate.Parent = Workspace
    end
end

return WorldManager