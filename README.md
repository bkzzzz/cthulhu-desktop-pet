# Cthulhu Desktop Pet
<img width="1535" height="1024" alt="thumbNail" src="https://github.com/user-attachments/assets/5c19f2e7-81bb-4918-98df-47ea5af27b8d" />

> Built for OpenAI Build Week using GPT-5.6 and the OpenAI Codex extension.

Cthulhu Desktop Pet is a Lovecraft-inspired desktop pet idle game.

Raise mysterious creatures that live on your desktop, grow your cult, attract devoted followers, and defend your desktop against waves of enemies.

The more followers you gather, the stronger your cult becomes.

**Can your cult conquer the universe... starting from your desktop?**

---

## Features
- 👾 Collect creepy desktop pets
- ⚔️ Defend your desktop in real-time battles
- 🙏 Gather Faith and attract devoted followers
- 🥚 Unlock new pets through progression and gacha
- 🖥️ Native Windows desktop pet experience
<img width="1032" height="626" alt="inventoryPic" src="https://github.com/user-attachments/assets/97a72a21-9000-4ce7-9797-d1abde47e51f" />

<img width="749" height="171" alt="desktopPic" src="https://github.com/user-attachments/assets/3b2e79eb-3cbf-4fe7-9f8c-d1c5dff18dbf" />

<img width="1023" height="120" alt="workplacePic2" src="https://github.com/user-attachments/assets/563a2ac8-4cd2-4be9-847b-b7f59c2cf3be" />

---
# How Codex was used

During OpenAI Build Week, I developed the game in Godot 4 using Visual Studio Code with the official OpenAI Codex extension and GPT-5.6.

Codex was part of my daily development workflow. I relied on it to implement new gameplay systems, prototype mechanics, debug gameplay logic, refactor existing code, and iterate on UI behavior. This made it much easier to experiment with different ideas and immediately test them inside Godot.

During Build Week, the biggest additions included:

- Desktop battle system
- Enemy waves and boss fights
- Pet evolution
- Additional desktop pets
- Progression balancing
- UI improvements
- Overall gameplay polish

This rapid build-test-iterate workflow made it much easier to turn an early prototype into a complete playable game within a single week.

---
## Play

The easiest way to play is through the Windows build on itch.io.

**itch.io**  
https://bkzzzz.itch.io/cthulhu-desktop-pet

**Download the latest Windows build**  
https://github.com/bkzzzz/cthulhu-desktop-pet/releases/latest

> **Note for OpenAI Build Week reviewers:**  
> A built-in **Developer Mode** is available in **Settings** to quickly access late-game content, including stronger pets, evolutions, enemy factions, and boss battles.

---
## Running from Source

### Requirements

- Windows 10 / 11
- Godot 4.x

Run the game:

```powershell
.\run_game.cmd
```

Open in the Godot editor:

```powershell
.\run_game.cmd -Editor
```

Run automated tests:

```powershell
.\run_tests.cmd
```

---

## Project Structure

```
assets/      Sprites, UI, audio and visual effects
scenes/      Godot scenes
scripts/     Gameplay and game logic
tests/       Automated tests
builds/      Windows builds
```
---

## License

Copyright © 2026 Bingkun Ye. All rights reserved.

See the `LICENSE` file for details.
