--[[
    StoreClient.lua
    by Jules

    This client-side script handles all player interaction with the
    Store Keeper NPC, including proximity checks and UI management.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

-- Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getStoreData = remotes:WaitForChild("GetStoreData")
local purchaseFailed = remotes:WaitForChild("PurchaseFailed")
local purchaseItemRequest = remotes:WaitForChild("PurchaseItemRequest")

-- Player Globals
local player = Players.LocalPlayer

-- Configuration
local CONFIG = {
    INTERACTION_DISTANCE = 12,
    NPC_NAME = "StoreKeeper"
}

-- The Module
local StoreClient = {}

-- State variables
local nearbyNPC = nil
local isUiVisible = false

-- Helper function to create the interaction prompt
local function createInteractionPrompt()
    local promptGui = Instance.new("BillboardGui")
    promptGui.Name = "InteractionPrompt"
    promptGui.Size = UDim2.new(5, 0, 2, 0)
    promptGui.AlwaysOnTop = true
    local textLabel = Instance.new("TextLabel", promptGui)
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Text = "[E] to Interact"
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 30
    textLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    textLabel.BackgroundTransparency = 1
    return promptGui
end

-- Helper function to split a string by a delimiter
local function splitString(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    string.gmatch(str, pattern)(function(c) fields[#fields + 1] = c end)
    return fields
end

-- This function is now responsible for the entire UI lifecycle
local function showStoreUI()
    if isUiVisible then return end

    -- Get the dynamic store data from the server
    local itemsString, playerCoins = getStoreData:InvokeServer()
    if not itemsString or itemsString == "" then
        warn("StoreClient: Could not get store data from server or store is not active.")
        return
    end

    isUiVisible = true

    local currentItems = splitString(itemsString, ",")

    -- Create the base GUI
    local screenGui = Instance.new("ScreenGui", player.PlayerGui)
    screenGui.Name = "StoreGui"
    screenGui.ResetOnSpawn = false

    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 600, 0, 400)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BorderSizePixel = 2

    local titleLabel = Instance.new("TextLabel", mainFrame)
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Text = "The Wandering Shop"
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

    local coinsLabel = Instance.new("TextLabel", mainFrame)
    coinsLabel.Size = UDim2.new(0, 200, 0, 30)
    coinsLabel.Position = UDim2.new(0, 10, 1, -40)
    coinsLabel.Font = Enum.Font.SourceSansBold
    coinsLabel.TextSize = 20
    coinsLabel.TextColor3 = Color3.new(1,1,1)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Text = string.format("Your Coins: %d", playerCoins)

    local closeButton = Instance.new("TextButton", mainFrame)
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.Text = "X"
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 20
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

    -- --- Dynamic Item Buttons & Affordability ---
    local itemInfo = {
        ["Hammer"] = {Price = 3},
        ["Med-kit"] = {Price = 6},
        ["Smoke Bomb"] = {Price = 3},
        ["Active Cola"] = {Price = 2}
    }

    for i, itemName in ipairs(currentItems) do
        local itemData = itemInfo[itemName]
        if not itemData then continue end

        local itemButton = Instance.new("TextButton", mainFrame)
        itemButton.Name = itemName .. "Button"
        itemButton.Size = UDim2.new(0, 250, 0, 50)
        itemButton.Position = UDim2.new(0.5, -125, 0, 50 + ((i - 1) * 70))
        itemButton.Text = string.format("%s (%d Coins)", itemName, itemData.Price)
        itemButton.Font = Enum.Font.SourceSansBold
        itemButton.TextSize = 20

        if playerCoins < itemData.Price then
            -- Gray out and disable the button if unaffordable
            itemButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            itemButton.TextColor3 = Color3.fromRGB(180, 180, 180)
            itemButton.AutoButtonColor = false
        else
            -- Normal button behavior
            itemButton.MouseButton1Click:Connect(function()
                print(string.format("Player requested to buy %s", itemName))
                purchaseItemRequest:FireServer(itemName)
            end)
        end
    end

    -- --- Purchase Failed Feedback ---
    local feedbackLabel = Instance.new("TextLabel", mainFrame)
    feedbackLabel.Size = UDim2.new(1, 0, 0, 30)
    feedbackLabel.Position = UDim2.new(0, 0, 1, -75)
    feedbackLabel.Font = Enum.Font.SourceSansBold
    feedbackLabel.TextSize = 22
    feedbackLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    feedbackLabel.BackgroundTransparency = 1
    feedbackLabel.Visible = false

    local purchaseFailedConn = purchaseFailed.OnClientEvent:Connect(function()
        feedbackLabel.Text = "Insufficient Funds"
        feedbackLabel.Visible = true
        task.wait(2)
        feedbackLabel.Visible = false
    end)

    -- Cleanup and interruption logic
    local isInterrupted, stopInterruptCheck
    local heartbeatConnection

    local function closeGui()
        isUiVisible = false
        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end
        if stopInterruptCheck then stopInterruptCheck() end
        if purchaseFailedConn then purchaseFailedConn:Disconnect() end
        screenGui:Destroy()
    end

    closeButton.MouseButton1Click:Connect(closeGui)

    local startCharacter = player.Character
    if startCharacter and startCharacter.PrimaryPart then
        local startPos = startCharacter.PrimaryPart.Position
        heartbeatConnection = RunService.Heartbeat:Connect(function()
            if not player.Character or not player.Character.PrimaryPart or (player.Character.PrimaryPart.Position - startPos).Magnitude > CONFIG.INTERACTION_DISTANCE then
                closeGui()
            end
        end)
    end
end

function StoreClient.init()
    print("StoreClient.lua loaded.")

    -- Proximity check loop
    RunService.RenderStepped:Connect(function()
        if isUiVisible then return end

        local character = player.Character
        local isSurvivor = player.Team and player.Team == Teams.Survivors

        if not character or not character.PrimaryPart or not isSurvivor then
            if nearbyNPC and nearbyNPC.Parent then
                 local prompt = nearbyNPC:FindFirstChild("InteractionPrompt")
                 if prompt then prompt:Destroy() end
            end
            nearbyNPC = nil
            return
        end

        local characterPos = character.PrimaryPart.Position
        local storeNpc = Workspace:FindFirstChild(CONFIG.NPC_NAME)
        local closestNpcFound = nil

        if storeNpc then
            if (characterPos - storeNpc.PrimaryPart.Position).Magnitude < CONFIG.INTERACTION_DISTANCE then
                closestNpcFound = storeNpc
            end
        end

        if closestNpcFound ~= nearbyNPC then
            if nearbyNPC and nearbyNPC.Parent then
                local oldPrompt = nearbyNPC:FindFirstChild("InteractionPrompt")
                if oldPrompt then oldPrompt:Destroy() end
            end
            if closestNpcFound then
                createInteractionPrompt().Parent = closestNpcFound
            end
            nearbyNPC = closestNpcFound
        end
    end)

    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or isUiVisible or input.KeyCode ~= Enum.KeyCode.E or not nearbyNPC then
            return
        end

        showStoreUI()
    end)
end

return StoreClient
