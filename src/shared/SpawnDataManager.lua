--[[
    SpawnDataManager.lua
    by Jules

    This module provides authoritative, hard-coded lists of spawn points for all
    dynamic objects and players in the game. This deterministic approach
    replaces the previous, unreliable dynamic scanning systems.
]]

local SpawnDataManager = {}

-- All spawn points are defined as Vector3 coordinates.
-- The map is 300x300, so coordinates are generally within [-140, 140].
-- The Y-coordinate is kept consistent for ground-level objects.

SpawnDataManager.MachineSpawns = {
    Vector3.new(-100, 0, -100),
    Vector3.new(100, 0, 100),
    Vector3.new(-50, 0, 120),
    Vector3.new(130, 0, -40),
    Vector3.new(0, 0, 0),
    Vector3.new(75, 0, -80),
    Vector3.new(-90, 0, 60),
    Vector3.new(40, 0, 140),
    Vector3.new(-135, 0, -135),
    Vector3.new(135, 0, 135),
    Vector3.new(0, 0, -120)
}

SpawnDataManager.CoinStashSpawns = {
    Vector3.new(-120, 0, 0),
    Vector3.new(120, 0, 0),
    Vector3.new(0, 0, -120),
    Vector3.new(0, 0, 120),
    Vector3.new(-80, 0, -80),
    Vector3.new(80, 0, 80),
    Vector3.new(-80, 0, 80),
    Vector3.new(80, 0, -80),
    Vector3.new(-30, 0, -30),
    Vector3.new(30, 0, 30),
    Vector3.new(-30, 0, 30),
    Vector3.new(30, 0, -30),
    Vector3.new(-140, 0, 50),
    Vector3.new(140, 0, -50),
    Vector3.new(50, 0, -140)
}

SpawnDataManager.StoreKeeperSpawns = {
    Vector3.new(0, 0, 75),
    Vector3.new(75, 0, 0),
    Vector3.new(0, 0, -75),
    Vector3.new(-75, 0, 0),
    Vector3.new(90, 0, 90)
}

SpawnDataManager.SurvivorSpawns = {
    Vector3.new(-110, 5, -110),
    Vector3.new(110, 5, 110),
    Vector3.new(-60, 5, 110),
    Vector3.new(120, 5, -50),
    Vector3.new(10, 5, 10),
    Vector3.new(65, 5, -90),
    Vector3.new(-80, 5, 50),
    Vector3.new(30, 5, 130),
    Vector3.new(-125, 5, -125),
    Vector3.new(125, 5, 125),
    Vector3.new(10, 5, -110)
}

SpawnDataManager.KillerSpawns = {
    Vector3.new(-140, 5, 140),
    Vector3.new(140, 5, -140)
}

return SpawnDataManager