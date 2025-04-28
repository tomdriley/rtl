# Makefile for building and running a simple Verilator designa

FILE_LIST := waves.v
VERILATOR_BUILD_ARGS := --main --timing --build --exe -Wall -j 0 -o run_sim --trace

# Docker image containing Verilator
IMAGE := verilator/verilator:latest

# Common docker run flags
VERILATOR_DOCKER := docker run --rm -ti \
	-v "$(PWD)":/work \
	-e HOME=/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(IMAGE)

.PHONY: build run clean

# 'build' is simply an alias that ensures the binary exists
build: obj_dir/run_sim

# Generate the Verilator binary only if $(FILE_LIST) changed or missing
obj_dir/run_sim: $(FILE_LIST)
	$(VERILATOR_DOCKER) $(VERILATOR_BUILD_ARGS) $(FILE_LIST)

# Run the generated simulation (won't rebuild if up-to-date)
run: obj_dir/run_sim
	obj_dir/run_sim

# Clean generated files
clean:
	rm -rf obj_dir .cache *.vcd
