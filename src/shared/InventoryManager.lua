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
    local Config = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("Config"))
    local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local inventoryChangedEvent = remotes:WaitForChild("InventoryChanged")
    local useItemRequest = remotes:WaitForChild("UseItemRequest")
    local dropItemRequest = remotes:WaitForChild("DropItemRequest")
    local addItemRequest = remotes:WaitForChild("TestAddItemRequest")

    local inventories = {} -- { [Player]: { items: {string} } }

    -- Defines the server-side behavior for using an item
    local itemUseLogic = {
        ["Hammer"] = function(player)
            -- Case 1: Self-rescue from a cage
            if CagingManager.isCaged(player) then
                print(string.format("Server: %s used Hammer to rescue themselves.", player.Name))
                CagingManager.rescuePlayer(player)
                InventoryManager.removeItem(player, "Hammer")
                return -- Action complete
            end

            -- Case 2: Rescue a nearby caged teammate
            local character = player.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end

            local rootPart = character.HumanoidRootPart
            local playerPos = rootPart.Position
            local rescuedTarget = nil

            -- Find a nearby caged survivor
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Team and otherPlayer.Team.Name == "Survivors" then
                    if CagingManager.isCaged(otherPlayer) then
                        local otherChar = otherPlayer.Character
                        if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                             local otherPos = otherChar.HumanoidRootPart.Position
                            if (playerPos - otherPos).Magnitude <= Config.HANGER_INTERACT_DISTANCE then
                                rescuedTarget = otherPlayer
                                break -- Rescue the first target found
                            end
                        end
                    end
                end
            end

            if rescuedTarget then
                print(string.format("Server: %s used Hammer to rescue %s.", player.Name, rescuedTarget.Name))
                CagingManager.rescuePlayer(rescuedTarget)
                InventoryManager.removeItem(player, "Hammer") -- Consume on successful use
            else
                print(string.format("Server: %s used Hammer, but no caged survivor was in range.", player.Name))
                -- NOTE: We do not consume the item if it had no effect.
            end
        end,
        ["Med-kit"] = function(player)
            -- Use the centralized HealthManager to ensure UI events are fired
            HealthManager.applyHealing(player, 50)
            InventoryManager.removeItem(player, "Med-kit")
        end,
        ["Active Cola"] = function(player)
            local character = player.Character
            if not character then
                InventoryManager.removeItem(player, "Active Cola")
                return
            end

            -- If player is downed, consume item with no effect
            if character:GetAttribute("Downed") == true then
                print(string.format("Server: %s used Active Cola while downed. No effect.", player.Name))
                InventoryManager.removeItem(player, "Active Cola")
                return
            end

            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                InventoryManager.removeItem(player, "Active Cola")
                return
            end

            local originalSpeed = humanoid.WalkSpeed
            humanoid.WalkSpeed = originalSpeed + 8
            print(string.format("Server: %s used Active Cola. Speed increased.", player.Name))
            InventoryManager.removeItem(player, "Active Cola")

            -- Respawn in a new thread to avoid blocking
            task.spawn(function()
                task.wait(10)
                -- Check if humanoid still exists and speed hasn't been changed by another effect
                if humanoid and humanoid.WalkSpeed == originalSpeed + 8 then
                    humanoid.WalkSpeed = originalSpeed
                    print(string.format("Server: %s's Active Cola effect wore off.", player.Name))
                end
            end)
        end,
        ["Smoke Bomb"] = function(player)
            local character = player.Character
            if not character or not character:FindFirstChild("HumanoidRootPart") then
                return -- Can't use without a character
            end

            InventoryManager.removeItem(player, "Smoke Bomb")
            local rootPart = character.HumanoidRootPart
            local smokePosition = rootPart.Position

            -- Create the smoke effect
            local smokePart = Instance.new("Part")
            smokePart.Size = Vector3.new(1, 1, 1)
            smokePart.Position = smokePosition
            smokePart.Anchored = true
            smokePart.CanCollide = false
            smokePart.Transparency = 1
            smokePart.Name = "SmokeEffect"
            smokePart.Parent = Workspace

            local smokeEmitter = Instance.new("ParticleEmitter")
            smokeEmitter.Texture = "rbxassetid://2619231367" -- A decent smoke texture
            smokeEmitter.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80), Color3.fromRGB(50, 50, 50))
            smokeEmitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.5),
                NumberSequenceKeypoint.new(0.2, 0.2),
                NumberSequenceKeypoint.new(0.8, 0.8),
                NumberSequenceKeypoint.new(1, 1),
            })
            smokeEmitter.Size = NumberSequence.new(10, 25)
            smokeEmitter.Lifetime = NumberRange.new(5, 8)
            smokeEmitter.Rate = 50
            smokeEmitter.Speed = NumberRange.new(0.5, 2)
            smokeEmitter.SpreadAngle = Vector2.new(360, 360)
            smokeEmitter.Parent = smokePart

            -- Start the blindness checking logic in a new thread
            task.spawn(function()
                local Teams = game:GetService("Teams")
                local killersTeam = Teams:WaitForChild("Killers")
                local applyBlindnessEvent = remotes:WaitForChild("ApplyBlindnessEffect_CLIENT")

                local affectedKillers = {} -- { [Player]: isBlind }
                local duration = 10 -- Smoke lasts for 10 seconds
                local elapsed = 0

                while elapsed < duration do
                    local killers = killersTeam:GetPlayers()

                    for _, killer in ipairs(killers) do
                        local killerChar = killer.Character
                        if killerChar and killerChar:FindFirstChild("HumanoidRootPart") then
                            local distance = (killerChar.HumanoidRootPart.Position - smokePosition).Magnitude
                            local isInsideSmoke = distance <= Config.SMOKE_BOMB_RADIUS

                            if isInsideSmoke and not affectedKillers[killer] then
                                -- Killer entered the smoke
                                affectedKillers[killer] = true
                                applyBlindnessEvent:FireClient(killer, true)
                                print("Server: Applied blindness to", killer.Name)
                            elseif not isInsideSmoke and affectedKillers[killer] then
                                -- Killer left the smoke
                                affectedKillers[killer] = false
                                applyBlindnessEvent:FireClient(killer, false)
                                print("Server: Removed blindness from", killer.Name)
                            end
                        end
                    end

                    task.wait(0.25) -- Check 4 times per second
                    elapsed = elapsed + 0.25
                end

                -- Clean up: Un-blind anyone still in the smoke
                for killer, isBlind in pairs(affectedKillers) do
                    if isBlind then
                        applyBlindnessEvent:FireClient(killer, false)
                        print("Server: Cleaned up blindness for", killer.Name)
                    end
                end

                -- Destroy the smoke effect part
                smokePart:Destroy()
            end)
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

    addItemRequest.OnServerEvent:Connect(function(player, itemName)
        print("[DEBUG] Received AddItem request from client:", player.Name, "Item:", itemName)
        InventoryManager.addItem(player, itemName)
    end)

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
    local Teams = game:GetService("Teams")
    local killersTeam = Teams:WaitForChild("Killers")

    function InventoryManager.createOrUpdateInventoryUI(items)
        -- If the player is a killer, destroy any existing inventory UI and do nothing else.
        if player.Team == killersTeam then
            local existingGui = playerGui:FindFirstChild(INVENTORY_UI_NAME)
            if existingGui then
                existingGui:Destroy()
            end
            return
        end

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
