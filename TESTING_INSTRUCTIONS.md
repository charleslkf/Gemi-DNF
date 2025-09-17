# Testing Instructions for Version 1.6.7

This document provides a comprehensive test plan for the final, complete implementation of the Killer gameplay features.

---

### Test Setup:
*   Start a test server with **two players**.
*   **Player1** will be the **Killer**.
*   **Player2** will be the **Survivor**.
*   It's helpful to have the **Output log** visible for both the client and server to see the print messages.

---

### Part 1: HUD and Basic Attack Test

1.  **Start the Round:** As either player, click the "Manual Start" button.
2.  **Check the HUD:**
    *   On the **Killer's screen (Player1)**, confirm there are **NO** item boxes at the bottom.
    *   On the **Survivor's screen (Player2)**, confirm the two empty `[Empty]` item boxes **ARE** visible.
3.  **Test Normal Attack:**
    *   As the Killer, walk up to the Survivor and click them anywhere on their character (including head/accessories).
    *   **Expected Result:** The Survivor's health should drop to 75. The server log should show a validated attack.
4.  **Test Cooldown:**
    *   Immediately click the Survivor again (within 5 seconds).
    *   **Expected Result:** Nothing should happen. The server log should print an "Attack blocked: ... is on cooldown" message.
5.  **Test Caging:**
    *   After the 5-second cooldown, hit the Survivor two more times. Their health should drop to 25, and they should be placed in a cage with a 30-second timer.
6.  **Test Attack on Caged Player:**
    *   While the Survivor is in the cage, try to hit them again.
    *   **Expected Result:** Nothing should happen. The server log should print an "Attack blocked: ... is already caged" message.

---

### Part 2: Ultimate Ability Test

**Setup for Easier Testing (Optional but Recommended):**
*   Open the script `src/shared/KillerAbilityManager.module.lua`.
*   On line 18, change `local ELIMINATIONS_FOR_ULTIMATE = 3` to `local ELIMINATIONS_FOR_ULTIMATE = 1`.
*   This will make the ultimate trigger after only **one** elimination.

**Testing the Ultimate:**
1.  **Get an Elimination:** As the Killer, hit the Survivor four times to bring their health to 0. This will count as one elimination.
2.  **Check for Ultimate:**
    *   **Expected Result:** As soon as the Survivor is eliminated, the Killer's character should start glowing with a **red trail** and you should hear a **menacing sound**. The server log will print `Triggering ULTIMATE for Player1!`.
3.  **Wait for Respawn:** Wait for the Survivor to respawn and run back to the Killer.
4.  **Test Ultimate Hit:**
    *   While the ultimate is active (within the 10-second window), hit the full-health Survivor just **once**.
    *   **Expected Result:** The Survivor should be instantly eliminated. The server log will show a message like `Player1 used their ultimate to eliminate Player2!`. The `EliminationEvent` should fire, and the Killer's elimination count should now be 1.
5.  **Check Deactivation:**
    *   If you don't use the ultimate hit, simply wait 10 seconds.
    *   **Expected Result:** The red trail and sound on the Killer should disappear. If you hit a Survivor now, it should only do 25 damage again.

---

This covers all the new functionality. Please follow these steps and let me know the results. I am confident this version is correct.
