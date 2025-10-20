--[[
    KillerControls.client.lua

    This client-side script handles the killer's ability to attack survivors.
    It's responsible for detecting clicks on survivors, checking proximity,
    and notifying the server of a valid attack attempt.
]]

-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- Modules
local CONFIG = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("Config"))
local SimulatedPlayerManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("SimulatedPlayerManager"))

-- Player Globals
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Configuration
local MAX_ATTACK_DISTANCE = 10

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")
local RequestGrab = Remotes:WaitForChild("RequestGrab")
local RequestDrop = Remotes:WaitForChild("RequestDrop")
local CarryingStateChanged = Remotes:WaitForChild("CarryingStateChanged")
local RequestHang = Remotes:WaitForChild("RequestHang")

-- State
local isCarrying = false
local targetHanger = nil
local killersTeam = Teams:WaitForChild("Killers")

-- Function to check if the player is a killer
local function isKiller()
    return player.Team == killersTeam
end

-- Helper function to find a character model from any of its descendant parts
local function findCharacterFromPart(part)
    if not part then return nil end
    local current = part
    -- A model can be nested, so we search up to 5 levels deep.
    for _ = 1, 5 do
        if current and current:FindFirstChildWhichIsA("Humanoid") then
            return current
        end
        if not current or not current.Parent then
            return nil
        end
        current = current.Parent
    end
    return nil
end

-- Helper function to find the nearest character in the "Downed" state
local function findNearestDownedCharacter(position, maxDistance)
    local nearestCharacter = nil
    local minDistance = maxDistance

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetCharacter = otherPlayer.Character
            if targetCharacter:GetAttribute("Downed") == true then
                local distance = (position - targetCharacter.HumanoidRootPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestCharacter = targetCharacter
                end
            end
        end
    end
    -- Find the nearest downed bot
    local activeBots = SimulatedPlayerManager.getSpawnedBots()
    for _, botModel in ipairs(activeBots) do
        if botModel and botModel.Parent and botModel:FindFirstChild("HumanoidRootPart") then
            if botModel:GetAttribute("Downed") == true then
                local distance = (position - botModel.HumanoidRootPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestCharacter = botModel
                end
            end
        end
    end

    return nearestCharacter
end

-- Main Attack & Grab Logic
local function onInputBegan(input, gameProcessed)
    -- Ignore input if it's already being handled by the game engine
    if gameProcessed then
        return
    end

    -- Abort if the player is not a killer or if their character doesn't exist
    if not isKiller() or not player.Character or not player.Character.PrimaryPart then
        return
    end

    local killerCharacter = player.Character

    -- Handle 'E' key for Hang
    if input.KeyCode == CONFIG.HANG_KEY then
        if isCarrying and targetHanger then
            print(string.format("[KillerControls] E pressed. Requesting hang on %s.", targetHanger.Name))
            RequestHang:FireServer(targetHanger)
        end
        return -- End processing for 'E' key
    end

    -- Handle 'F' key for Grab/Drop
    if input.KeyCode == Enum.KeyCode.F then
        if isCarrying then
            -- If already carrying, drop the survivor
            print("[KillerControls] F pressed. Requesting drop.")
            RequestDrop:FireServer()
        else
            -- If not carrying, attempt to grab a downed survivor
            local nearestDowned = findNearestDownedCharacter(killerCharacter.PrimaryPart.Position, CONFIG.GRAB_DISTANCE)
            if nearestDowned then
                print(string.format("[KillerControls] F pressed. Found downed character %s. Requesting grab.", nearestDowned.Name))
                RequestGrab:FireServer(nearestDowned)
            else
                 print("[KillerControls] F pressed. No downed character in range.")
            end
        end
        return -- End processing for 'F' key
    end

    -- Handle MouseButton1 for Attack
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    -- Abort if the player is not a killer or if their character doesn't exist
    if not isKiller() or not player.Character or not player.Character.PrimaryPart then
        return
    end

    local targetPart = mouse.Target
    if not targetPart then return end

    -- Find the character model from the clicked part
    local targetCharacter = findCharacterFromPart(targetPart)
    if not targetCharacter or targetCharacter == player.Character then
        return -- Abort if no character was found, or if it's the killer's own character
    end

    -- Check if the target is a real player
    local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
    if targetPlayer then
        -- If it's a real player, they must be on the opposing team
        if targetPlayer.Team == killersTeam then
            return
        end
    -- If it's not a real player, check if it's a bot model
    elseif not targetCharacter.Name:match("^Bot") then
        -- If it's not a player and not a bot, it's an invalid target
        return
    end

    -- Check the distance between the killer and the target
    local distance = (player.Character.PrimaryPart.Position - targetCharacter.PrimaryPart.Position).Magnitude
    if distance > MAX_ATTACK_DISTANCE then
        print(string.format("Attack failed: %s is too far away (%.1f studs).", targetCharacter.Name, distance))
        return
    end

    -- If all checks pass, notify the server, sending the character model itself.
    -- The server can then determine if it's a player or a bot.
    print(string.format("Attack success: Firing remote for %s.", targetCharacter.Name))
    AttackRequest:FireServer(targetCharacter)
end

-- Connect the handler to user input
UserInputService.InputBegan:Connect(onInputBegan)

-- Listen for state changes from the server
CarryingStateChanged.OnClientEvent:Connect(function(newState)
    isCarrying = newState
    print("[KillerControls] Carrying state updated to:", newState)
end)

-- Proximity checks for UI prompts
local RunService = game:GetService("RunService")
local UIManager = require(player.PlayerScripts:WaitForChild("UIManager"))
local Workspace = game:GetService("Workspace")

RunService.RenderStepped:Connect(function()
    if not isCarrying or not player.Character or not player.Character.PrimaryPart then
        UIManager.setInteractionPrompt("") -- Hide prompt if not carrying
        targetHanger = nil
        return
    end

    local killerPos = player.Character.PrimaryPart.Position
    local hangersFolder = Workspace:FindFirstChild("Hangers")
    local closestHanger = nil
    local minDistance = CONFIG.HANGER_INTERACT_DISTANCE

    if hangersFolder then
        for _, hanger in ipairs(hangersFolder:GetChildren()) do
            if hanger:FindFirstChild("AttachPoint") then
                local distance = (killerPos - hanger.AttachPoint.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestHanger = hanger
                end
            end
        end
    end

    if closestHanger then
        UIManager.setInteractionPrompt("[E] to Hang")
        targetHanger = closestHanger
    else
        UIManager.setInteractionPrompt("")
        targetHanger = nil
    end
end)

print("KillerControls.client.lua loaded.")
