# Changelog

This document tracks the major features and bug fixes implemented in the Gemi-DNF project during our session.

## Version 6.3.0
- **Major Feature: Survivor Items & Debug Tools**
  - **Item Implementation:** Implemented the full server-side logic and client-side effects for four new survivor items:
    - **Med-kit:** Restores 50 HP. Correctly updates the client's health bar by using the centralized `HealthManager`.
    - **Active Cola:** Provides a temporary speed boost. The item is consumed with no effect if the survivor is in the "Downed" state.
    - **Hammer:** Now has dual functionality. It can be used to rescue a teammate from a hanger at a distance, and also allows a survivor to rescue themselves from a hanger.
    - **Smoke Bomb:** Creates a visual smoke cloud that applies a temporary blindness effect to any Killer who enters its radius.
  - **Debug Buttons:** Added a new, refactored set of debug buttons to the client UI for Survivors, allowing testers to easily grant themselves any of the new items.
- **Critical Bug Fix: "Downed" State Logic**
  - Fixed a critical bug where a survivor would remain in the "Downed" state (slowed and grab-able) even after being healed to full health.
  - The fix involved creating a new, dedicated client-side controller (`DownedStateController.client.lua`) to correctly manage the visual state of being downed and a new server-to-server event system to ensure all server modules are aware of health changes.

## Version 6.2.2
- **Major Feature: Complete "Killer Hanger" Gameplay Loop**
  - Implemented the full gameplay loop for the killer's primary mechanic:
    1.  **Downed State:** Survivors now enter a "Downed" state with reduced speed when their health is low.
    2.  **Grab & Carry:** The killer can now grab a downed survivor with [F], carry them, and drop them with [F].
    3.  **Hanging:** The killer can hang a carried survivor on a hanger with [E], which triggers the tiered elimination timer.
    4.  **Rescue:** Healthy survivors can rescue a teammate from a hanger by approaching them and pressing [E].
- **Critical Bug Fixes & Refactoring**
  - **UI & Input System:** Overhauled the client-side control scripts to resolve numerous bugs where UI prompts were incorrect, flickering, or missing, and input was unresponsive. Killer and Survivor controls are now isolated and team-aware.
  - **Server-Side Stability:** Fixed multiple server crashes and race conditions, including a critical bug in the caging timer that caused premature eliminations. Server-side logic is now more robust with decoupled modules and idempotent initialization.
  - **Physics & Movement:** Permanently resolved a persistent physics bug that restricted the killer's movement. The final solution makes the carried survivor's limbs `Massless` to prevent any physics interference.

## Version 6.1.10
- **Bug Fix: Resolved Multiple Gameplay Regressions**
  - **Machine/NPC Collision:** Machines and the Store Keeper are now solid and can no longer be walked through. The `CanCollide` property is now correctly set on their PrimaryPart when they are spawned.
  - **Universal Escape UI:** The escape sequence UI (screen crack effect) is now correctly displayed for all players, including the Killer. The server now fires the `EscapeSequenceStarted` event to all clients, not just survivors.
  - **Killer Machine Interaction:** Killers can no longer interact with or repair machines. A server-side check was added to the `MachineFixed` event to ensure the action is only performed by players on the "Survivors" team.
  - **Time Bonus Fix:** The "+5 sec" time bonus for repairing a machine is now correctly applied to the round timer and a notification is displayed on the HUD. This fixed a race condition and a duplicate event listener that was preventing the bonus from working as intended.

## Version 4.4.1
- **Bug Fix: All Spawned Objects "Half-Buried"**
  - Corrected the spawning logic for every object type in the game (Players, Killers, Machines, Hangers, Coin Stashes, Store Keepers, and Victory Gates).
  - The code now correctly calculates a vertical offset based on each object's height, ensuring their models rest perfectly on top of the ground instead of clipping through it.

## Version 4.4.0
- **Major Feature: Custom Map and Designated Spawn System**
  - **Replaced Procedural Generation:** The entire procedural map generation system in `MapGenerator.lua` was replaced. The game now relies on the user to create a custom map model in Roblox Studio and place it in `ServerStorage/Maps`.
  - **Implemented Designated Spawning:** Created a new, robust system (`PotentialSpawns`) where the game logic reads spawn locations from a folder of marker parts inside the user's custom map model.
  - **Refactored All Spawning Logic:** Systematically updated all relevant scripts (`GameManager`, `CoinStashManager`, `StoreKeeperManager`) to remove all forms of random coordinate generation and use the new designated spawn point system. This ensures all objects now spawn exactly where the user places their markers.

## Version 3.5.0
- **Feature: Restored and Enhanced Escape Sequence**
  - **Restored Pathfinding Arrow:** Completely rewrote the `EscapeUIController` to remove a non-functional single-arrow system and restore the original, superior four-arrow `PathfindingService` implementation.
  - **Intelligent Gate Selection:** The arrow system is now "intelligent," meaning it calculates the path to all active gates and directs the player along the route with the shortest *walkable distance*, not just the shortest straight-line distance.
  - **Intuitive Arrow Direction:** The arrow logic was rewritten to be intuitive from the player's perspective. The arrows now correctly guide the player "forward" (Up), "backward/turn around" (Down), "left," and "right" relative to the camera's view on a horizontal plane.
  - **Dynamic Waypoint Targeting:** Fixed a critical bug where the arrow would point in the opposite direction when moving. The system now dynamically targets the *next* waypoint in the path as the player progresses, ensuring the guidance is always accurate.
  - **Robust Gate Spawning:** Replaced the Victory Gate spawning logic with a robust system that uses map bounding boxes, insetting, and downward raycasting. This ensures gates are always placed in reachable locations on the ground and away from the outer walls.
- **Bug Fix: Client Crash**
  - Resolved a client-side crash in the `EscapeUIController` caused by a function being called before it was defined.
- **Quality of Life: Increased Escape Time**
  - Increased the `VICTORY_GATE_TIMER` from 15 to 30 seconds to allow for easier testing and balancing.

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
