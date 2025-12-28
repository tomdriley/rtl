# sv2v Example

This example demonstrates converting SystemVerilog (`.sv`) to Verilog (`.v`) using `sv2v` inside the toolkit containers.

## Supported commands

- `make sv2v` — Convert files listed in `SV2V_FILES`
- `make clean` — Remove generated `.v` files (local to this example)

## Variables

- `SV2V_FILES` — SystemVerilog files to convert (defaults to `simple_counter.sv`)
- `SV2V_OUT_DIR` — Optional output directory for generated `.v` files

## Notes

- By default, `sv2v` writes the `.v` file adjacent to the `.sv` file.
