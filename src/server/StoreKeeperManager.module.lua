--[[
    StoreKeeperManager.module.lua
    by Jules

    This server-side module is responsible for managing the Store Keeper NPC,
    including its spawning, location, and inventory.
]]

local Workspace = game:GetService("Workspace")

local StoreKeeperManager = {}

-- Configuration for the NPC
local NPC_CONFIG = {
    Name = "StoreKeeper",
    SpawnPosition = Vector3.new(10, 5, 10) -- A fixed position for now
}

-- Variable to hold the NPC model reference
local activeNPC = nil

function StoreKeeperManager.spawnNPC()
    if activeNPC then
        warn("StoreKeeperManager: NPC already exists.")
        return
    end

    print("StoreKeeperManager: Spawning NPC.")

    -- Create a simple R15 mannequin
    local npc = Instance.new("Model")
    npc.Name = NPC_CONFIG.Name

    local humanoid = Instance.new("Humanoid")
    humanoid.DisplayName = "Store Keeper"
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.Parent = npc

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.CFrame = CFrame.new(NPC_CONFIG.SpawnPosition)
    hrp.Anchored = true
    hrp.Parent = npc

    npc.PrimaryPart = hrp
    npc.Parent = Workspace
    activeNPC = npc
end

function StoreKeeperManager.cleanupNPC()
    if activeNPC and activeNPC.Parent then
        print("StoreKeeperManager: Cleaning up NPC.")
        activeNPC:Destroy()
    end
    activeNPC = nil
end

function StoreKeeperManager.initialize()
    print("StoreKeeperManager initialized.")
end

return StoreKeeperManager
