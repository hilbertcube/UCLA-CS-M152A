# Space Invaders – Architecture Overview

## Block Diagram

```
                        100 MHz board clock
                              │
                         ┌────▼────┐
                         │ clk_div │ → 25 MHz pix_clk
                         │         │ → game_tick (~60 Hz pulse)
                         └─────────┘
                               │ pix_clk
          ┌────────────────────┼────────────────────┐
          │                    │                    │
    ┌─────▼──────┐      ┌──────▼──────┐      ┌─────▼──────┐
    │  vga_sync  │      │ game_logic  │      │  renderer  │
    │            │      │             │      │            │
    │ hcnt, vcnt │      │ player_x    │      │ pix_x,y    │
    │ hsync      │─────▶│ villain_*   │─────▶│ game state │
    │ vsync      │      │ pb_*        │      │ → RGB out  │
    │ video_on   │      │ vb_*        │      └─────┬──────┘
    │ pix_x, y   │      │ lives,score │            │
    └────────────┘      │ game_state  │     ┌──────▼──────┐
                        └─────────────┘     │  villain_rom│
                               │            │  player_rom │
                        ┌──────▼──────┐     │  text_rom   │
                        │ seg7_display│     └─────────────┘
                        │ (score HUD) │
                        └─────────────┘
```

---

## Clock Generation — `clk_div.v`

The Basys3 board provides a 100 MHz clock. Two derived signals are needed:

**25 MHz pixel clock (`pix_clk`)**
VGA 640×480 @ 60 Hz requires a pixel clock of 25.175 MHz. We divide by 4 using a 2-bit counter that toggles `pix_clk` on counts 1 and 3, giving a clean 50% duty-cycle 25 MHz output.

```
100 MHz → ÷4 → 25 MHz pix_clk
```

**Game tick (~60 Hz)**
A 19-bit counter running on `pix_clk` fires a single-cycle pulse every 416,666 pixel clocks:

```
25 MHz / 416,666 ≈ 60 Hz
```

All game state advances once per `game_tick`. Rendering happens every pixel clock (25 MHz), but the game objects only move at 60 Hz.

---

## VGA Sync — `vga_sync.v`

Generates the timing signals that tell a VGA monitor where each pixel is.

**640×480 @ 60 Hz timing:**

| Region | Horizontal | Vertical |
|--------|-----------|----------|
| Visible | 640 px | 480 lines |
| Front porch | 16 | 10 |
| Sync pulse | 96 | 2 |
| Back porch | 48 | 33 |
| **Total** | **800** | **525** |

Two counters (`h_cnt`, `v_cnt`) increment every pixel clock and wrap at 800/525 respectively. The sync pulses are active-low (0 = syncing, 1 = normal).

`video_on` goes high only inside the 640×480 visible area. The renderer outputs black (0,0,0) whenever `video_on` is low — this is what creates the blanking border around the image.

`pix_x` and `pix_y` export the current counter values so the renderer knows which pixel it is drawing right now.

---

## Game Logic — `game_logic.v`

The main state machine. Advances on `game_tick` (~60 Hz). Everything is registered state; combinational collision detection reads the current state and the sequential block updates it one tick later.

### Player
- Position `player_x` (10-bit, clamped to 0..624)
- Moves ±4 px/tick while `btnL`/`btnR` held
- `player_blink` pulses for ~1 s after taking damage (also makes the player invulnerable during that window)

### Villains
- 5 columns × 3 rows = 15 villains, each with an `alive` bit in `villain_alive[14:0]`
- All 15 share a single base position (`villain_base_x`, `villain_base_y`)
- Each villain's screen position is computed from the base plus its column/row offset:
  ```
  vx[i] = villain_base_x + col(i) × 40
  vy[i] = villain_base_y + row(i) × 32
  ```
- The group moves right 2 px/tick until the rightmost column would go off-screen, then reverses direction and moves left
- Three sprite types determined by row: squid (row 0), crab (row 1), octopus (row 2)

### Bullets
**Player bullets (3 slots):** Travel upward at 4 px/tick. Fire on button press into the lowest free slot. Stop at walls or screen top.

**Villain bullets (12 slots):** Travel downward at 4 px/tick. Every 45 ticks (~0.75 s) an LFSR selects up to 3 random living villains to fire. Bullets are assigned to three fixed slot ranges (0–3, 4–7, 8–11) to avoid clobbering each other. Stop at walls, player, or screen bottom.

### Collision Detection
All collision uses AABB (axis-aligned bounding box) overlap: `ax < bx+bw && ax+aw > bx && ay < by+bh && ay+ah > by`.

Collision wires are purely combinational (evaluated every clock cycle from the registered bullet/villain positions). The sequential block acts on them once per `game_tick`.

- Player bullet vs. villain → bullet deactivates, villain `alive` bit cleared, score +10
- Villain bullet vs. player → player blinks (invulnerable) for 60 ticks, lives −1
- Any bullet vs. wall → bullet deactivates (wall is solid)

### LFSR (random villain shooter)
A 16-bit Galois LFSR advances every clock cycle. When a villain volley fires, three 4-bit slices of the LFSR select which villains shoot. This makes the fire pattern feel random without requiring a true RNG.

```
lfsr[15:0] → lfsr[0] = lfsr[15] XOR lfsr[13] XOR lfsr[12] XOR lfsr[10]
```

### Game State Machine
```
PLAY (00) ──[lives == 0]──▶ GAME_OVER (01)
PLAY (00) ──[all villains dead]──▶ WIN (10)
```

---

## Renderer — `renderer.v`

A large purely combinational block. Every pixel clock it receives `pix_x`, `pix_y`, and the full game state, and outputs the 12-bit RGB color for that exact pixel. No registers — it's a giant priority-encoded color selector.

### Priority (highest wins)

1. **Blank** — `video_on` is low → output black
2. **Text overlay** — GAME OVER / YOU WIN banner
3. **Lives HUD** — small ship icons top-right
4. **Player ship** — green, with sprite ROM shape
5. **Player bullets** — white
6. **Villain bullets** — yellow
7. **Shields** — green arch shapes
8. **Villains** — red / purple / cyan by row
9. **Background** — black

### Sprite rendering
For every object with a bitmap shape (player, villains, text), the renderer:
1. Checks if `(pix_x, pix_y)` is inside the object's bounding box
2. Computes the sub-pixel position within the bounding box
3. Looks up the corresponding bit in the sprite ROM
4. ANDs the ROM output with the bounding-box check

For villains, which are displayed at 2× scale (24×16 on screen from a 12×8 ROM), the sub-pixel coordinates are halved before the ROM lookup (`sp_x[4:1]`, `sp_y[3:1]`), so each ROM pixel becomes a 2×2 block.

---

## Sprite ROMs

### `villain_rom.v`
Stores bitmaps for three alien types selected by a compile-time parameter `ATYPE`:
- **0 = Squid** (top row, red)
- **1 = Crab** (middle row, purple)  
- **2 = Octopus** (bottom row, cyan)

Each sprite is a 12-wide × 8-tall bitmap stored as 8 rows of 12-bit values. The renderer instantiates 15 copies (one per villain) inside a `generate` loop, each with its `ATYPE` baked in at synthesis time — the mux between the three bitmaps is optimised away entirely.

### `player_rom.v`
A 16-wide × 8-tall bitmap for the player ship — cannon tip at the top, widening body, engine gaps at the base. Same lookup pattern as villain_rom.

### `text_rom.v`
Stores 8×8 pixel glyphs for the 13 characters needed by the "GAME OVER" and "YOU WIN" overlays: space, G, A, M, E, O, V, R, Y, U, W, I, N. The renderer scales each glyph 4× (to 32×32) and sequences through the characters to spell out the full strings.

---

## Debouncer — `debouncer.v`

Button inputs are noisy mechanical signals. Without debouncing, a single press reads as many rapid toggles.

Each button goes through:
1. **2-stage synchroniser** — moves the async button input safely into the `pix_clk` domain
2. **Saturating counter** — the debounced output only changes state after the raw input has held stable for 65,536 pixel clocks (~2.6 ms)
3. **Edge detector** — produces a single-cycle `btn_pulse` on the rising edge, used for fire

---

## 7-Segment Display — `seg7_display.v`

Displays the score (0–9999) on the four-digit 7-segment display.

- The 14-bit binary score is converted to four BCD digits using integer division by 10/100/1000
- An 18-bit counter selects which digit is active at any moment, cycling through all four at ~95 Hz — fast enough to appear solid to the eye
- The active digit drives `seg[6:0]` (active-low segment pattern) and `an[3:0]` (active-low anode select)

---

## Top Level — `top.v`

Wires everything together. Responsibilities:

- Instantiates `clk_div`, `vga_sync`, `game_logic`, `renderer`, `seg7_display`, and four `debouncer`s
- Synchronises the hard-reset button into the `pix_clk` domain using a 2-stage FF chain
- Implements the "hold BTND for 3 seconds → soft reset" counter (requires 75,000,000 pixel clock cycles)
- Combines hard reset and soft reset: `game_rst = rst | soft_rst`

---

## Key Design Decisions

**Why a single base position for all villains?** Moving 15 individual x/y registers every tick would be 30 register updates. Using one shared `villain_base_x` + offsets means only one register update drives the whole grid.

**Why 15 villain_rom instances?** Sprite ROMs are tiny (96 bits each). Instantiating 15 copies in a `generate` loop lets each villain be checked in parallel every pixel clock — essential since the renderer is purely combinational and must produce a result within one 25 MHz cycle.

**Why separate `game_tick` from `pix_clk`?** The renderer must run at 25 MHz to keep up with the VGA pixel stream. Game objects only need to move at ~60 Hz. Mixing them would either slow the renderer or make the game run at an unplayable speed.

**Why AABB and not pixel-perfect collision?** Pixel-perfect collision on sprites would require checking the ROM for every bullet-villain pair — hundreds of ROM reads per tick. AABB is a few comparators per pair and is indistinguishable from pixel-perfect at this sprite scale.
