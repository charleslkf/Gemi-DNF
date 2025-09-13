# Agent Guidelines for Gemi-DNF Project

This document contains a set of rules and guidelines to follow during the development of this project. These are based on previous interactions and are meant to prevent repeated mistakes.

## 1. Rojo Configuration (default.project.json)
- **Filename:** The project file must be named `default.project.json`.
- **Ignoring Instances:** To prevent Rojo from deleting instances in the Studio (like Terrain), use `"$ignoreUnknownInstances": true` on the relevant node (e.g., Workspace). Do not use the `$ignore` property.
- **Map Generation:** All map elements (Baseplate, walls, interactables, etc.) must be created programmatically by the `ServerScriptService/MapBuilder.server.lua` script. Do not use `.model.json` files for map parts.

## 2. Versioning
- **version.md:** A `version.md` file exists in the root directory.
- **Increment on Submit:** For every submission (`submit` tool call), the version number in this file must be incremented (e.g., from `1.0.3` to `1.0.4`).

## 3. Communication
- **Acknowledge User Input:** Always acknowledge user requests and feedback with the `message_user` tool before creating a new plan.
- **Testing Instructions:** Provide clear, step-by-step instructions for testing. Differentiate between client-side and server-side checks.

## 4. General Workflow
- **Verify Changes:** After creating or modifying a file, always use a read-only tool like `read_file` or `ls` to verify the change was applied correctly before marking a plan step as complete.
- **Diagnose Before Acting:** When an error is reported, diagnose the root cause by reviewing logs and file contents before implementing a fix.

## 5. Strategic Pivots
- **Directive is King:** The user's most recent directive always supersedes all previous plans and documentation.
- **Docs First:** When a major strategic pivot occurs, the first priority is to update this `AGENTS.md` file to reflect the new strategy. Code implementation must wait until the documentation is aligned.

## 6. Known System Limitations
- **Branching:** Due to a system restriction, the `submit` tool cannot create new branches. All commits will be added to the existing branch (`gemi-dnf-1`). The `branch_name` parameter is ignored.
