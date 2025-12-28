# Logical Equivalence Checking (LEC) Example

This example demonstrates how to use EQY (Equivalence checking with Yosys) to verify that two different implementations of the same design are functionally equivalent.

## Supported commands

- `make lec` — Run equivalence checking
- `make lec-waves` — Open generated EQY VCD traces in GTKWave
- `make clean` — Remove generated artifacts

## Files

- `counter_gold.v` - The "gold" reference implementation (known to be correct)
- `counter_gate.v` - The "gate" implementation to be verified for equivalence
- `counter_lec.eqy` - EQY configuration file for the equivalence check
- `Makefile` - Build targets for running the equivalence check

## Usage

### Run Equivalence Check
```bash
make lec
```

### View Traces (if equivalence fails)
```bash
make lec-waves
```

### Clean Build Artifacts
```bash
make clean
```

## EQY Configuration Explained

The `.eqy` file defines:
- **[gold]** section: Yosys commands to process the reference design
- **[gate]** section: Yosys commands to process the design under test
- **[collect]** section: How to group logic for verification
- **[strategy]** section: Which equivalence checking strategy to use

## Expected Result

Since both counter implementations are functionally equivalent (just written in different styles), EQY should report:
```
EQY [counter_lec] Successfully proved designs equivalent
```

If the designs were not equivalent, EQY would generate trace files showing the differences, which can be viewed with GTKWave using `make lec-waves`.
