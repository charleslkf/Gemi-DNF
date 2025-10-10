# Changelog

This document tracks the major features and bug fixes implemented in the Gemi-DNF project during our session.

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