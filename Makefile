# Docker image containing Verilator
IMAGE := verilator/verilator:latest

# Common docker run flags
docker_run := docker run --rm -ti \
	-v "$(PWD)":/work \
	-e HOME=/work \
	-w /work \
	--user $(shell id -u):$(shell id -g) \
	$(IMAGE)

.PHONY: setup version clean

# Setup: ensure Docker + Verilator image are ready
setup:
	@./setup.sh

# Show Verilator version (runs setup first)
version: setup
	$(docker_run) --version

# Clean generated files
clean:
	rm -rf obj_dir .ccache
