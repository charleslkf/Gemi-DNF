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

-- Use WaitForChild to ensure all remote events are loaded before continuing
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameStateChanged = Remotes:WaitForChild("GameStateChanged")
local EscapeSequenceStarted = Remotes:WaitForChild("EscapeSequenceStarted")

-- Use WaitForChild to ensure the UIManager has created the MainHUD
local screenGui = playerGui:WaitForChild("MainHUD", 10)
if not screenGui then
    print("[EscapeUIController] FATAL: MainHUD not found after 10 seconds. Aborting.")
    return
end

local arrowImage = Instance.new("ImageLabel")
arrowImage.Name = "EscapeArrow"
arrowImage.Image = "rbxassetid://4984448565" -- New, valid asset ID provided by user
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
local activeGates = {}

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
    if nearestGate and camera then
        arrowImage.Visible = true
        local gatePos = nearestGate.Position
        local screenPoint, onScreen = camera:WorldToScreenPoint(gatePos)
        if onScreen then
            arrowImage.Position = UDim2.new(0, screenPoint.X, 0, screenPoint.Y)
            arrowImage.Rotation = 0
        else
            local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            local direction = (Vector2.new(screenPoint.X, screenPoint.Y) - screenCenter).Unit
            local boundX = math.clamp(screenCenter.X + direction.X * 1000, 50, camera.ViewportSize.X - 50)
            local boundY = math.clamp(screenCenter.Y + direction.Y * 1000, 50, camera.ViewportSize.Y - 50)
            arrowImage.Position = UDim2.new(0, boundX, 0, boundY)
            arrowImage.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
        end
    else
        arrowImage.Visible = false
    end
end

-- Listen for the dedicated escape event to start the UI
EscapeSequenceStarted.OnClientEvent:Connect(function(gates)
    if player.Team and player.Team.Name == "Survivors" then
        activeGates = gates
        if not escapeConnection then
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
        end
    end
end)

print("EscapeUIController.client.lua loaded.")