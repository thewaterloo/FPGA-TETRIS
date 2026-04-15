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
- **Self-contained timing closure** — the design meets at 50 MHz with
  plenty of slack; the critical path is the combinational collision
  check inside the FSM

## Repo layout

```
fpga-tetris/
├── rtl/            SystemVerilog sources (synthesised)
├── sim/            ModelSim testbenches
├── quartus/        tetris.qsf + tetris.sdc (open-and-compile)
└── scripts/        push_to_github.sh helper
```

## Building

1. Open Quartus Prime (18.1 or later — Lite edition is enough for the
   5CSEMA5F31C6 part).
2. `File → New Project Wizard`, point it at `quartus/`, name the
   project `tetris`, add all files from `rtl/` as SystemVerilog sources,
   add `quartus/tetris.sdc` as the SDC file.
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

The `sim/` folder has two testbenches you can run straight in ModelSim
(bundled with Quartus):

```tcl
vlib work
vlog -sv ../rtl/*.sv ../sim/tb_vga_controller.sv
vsim -c tb_vga_controller -do "run -all; quit"

vlog -sv ../rtl/*.sv ../sim/tb_tetris_top.sv
vsim tb_tetris_top -do "add wave -r /*; run 2500 ms"
```

`tb_vga_controller` self-checks that exactly 525 HS pulses fire per
frame. `tb_tetris_top` is a waveform driver — reset the DUT, press a few
keys, and watch gravity drop a piece through the lock/redraw cycle.

## Notes on the pixel clock

The spec pixel clock for 640×480 @ 60 Hz is **25.175 MHz**; this design
divides 50 MHz by 2 to get 25.000 MHz. Every VGA monitor I've tried
tolerates the ~0.7 % deviation, but if you want bit-exact VESA timing,
drop an ALTPLL between `CLOCK_50` and `pix_clk` and set it to output
25.175 MHz. No other changes needed.

## License

MIT — see `LICENSE`.
