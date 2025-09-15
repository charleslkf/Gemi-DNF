--[[
    InventoryClient.client.lua
    by Jules

    This script handles all client-side inventory interactions.
    - Listens for server updates to the inventory and updates the UI.
    - Listens for player input to use or drop items.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Modules
local InventoryManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("InventoryManager"))

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local inventoryChangedEvent = remotes:WaitForChild("InventoryChanged")
local useItemRequest = remotes:WaitForChild("UseItemRequest")
local dropItemRequest = remotes:WaitForChild("DropItemRequest")

-- Local State
local currentInventory = {}

-- Event Listeners
inventoryChangedEvent.OnClientEvent:Connect(function(items)
    currentInventory = items
    InventoryManager.createOrUpdateInventoryUI(items)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    local itemToUse = nil
    if input.KeyCode == Enum.KeyCode.One then
        itemToUse = currentInventory[1]
    elseif input.KeyCode == Enum.KeyCode.Two then
        itemToUse = currentInventory[2]
    end

    if itemToUse then
        print("Client: Requesting to use item: " .. itemToUse)
        useItemRequest:FireServer(itemToUse)
    end

    if input.KeyCode == Enum.KeyCode.G then
        -- Drop the first item for simplicity
        local itemToDrop = currentInventory[1]
        if itemToDrop then
            print("Client: Requesting to drop item: " .. itemToDrop)
            dropItemRequest:FireServer(itemToDrop)
        end
    end
end)

print("InventoryClient.client.lua loaded and listening.")
