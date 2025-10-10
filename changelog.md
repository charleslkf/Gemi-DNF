# Changelog

This document tracks the major features and bug fixes implemented in the Gemi-DNF project during our session.

## Version 3.4.21
- **Critical Bug Fix: Client Crash on Escape:**
  - Fixed a typo (`GetLenth` -> `GetLength`) in `EscapeUIController.client.lua` that was causing the script to crash when calculating the path to the nearest victory gate. The directional arrow now functions correctly.

## Version 3.4.20
- **Critical Bug Fix: Directional Arrow Not Appearing:**
  - Fixed a bug where the escape sequence directional arrow was not appearing. The client-side `EscapeUIController` was reset in a previous step and was not correctly handling the gate name data being sent from the server.
  - The script has been updated to correctly look up the gate parts by name and re-implements the full pathfinding and four-arrow UI logic.

## Version 3.4.19
- **Architectural Refactor: Intelligent Spawning System**
  - Replaced all previous spawning systems with a new, authoritative `IntelligentSpawnManager`.
  - This new manager works in two phases for maximum reliability:
    1.  **Broad-phase Scan:** It first scans the map using a fine-grained grid to find all potential empty spaces, correctly ignoring the floor, baseplate, and bot navigation areas.
    2.  **Narrow-phase Check:** When an object is spawned, it performs a final, precise collision check using the object's actual size plus a "padding" buffer to ensure it fits perfectly and does not spawn too close to walls.
- **Full Integration and Cleanup:**
  - All relevant managers (`GameManager`, `CoinStashManager`, `StoreKeeperManager`) have been refactored to use this new, intelligent system.
  - All old, faulty spawning modules have been completely removed from the project.
- **Bug Fixes:**
  - Fixed a critical typo in the `MapGenerator` that was causing it to crash.
  - Hardened the `GameManager` to exclusively load the procedural map, preventing any future map-loading bugs.
  - Fixed a race condition in the spawning system that was causing it to fail intermittently.
  - Fixed a crash that occurred when spawning players due to incorrect handling of `Part` objects.

## Version 3.4.17
- **Project Cleanup:**
  - Reset `EscapeUIController.client.lua` and `MiniGameManager.lua` to their original state to create a clean, focused commit for the spawning system fixes.
- **Critical Bug Fix: Deterministic Map Loading:**
  - Replaced the random map selection logic in `GameManager` with a new `loadProceduralMap` function.
  - This function now exclusively loads the "GeneratedProceduralMap", removing all ambiguity and guaranteeing that the correct map with the maze walls is always used. This resolves the persistent issue of the wrong map being loaded.

## Version 3.4.16
- **Critical Bug Fix: Map Generation Crash:**
  - Fixed a typo in `MapGenerator.server.lua` that was causing the script to crash and preventing the procedural map from being created. The script now correctly references the `MAP_CONFIG` table, resolving the error.

## Version 3.4.15
- **Architectural Refactor: Pre-defined Spawning System**
  - Replaced the previous dynamic spawning system with a new, authoritative `SpawnDataManager` module. This module uses hard-coded lists of `Vector3` coordinates to guarantee that all players and objects spawn in valid, developer-approved locations.
  - All relevant managers (`GameManager`, `CoinStashManager`, `StoreKeeperManager`) have been refactored to use this new, deterministic system.
- **Feature: Procedural Map Generation**
  - Added a `MapGenerator.server.lua` script that runs on startup to create a new, complex map layout featuring a maze of inner walls and four large, enclosing boundary walls.
  - The `GameManager` has been updated to exclusively load this new procedural map, ensuring a consistent gameplay experience.
- **Bug Fixes and Cleanup**
  - Fixed a client-side crash in the `EscapeUIController` by ensuring the server sends the correct data type.
  - The old, faulty `SpawnPointManager` has been completely removed from the project.

## Version 3.4.13
- **Critical Bug Fix: Spawning Race Condition:**
  - Fixed the definitive root cause of the spawning failures. A race condition was causing the `SpawnPointManager` to look for the "PlayableArea" part before it was created. The logic has been updated to find the "PlayableArea" at the time of use, guaranteeing it exists and resolving the "Found 0 potential spawn points" error.

## Version 3.4.12
- **Critical Bug Fix: Definitive Spawning Fix:**
  - The `SpawnPointManager` now correctly ignores the invisible "PlayableArea" used for bot navigation during its initial scan. This was the final root cause of the "Found 0 potential spawn points" error, and all objects should now spawn reliably.

## Version 3.4.11
- **Critical Bug Fix: Deterministic Map Loading:**
  - Replaced the random map selection logic in `GameManager` with a new `loadProceduralMap` function.
  - This function now exclusively loads the "GeneratedProceduralMap", removing all ambiguity and guaranteeing that the correct map with the maze walls is always used. This resolves the persistent issue of the wrong map being loaded.

## Version 3.4.10
- **Critical Bug Fix: Spawn Point Generation:**
  - Fixed the true root cause of the "Found 0 potential spawn points" error. The initial scan in `SpawnPointManager` was not correctly ignoring the map's floor, causing it to find no valid locations. The logic has been patched to correctly filter out the floor, ensuring a valid list of spawn points is generated.

## Version 3.4.9
- **Architectural Refactor: Deterministic Spawning System:**
  - Replaced the old, unreliable random spawning utility with a new, authoritative `SpawnPointManager`.
  - This new manager scans the map once at the start of each round to generate a list of all possible spawn locations.
  - When an object needs to be placed, the manager now performs a final, precise collision check using the object's actual size, guaranteeing a perfect fit and preventing clipping into walls.
  - All relevant managers (`GameManager`, `CoinStashManager`, `StoreKeeperManager`) have been refactored to use this new, robust system.
- **Cleanup:**
  - The old `SafeSpawnUtil.lua` has been completely removed from the project.

## Version 3.4.8
- **Critical Bug Fix: Spawning Logic Root Cause:**
  - Fixed the true root cause of the spawning failures. The collision check in `SafeSpawnUtil.lua` now correctly ignores both the map's floor and the invisible "PlayableArea" used for bot navigation, which was the final unseen obstacle. All objects should now spawn reliably.

## Version 3.4.7
- **Critical Bug Fix: Spawning Logic:**
  - Fixed a fundamental flaw in `SafeSpawnUtil.lua` where the collision check was incorrectly detecting the map's floor as an obstacle. The logic now correctly ignores the floor by manually removing it from the detected parts list, allowing all objects to spawn reliably.

## Version 3.4.6
- **Critical Bug Fix: Client Crash on Escape:**
  - Fixed a crash in the `EscapeUIController` by modifying `GameManager` to send a table of gate *names* (strings) to the client instead of gate *instances*.
- **Critical Bug Fix: Spawning Failures:**
  - Resolved an issue where `SafeSpawnUtil` would always fail to find a spawn location. The collision check now correctly ignores the map's floor, preventing false positives.
- **Bug Fix: Victory Gate Placement:**
  - The Victory Gates are no longer spawned randomly. They are now deterministically placed on opposite (North and South) edges of the map to meet the design requirement.

## Version 3.4.5
- **Critical Bug Fix: Spawning Crash:**
  - Fixed a crash in `SafeSpawnUtil.lua` that occurred when trying to spawn simple `Part` objects like the Victory Gate. The collision check was updated to use `GetPartBoundsInBox`, which is more robust and does not require a `PrimaryPart`.
- **Critical Bug Fix: Incorrect Map Loading:**
  - Corrected a regression in `GameManager.server.lua` that caused the old "Map1" to be loaded instead of the new procedural map. The logic to filter out "Map1" has been restored.

## Version 3.4.2
- **Feature: Dynamic Pathfinding Arrow:**
  - Implemented a smart directional arrow in `EscapeUIController.client.lua` to guide Survivors to the nearest Victory Gate.
  - The system uses `PathfindingService` to compute a path that avoids obstacles.
  - The path is dynamically recalculated every second in a non-blocking thread (`task.spawn()`) to provide accurate, real-time directions as the player moves.
  - Replaced the single rotating arrow with a more robust four-arrow system, which uses verified Texture IDs and stable screen-edge positioning to prevent visual bugs.
- **Bug Fix: Killer Machine Interaction:**
  - Added team checks to `MiniGameManager.lua` to prevent players on the "Killers" team from seeing interaction prompts on or activating mini-game machines.
- **Bug Fix: UI Not Persisting After Round:**
  - Fixed a bug where the directional arrow would remain on screen after the escape sequence ended. The `GameStateChanged` event handler now correctly cleans up all arrow UI elements.
- **Quality of Life: Removed UI Delay:**
  - Removed a 2-second `task.wait()` from `GameManager.server.lua` to ensure the escape sequence UI effects (like the screen crumbling) begin immediately when the last machine is fixed.

## Version 2.3.0
- **Feature: World Management System**
  - Created a new `WorldManager.server.lua` script to handle loading and unloading pre-made map assets from `ServerStorage`.
  - Integrated the `WorldManager` into the `GameManager` to load a random map at the start of each round.
- **Bug Fix: Random Map Selection**
  - Fixed a bug where the same map was being loaded every round by properly seeding the random number generator.
- **Architectural Refactor: Finalized GameManager**
  - Completed the major refactor by consolidating all game loop, lobby, world, and test asset creation logic into the `GameManager`.
  - This resolved all outstanding startup crashes and synchronization issues, resulting in a stable and robust game loop.

## Version 2.2.5
- **Major Refactor: GameManager**
  - Centralized the entire game loop logic into a new, authoritative `GameManager.server.lua` script.
  - This refactor establishes a single source of truth for game state, improving stability and scalability.
- **Bug Fix: Startup Crash & Sync Issues**
  - Resolved a critical startup crash caused by circular dependencies and script synchronization problems by creating a new `LobbyUtils` module and neutralizing old, conflicting scripts.
- **Bug Fix: Manual Start Button**
  - The "Manual Start" button is now fully functional and correctly managed by the `GameManager`.
- **Bug Fix: Bot Movement**
  - The logic to create the `PlayableArea` and `BotTemplate` assets was moved into the `GameManager` to ensure bots can always navigate correctly.

## Version 2.1.0
- **Feature: Cumulative Ultimate Ability**
  - Added a visible "Kills" leaderstat for the Killer.
  - The ultimate ability now triggers every 3 kills (3, 6, 9, etc.) based on this new cumulative stat.
- **Bug Fix:** Corrected the ultimate ability's visual (red glow) and audio effects to ensure they play reliably.
- **Bug Fix:** Resolved a server error that occurred when a player disconnected.
- **Quality of Life:** Increased the round duration to 3 minutes for easier testing.

## Version 2.0.6
- **Feature: Fully Integrated & Damageable Bots**
  - Bots are now fully integrated into the game loop, spawning at the start of a round and despawning at the end.
  - Bots can be damaged, caged, and eliminated, and their elimination correctly counts towards the Killer's score.
- **Bug Fix:** Fixed multiple bugs related to the bot system, including issues with health bar visibility, damage calculation, win condition checks, and the "Rescue" UI prompt.
- **Cleanup:** Removed the old, temporary test scripts for the bot system.

## Version 2.0.1
- **Feature: Automated Bot Testing System**
  - Created a `SimulatedPlayerManager` to handle the spawning, pathfinding-based movement, and despawning of simulated players.
  - Added scripts to automatically generate the necessary test assets (`BotTemplate` and `PlayableArea`) so no manual setup is required.

## Pre-2.0.0
- **Critical Bug Fix: Duplicate Health Bar**
  - Investigated and resolved a long-standing issue with a duplicate health bar appearing on the HUD. This involved several steps, including neutralizing a "ghost script" that was running despite being excluded from the build.
- **Feature: Billboard Health Bars**
  - Replaced the original 2D HUD health bar with a 3D billboard UI that floats above each player's head and is visible to all other players.
- **Documentation:** Updated `AGENTS.md` to document the new bot system.