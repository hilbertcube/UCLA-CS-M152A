# Lab 3: Stopwatch Requirements

This README summarizes what the stopwatch clock must do based on `lab_3/docs/lab_3.pdf`.

## Overall Stopwatch Behavior

- The design acts as a stopwatch or basic clock that counts **minutes and seconds**.
- The left two seven-segment digits show **minutes**.
- The right two seven-segment digits show **seconds**.
- The display format is `MMSS`.
- Example: after 1 minute and 43 seconds, the display should read `0143`.

## Normal Counting Behavior

- In normal mode, the stopwatch increments **once per second**.
- The seconds field counts from `00` to `59`.
- When seconds roll over from `59` to `00`, the minutes field increments by 1.
- The minutes field also behaves as a `00` to `59` counter.

## Inputs That Control the Stopwatch

### `RESET`

- `RESET` forces the stopwatch back to **`00:00`**.

### `PAUSE`

- Pressing `PAUSE` once stops the stopwatch.
- Pressing `PAUSE` again resumes counting.

### `ADJ`

- `ADJ = 0`: the stopwatch behaves normally.
- `ADJ = 1`: the stopwatch enters **adjustment mode**.

### `SEL`

- `SEL = 0`: adjustment mode changes **minutes**.
- `SEL = 1`: adjustment mode changes **seconds**.

## Adjustment Mode Behavior

- While `ADJ` is high, **normal 1 Hz counting is halted**.
- Instead of normal counting, the **selected field** increments at **2 Hz**.
- The **unselected field remains frozen** while adjusting.
- The selected field must **blink** while adjustment mode is active.

## What the Clock Module Must Generate

The lab handout recommends a dedicated clock module driven by the Basys 3 **100 MHz** master clock. That module should produce these timing signals:

### `1 Hz` clock or enable

- Used for normal stopwatch counting.
- Causes the stopwatch to advance once per second in normal mode.

### `2 Hz` clock or enable

- Used in adjustment mode.
- Causes the selected field to increment two times per second.

### Fast scan clock in the `50-700 Hz` range

- Used to multiplex the four seven-segment digits.
- The display hardware can only drive one digit pattern at a time, so the design must cycle through the digits quickly.
- This scan rate must be fast enough that the human eye perceives all four digits as continuously lit.
- The handout also notes that this faster clock can be used as a sampling clock for debouncing.

### Blink clock greater than `1 Hz`

- Used to blink the selected field during adjustment mode.
- This clock must be **faster than 1 Hz**.
- The handout explicitly says it **must not be 2 Hz**, because then the adjusted digits would not appear to increment correctly.
- The exact blink rate is designer-chosen as long as it looks reasonable.

## Display-Related Requirements

- The stopwatch uses the Basys 3 four-digit seven-segment display.
- The design must multiplex the display digits using the fast scan clock.
- During adjustment mode, the selected field should blink while the other field remains visible.

## Input Reliability Requirements

- Buttons and switches are noisy and must be **debounced**.
- Buttons and switches are asynchronous to the FPGA clock and should be **synchronized** before being used by the rest of the design.
- The lab handout specifically calls out both **bounce filtering** and **metastability protection** as required parts of the design.

## Practical Summary

To satisfy the lab, the stopwatch clock logic should support:

- normal `MM:SS` counting at `1 Hz`
- time adjustment at `2 Hz`
- display multiplexing at `50-700 Hz`
- visible blinking of the selected field at a rate `> 1 Hz` and not equal to `2 Hz`
- clean operation with debounced and synchronized button and switch inputs