# FPGA Tetris

A complete Tetris implementation in SystemVerilog targeting the Terasic
DE1-SoC (Intel Cyclone V 5CSEMA5F31C6). Renders a 10×20 playfield over
VGA at 640×480 @ 60 Hz, with all game logic — spawning, collision,
rotation, line clearing, score — running in RTL. No NIOS, no software.

## Features

- **640×480 @ 60 Hz VGA output** with 25 MHz pixel clock derived from the
  50 MHz system clock
- **Dual-clock dual-port BRAM framebuffer** (200 cells × 3 bits) for
  glitch-free read-while-write between the game FSM and the VGA scanout
- **Full 7-piece set** (I, O, T, S, Z, J, L) with 4-way rotation where
  applicable, driven by a 16-bit LFSR randomizer
- **Line clear with cascade**: scans bottom-up, clears, shifts, rescores
  (100 / 300 / 500 / 800 per 1/2/3/4 lines)
- **Debounced edge-triggered input** on the four DE1-SoC push buttons +
  SW0 for soft drop
- **Hex display HUD** showing the 16-bit score across HEX3..HEX0
- **Live piece rendering** — accepted movement triggers a framebuffer
  redraw, with the active piece layered over the locked grid

## Repo layout

```
FPGA-TETRIS/
├── *.sv            RTL and two simulation testbenches
├── tetris.qsf      Quartus assignments
└── tetris.sdc      50 MHz timing constraint
```

## Building

1. Open Quartus Prime with the DE1-SoC Cyclone V device installed.
2. Open the repository-root `tetris.qsf`, whose source paths match this
   repository layout. Testbenches are for simulation only.
3. Set `tetris_top` as the top-level entity.
4. `Processing → Start Compilation`.
5. Flash the resulting `output_files/tetris.sof` to the board via the
   USB Blaster II.

## Controls

| Input        | Action       |
|--------------|--------------|
| `KEY[0]`     | Reset        |
| `KEY[1]`     | Move left    |
| `KEY[2]`     | Rotate CW    |
| `KEY[3]`     | Move right   |
| `SW[0]` ↑    | Soft drop    |

## Simulating

The repository has two testbenches you can run in ModelSim
(bundled with Quartus):

```tcl
vlib work
vlog -sv framebuffer.sv game_fsm.sv input_handler.sv lfsr_rng.sv tetris_top.sv vga_controller.sv tb_vga_controller.sv
vsim -c tb_vga_controller -do "run -all; quit"

vlog -sv tb_tetris_top.sv
vsim tb_tetris_top -do "add wave -r /*; run 2500 ms"
```

`tb_vga_controller` checks the sync timing. `tb_tetris_top` is a waveform
driver — reset the DUT, press a few
keys, and watch gravity drop a piece through the lock/redraw cycle.

## Notes on the pixel clock

The spec pixel clock for 640×480 @ 60 Hz is **25.175 MHz**; this design
divides 50 MHz by 2 to get 25.000 MHz. Some monitors tolerate the
~0.7 % deviation; for exact VESA timing,
drop an ALTPLL between `CLOCK_50` and `pix_clk` and set it to output
25.175 MHz. No other changes needed.

## License

MIT — see `LICENSE`.
