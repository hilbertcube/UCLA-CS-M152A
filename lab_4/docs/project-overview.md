# CS M152A Lab 4 — Final Project Proposal

Space Invaders on Basys3 FPGA

Team: Gaurav Kumar & Don Le  |  Spring 2026

## Overview

We propose to implement a simplified version of the classic arcade game Space Invaders on the Basys3 FPGA board using Verilog. The game will be displayed on a VGA monitor and controlled via the onboard buttons and switches. The project is designed to have core digital design concepts including synchronous FSMs, VGA signal generation, collision detection, and simple game logic.

## Game Description

The game consists of a single level. The player controls a spaceship at the bottom of the screen and must shoot down a grid of enemy (villain) spaceships moving side-to-side across the screen. The villain spaceships will periodically shoot back at the player. The game ends when either:

- All villain spaceships are destroyed (player wins), or
- The player loses all 3 lives (game over).

There will also be barriers between the player and the villain spaceships which provide protection for both sides. Barriers can be destroyed by shooting at them. There are no power-ups or multiple levels in this simplified version. The focus is on clean, correct game logic and stable VGA rendering.

## Hardware & Display

### VGA Output

The game will render at 640x480 @ 60 Hz over the VGA port. All game objects (player ship, villain ships, bullets) will be drawn as simple colored rectangular sprites using combinational logic that maps pixel coordinates to on-screen objects. No external ROM or sprite sheets are required — all shapes are defined by bounding box logic.

| **Object** | Color / Description |
| --- | --- |
| **Player ship** | Green rectangle (~16x8 px) |
| **Villain ships** | Red rectangles (~12x8 px), arranged in a 5x3 grid |
| **Player bullet** | White 2x8 px bar |
| **Villain bullets** | Yellow 2x6 px bars |
| **Background** | Black |
| **Lives display** | 3 small green icons, top-left corner |

### Controls (Buttons & Switches)

- BTNL / BTNR — move player left / right
- BTNT (top button) — fire a bullet
- BTNB (bottom button) — hold for 3 sec to reset the game

### 7-Segment Display

The score (number of villains destroyed) will be shown on the 4-digit 7-segment display in decimal. Each villain destroyed increments the score by 10 points.

## System Architecture

The design is divided into the following Verilog modules:

| **Module** | Responsibility |
| --- | --- |
| **top.v** | Top-level instantiation; connects all submodules |
| **vga_sync.v** | Generates hsync, vsync, and pixel x/y counters at 25 MHz (640x480) |
| **game_render.v** | Combinational pixel color output based on current game state |
| **player_ctrl.v** | Reads button inputs, updates player X position, fires player bullet |
| **villain_ctrl.v** | FSM for villain grid movement (left/right/step-down) and villain bullet firing |
| **collision.v** | Detects bullet-villain and bullet-player hits; updates lives and score |
| **score_display.v** | Binary-to-BCD + 7-segment driver for score output |
| **clk_div.v** | Clock divider: generates 25 MHz pixel clock and slower game-tick clock |

### Clock Strategy

A 100 MHz system clock from the Basys3 is divided down to two derived clocks:

- 25 MHz — pixel clock for VGA sync generation
- ~60 Hz game tick — controls villain movement speed and bullet travel speed

All game state registers update on the game-tick clock edge to keep logic timing clean.

## Gameplay Logic Details

### Player Movement & Shooting

The player ship is clamped to the screen boundaries (X: 0 to 624). Player bullets and villian bullets travel in a straight line from where they were shot towards the opposing side. For the player the bullet travels upward at a fixed speed of 4 pixels per game tick until it either hits a villain or exits the top of the screen.

### Villain Movement

The 15 villains (5 columns x 3 rows) move together as a unit in a simple FSM:

- State MOVE_RIGHT: shift grid right by 2 px per game tick
- State MOVE_LEFT: shift grid left by 2 px per game tick

When a villain reaches the end of the screen, flip the state and move the villains in the opposite direction. Destroyed villains are marked with a "dead" flag and are skipped in both rendering and boundary detection.

### Villain Shooting

Every N game ticks (approximately every 1.5 seconds), 3 random living villains are selected to fire a bullet downward. Up to 12 villain bullets may be active simultaneously. Bullets travel downward at 4 pixels per game tick. If a villain bullet reaches the bottom of the screen without hitting the player, it disappears.

### Collision Detection

On every game tick, the collision module checks:

- Player bullet vs. each villain bounding box — on hit: villain marked dead, score +10, bullet removed
- Each villain bullet vs. player bounding box — on hit: lives -1, bullet removed, brief flash effect (player blinks for 60 ticks)

### Lives & Game Over

The player starts with 3 lives shown as small ship icons in the top-left corner of the screen. Losing the last life transitions the FSM to a GAME_OVER state, which displays a static "GAME OVER" text on the VGA screen and stops all movement. Destroying all 15 villains transitions to a WIN state that displays "YOU WIN".

## Reset Functionality

The game can be reset at any time by toggling by holding BTNB for 3 seconds. On reset, all game state registers return to their initial values: player centered, full villain grid restored, 3 lives, score 0, all bullets cleared. The VGA sync is not interrupted by reset — only game-state registers are cleared.

## Grading Rubric

| **Points** | **Weight** | **Requirement & Demo Criteria** |
| --- | --- | --- |
| **Part 1** | 30% | Player can move left/right and fire a bullet. The bullet travels in a straight upward path from the player's position. |
| **Part 2** | 20% | Player bullet correctly collides with and destroys villain ships. Destroyed villains disappear from the screen. Score increments on the 7-segment display for each villain destroyed. |
| **Part 3** | 20% | Player can die from villain bullets. When a villain bullet reaches the player bounding box, lives decrement. The lives counter on screen updates accordingly. The game displays GAME OVER when all 3 lives are lost. |
| **Part 4** | 25% | Villains periodically shoot back. 3 villians shoot every 1.5 sec. Bullets originate from a living villain and travel straight down. |
| **Part 5** | 5% | Reset functionality: toggling SW0 or holding a button resets all game state. Demo: demonstrate reset mid-game; score, lives, and villain positions all return to initial values. |