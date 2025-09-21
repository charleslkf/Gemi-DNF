-- MapBuilder
-- This ModuleScript is responsible for procedurally generating and cleaning up map elements.
-- Its main job is to create and destroy the "MiniGameMachine" parts.

local Workspace = game:GetService("Workspace")

-- Configuration
local MAP_CONFIG = {
    NumberOfMachines = 3,
    SpawnArea = {
        Min = Vector3.new(-50, 1, -50),
        Max = Vector3.new(50, 1, 50)
    },
    MachineSize = Vector3.new(4, 6, 2),
    GameTypes = {"ButtonMash", "MemoryCheck"}, -- The available mini-game types
    MACHINE_FOLDER_NAME = "MiniGameMachines"
}

local MapManager = {}

function MapManager.generate()
    -- Create a container for the machines in the Workspace
    local machineContainer = Instance.new("Folder")
    machineContainer.Name = MAP_CONFIG.MACHINE_FOLDER_NAME
    machineContainer.Parent = Workspace

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
    end
    print("MapManager: Generated", MAP_CONFIG.NumberOfMachines, "machines.")
end

function MapManager.cleanup()
    local machineContainer = Workspace:FindFirstChild(MAP_CONFIG.MACHINE_FOLDER_NAME)
    if machineContainer then
        machineContainer:Destroy()
        print("MapManager: Cleaned up machines.")
    end
end

return MapManager
