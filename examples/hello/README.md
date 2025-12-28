# Hello (Simulation) Example

This is the smallest simulation example using Verilator inside the toolkit containers.

## Supported commands

- `make build` — Build the simulation binary with Verilator
- `make run` — Run the simulation
- `make clean` — Remove generated artifacts

## Notes

- This example does not dump a VCD waveform. If you want to view waves, use the `examples/waves` example.

## Variables

- `FILE_LIST` — Input Verilog files for Verilator (defaults to `hello.v` via the Makefile)
- `PLUSARGS` — Extra plusargs passed to the simulator when running (`make run PLUSARGS=...`)
