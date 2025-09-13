--[[
    MiniGameManager.lua
    by Jules (v6 - Definitive Rewrite)

    A modular, client-side system for handling complex, interruptible mini-games.
    This version is a full rewrite to ensure correctness and add extensive debugging.
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
    INTERACTION_DISTANCE = 12,
    MACHINE_FOLDER_NAME = "MiniGameMachines",
    INTERRUPT_MOVE_DISTANCE = 10,
    KILLER_PROXIMITY_RANGE = 40,
    PROXIMITY_SOUND_ID = "rbxassetid://1842289390", -- Invalid ID
}

-- The Module
local MiniGameManager = {}

-- State variables
local isGameActive = false
local nearbyMachine = nil
local machinesFolder = Workspace:FindFirstChild(CONFIG.MACHINE_FOLDER_NAME) or Instance.new("Folder", Workspace)
machinesFolder.Name = CONFIG.MACHINE_FOLDER_NAME

-- HELPER FUNCTIONS ---

local function createBaseGui(title)
    print("Creating base GUI for:", title)
    local screenGui = Instance.new("ScreenGui", playerGui)
    screenGui.Name = "MiniGameGui"
    screenGui.ResetOnSpawn = false

    local frame = Instance.new("Frame", screenGui)
    frame.Size = UDim2.new(0, 500, 0, 400) -- FIX: Increased height
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

    return screenGui, frame
end

local function startInterruptionCheck()
    print("Starting interruption check.")
    local startCharacter = player.Character
    if not startCharacter or not startCharacter.PrimaryPart then
        print("Interruption check failed: No character or PrimaryPart.")
        return function() return true end, function() end
    end

    local startPos = startCharacter.PrimaryPart.Position
    local wasInterrupted = false

    local conn = RunService.Heartbeat:Connect(function()
        local currentCharacter = player.Character
        if wasInterrupted then return end

        if currentCharacter and currentCharacter.PrimaryPart and currentCharacter == startCharacter then
            local dist = (currentCharacter.PrimaryPart.Position - startPos).Magnitude
            if dist > CONFIG.INTERRUPT_MOVE_DISTANCE then
                print("Interrupted by movement. Distance:", dist)
                wasInterrupted = true
            end
        else
            print("Interrupted by character change (respawn/death).")
            wasInterrupted = true
        end
    end)

    local function isInterrupted() return wasInterrupted end
    local function stop() print("Stopping interruption check."); conn:Disconnect() end

    return isInterrupted, stop
end

local function createInteractionPrompt()
    print("Creating interaction prompt.")
    local promptGui = Instance.new("BillboardGui")
    promptGui.Name = "InteractionPrompt"
    promptGui.Adornee = nil
    promptGui.Size = UDim2.new(5, 0, 2, 0) -- FIX: Stud-based size
    promptGui.AlwaysOnTop = true
    promptGui.Enabled = false -- Start disabled

    local textLabel = Instance.new("TextLabel", promptGui)
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Text = "[E] to Interact"
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.TextSize = 30
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.BackgroundTransparency = 1

    return promptGui
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do local j = math.random(i); tbl[i], tbl[j] = tbl[j], tbl[i] end
    return tbl
end

-- MINI-GAME IMPLEMENTATIONS ---

function MiniGameManager.startButtonMashing()
    print("Starting Button Mashing game.")
    local screenGui, frame = createBaseGui("Mash the Button!")
    local success = false
    local isInterrupted, stopInterruptCheck = startInterruptionCheck()

    local mashButton = Instance.new("TextButton", frame)
    mashButton.Size = UDim2.new(0, 150, 0, 50); mashButton.Position = UDim2.new(0.5, 0, 0.6, 0); mashButton.AnchorPoint = Vector2.new(0.5, 0.5)
    mashButton.Text = "CLICK!"; mashButton.Font = Enum.Font.SourceSansBold; mashButton.TextSize = 28

    local goal = 25; local current = 0; local duration = 5
    mashButton.MouseButton1Click:Connect(function() current = current + 1 end)

    local startTime = tick()
    while tick() - startTime < duration do
        if isInterrupted() then success = false; break end
        if current >= goal then success = true; break end
        RunService.Heartbeat:Wait()
    end

    stopInterruptCheck(); screenGui:Destroy()
    return success
end

function MiniGameManager.startQTE()
    print("Starting QTE game.")
    local screenGui, frame = createBaseGui("QTE: Simon Says")
    local success = false
    local isInterrupted, stopInterruptCheck = startInterruptionCheck()
    local roundsToWin = 3; local currentRound = 1
    local buttons = {}; for r=1,3 do for c=1,3 do local btn=Instance.new("TextButton",frame); btn.Size=UDim2.new(0,100,0,80); btn.Position=UDim2.new(0.5,-150+(c-1)*110,0.5,-130+(r-1)*90); btn.BackgroundColor3=Color3.fromRGB(80,80,80); table.insert(buttons,btn) end end
    local playerInputSequence = {}; for i, button in ipairs(buttons) do button.MouseButton1Click:Connect(function() table.insert(playerInputSequence,i); button.BackgroundColor3=Color3.new(1,1,1); task.wait(0.1); button.BackgroundColor3=Color3.fromRGB(80,80,80) end) end

    coroutine.wrap(function()
        while currentRound <= roundsToWin and not success and not isInterrupted() do
            local sequence = {}; for i=1,currentRound+1 do table.insert(sequence,math.random(#buttons)) end
            task.wait(1)
            for _,buttonIndex in ipairs(sequence) do if isInterrupted() then break end; buttons[buttonIndex].BackgroundColor3=Color3.fromRGB(200,200,100); task.wait(0.4); buttons[buttonIndex].BackgroundColor3=Color3.fromRGB(80,80,80); task.wait(0.1) end
            if isInterrupted() then break end
            playerInputSequence = {}; local inputStartTime=tick()
            while #playerInputSequence < #sequence do if isInterrupted() then break end; if tick()-inputStartTime > 5 then break end; RunService.Heartbeat:Wait() end
            if isInterrupted() then break end
            local correct = true; if #playerInputSequence ~= #sequence then correct = false end
            for i,buttonIndex in ipairs(sequence) do if playerInputSequence[i]~=buttonIndex then correct=false; break end end
            if correct then currentRound = currentRound + 1; if currentRound > roundsToWin then success = true end else break end
        end
    end)()

    while not success and currentRound <= roundsToWin and not isInterrupted() do RunService.Heartbeat:Wait() end
    stopInterruptCheck(); screenGui:Destroy()
    return success
end

function MiniGameManager.startMatching()
    print("Starting Matching game.")
    local screenGui, frame = createBaseGui("Matching Game")
    local success = false
    local isInterrupted, stopInterruptCheck = startInterruptionCheck()
    local ICONS = {"rbxassetid://2844027442","rbxassetid://2844027442","rbxassetid://2844027289","rbxassetid://2844027289","rbxassetid://2844027142","rbxassetid://2844027142","rbxassetid://2844026998","rbxassetid://2844026998","rbxassetid://2844026848","rbxassetid://2844026848","rbxassetid://2844026698","rbxassetid://2844026698"}
    local shuffledIcons=shuffle(ICONS)
    local firstCard,secondCard = nil,nil; local pairsFound=0; local canClick=true

    for i=1,12 do
        local card=Instance.new("ImageButton",frame); card.Size=UDim2.new(0,80,0,80); card.Position=UDim2.new(0.5,-180+((i-1)%4)*90,0.5,-90+math.floor((i-1)/3)*90); card.BackgroundColor3=Color3.fromRGB(100,100,100); card.Image=""
        card.MouseButton1Click:Connect(function()
            if not canClick or card.Image~="" or (firstCard and card==firstCard.button) then return end
            card.Image=shuffledIcons[i]
            if not firstCard then firstCard={button=card,id=shuffledIcons[i]}
            else canClick=false; secondCard={button=card,id=shuffledIcons[i]}; task.wait(0.7)
                if firstCard.id==secondCard.id then firstCard.button.Visible=false; secondCard.button.Visible=false; pairsFound=pairsFound+1; if pairsFound==6 then success=true end
                else firstCard.button.Image=""; secondCard.button.Image="" end
                firstCard,secondCard=nil,nil; canClick=true
            end
        end)
    end

    local duration=30; local startTime=tick(); while not success and not isInterrupted() and tick()-startTime<duration do RunService.Heartbeat:Wait() end
    stopInterruptCheck(); screenGui:Destroy()
    return success
end

-- ACTIVATION & MAIN LOGIC ---

function MiniGameManager.init()
    print("MiniGameManager: Initializing system for player.")
    local interactionPrompt = createInteractionPrompt()
    interactionPrompt.Parent = playerGui

    if not machinesFolder:FindFirstChild("MiniGameMachine") then
        local machine=Instance.new("Part",machinesFolder); machine.Name="MiniGameMachine"; machine.Size=Vector3.new(4,6,2); machine.Position=Vector3.new(10,3,10); machine.Anchored=true; machine.BrickColor=BrickColor.new("New Yeller"); machine.Material=Enum.Material.Neon
    end

    RunService.RenderStepped:Connect(function()
        if isGameActive then interactionPrompt.Enabled=false; return end
        local character=player.Character; if not character or not character.PrimaryPart then interactionPrompt.Enabled=false; return end

        local closestMachineFound = nil
        for _,machine in ipairs(machinesFolder:GetChildren()) do
            if (character.PrimaryPart.Position-machine.Position).Magnitude < CONFIG.INTERACTION_DISTANCE then
                closestMachineFound = machine
                break
            end
        end

        nearbyMachine = closestMachineFound
        if nearbyMachine then
            interactionPrompt.Adornee = nearbyMachine
            interactionPrompt.Enabled = true
        else
            interactionPrompt.Adornee = nil
            interactionPrompt.Enabled = false
        end
    end)

    UserInputService.InputBegan:Connect(function(input,gameProcessed)
        if not gameProcessed and not isGameActive and input.KeyCode==Enum.KeyCode.E and nearbyMachine then
            isGameActive=true
            local games={MiniGameManager.startButtonMashing,MiniGameManager.startQTE,MiniGameManager.startMatching}
            local random_game=games[math.random(#games)]
            local success=random_game()
            if success then print("Mini-game success!") else print("Mini-game failed or was interrupted!") end
            isGameActive=false
        end
    end)
end

return MiniGameManager
