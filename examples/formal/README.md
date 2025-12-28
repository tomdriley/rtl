# Formal Verification Example

This example runs formal verification with SymbiYosys (SBY) inside the toolkit containers.

## Supported commands

- `make formal` — Run bounded model checking (BMC)
- `make formal-cover` — Run cover analysis
- `make formal-waves` — Open a generated formal VCD in GTKWave (auto-selects)
- `make waves WAVE=<file.vcd>` — Open a specific VCD file
- `make waves-list` — List available formal VCD traces
- `make waves-cover` — Open a cover trace (if present)
- `make waves-bmc` — Open a BMC trace (if present)
- `make clean` — Remove generated artifacts

## Variables

- `SBY_FILE` — Which `.sby` file to run (defaults to `formal.sby` via the Makefile)
- `WAVE` — Path to a specific `.vcd` to open
