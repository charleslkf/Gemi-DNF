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
    textLabel.TextColor3 = Color3.fromRGB(100, 255, 150) -- A greenish prompt color
    textLabel.BackgroundTransparency = 1
    return promptGui
end

-- Helper function to create the main store UI
local function createStoreGui()
    isUiVisible = true

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

    local closeButton = Instance.new("TextButton", mainFrame)
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.Text = "X"
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.TextSize = 20
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)

    -- Placeholder item buttons
    local items = {"Hammer", "Med-kit", "Smoke Bomb", "Active Cola"}
    for i, itemName in ipairs(items) do
        local itemButton = Instance.new("TextButton", mainFrame)
        itemButton.Size = UDim2.new(0, 250, 0, 50)
        itemButton.Position = UDim2.new(0.5, -125, 0, 50 + (i * 60))
        itemButton.Text = itemName
        itemButton.Font = Enum.Font.SourceSansBold
        itemButton.TextSize = 20
    end

    -- Event handlers
    closeButton.MouseButton1Click:Connect(function()
        isUiVisible = false
        screenGui:Destroy()
    end)
end

function StoreClient.init()
    print("StoreClient initialized.")

    -- Proximity check loop (RenderStepped)
    RunService.RenderStepped:Connect(function()
        if isUiVisible then return end -- Don't check for NPCs if the UI is open

        local character = player.Character
        local isSurvivor = player.Team and player.Team == Teams.Survivors

        -- Only run for survivors
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

        -- Manage the prompt GUI
        if closestNpcFound ~= nearbyNPC then
            -- Remove old prompt if it exists
            if nearbyNPC and nearbyNPC.Parent then
                local oldPrompt = nearbyNPC:FindFirstChild("InteractionPrompt")
                if oldPrompt then oldPrompt:Destroy() end
            end
            -- Add new prompt if an NPC is found
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

        createStoreGui()
    end)
end

return StoreClient
