# Agent Guidelines for Gemi-DNF Project

This document contains a set of rules and guidelines to follow during the development of this project. These are based on previous interactions and are meant to prevent repeated mistakes.

## 1. Plan Approval Workflow (MANDATORY)
- **Propose First:** After receiving a new objective, first analyze the request and create a detailed, step-by-step plan.
- **Wait for Approval:** Present this plan to the user. **DO NOT** begin any work (creating files, editing code, etc.) until you receive explicit permission to proceed from the user. This is to prevent wasted work from misunderstandings.

## 2. Rojo Configuration (default.project.json)
- **Filename:** The project file must be named `default.project.json`.
- **Ignoring Instances:** To prevent Rojo from deleting instances in the Studio (like Terrain), use `"$ignoreUnknownInstances": true` on the relevant node (e.g., Workspace). Do not use the `$ignore` property.
- **Map Generation:** All map elements (Baseplate, walls, interactables, etc.) must be created programmatically by the `MapManager.lua` module. This includes mini-game machines, which should be created with a `GameType` attribute (e.g., "ButtonMash", "QTE") to define which mini-game they host for the round.

## 3. Versioning
- **version.md:** A `version.md` file exists in the root directory.
- **Increment on Submit:** For every submission (`submit` tool call), the version number in this file must be incremented.

## 4. Communication
- **Acknowledge User Input:** Always acknowledge user requests and feedback with the `message_user` tool before creating a new plan.
- **Testing Instructions:** Provide clear, step-by-step instructions for testing. Differentiate between client-side and server-side checks.

## 5. General Workflow
- **Verify Changes:** After creating or modifying a file, always use a read-only tool like `read_file` or `ls` to verify the change was applied correctly before marking a plan step as complete.
- **Diagnose Before Acting:** When an error is reported, diagnose the root cause by reviewing logs and file contents before implementing a fix.

## 6. Strategic Pivots
- **Directive is King:** The user's most recent directive always supersedes all previous plans and documentation.
- **Docs First:** When a major strategic pivot occurs, the first priority is to update this `AGENTS.md` file to reflect the new strategy. Code implementation must wait until the documentation is aligned.

## 7. Known System Limitations
- **Branching:** Due to a system restriction, the `submit` tool cannot create new branches. All commits will be added to the existing branch (`gemi-dnf-1`). The `branch_name` parameter is ignored.

## 8. Feature: Mini-Game System (`MiniGameManager.lua`)
This is a client-side `ModuleScript` located in `src/shared`.

### Core Activation
- The module should handle player proximity checks and listen for the 'E' key to activate a machine.
- Upon activation, the client script **must read a `GameType` attribute** from the machine part to determine which game to run. It should not choose a game randomly.
- The '[E] to Interact' prompt text should be blue.

### General Game Flow & Rules
- **Success:** When a mini-game is completed successfully, the machine should display a permanent visual effect (e.g., green light) and become disabled (e.g., via an `IsCompleted` attribute), preventing further interaction. A large, green "SUCCESS" message should be displayed to the player.
- **Attempt Failure:** Failing a single attempt within a mini-game (e.g., clicking the wrong sequence in QTE) should **not** end the game. It should reset the current attempt, allowing the player to try again immediately without losing overall progress.
- **Interruption (Game Failure):** The mini-game must be interrupted and considered a total failure if the player moves too far away. The large, red "FAILURE" message should *only* be shown in this interruption scenario.

### Specific Game Mechanics (Click-Oriented)
- **`startQTE` (Memory Check):** A sequence-clicking game. Must include a round counter.
- **`startButtonMashing`:** A simple click-mashing game. Must include a timer and a click counter.

## 9. Feature: Simulated Player System
This system is designed to facilitate testing by ensuring a minimum number of "players" are in a round.

### Core Components
- **`SimulatedPlayerManager.lua` (`src/shared`):** The core module responsible for spawning, moving, and despawning bot character models.
- **`BotTemplate` (Asset in `ReplicatedStorage`):** A standard R6 model that is cloned to create new bots. This must be created manually in Studio.
- **`PlayableArea` (Asset in `Workspace`):** A transparent, non-collidable Part that defines the boundaries for bot movement. This must be created manually in Studio.
- **`LobbyManager.server.lua` (`src/server`):** The integration point. This script now handles the bot lifecycle.

### Gameplay Integration
- **Spawning:** At the start of a round, the `LobbyManager` will check the number of real players. If the count is below the `MIN_PLAYERS` config variable (e.g., 5), it will call `SimulatedPlayerManager.spawnSimulatedPlayers()` to create enough bots to meet the minimum.
- **Team Assignment:** All spawned bots are automatically considered part of the "Survivors" team for win condition checks.
- **Functionality:** Bots are damageable and can be caged and eliminated just like real players. Their elimination correctly contributes to the Killer's Ultimate Ability counter.
- **Despawning:** All bots are automatically destroyed when the game returns to the "Waiting" state at the end of a round.
