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

-- Player Globals
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Configuration
local MAX_ATTACK_DISTANCE = 10

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AttackRequest = Remotes:WaitForChild("AttackRequest")

-- State
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

-- Main Attack Logic
local function onInputBegan(input, gameProcessed)
    -- Only proceed if input was a left-click and not handled by the game engine already
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 or gameProcessed then
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

print("KillerControls.client.lua loaded.")
