--[[
    TestAssetManager.server.lua

    This script programmatically creates the necessary assets for running automated tests,
    such as the BotTemplate model and the PlayableArea part.
    This ensures that tests can be run without requiring any manual setup in Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TestAssetManager = {}

function TestAssetManager.createAssets()
    -- --- Create PlayableArea ---
    if not Workspace:FindFirstChild("PlayableArea") then
        print("TestAssetManager: Creating PlayableArea part.")
        local playableArea = Instance.new("Part")
        playableArea.Name = "PlayableArea"
        playableArea.Size = Vector3.new(200, 1, 200)
        playableArea.Position = Vector3.new(0, 0.5, 0)
        playableArea.Anchored = true
        playableArea.Transparency = 1
        playableArea.CanCollide = false
        playableArea.Parent = Workspace
    end

    -- --- Create BotTemplate ---
    if not ReplicatedStorage:FindFirstChild("BotTemplate") then
        print("TestAssetManager: Creating R6 BotTemplate model.")
        local model = Instance.new("Model")
        model.Name = "BotTemplate"

        local humanoid = Instance.new("Humanoid")
        humanoid.Parent = model

        local rootPart = Instance.new("Part")
        rootPart.Name = "HumanoidRootPart"
        rootPart.Size = Vector3.new(2, 2, 1)
        rootPart.CFrame = CFrame.new(0, 3, 0)
        rootPart.Parent = model
        model.PrimaryPart = rootPart

        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(2, 1, 1)
        head.CFrame = CFrame.new(0, 4.5, 0)
        head.Parent = model

        local torso = Instance.new("Part")
        torso.Name = "Torso"
        torso.Size = Vector3.new(2, 2, 1)
        torso.CFrame = CFrame.new(0, 2, 0)
        torso.Parent = model

        -- A simplified R6 model is sufficient for pathfinding and targeting.
        -- Creating all the joints is overly complex for this testing scope.

        model.Parent = ReplicatedStorage
    end
end

-- Run asset creation as soon as the script loads.
TestAssetManager.createAssets()

return TestAssetManager