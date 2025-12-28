# Waves (Simulation + Viewing) Example

This example produces a waveform (`.vcd`) and demonstrates opening it with GTKWave.

## Supported commands

- `make build` — Build the simulation binary with Verilator
- `make run` — Run the simulation to generate the VCD
- `make waves` — Open `WAVE_FILE` in GTKWave
- `make clean` — Remove generated artifacts

## Variables

- `FILE_LIST` — Input Verilog files for Verilator (defaults to `waves.v`)
- `WAVE_FILE` — VCD file to open (defaults to `waves.vcd`)
- `PLUSARGS` — Extra plusargs passed to the simulator when running
