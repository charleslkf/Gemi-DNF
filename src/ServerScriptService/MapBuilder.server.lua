-- MapBuilder.server.lua
-- This script is responsible for procedurally generating the map elements at the start of each round.
-- Currently, its main job is to create the "MiniGameMachine" parts with persistent GameTypes.

local ServerScriptService = game:GetService("ServerScriptService")

-- Configuration
local MAP_CONFIG = {
    NumberOfMachines = 9,
    SpawnArea = {
        Min = Vector3.new(-50, 1, -50),
        Max = Vector3.new(50, 1, 50)
    },
    MachineSize = Vector3.new(4, 6, 2),
    GameTypes = {"ButtonMash", "MemoryCheck", "Matching"} -- The available mini-game types
}

local MapBuilder = {}

function MapBuilder.generateMachines()
    -- Create a container for the machines in the Workspace
    local machineContainer = Instance.new("Folder")
    machineContainer.Name = "MiniGameMachines"
    machineContainer.Parent = workspace

    local gameTypes = MAP_CONFIG.GameTypes
    local numGameTypes = #gameTypes

    for i = 1, MAP_CONFIG.NumberOfMachines do
        local machine = Instance.new("Part")
        machine.Name = "MiniGameMachine"
        machine.Size = MAP_CONFIG.MachineSize
        machine.Color = Color3.fromRGB(100, 100, 255) -- A distinct blue color
        machine.Anchored = true
        machine.CanCollide = true

        -- Calculate a random position
        local x = math.random(MAP_CONFIG.SpawnArea.Min.X, MAP_CONFIG.SpawnArea.Max.X)
        local z = math.random(MAP_CONFIG.SpawnArea.Min.Z, MAP_CONFIG.SpawnArea.Max.Z)
        machine.Position = Vector3.new(x, MAP_CONFIG.MachineSize.Y / 2, z)

        -- Assign a GameType attribute, cycling through the available types
        local gameType = gameTypes[((i - 1) % numGameTypes) + 1]
        machine:SetAttribute("GameType", gameType)

        machine.Parent = machineContainer
        print("Created MiniGameMachine of type:", gameType, "at", machine.Position)
    end
end

-- TODO: This should be triggered by a round start event from LobbyManager.
-- For now, it runs once on server startup for testing purposes.
MapBuilder.generateMachines()

return MapBuilder
