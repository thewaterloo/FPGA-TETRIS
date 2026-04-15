# tetris.sdc - timing constraints
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty

# VGA pixel clock is a /2 of CLOCK_50 → 25 MHz
create_generated_clock -name pix_clk -source [get_ports CLOCK_50] -divide_by 2 [get_registers {clk_div}]

set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*]}]
set_false_path -to   [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS VGA_BLANK_N VGA_SYNC_N VGA_CLK}]
