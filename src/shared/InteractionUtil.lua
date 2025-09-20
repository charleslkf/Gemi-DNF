--[[
    InteractionUtil.lua
    by Jules

    This shared module provides common utility functions for player
    interactions, such as checking for movement interruption.
]]

local InteractionUtil = {}

--[[
    Starts a check that monitors if a player moves too far from their starting position.
    Returns two functions:
    - isInterrupted(): A function that returns true if the player has moved too far.
    - stop(): A function to disconnect the check and clean up.
]]
function InteractionUtil.startInterruptionCheck(player, runService, interruptDistance)
    local startCharacter = player.Character
    if not startCharacter or not startCharacter.PrimaryPart then
        -- If character doesn't exist, immediately return an interrupted state.
        return function() return true end, function() end
    end

    local startPos = startCharacter.PrimaryPart.Position
    local wasInterrupted = false

    local conn = runService.Heartbeat:Connect(function()
        local currentCharacter = player.Character
        if wasInterrupted then return end

        if currentCharacter and currentCharacter.PrimaryPart and currentCharacter == startCharacter then
            if (currentCharacter.PrimaryPart.Position - startPos).Magnitude > interruptDistance then
                wasInterrupted = true
            end
        else
            -- Character has changed or been removed, which counts as an interruption.
            wasInterrupted = true
        end
    end)

    local function isInterrupted()
        return wasInterrupted
    end

    local function stop()
        if conn then
            conn:Disconnect()
            conn = nil
        end
    end

    return isInterrupted, stop
end

return InteractionUtil
