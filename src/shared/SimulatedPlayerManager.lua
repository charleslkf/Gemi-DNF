--[[
    SimulatedPlayerManager.lua

    Manages the lifecycle of simulated player characters (bots) for testing purposes.
    This module handles spawning, movement, and despawning of bot models in the Workspace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HealthManager = require(ReplicatedStorage:WaitForChild("MyModules"):WaitForChild("HealthManager"))

local SimulatedPlayerManager = {}

-- Constants
local BOT_TEMPLATE_NAME = "BotTemplate"

-- Store a reference to all bots managed by this module
local activeBots = {}

---
-- Destroys all currently active bot models from the workspace.
function SimulatedPlayerManager.despawnSimulatedPlayers()
    print(string.format("Despawning %d active bots.", #activeBots))
    for _, botModel in ipairs(activeBots) do
        if botModel and botModel.Parent then
            HealthManager.cleanupEntity(botModel) -- Clean up health data first
            botModel:Destroy()
        end
    end
    -- Clear the table for the next spawn cycle
    table.clear(activeBots)
end

---
-- Spawns a given number of simulated player characters.
-- @param count The number of bots to spawn.
-- @returns A table containing the models of the spawned bots.
function SimulatedPlayerManager.spawnSimulatedPlayers(count)
    -- Per the specification, despawn any existing bots to ensure a clean slate.
    SimulatedPlayerManager.despawnSimulatedPlayers()
    print(string.format("Spawning %d new bots...", count))

    local botTemplate = ReplicatedStorage:FindFirstChild(BOT_TEMPLATE_NAME)
    if not botTemplate then
        warn("SimulatedPlayerManager: Cannot find BotTemplate in ReplicatedStorage. No bots will be spawned.")
        return {}
    end

    for i = 1, count do
        local newBot = botTemplate:Clone()
        newBot.Name = "Bot" .. i

        -- Position the bot before parenting to avoid physics issues
        local spawnCFrame = CFrame.new(math.random(-50, 50), 5, math.random(-50, 50))
        newBot:SetPrimaryPartCFrame(spawnCFrame)

        newBot.Parent = Workspace

        table.insert(activeBots, newBot)

        -- Initialize health for the new bot
        HealthManager.initializeHealth(newBot)

        -- Start the movement logic for the newly spawned bot
        SimulatedPlayerManager.startRandomMovement(newBot)
    end

    print(string.format("Finished spawning %d bots.", #activeBots))
    return activeBots
end

local PathfindingService = game:GetService("PathfindingService")

---
-- Starts a movement loop for a single bot, causing it to wander randomly.
-- @param botModel The model of the bot to move.
function SimulatedPlayerManager.startRandomMovement(botModel)
    local humanoid = botModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("SimulatedPlayerManager: Bot model " .. botModel.Name .. " has no Humanoid.")
        return
    end

    local playableArea = Workspace:FindFirstChild("PlayableArea")
    if not playableArea then
        warn("SimulatedPlayerManager: Cannot find PlayableArea part in Workspace. Bots will not move.")
        return
    end

    -- Use a coroutine to allow each bot to have its own movement loop
    -- without blocking the main thread.
    coroutine.wrap(function()
        while botModel.Parent == Workspace do -- Loop as long as the bot is active
            local areaSize = playableArea.Size
            local areaPos = playableArea.Position

            -- Calculate a random point within the PlayableArea's bounds
            local randomX = areaPos.X + math.random(-areaSize.X / 2, areaSize.X / 2)
            local randomZ = areaPos.Z + math.random(-areaSize.Z / 2, areaSize.Z / 2)
            local randomY = areaPos.Y -- Keep the Y position the same for simplicity
            local destination = Vector3.new(randomX, randomY, randomZ)

            -- Create and compute the path
            local path = PathfindingService:CreatePath()
            path:ComputeAsync(botModel.HumanoidRootPart.Position, destination)

            if path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()

                -- Move to each waypoint in the path
                for _, waypoint in ipairs(waypoints) do
                    -- Check if the bot still exists before moving
                    if not botModel.Parent then break end

                    humanoid:MoveTo(waypoint.Position)
                    humanoid.MoveToFinished:Wait() -- Wait until the bot reaches the waypoint
                end
            else
                -- If path fails, wait a bit before trying again
                task.wait(2)
            end

            -- Small delay to prevent overly frequent pathfinding requests if a bot gets stuck
            task.wait(0.5)
        end
    end)()
end

return SimulatedPlayerManager