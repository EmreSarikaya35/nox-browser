# Spirit Quest: The Forgotten Shrine

A fully offline 2D pixel-art RPG written to be embedded in a web browser. Sumire wakes up in an abandoned shrine with
no memory and recovers her past by gathering forgotten spirits.

- 4 connected areas: Forgotten Shrine, Whispering Forest, Silent Village, Moon Sanctuary
- 10 collectible spirits (each with a real gameplay effect), 4 memories, 3 endings
- 9 quests (main, side, hidden, spirit, memory), 17 items, 10 achievements
- 4 puzzles: lantern order, rune stones, fox tracks, moon phases (a hint appears after two wrong attempts)
- Simple combat (the spirit bell) and one boss, who can also be talked down
- Automatic and manual saving, corrupted-save recovery, settings

The game is in Turkish.

## Technology and deliberate choices

No dependencies and no build step: plain JavaScript (ES modules), HTML5 Canvas and CSS.

- **No game engine or TypeScript.** The game is embedded in a browser with no network access; a few hundred lines of
  custom loop are lighter than a build chain plus a ~1 MB engine (which matters on older Intel Macs) and can be copied
  as is. That is why there is no `package.json` or `tsconfig.json`.
- **No image files.** The character, spirits, tiles, icons and portraits are drawn in code at startup in
  `src/art/sprites.js` (original pixel art). No separate PNG sprite sheets were produced.
- **No audio files.** Music and effects are synthesized with Web Audio in `src/audio.js`. Nothing is licensed from elsewhere.
- **Saves use `localStorage`** rather than IndexedDB: synchronous, small (a few KB) and reliable in WKWebView. Every
  save is written with a checksum and the previous good save is kept as a backup.

## Running (development / offline testing)

ES modules do not load over `file://`, so serve the folder with any local server:

```bash
python3 -m http.server 8770 --bind 127.0.0.1
```

Then open `http://localhost:8770/`. No internet connection is needed. The "production build" is this folder itself:
`index.html`, `style.css`, `src/`.

## Controls

| Key | Action |
|---|---|
| WASD / arrow keys | Move (four directions) |
| E or Enter | Interact, advance dialogue |
| Space | Spirit bell (damages nearby shadows) |
| I / J / M | Inventory / Journal / Map |
| Esc | Pause, back in menus |
| In menus | Arrow keys + Enter; 1–9 for choices |

## Folder structure

| Path | Contents |
|---|---|
| `src/main.js` | Entry point, scaling, main loop, scene transitions |
| `src/config.js`, `src/input.js` | Constants, keyboard |
| `src/save.js` | Saving, validation, backup, settings |
| `src/audio.js` | Synthesized music and effects |
| `src/art/sprites.js` | All pixel art |
| `src/data/` | Spirits, items, quests, achievements |
| `src/world/maps.js` | Maps of the four areas and every script (dialogue, puzzles, story) |
| `src/world/world.js` | Map runtime: collision, drawing, atmosphere |
| `src/systems/combat.js` | Enemies and the boss |
| `src/scenes/` | Game scene, title and ending backdrop |
| `src/ui/` | Dialogue box and menus |

Editing maps: each map in `maps.js` is a 40×24 character grid; the meaning of each character is documented at the top
of the file. The game logs a console warning if a row has the wrong length.

## Saving

- Automatic: on area transitions, on gaining a spirit or memory, on solving a puzzle and when the page is hidden.
- Manual: stone statues (which also restore health and become the respawn point) and Pause → Save.
- Keys: `spiritquest.save`, `spiritquest.save.bak`, `spiritquest.settings`.
- After an ending the save returns to just before the final choice, so the other endings can be seen.

## Embedding in WKWebView (macOS)

This is how the game is embedded in NOX Browser; the same approach works for any other browser:

1. Add the folder to the app bundle as a **folder reference** (`Resources/SpiritQuest/`).
2. Use a custom URL scheme instead of `file://` (for example `nox://game/index.html`): serve the files from the bundle
   with a `WKURLSchemeHandler`, send `Content-Type: text/javascript` for `.js`, and reject paths that escape the folder.
   Modules then load and saves are tied to a stable origin. Example: `NOX/GameSchemeHandler.swift`.
3. Optionally add a `WKScriptMessageHandler` named `spiritQuest`. When "Return to browser" is chosen the game posts
   `window.webkit.messageHandlers.spiritQuest.postMessage('exit')`. Without it the game tries `history.back()` and
   otherwise returns to its own main menu.
4. For saves to persist, the web view must use a persistent `WKWebsiteDataStore` (nothing is kept in a private tab).

The game makes no network requests, loads no external resources and relies on no API missing from WKWebView.

## Performance and battery

- 480×270 canvas with whole-pixel scaling; every drawing is generated once and cached.
- At most 36 particles; the "Reduce effects" setting turns off fog, screen shake and most particles.
- When the tab is hidden the browser stops the draw loop; the game also stops audio and the music timer.

## Test status

Tested with a script in a browser and with a real keyboard inside NOX: startup, new game, continue, walking and
collision, loading and transitions of all four maps, reachability of every interaction on every map, all NPC dialogue
and choices, 9 quests, inventory, collecting all 10 spirits, the four puzzles (including wrong order and hints),
enemies, the boss fight, defeat and respawn, talking the Guardian down, the "Keeper" ending, saving and loading (page
reload and app restart), the pause menu and keyboard navigation.

Not yet tested: audio balance, the fullscreen button, the effect of the settings sliders, the screens of the "Dawn" and
"Purple Moon" endings, the corrupted-save recovery path, difficulty balance over a long session.

---

[Türkçe README](README.tr.md)
