--[[
    MiniGameManager.lua
    by Jules (v10 - Server-Driven Refactor)

    A modular, client-side system for handling complex, interruptible mini-games.
    Reads GameType attribute from machines to determine which game to play.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Player Globals
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local CONFIG = {
    INTERACTION_DISTANCE = 12,
    MACHINE_FOLDER_NAME = "MiniGameMachines",
    INTERRUPT_MOVE_DISTANCE = 10,
}

-- The Module
local MiniGameManager = {}

-- State variables
local isGameActive = false
local nearbyMachine = nil

-- HELPER FUNCTIONS ---

local function createBaseGui(title)
    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "MiniGameGui"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 500, 0, 400)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 2

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Text = title
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

    local timerLabel = Instance.new("TextLabel", frame)
    timerLabel.Size = UDim2.new(0, 100, 0, 30)
    timerLabel.Position = UDim2.new(1, -110, 1, -40)
    timerLabel.Font = Enum.Font.SourceSansBold
    timerLabel.TextSize = 20
    timerLabel.TextColor3 = Color3.new(1, 1, 1)
    timerLabel.BackgroundTransparency = 1

    return screenGui, frame, timerLabel
end

local function startInterruptionCheck()
    local startCharacter = player.Character
    if not startCharacter or not startCharacter.PrimaryPart then return function() return true end, function() end end
    local startPos = startCharacter.PrimaryPart.Position
    local wasInterrupted = false
    local conn = RunService.Heartbeat:Connect(function()
        local currentCharacter = player.Character
        if wasInterrupted then return end
        if currentCharacter and currentCharacter.PrimaryPart and currentCharacter == startCharacter then
            if (currentCharacter.PrimaryPart.Position - startPos).Magnitude > CONFIG.INTERRUPT_MOVE_DISTANCE then
                wasInterrupted = true
            end
        else
            wasInterrupted = true
        end
    end)
    local function isInterrupted() return wasInterrupted end
    local function stop() conn:Disconnect() end
    return isInterrupted, stop
end

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
    textLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
    textLabel.BackgroundTransparency = 1
    return promptGui
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do local j = math.random(i); tbl[i], tbl[j] = tbl[j], tbl[i] end
    return tbl
end

-- Helper to repeat elements in a table N times
local function rep(tbl, n)
    local newTbl = {}
    for _ = 1, n do
        for _, v in ipairs(tbl) do
            table.insert(newTbl, v)
        end
    end
    return newTbl
end

local function showEndResult(isSuccess, wasInterrupted)
    if not isSuccess and not wasInterrupted then return end -- Don't show for normal attempt failures

    local resultGui = Instance.new("ScreenGui", playerGui)
    resultGui.Name = "ResultGui"
    resultGui.IgnoreGuiInset = true
    resultGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local resultLabel = Instance.new("TextLabel", resultGui)
    resultLabel.Size = UDim2.new(1, 0, 1, 0)
    resultLabel.Font = Enum.Font.SourceSansBold
    resultLabel.TextSize = 100
    resultLabel.BackgroundTransparency = 1

    if isSuccess then
        resultLabel.Text = "SUCCESS"
        resultLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    elseif wasInterrupted then
        resultLabel.Text = "FAILURE"
        resultLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    end

    task.wait(1.5)
    resultGui:Destroy()
end

-- MINI-GAME IMPLEMENTATIONS ---

function MiniGameManager.startButtonMashing()
    local screenGui, frame, timerLabel = createBaseGui("Mash the Button!")
    local success = false; local wasInterrupted = false; local isInterrupted, stopInterruptCheck = startInterruptionCheck()
    local mashButton = Instance.new("TextButton", frame); mashButton.Size = UDim2.new(0, 150, 0, 50); mashButton.Position = UDim2.new(0.5, 0, 0.6, 0); mashButton.AnchorPoint = Vector2.new(0.5, 0.5); mashButton.Text = "CLICK!"; mashButton.Font = Enum.Font.SourceSansBold; mashButton.TextSize = 28
    local counterLabel = Instance.new("TextLabel", frame); counterLabel.Size = UDim2.new(0, 150, 0, 30); counterLabel.Position = UDim2.new(0.5, -75, 0.3, 0); counterLabel.Font = Enum.Font.SourceSansBold; counterLabel.TextSize = 24; counterLabel.TextColor3 = Color3.new(1,1,1); counterLabel.BackgroundTransparency = 1
    local goal = 25; local current = 0; local duration = 5; counterLabel.Text = string.format("%d / %d", current, goal)
    mashButton.MouseButton1Click:Connect(function() current = current + 1; counterLabel.Text = string.format("%d / %d", current, goal) end)
    local startTime = tick(); while tick() - startTime < duration do if isInterrupted() then wasInterrupted=true; break end; if current >= goal then success = true; break end; local timeLeft = duration - (tick() - startTime); timerLabel.Text = string.format("%.1fs", timeLeft); RunService.Heartbeat:Wait() end
    stopInterruptCheck(); screenGui:Destroy(); showEndResult(success, wasInterrupted); return success
end

function MiniGameManager.startQTE()
    local screenGui, frame, timerLabel = createBaseGui("Memory Check")
    local success = false; local wasInterrupted = false; local isInterrupted, stopInterruptCheck = startInterruptionCheck()
    local roundsToWin = 3; local currentRound = 1
    local roundCounter = Instance.new("TextLabel", frame); roundCounter.Size = UDim2.new(0, 200, 0, 30); roundCounter.Position = UDim2.new(0, 10, 1, -40); roundCounter.Font = Enum.Font.SourceSansBold; roundCounter.TextSize = 20; roundCounter.TextColor3 = Color3.new(1,1,1); roundCounter.BackgroundTransparency = 1; roundCounter.Text = string.format("Round: %d / %d", currentRound-1, roundsToWin)
    local buttons = {}; for r=1,3 do for c=1,3 do local btn=Instance.new("TextButton",frame); btn.Size=UDim2.new(0,100,0,80); btn.Position=UDim2.new(0.5,-165+(c-1)*110,0.5,-130+(r-1)*90); btn.BackgroundColor3=Color3.fromRGB(80,80,80); table.insert(buttons,btn) end end
    local playerInputSequence = {}; for i, button in ipairs(buttons) do button.MouseButton1Click:Connect(function() table.insert(playerInputSequence,i); button.BackgroundColor3=Color3.new(1,1,1); task.wait(0.1); button.BackgroundColor3=Color3.fromRGB(80,80,80) end) end

    while currentRound <= roundsToWin and not isInterrupted() do
        roundCounter.Text = string.format("Round: %d / %d", currentRound - 1, roundsToWin)
        local sequence = {}; for i=1,currentRound+1 do table.insert(sequence,math.random(#buttons)) end; task.wait(1)
        for _,buttonIndex in ipairs(sequence) do if isInterrupted() then break end; buttons[buttonIndex].BackgroundColor3=Color3.fromRGB(200,200,100); task.wait(0.4); buttons[buttonIndex].BackgroundColor3=Color3.fromRGB(80,80,80); task.wait(0.1) end
        if isInterrupted() then break end; playerInputSequence = {}; local inputStartTime=tick()
        while #playerInputSequence<#sequence do if isInterrupted() then break end; if tick()-inputStartTime>5 then break end; RunService.Heartbeat:Wait() end
        if isInterrupted() then break end; local correct = true; if #playerInputSequence~=#sequence then correct=false end
        for i,buttonIndex in ipairs(sequence) do if playerInputSequence[i]~=buttonIndex then correct=false; break end end
        if correct then currentRound=currentRound+1 else frame.BackgroundColor3=Color3.fromRGB(150,0,0); task.wait(0.3); frame.BackgroundColor3=Color3.fromRGB(30,30,30) end
    end

    if currentRound > roundsToWin then success = true end
    if isInterrupted() then wasInterrupted = true; success = false; end
    stopInterruptCheck(); screenGui:Destroy(); showEndResult(success, wasInterrupted); return success
end

-- ACTIVATION & MAIN LOGIC ---

local gameFunctions = {
    ButtonMash = MiniGameManager.startButtonMashing,
    MemoryCheck = MiniGameManager.startQTE
}

function MiniGameManager.init()
    print("MiniGameManager: Initializing system for player.")

    -- Proximity check loop (RenderStepped)
    RunService.RenderStepped:Connect(function()
        if isGameActive then return end

        local machinesFolder = Workspace:FindFirstChild(CONFIG.MACHINE_FOLDER_NAME)
        local character = player.Character

        if not machinesFolder or not character or not character.PrimaryPart then
            if nearbyMachine and nearbyMachine.Parent then
                 local prompt = nearbyMachine:FindFirstChild("InteractionPrompt")
                 if prompt then prompt:Destroy() end
            end
            nearbyMachine = nil
            return
        end

        local characterPos = character.PrimaryPart.Position
        local closestMachineFound

        for _, machine in ipairs(machinesFolder:GetChildren()) do
            if not machine:IsA("BasePart") then continue end
            if (characterPos - machine.Position).Magnitude < CONFIG.INTERACTION_DISTANCE and not machine:GetAttribute("IsCompleted") then
                closestMachineFound = machine
                break
            end
        end

        if closestMachineFound ~= nearbyMachine then
            if nearbyMachine and nearbyMachine.Parent then
                local oldPrompt = nearbyMachine:FindFirstChild("InteractionPrompt")
                if oldPrompt then oldPrompt:Destroy() end
            end
            if closestMachineFound then
                createInteractionPrompt().Parent = closestMachineFound
            end
            nearbyMachine = closestMachineFound
        end
    end)

    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or isGameActive or input.KeyCode ~= Enum.KeyCode.E or not nearbyMachine then
            return
        end

        local gameType = nearbyMachine:GetAttribute("GameType")
        local gameToPlay = gameFunctions[gameType]

        if not gameToPlay then
            warn("MiniGameManager: Machine has invalid GameType:", gameType)
            return
        end

        isGameActive = true

        local success = gameToPlay()

        if success then
            -- On success, mark machine as completed and change color
            nearbyMachine:SetAttribute("IsCompleted", true)
            nearbyMachine.Color = Color3.fromRGB(0, 255, 0)
            -- The interaction prompt will be removed on the next RenderStepped cycle
        end

        -- Allow another game to be started
        isGameActive = false
    end)
end

return MiniGameManager
