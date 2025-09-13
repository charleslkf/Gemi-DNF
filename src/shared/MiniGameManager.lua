--[[
    MiniGameManager.lua
    by Jules (v2 - Click-Oriented, Interruptible)

    A modular, client-side system for handling complex, interruptible mini-games.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
    INTERACTION_DISTANCE = 10,
    MACHINE_FOLDER_NAME = "MiniGameMachines",
    INTERRUPT_MOVE_DISTANCE = 8,
    KILLER_PROXIMITY_RANGE = 40,
    -- TODO: Add real Sound IDs
    PROXIMITY_SOUND_ID = "rbxassetid://1842289390",
}

-- The Module
local MiniGameManager = {}

-- State variables
local nearbyMachine = nil
local isGameActive = false
local machinesFolder = Workspace:FindFirstChild(CONFIG.MACHINE_FOLDER_NAME) or Instance.new("Folder", Workspace)
machinesFolder.Name = CONFIG.MACHINE_FOLDER_NAME
local proximitySound

-- HELPER FUNCTIONS ---

-- Creates the base UI frame for a mini-game
local function createBaseGui(title)
    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "MiniGameGui"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 500, 0, 300); frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); frame.BorderSizePixel = 2

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size = UDim2.new(1, 0, 0, 40); titleLabel.Text = title; titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 24; titleLabel.TextColor3 = Color3.new(1, 1, 1); titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

    return screenGui, frame
end

-- Starts a loop to check if the player moves too far
local function startInterruptionCheck()
    local character = player.Character
    if not character or not character.PrimaryPart then return function() return true end, function() end end

    local startPos = character.PrimaryPart.Position
    local wasInterrupted = false

    local conn = RunService.Heartbeat:Connect(function()
        if not wasInterrupted and character and character.PrimaryPart then
            if (character.PrimaryPart.Position - startPos).Magnitude > CONFIG.INTERRUPT_MOVE_DISTANCE then
                wasInterrupted = true
            end
        end
    end)

    local function isInterrupted() return wasInterrupted end
    local function stop() conn:Disconnect() end

    return isInterrupted, stop
end


-- MINI-GAME IMPLEMENTATIONS ---

function MiniGameManager.startButtonMashing()
    local screenGui, frame = createBaseGui("Mash the Button!")
    local success = false
    local isInterrupted, stopInterruptCheck = startInterruptionCheck()

    local mashButton = Instance.new("TextButton", frame)
    mashButton.Size = UDim2.new(0, 150, 0, 50); mashButton.Position = UDim2.new(0.5, 0, 0.6, 0); mashButton.AnchorPoint = Vector2.new(0.5, 0.5)
    mashButton.Text = "CLICK!"; mashButton.Font = Enum.Font.SourceSansBold; mashButton.TextSize = 28

    local goal = 25; local current = 0; local duration = 5

    mashButton.MouseButton1Click:Connect(function()
        current = current + 1
    end)

    local startTime = tick()
    while tick() - startTime < duration do
        if isInterrupted() then success = false; break end
        if current >= goal then success = true; break end
        frame.Size = UDim2.new(0, 500, 0, 300 + math.sin(tick() * 20) * 5) -- Screen shake
        RunService.Heartbeat:Wait()
    end

    stopInterruptCheck()
    screenGui:Destroy()
    return success
end

function MiniGameManager.startQTE()
    local screenGui, frame = createBaseGui("QTE: Simon Says")
    local success = false
    local isInterrupted, stopInterruptCheck = startInterruptionCheck()

    local roundsToWin = 3
    local currentRound = 1

    -- Create a 3x3 grid of buttons
    local buttons = {}
    for r = 1, 3 do
        for c = 1, 3 do
            local button = Instance.new("TextButton", frame)
            button.Size = UDim2.new(0, 80, 0, 80)
            button.Position = UDim2.new(0, 50 + (c-1)*100, 0, 50 + (r-1)*100)
            button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            button.Text = ""
            table.insert(buttons, button)
        end
    end

    local playerInputSequence = {}
    for i, button in ipairs(buttons) do
        button.MouseButton1Click:Connect(function()
            table.insert(playerInputSequence, i)
            -- Animate click
            button.BackgroundColor3 = Color3.new(1,1,1)
            task.wait(0.1)
            button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
    end

    -- Game Loop
    coroutine.wrap(function()
        while currentRound <= roundsToWin and not success and not isInterrupted() do
            -- Generate sequence
            local sequence = {}
            for i = 1, currentRound + 2 do
                table.insert(sequence, math.random(#buttons))
            end

            -- Show sequence
            task.wait(1)
            for _, buttonIndex in ipairs(sequence) do
                if isInterrupted() then break end
                buttons[buttonIndex].BackgroundColor3 = Color3.fromRGB(200, 200, 100)
                task.wait(0.5)
                buttons[buttonIndex].BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                task.wait(0.1)
            end

            if isInterrupted() then break end

            -- Get player input
            playerInputSequence = {}
            local inputStartTime = tick()
            while #playerInputSequence < #sequence do
                if isInterrupted() then break end
                if tick() - inputStartTime > 5 then break end -- 5 seconds per sequence
                RunService.Heartbeat:Wait()
            end

            if isInterrupted() then break end

            -- Check if sequence is correct
            local correct = true
            if #playerInputSequence ~= #sequence then correct = false end
            for i, buttonIndex in ipairs(sequence) do
                if playerInputSequence[i] ~= buttonIndex then
                    correct = false
                    break
                end
            end

            if correct then
                currentRound = currentRound + 1
                if currentRound > roundsToWin then
                    success = true
                end
            else
                break -- Incorrect sequence, end game
            end
        end
    end)()

    -- Wait for game to finish or be interrupted
    while not success and currentRound <= roundsToWin and not isInterrupted() do
        RunService.Heartbeat:Wait()
    end

    stopInterruptCheck()
    screenGui:Destroy()
    return success
end

function MiniGameManager.startMatching()
    local screenGui, frame = createBaseGui("Matching Game")
    local success = false
    local isInterrupted, stopInterruptCheck = startInterruptionCheck()

    local ICONS = {
        "rbxassetid://2844027442", "rbxassetid://2844027442",
        "rbxassetid://2844027289", "rbxassetid://2844027289",
        "rbxassetid://2844027142", "rbxassetid://2844027142",
        "rbxassetid://2844026998", "rbxassetid://2844026998",
        "rbxassetid://2844026848", "rbxassetid://2844026848",
        "rbxassetid://2844026698", "rbxassetid://2844026698",
    }
    local shuffledIcons = shuffle(ICONS)

    local firstCard, secondCard = nil, nil
    local pairsFound = 0
    local canClick = true

    for i = 1, 12 do
        local card = Instance.new("ImageButton", frame)
        card.Size = UDim2.new(0, 80, 0, 80)
        card.Position = UDim2.new(0, 50 + ((i-1)%4)*100, 0, 50 + math.floor((i-1)/4)*100)
        card.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        card.Image = "" -- Initially blank

        card.MouseButton1Click:Connect(function()
            if not canClick or card.Image ~= "" or (firstCard and card == firstCard.button) then return end

            card.Image = shuffledIcons[i]

            if not firstCard then
                firstCard = {button = card, id = shuffledIcons[i]}
            else
                canClick = false
                secondCard = {button = card, id = shuffledIcons[i]}

                task.wait(0.7)
                if firstCard.id == secondCard.id then
                    firstCard.button.Visible = false
                    secondCard.button.Visible = false
                    pairsFound = pairsFound + 1
                    if pairsFound == 6 then
                        success = true
                    end
                else
                    firstCard.button.Image = ""
                    secondCard.button.Image = ""
                end
                firstCard, secondCard = nil, nil
                canClick = true
            end
        end)
    end

    -- Game Loop to check for interruption
    local duration = 30 -- 30 second time limit
    local startTime = tick()
    while not success and not isInterrupted() and tick() - startTime < duration do
        RunService.Heartbeat:Wait()
    end

    stopInterruptCheck()
    screenGui:Destroy()
    return success
end

-- ACTIVATION & MAIN LOGIC ---

function MiniGameManager.startMiniGame(machine)
    if isGameActive then return end
    isGameActive = true

    local games = { MiniGameManager.startButtonMashing, MiniGameManager.startQTE, MiniGameManager.startMatching }
    local random_game = games[math.random(#games)]

    local success = random_game()

    if success then
        print("Mini-game success!")
    else
        print("Mini-game failed or was interrupted!")
    end

    isGameActive = false
end

function MiniGameManager.init()
    print("MiniGameManager Initialized.")

    -- Setup audio
    proximitySound = Instance.new("Sound", playerGui); proximitySound.SoundId = CONFIG.PROXIMITY_SOUND_ID; proximitySound.Looped = true

    -- For testing, create a sample machine
    if not machinesFolder:FindFirstChild("MiniGameMachine") then
        local machine = Instance.new("Part", machinesFolder); machine.Name = "MiniGameMachine"; machine.Size = Vector3.new(4, 6, 2)
        machine.Position = Vector3.new(10, 3, 10); machine.Anchored = true; machine.BrickColor = BrickColor.new("New Yeller"); machine.Material = Enum.Material.Neon
    end

    -- Proximity and Input Loop
    RunService.RenderStepped:Connect(function()
        local character = player.Character
        if not character or not character.PrimaryPart or isGameActive then return end

        -- Killer proximity check
        local killerTeam = Teams:FindFirstChild("Killers")
        local closestKillerDist = math.huge
        if killerTeam then
            for _, p in ipairs(killerTeam:GetPlayers()) do
                if p ~= player and p.Character and p.Character.PrimaryPart then
                    closestKillerDist = math.min(closestKillerDist, (character.PrimaryPart.Position - p.Character.PrimaryPart.Position).Magnitude)
                end
            end
        end

        if closestKillerDist < CONFIG.KILLER_PROXIMITY_RANGE then
            if not proximitySound.IsPlaying then proximitySound:Play() end
        else
            if proximitySound.IsPlaying then proximitySound:Stop() end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and not isGameActive and input.KeyCode == Enum.KeyCode.E then
            local character = player.Character
            if not character or not character.PrimaryPart then return end

            local closestDist = INTERACTION_DISTANCE
            for _, machine in ipairs(machinesFolder:GetChildren()) do
                local dist = (character.PrimaryPart.Position - machine.Position).Magnitude
                if dist < closestDist then
                    MiniGameManager.startMiniGame(machine)
                    break
                end
            end
        end
    end)
end

return MiniGameManager
