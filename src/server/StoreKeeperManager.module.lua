--[[
    StoreKeeperManager.module.lua
    by Jules

    This server-side module is responsible for managing the Store Keeper NPC,
    including its spawning, location, and inventory.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local InventoryManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("InventoryManager"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseItemRequest = remotes:WaitForChild("PurchaseItemRequest")

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

-- Server-side price list to prevent exploits
local ITEM_PRICES = {
    ["Hammer"] = 3,
    ["Med-kit"] = 6,
    ["Smoke Bomb"] = 3,
    ["Active Cola"] = 2
}

local function onPurchaseRequest(player, itemName)
    local price = ITEM_PRICES[itemName]
    if not price then
        warn(string.format("Player '%s' requested to buy invalid item '%s'", player.Name, itemName))
        return
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    local levelCoins = leaderstats and leaderstats:FindFirstChild("LevelCoins")

    if not levelCoins then
        warn(string.format("Could not find LevelCoins for player '%s'", player.Name))
        return
    end

    if levelCoins.Value >= price then
        print(string.format("Processing purchase for %s: item %s, price %d", player.Name, itemName, price))
        levelCoins.Value = levelCoins.Value - price
        InventoryManager.addItem(player, itemName)
    else
        print(string.format("Player %s has insufficient funds to buy %s", player.Name, itemName))
        -- In the future, we could fire a remote back to the client to show a "Not enough coins" message.
    end
end

function StoreKeeperManager.initialize()
    print("StoreKeeperManager initialized.")
    purchaseItemRequest.OnServerEvent:Connect(onPurchaseRequest)
end

return StoreKeeperManager
