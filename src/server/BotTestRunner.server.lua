--[[
    BotTestRunner.server.lua

    This script runs an automated test of the SimulatedPlayerManager module
    to verify its functionality.
]]

-- Configuration
local BOTS_TO_SPAWN = 5
local DESPAWN_TIMER_SECONDS = 120 -- 2 minutes

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the modules to be replicated and assets to be created
local MyModules = ReplicatedStorage:WaitForChild("MyModules")
local SimulatedPlayerManager = require(MyModules:WaitForChild("SimulatedPlayerManager"))

-- Give the game a moment to load before starting the test
task.wait(5)

print("--- Starting Automated Bot Test ---")

-- Test spawning bots
print(string.format("Spawning %d bots...", BOTS_TO_SPAWN))
local spawnedBots = SimulatedPlayerManager.spawnSimulatedPlayers(BOTS_TO_SPAWN)
print("Spawned " .. #spawnedBots .. " bots.")

-- Let them wander around for a while to test movement
print(string.format("Bots will now wander for %d seconds...", DESPAWN_TIMER_SECONDS))
task.wait(DESPAWN_TIMER_SECONDS)

-- Test despawning the bots
print("Despawning all bots...")
SimulatedPlayerManager.despawnSimulatedPlayers()

print("--- Automated Bot Test Finished ---")