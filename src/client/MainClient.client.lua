--!nonstrict
--[[
    MainClient.client.lua
    by Jules

    This script is the main entry point for client-side logic.
    It initializes all necessary client-side modules.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the modules folder and the manager to be replicated
local MyModules = ReplicatedStorage:WaitForChild("MyModules")
local MiniGameManager = MyModules:WaitForChild("MiniGameManager")
local StoreClient = require(script.Parent:WaitForChild("StoreClient"))

-- Require and initialize the Mini-Game Manager
require(MiniGameManager).init()

-- Initialize the Store Client
StoreClient.init()

print("Client systems initialized.")
