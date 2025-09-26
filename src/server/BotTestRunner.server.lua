--[[
    BotTestRunner.server.lua

    This script runs an automated test of the SimulatedPlayerManager module
    to verify its functionality.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the modules to be replicated and assets to be created
local MyModules = ReplicatedStorage:WaitForChild("MyModules")
local SimulatedPlayerManager = require(MyModules:WaitForChild("SimulatedPlayerManager"))

-- Give the game a moment to load before starting the test
task.wait(5)

print("--- Starting Automated Bot Test ---")

-- Test spawning 5 bots
print("Spawning 5 bots...")
local spawnedBots = SimulatedPlayerManager.spawnSimulatedPlayers(5)
print("Spawned " .. #spawnedBots .. " bots.")

-- Let them wander around for a while to test movement
print("Bots will now wander for 30 seconds...")
task.wait(30)

-- Test despawning the bots
print("Despawning all bots...")
SimulatedPlayerManager.despawnSimulatedPlayers()

print("--- Automated Bot Test Finished ---")