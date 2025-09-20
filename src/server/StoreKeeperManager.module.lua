--[[
    StoreKeeperManager.module.lua
    by Jules

    This server-side module is responsible for managing the Store Keeper NPC,
    including its spawning, teleporting, and inventory.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local InventoryManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("InventoryManager"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseItemRequest = remotes:WaitForChild("PurchaseItemRequest")
local getStoreData = remotes:WaitForChild("GetStoreData")
local purchaseFailed = remotes:WaitForChild("PurchaseFailed")

local StoreKeeperManager = {}

-- Configuration
local NPC_CONFIG = {
    Name = "StoreKeeper",
    SpawnPosition = Vector3.new(10, 5, 10),
    SpawnArea = {
        Min = Vector3.new(-50, 5, -50),
        Max = Vector3.new(50, 5, 50)
    },
    VISIBLE_DURATION = 30,
    HIDDEN_DURATION = 10
}

-- Server-side price list to prevent exploits
local ITEM_PRICES = {
    ["Hammer"] = 3,
    ["Med-kit"] = 6,
    ["Smoke Bomb"] = 3,
    ["Active Cola"] = 2
}

-- State variables
local activeNPC = nil
local managementCoroutine = nil

-- Helper function to shuffle a table in place
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

-- Private helper to spawn the NPC model at a random location
local function _spawnNPCRandomly()
    if activeNPC then return end

    print("StoreKeeperManager: Spawning NPC.")
    activeNPC = Instance.new("Model")
    activeNPC.Name = NPC_CONFIG.Name

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Anchored = true

    local humanoid = Instance.new("Humanoid", activeNPC)
    humanoid.DisplayName = "Store Keeper"

    hrp.Parent = activeNPC
    activeNPC.PrimaryPart = hrp

    local x = math.random(NPC_CONFIG.SpawnArea.Min.X, NPC_CONFIG.SpawnArea.Max.X)
    local z = math.random(NPC_CONFIG.SpawnArea.Min.Z, NPC_CONFIG.SpawnArea.Max.Z)
    local y = NPC_CONFIG.SpawnArea.Min.Y
    activeNPC:SetPrimaryPartCFrame(CFrame.new(x, y, z))

    -- Select and store the random items for this spawn
    local allItemNames = {}
    for name, _ in pairs(ITEM_PRICES) do
        table.insert(allItemNames, name)
    end
    shuffle(allItemNames)
    local currentItems = {allItemNames[1], allItemNames[2]}
    activeNPC:SetAttribute("CurrentItems", currentItems)

    activeNPC.Parent = Workspace
end

-- Private helper to clean up the NPC
local function _cleanupNPC()
    if activeNPC then
        activeNPC:Destroy()
        activeNPC = nil
    end
end

-- Public Functions
function StoreKeeperManager.startManaging(level)
    print("StoreKeeperManager: Received start signal for level", level)

    -- Stop any previous loop if it exists
    StoreKeeperManager.stopManaging()

    -- Rule: Only spawn on odd-numbered levels
    if level % 2 == 0 then
        print("StoreKeeperManager: Even level, will not spawn.")
        return
    end

    -- Start the management loop in a new coroutine
    managementCoroutine = task.spawn(function()
        print("StoreKeeperManager: Starting management loop.")
        while true do
            _spawnNPCRandomly()
            task.wait(NPC_CONFIG.VISIBLE_DURATION)

            _cleanupNPC()
            task.wait(NPC_CONFIG.HIDDEN_DURATION)
        end
    end)
end

function StoreKeeperManager.stopManaging()
    if managementCoroutine then
        print("StoreKeeperManager: Stopping management loop.")
        task.cancel(managementCoroutine)
        managementCoroutine = nil
    end
    _cleanupNPC()
end

-- Server-side price list to prevent exploits
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
        purchaseFailed:FireClient(player)
    end
end


function StoreKeeperManager.initialize()
    print("StoreKeeperManager initialized and listening for purchases.")
    purchaseItemRequest.OnServerEvent:Connect(onPurchaseRequest)

    getStoreData.OnServerInvoke = function(player)
        if not activeNPC then return nil, 0 end

        local items = activeNPC:GetAttribute("CurrentItems")
        local leaderstats = player:FindFirstChild("leaderstats")
        local levelCoins = leaderstats and leaderstats:FindFirstChild("LevelCoins")

        if items and levelCoins then
            return items, levelCoins.Value
        end

        return nil, 0
    end
end

return StoreKeeperManager
