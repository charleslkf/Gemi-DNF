--[[
    MiniGameManager.client.lua
    by Jules

    A modular, client-side system for handling mini-game machines.
    This module should be `require()`'d and its `init()` function called
    by a LocalScript, for example in StarterPlayerScripts.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The Module
local MiniGameManager = {}

-- Helper to create the base UI
local function createMiniGameGui(title)
    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "MiniGameGui"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 400, 0, 200)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(80, 80, 80)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

    local timerLabel = Instance.new("TextLabel", frame)
    timerLabel.Size = UDim2.new(0, 100, 0, 30)
    timerLabel.Position = UDim2.new(0.5, -50, 1, -40)
    timerLabel.Font = Enum.Font.SourceSansBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.new(1, 1, 1)

    return screenGui, frame, timerLabel
end

function MiniGameManager.startQTE()
    local screenGui, frame, timerLabel = createMiniGameGui("Quick Time Event!")

    local possibleKeys = {"F", "G", "H", "J", "K"}
    local targetKey = possibleKeys[math.random(#possibleKeys)]
    local targetKeyCode = Enum.KeyCode[targetKey]

    local promptLabel = Instance.new("TextLabel", frame)
    promptLabel.Size = UDim2.new(1, 0, 1, -80)
    promptLabel.Position = UDim2.new(0, 0, 0.5, 0)
    promptLabel.Text = string.format("Press [%s]!", targetKey)
    promptLabel.Font = Enum.Font.SourceSansBold
    promptLabel.TextSize = 80
    promptLabel.TextColor3 = Color3.new(1, 1, 1)
    promptLabel.BackgroundTransparency = 1

    local duration = 2
    local success = false

    local inputConn
    inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == targetKeyCode then
            success = true
        end
    end)

    local startTime = tick()
    while tick() - startTime < duration do
        if success then break end
        local timeLeft = duration - (tick() - startTime)
        timerLabel.Text = string.format("%.2fs", timeLeft)
        RunService.Heartbeat:Wait()
    end

    inputConn:Disconnect()
    screenGui:Destroy()
    print("QTE result: " .. tostring(success))
    return success
end

function MiniGameManager.startMatching()
    local screenGui, frame, timerLabel = createMiniGameGui("Pattern Matching!")

    local charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local sequence = ""
    for i = 1, 5 do
        local randIndex = math.random(#charSet)
        sequence = sequence .. charSet:sub(randIndex, randIndex)
    end

    local promptLabel = Instance.new("TextLabel", frame)
    promptLabel.Size = UDim2.new(1, -20, 0, 50)
    promptLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
    promptLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    promptLabel.Font = Enum.Font.SourceSansBold
    promptLabel.TextSize = 40
    promptLabel.TextColor3 = Color3.new(1, 1, 1)
    promptLabel.BackgroundTransparency = 1
    promptLabel.Text = sequence

    local inputBox = Instance.new("TextBox", frame)
    inputBox.Size = UDim2.new(1, -40, 0, 40)
    inputBox.Position = UDim2.new(0.5, 0, 0.75, 0)
    inputBox.AnchorPoint = Vector2.new(0.5, 0.5)
    inputBox.Font = Enum.Font.SourceSans
    inputBox.TextSize = 24
    inputBox.PlaceholderText = "Type the sequence here..."
    inputBox.Visible = false -- Hide until memory phase is over

    local success = false
    local showDuration = 3
    local inputDuration = 5

    -- Show phase
    local startTime = tick()
    while tick() - startTime < showDuration do
        local timeLeft = showDuration - (tick() - startTime)
        timerLabel.Text = string.format("Memorize: %.1fs", timeLeft)
        RunService.Heartbeat:Wait()
    end

    promptLabel.Text = "???"
    inputBox.Visible = true
    inputBox:CaptureFocus()

    -- Input phase
    startTime = tick()
    while tick() - startTime < inputDuration do
        local timeLeft = inputDuration - (tick() - startTime)
        timerLabel.Text = string.format("Recall: %.1fs", timeLeft)
        RunService.Heartbeat:Wait()
    end

    if inputBox.Text:upper() == sequence:upper() then
        success = true
    end

    screenGui:Destroy()
    print("Matching result: " .. tostring(success))
    return success
end

function MiniGameManager.startButtonMashing()
    local screenGui, frame, timerLabel = createMiniGameGui("Button Mashing!")

    local promptLabel = Instance.new("TextLabel", frame)
    promptLabel.Size = UDim2.new(1, -20, 0, 50)
    promptLabel.Position = UDim2.new(0.5, 0, 0.5, -40)
    promptLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    promptLabel.Text = "Mash the [E] key!"
    promptLabel.Font = Enum.Font.SourceSansBold
    promptLabel.TextSize = 30
    promptLabel.TextColor3 = Color3.new(1, 1, 1)
    promptLabel.BackgroundTransparency = 1

    local progressBar = Instance.new("Frame", frame)
    progressBar.Size = UDim2.new(1, -40, 0, 30)
    progressBar.Position = UDim2.new(0.5, 0, 0.5, 20)
    progressBar.AnchorPoint = Vector2.new(0.5, 0.5)
    progressBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    progressBar.BorderSizePixel = 1

    local progressFill = Instance.new("Frame", progressBar)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)

    local goal = 30
    local current = 0
    local duration = 5
    local success = false

    local inputConn
    inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.E then
            current = current + 1
            local progress = math.clamp(current / goal, 0, 1)
            progressFill.Size = UDim2.new(progress, 0, 1, 0)
        end
    end)

    local startTime = tick()
    while tick() - startTime < duration do
        local timeLeft = duration - (tick() - startTime)
        timerLabel.Text = string.format("%.1fs", timeLeft)
        if current >= goal then
            success = true
            break
        end
        RunService.Heartbeat:Wait()
    end

    inputConn:Disconnect()
    screenGui:Destroy()
    print("Button Mashing result: " .. tostring(success))
    return success
end

-- Configuration for the interaction system
local INTERACTION_DISTANCE = 10
local MACHINE_FOLDER_NAME = "MiniGameMachines"
local machinesFolder = Workspace:FindFirstChild(MACHINE_FOLDER_NAME) or Instance.new("Folder", Workspace)
machinesFolder.Name = MACHINE_FOLDER_NAME

-- State variables
local nearbyMachine = nil
local isGameActive = false

-- Helper to create the interaction prompt
local function createInteractionPrompt()
    local promptGui = Instance.new("BillboardGui")
    promptGui.Name = "InteractionPrompt"
    promptGui.Adornee = nil
    promptGui.Size = UDim2.new(0, 200, 0, 50)
    promptGui.AlwaysOnTop = true

    local textLabel = Instance.new("TextLabel", promptGui)
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Text = "[E] to Interact"
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 30
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.BackgroundTransparency = 1

    return promptGui
end

local interactionPrompt = createInteractionPrompt()

function MiniGameManager.init()
    print("MiniGameManager Initialized.")

    -- For testing, create a sample machine if one doesn't exist
    if not machinesFolder:FindFirstChild("MiniGameMachine") then
        local sampleMachine = Instance.new("Part", machinesFolder)
        sampleMachine.Name = "MiniGameMachine"
        sampleMachine.Size = Vector3.new(4, 6, 2)
        sampleMachine.Position = Vector3.new(10, 3, 10)
        sampleMachine.Anchored = true
    end

    interactionPrompt.Parent = playerGui -- Parent it once

    -- Main loop to find nearby machines
    RunService.RenderStepped:Connect(function()
        if isGameActive then
            interactionPrompt.Enabled = false
            return
        end

        local character = player.Character
        if not character or not character.PrimaryPart then
            interactionPrompt.Enabled = false
            return
        end

        local closestMachine, closestDist = nil, INTERACTION_DISTANCE
        for _, machine in ipairs(machinesFolder:GetChildren()) do
            local dist = (character.PrimaryPart.Position - machine.Position).Magnitude
            if dist < closestDist then
                closestMachine = machine
                closestDist = dist
            end
        end

        nearbyMachine = closestMachine
        if nearbyMachine then
            interactionPrompt.Adornee = nearbyMachine
            interactionPrompt.Enabled = true
        else
            interactionPrompt.Enabled = false
        end
    end)

    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and not isGameActive and input.KeyCode == Enum.KeyCode.E and nearbyMachine then
            isGameActive = true

            local games = {
                MiniGameManager.startButtonMashing,
                MiniGameManager.startQTE,
                MiniGameManager.startMatching
            }
            local random_game = games[math.random(#games)]

            local success = random_game()
            print("Mini-game result: ", success)

            isGameActive = false
        end
    end)
end

return MiniGameManager
