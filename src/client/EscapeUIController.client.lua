--[[
    EscapeUIController.client.lua

    This script is solely responsible for managing the UI effects during
    the escape sequence (the screen crack and the directional arrow).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local EscapeSequenceStarted = Remotes:WaitForChild("EscapeSequenceStarted")

-- Find the main ScreenGui created by UIManager
local screenGui = playerGui:WaitForChild("MainHUD")

local arrowImage = Instance.new("ImageLabel")
arrowImage.Name = "EscapeArrow"
arrowImage.Image = "rbxassetid://5989193313"
arrowImage.Size = UDim2.new(0, 50, 0, 50)
arrowImage.AnchorPoint = Vector2.new(0.5, 0.5)
arrowImage.BackgroundTransparency = 1
arrowImage.Visible = false
arrowImage.ZIndex = 2 -- Set ZIndex to render on top
arrowImage.Parent = screenGui

local screenCrackImage = Instance.new("ImageLabel")
screenCrackImage.Name = "ScreenCrackEffect"
screenCrackImage.Image = "rbxassetid://268393522"
screenCrackImage.ImageTransparency = 0.8
screenCrackImage.Size = UDim2.new(1, 0, 1, 0)
screenCrackImage.Visible = false
screenCrackImage.ZIndex = 1 -- Keep crack effect behind the arrow
screenCrackImage.Parent = screenGui

local escapeConnection = nil
local flickerCounter = 0
local activeGates = {} -- Will be populated by the server event
local hasPrintedDebugReport = false

local function findNearestGateFromActive()
    local playerChar = player.Character
    if not playerChar or not playerChar:FindFirstChild("HumanoidRootPart") or #activeGates == 0 then return nil end

    local playerPos = playerChar.HumanoidRootPart.Position
    local nearestGate, minDistance = nil, math.huge

    for _, part in ipairs(activeGates) do
        if part and part.Parent then -- Check if gate is valid
            local distance = (playerPos - part.Position).Magnitude
            if distance < minDistance then
                minDistance = distance
                nearestGate = part
            end
        end
    end
    return nearestGate
end

local function updateEscapeUI()
    flickerCounter = (flickerCounter + 1) % 10
    screenCrackImage.Visible = (flickerCounter < 5)

    local nearestGate = findNearestGateFromActive()
    local newRotation = arrowImage.Rotation -- Default to current rotation

    if nearestGate and camera then
        arrowImage.Visible = true
        local gatePos = nearestGate.Position
        local screenPoint, onScreen = camera:WorldToScreenPoint(gatePos)
        if onScreen then
            arrowImage.Position = UDim2.new(0, screenPoint.X, 0, screenPoint.Y)
            newRotation = 0
        else
            local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            local direction = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Unit
            local boundX = math.clamp(screenCenter.X + direction.X * 1000, 50, camera.ViewportSize.X - 50)
            local boundY = math.clamp(screenCenter.Y + direction.Y * 1000, 50, camera.ViewportSize.Y - 50)
            arrowImage.Position = UDim2.new(0, boundX, 0, boundY)
            newRotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
        end
        arrowImage.Rotation = newRotation
    else
        arrowImage.Visible = false
    end
    -- Log #6
    print("[UIManager-DEBUG] In update loop. New rotation is:", newRotation)
end

-- Listen for the dedicated escape event to start the UI
EscapeSequenceStarted.OnClientEvent:Connect(function(gates)
    if player.Team and player.Team.Name == "Survivors" then
        -- Log #1
        print("[UIManager-DEBUG] 'EscapeSequenceStarted' event received by client.")
        activeGates = gates

        -- Log #2
        print("[UIManager-DEBUG] Attempting to find the Arrow GUI object.")
        if arrowImage then
            -- Log #3
            print("[UIManager-DEBUG] Arrow GUI object found:", arrowImage.Name)
            arrowImage.Visible = true
            -- Log #4
            print("[UIManager-DEBUG] Set arrow visibility to true. Current absolute position:", arrowImage.AbsolutePosition)

            print("--- ARROW UI DEBUG REPORT ---")
            print("  - Arrow Name:", arrowImage.Name)
            print("  - Arrow Parent:", arrowImage.Parent and arrowImage.Parent.Name or "nil")
            print("  - Is Arrow Visible:", arrowImage.Visible)
            print("  - Is Parent Enabled:", arrowImage.Parent and arrowImage.Parent.Enabled or "nil")
            print("  - Position (UDim2):", arrowImage.Position)
            print("  - AbsolutePosition (Pixels):", arrowImage.AbsolutePosition)
            print("  - Size (UDim2):", arrowImage.Size)
            print("  - AbsoluteSize (Pixels):", arrowImage.AbsoluteSize)
            print("  - ZIndex:", arrowImage.ZIndex)
            print("  - Image Asset ID:", arrowImage.Image)
            print("  - ImageTransparency:", arrowImage.ImageTransparency)
            print("--- END REPORT ---")
        else
            print("  - ERROR: Arrow object is nil!")
        end

        if not escapeConnection then
            -- Log #5
            print("[UIManager-DEBUG] Preparing to start the arrow direction update loop.")
            escapeConnection = RunService.Heartbeat:Connect(updateEscapeUI)
        end
    end
end)

-- Listen for general game state changes to know when to stop
GameStateChanged.OnClientEvent:Connect(function(newState)
    if newState.Name ~= "Escape" then
        if escapeConnection then
            escapeConnection:Disconnect()
            escapeConnection = nil
            screenCrackImage.Visible = false
            arrowImage.Visible = false
            activeGates = {}
            print("[EscapeUIController] Escape sequence UI deactivated.")
        end
    end
end)

print("EscapeUIController.client.lua loaded.")