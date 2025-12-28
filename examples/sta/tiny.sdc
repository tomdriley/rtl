# Simple constraints for the tiny STA example.
# This is intentionally minimal and beginner-friendly.

create_clock -name clk -period 10 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]

# Give inputs/outputs some basic budgets (arbitrary but useful for experimentation)
set_input_delay  1.0 -clock clk [get_ports {a b}]
set_output_delay 1.0 -clock clk [get_ports y]
