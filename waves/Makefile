# Makefile for building and running a simple Verilator waves-world design

# Docker image containing Verilator
IMAGE := verilator/verilator:latest

# Common docker run flags
docker_run := docker run --rm -ti \
	-v "$(PWD)":/work \
	-e HOME=/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(IMAGE)

.PHONY: build run clean

# 'build' is simply an alias that ensures the binary exists
build: obj_dir/Vwaves

# Generate the Verilator binary only if waves.v changed or missing
obj_dir/Vwaves: waves.v
	$(docker_run) --binary -j 0 -Wall --trace waves.v

# Run the generated simulation (won't rebuild if up-to-date)
run: obj_dir/Vwaves
	obj_dir/Vwaves

# Clean generated files
clean:
	rm -rf obj_dir .ccache
