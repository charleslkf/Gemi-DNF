--[[
    InventoryManager.lua
    by Jules

    A self-contained module to manage player inventories, items, and usage.
    This module has code paths for both the server (authoritative logic)
    and the client (UI management).
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Module Table
local InventoryManager = {}

-- Constants
local INVENTORY_CAPACITY = 2
local INVENTORY_UI_NAME = "InventoryGui"

-----------------------------------------------------------------------------
-- SERVER-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsServer() then
    local CagingManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("CagingManager"))
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local inventoryChangedEvent = remotes:WaitForChild("InventoryChanged")
    local useItemRequest = remotes:WaitForChild("UseItemRequest")
    local dropItemRequest = remotes:WaitForChild("DropItemRequest")

    local inventories = {} -- { [Player]: { items: {string} } }

    -- Defines the server-side behavior for using an item
    local itemUseLogic = {
        ["Hammer"] = function(player)
            -- For now, the hammer can only be used to rescue oneself.
            -- A future implementation could check for nearby caged players.
            print(string.format("Server: %s used Hammer to rescue themselves.", player.Name))
            CagingManager.rescuePlayer(player)
            InventoryManager.removeItem(player, "Hammer")
        end,
    }

    function InventoryManager.initializeInventory(player)
        inventories[player] = {
            items = {},
            capacity = INVENTORY_CAPACITY
        }
        inventoryChangedEvent:FireClient(player, inventories[player].items)
    end

    function InventoryManager.addItem(player, itemName)
        if not inventories[player] then return false end

        local inv = inventories[player]
        if #inv.items < inv.capacity then
            table.insert(inv.items, itemName)
            print(string.format("Server: Added %s to %s's inventory.", itemName, player.Name))
            inventoryChangedEvent:FireClient(player, inv.items)
            return true
        end
        return false
    end

    function InventoryManager.removeItem(player, itemName)
        if not inventories[player] then return false end

        local inv = inventories[player].items
        for i, item in ipairs(inv) do
            if item == itemName then
                table.remove(inv, i)
                print(string.format("Server: Removed %s from %s's inventory.", itemName, player.Name))
                inventoryChangedEvent:FireClient(player, inv)
                return true
            end
        end
        return false
    end

    function InventoryManager.dropItem(player, itemName)
        if not inventories[player] then return end

        -- For now, dropping an item just removes it.
        -- A future implementation would create a physical part in the workspace.
        print(string.format("Server: %s dropped %s.", player.Name, itemName))
        InventoryManager.removeItem(player, itemName)
    end

    useItemRequest.OnServerEvent:Connect(function(player, itemName)
        if not inventories[player] then return end

        local hasItem = table.find(inventories[player].items, itemName)
        if not hasItem then return end

        local useFunc = itemUseLogic[itemName]
        if useFunc then
            useFunc(player)
        else
            warn("Server: No use logic defined for item: " .. itemName)
        end
    end)

    dropItemRequest.OnServerEvent:Connect(function(player, itemName)
        InventoryManager.dropItem(player, itemName)
    end)

    Players.PlayerRemoving:Connect(function(player)
        if inventories[player] then
            inventories[player] = nil
        end
    end)
end

-----------------------------------------------------------------------------
-- CLIENT-SIDE LOGIC
-----------------------------------------------------------------------------
if RunService:IsClient() then
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    function InventoryManager.createOrUpdateInventoryUI(items)
        print("[DEBUG] InventoryManager: createOrUpdateInventoryUI called for player. Team:", player.Team)
        local screenGui = playerGui:FindFirstChild(INVENTORY_UI_NAME)
        if not screenGui then
            screenGui = Instance.new("ScreenGui")
            screenGui.Name = INVENTORY_UI_NAME
            screenGui.ResetOnSpawn = false
            screenGui.Parent = playerGui

            local container = Instance.new("Frame", screenGui)
            container.Name = "Container"
            container.Size = UDim2.new(0, 210, 0, 100) -- Size for 2 slots + padding
            container.Position = UDim2.new(0.5, -105, 1, -190) -- Above health bar
            container.BackgroundTransparency = 1

            local listLayout = Instance.new("UIListLayout", container)
            listLayout.FillDirection = Enum.FillDirection.Horizontal
            listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            listLayout.Padding = UDim.new(0, 10)

            for i = 1, INVENTORY_CAPACITY do
                local slot = Instance.new("Frame", container)
                slot.Name = "Slot" .. i
                slot.Size = UDim2.new(0, 100, 0, 100)
                slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                slot.BorderSizePixel = 2

                local itemLabel = Instance.new("TextLabel", slot)
                itemLabel.Name = "ItemName"
                itemLabel.Size = UDim2.new(1, 0, 1, 0)
                itemLabel.BackgroundTransparency = 1
                itemLabel.TextColor3 = Color3.new(255, 255, 255)
                itemLabel.Font = Enum.Font.SourceSansBold
                itemLabel.TextScaled = true
            end
        end

        local container = screenGui:WaitForChild("Container")
        for i = 1, INVENTORY_CAPACITY do
            local slot = container:FindFirstChild("Slot" .. i)
            if slot then
                local itemLabel = slot:FindFirstChild("ItemName")
                if items[i] then
                    itemLabel.Text = items[i]
                else
                    itemLabel.Text = "[Empty]"
                end
            end
        end
    end
end

return InventoryManager
