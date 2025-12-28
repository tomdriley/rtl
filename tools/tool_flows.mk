ifndef TOOL_FLOWS_MK
TOOL_FLOWS_MK := 1

ifndef PROJECT_ROOT
PROJECT_ROOT := $(PWD)
endif # PROJECT_ROOT

ifndef CURRENT_DIR
CURRENT_DIR := /work
endif # CURRENT_DIR

# Common variables
VERILATOR_IMAGE := verilator/verilator:v5.036
VERILATOR_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-e HOME=$(CURRENT_DIR) \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(VERILATOR_IMAGE)
VERILATOR_BUILD_ARGS := --main --timing --build --exe -Wall -j 0 -o run_sim --trace --assert $(DEFINES)
VERILATOR_INCLUDE_ARGS = $(addprefix -I, $(INCLUDE_DIRS))

GTK_WAVES_IMAGE := gtk-wave:latest
OSS_CAD_IMAGE := oss-cad:latest
SV2V_IMAGE := sv2v:latest

# SBY Docker command
SBY_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) sby

# EQY Docker command
EQY_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) eqy

# SV2V Docker command
SV2V_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(SV2V_IMAGE) sv2v

# Yosys Docker command (for synthesis)
YOSYS_DOCKER := docker run --rm -ti \
	-v "$(PROJECT_ROOT)":/work \
	-w $(CURRENT_DIR) \
	--user $(shell id -u):$(shell id -g) \
	$(OSS_CAD_IMAGE) yosys

# Auto-detect display environment (X11 socket vs networked/VNC)
ifeq ($(shell test -S /tmp/.X11-unix/X$(patsubst :%,%,$(DISPLAY)) && echo has_x11_socket),has_x11_socket)
    # X11 socket environment (e.g., WSL2/WSLg, native Linux with X11)
    GTKWAVES_DOCKER := docker run --rm -it \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        $(if $(wildcard /mnt/wslg),-v /mnt/wslg:/mnt/wslg) \
        $(if $(WAYLAND_DISPLAY),-v $(XDG_RUNTIME_DIR):$(XDG_RUNTIME_DIR)) \
        -e DISPLAY -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR \
        -v "$(PROJECT_ROOT)":/work \
        -e HOME=$(CURRENT_DIR) \
        -w $(CURRENT_DIR) \
        --user $(shell id -u):$(shell id -g) \
        $(GTK_WAVES_IMAGE) gtkwave
else
    # Networked display environment (e.g., dev container VNC)
    GTKWAVES_DOCKER := docker run --rm -it \
        --network host \
        -e DISPLAY=$(DISPLAY) \
        $(if $(wildcard $(HOME)/.Xauthority),-v "$(HOME)/.Xauthority:$(HOME)/.Xauthority:ro") \
        -v "$(PROJECT_ROOT)":/work \
        -e HOME=$(CURRENT_DIR) \
        -w $(CURRENT_DIR) \
        --user $(shell id -u):$(shell id -g) \
        $(GTK_WAVES_IMAGE) gtkwave
endif


# Common rules
.PHONY: clean rebuild build run waves formal formal-cover formal-waves waves-list waves-cover waves-bmc lec lec-waves synth sv2v

clean:
	@# Clean Verilator artifacts
	rm -rf obj_dir .cache *.vcd
	@# Clean formal verification artifacts
	rm -rf *_bmc *_cover *_prove *_live
	rm -rf sby-* *.xml *.sqlite *.smtc *.yw *_tb.v
	rm -rf status status.* PASS FAIL UNKNOWN logfile.txt config.sby
	@# Clean equivalence checking artifacts
	rm -rf eqy-* *.eqy.log
	@# Clean synthesis artifacts
	rm -f *_synth*.v _synth*.sv*.log
	@# Remove any directories that match .sby/.eqy basenames (SBY/EQY output directories)
	@for f in *.sby; do [ -f "$$f" ] && rm -rf "$$(basename "$$f" .sby)" || true; done 2>/dev/null || true
	@for f in *.eqy; do [ -f "$$f" ] && rm -rf "$$(basename "$$f" .eqy)" || true; done 2>/dev/null || true
	# Clean up scratch / temporary files
	rm -rf temp/ tmp/ scratch/ build_*/ 


rebuild:
	$(MAKE) clean
	$(MAKE) build

build: obj_dir/run_sim

obj_dir/run_sim: $(FILE_LIST)
	$(VERILATOR_DOCKER) $(VERILATOR_BUILD_ARGS) $(VERILATOR_INCLUDE_ARGS) $(FILE_LIST)

run: obj_dir/run_sim
	obj_dir/run_sim $(PLUSARGS)

# Formal verification rules
formal: $(SBY_FILE)
	$(SBY_DOCKER) -f $(SBY_FILE)

formal-cover: $(SBY_FILE)
	$(SBY_DOCKER) -f $(SBY_FILE) cover

formal-waves: $(SBY_FILE)
	@# List and select VCD files from formal verification
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	if [ -n "$(WAVE)" ]; then \
		if [ -f "$(WAVE)" ]; then \
			echo "Opening specified trace: $(WAVE)"; \
			$(GTKWAVES_DOCKER) $(WAVE); \
		else \
			echo "Error: Specified wave file '$(WAVE)' not found."; \
			exit 1; \
		fi \
	else \
		TRACE_FILES=$$(find "$${SBY_BASE}_"* -name "*.vcd" 2>/dev/null | sort); \
		if [ -n "$$TRACE_FILES" ]; then \
			TRACE_COUNT=$$(echo "$$TRACE_FILES" | wc -l); \
			if [ $$TRACE_COUNT -eq 1 ]; then \
				TRACE_FILE=$$TRACE_FILES; \
				echo "Opening formal trace: $$TRACE_FILE"; \
				$(GTKWAVES_DOCKER) $$TRACE_FILE; \
			else \
				echo "Multiple VCD files found:"; \
				echo "$$TRACE_FILES" | nl -w2 -s': '; \
				echo ""; \
				echo "Usage options:"; \
				echo "  make waves WAVE=<filename>     # Open specific file"; \
				echo "  make waves-list                # List all available traces"; \
				echo "  make waves-cover               # Open cover traces"; \
				echo "  make waves-bmc                 # Open BMC traces"; \
				echo ""; \
				echo "Opening first trace: $$(echo "$$TRACE_FILES" | head -1)"; \
				$(GTKWAVES_DOCKER) $$(echo "$$TRACE_FILES" | head -1); \
			fi \
		else \
			echo "No VCD trace files found. Run 'make formal' or 'make cover' first."; \
		fi \
	fi

# Additional wave viewing targets
waves-list: $(SBY_FILE)
	@# List all available VCD files from formal verification
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	TRACE_FILES=$$(find "$${SBY_BASE}_"* -name "*.vcd" 2>/dev/null | sort); \
	if [ -n "$$TRACE_FILES" ]; then \
		echo "Available VCD trace files:"; \
		echo "$$TRACE_FILES" | nl -w2 -s': '; \
		echo ""; \
		echo "Usage: make waves WAVE=<filename>"; \
	else \
		echo "No VCD trace files found. Run 'make formal' or 'make cover' first."; \
	fi

waves-cover: $(SBY_FILE)
	@# Open cover traces specifically
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	TRACE_FILE=$$(find "$${SBY_BASE}_cover" -name "*.vcd" 2>/dev/null | head -1); \
	if [ -n "$$TRACE_FILE" ]; then \
		echo "Opening cover trace: $$TRACE_FILE"; \
		$(GTKWAVES_DOCKER) $$TRACE_FILE; \
	else \
		echo "No cover trace files found. Run 'make cover' first."; \
	fi

waves-bmc: $(SBY_FILE)
	@# Open BMC traces specifically  
	@SBY_BASE=$$(basename $(SBY_FILE) .sby); \
	TRACE_FILE=$$(find "$${SBY_BASE}_bmc" -name "*.vcd" 2>/dev/null | head -1); \
	if [ -n "$$TRACE_FILE" ]; then \
		echo "Opening BMC trace: $$TRACE_FILE"; \
		$(GTKWAVES_DOCKER) $$TRACE_FILE; \
	else \
		echo "No BMC trace files found. Run 'make formal' first."; \
	fi

waves:
	@# Auto-detect whether to use regular waves or formal waves
	@if [ -n "$(WAVE_FILE)" ] && [ -f "$(WAVE_FILE)" ]; then \
		echo "Opening simulation trace: $(WAVE_FILE)"; \
		$(GTKWAVES_DOCKER) $(WAVE_FILE); \
	elif [ -n "$(WAVE)" ] && [ -f "$(WAVE)" ]; then \
		echo "Opening specified trace: $(WAVE)"; \
		$(GTKWAVES_DOCKER) $(WAVE); \
	elif [ -n "$(SBY_FILE)" ]; then \
		$(MAKE) formal-waves; \
	else \
		echo "No wave file specified. Set WAVE_FILE or WAVE variable, or run from formal verification directory."; \
		exit 1; \
	fi

# Logical Equivalence Checking (LEC) rules
lec: $(EQY_FILE)
	$(EQY_DOCKER) -f $(EQY_FILE)

# Synthesis rules
synth: $(SYNTH_SCRIPT)
	$(YOSYS_DOCKER) -s $(SYNTH_SCRIPT)

lec-waves: $(EQY_FILE)
	@# List and select VCD files from equivalence checking
	@EQY_BASE=$$(basename $(EQY_FILE) .eqy); \
	if [ -n "$(WAVE)" ]; then \
		if [ -f "$(WAVE)" ]; then \
			echo "Opening specified trace: $(WAVE)"; \
			$(GTKWAVES_DOCKER) $(WAVE); \
		else \
			echo "Error: Specified wave file '$(WAVE)' not found."; \
			exit 1; \
		fi \
	else \
		TRACE_FILES=$$(find "$${EQY_BASE}" -name "*.vcd" 2>/dev/null | sort); \
		if [ -n "$$TRACE_FILES" ]; then \
			TRACE_COUNT=$$(echo "$$TRACE_FILES" | wc -l); \
			if [ $$TRACE_COUNT -eq 1 ]; then \
				TRACE_FILE=$$TRACE_FILES; \
				echo "Opening equivalence trace: $$TRACE_FILE"; \
				$(GTKWAVES_DOCKER) $$TRACE_FILE; \
			else \
				echo "Multiple VCD files found:"; \
				echo "$$TRACE_FILES" | nl -w2 -s': '; \
				echo ""; \
				echo "Usage: make lec-waves WAVE=<filename>     # Open specific file"; \
				echo ""; \
				echo "Opening first trace: $$(echo "$$TRACE_FILES" | head -1)"; \
				$(GTKWAVES_DOCKER) $$(echo "$$TRACE_FILES" | head -1); \
			fi \
		else \
			echo "No VCD trace files found. Run 'make lec' first."; \
		fi \
	fi

# SystemVerilog to Verilog conversion rules
# Usage: make sv2v SV2V_FILES="file1.sv file2.sv" [SV2V_OUT_DIR=output_dir]
# If SV2V_OUT_DIR is not specified, creates .v files adjacent to .sv files
sv2v:
	@if [ -z "$(SV2V_FILES)" ]; then \
		echo "Error: SV2V_FILES variable not set. Please specify SystemVerilog files to convert."; \
		echo "Usage: make sv2v SV2V_FILES=\"file1.sv file2.sv\" [SV2V_OUT_DIR=output_dir]"; \
		exit 1; \
	fi
	@echo "Converting $(SV2V_FILES) to adjacent .v files..."; \
	$(SV2V_DOCKER) --write=adjacent $(SV2V_FILES); \
	if [ -n "$(SV2V_OUT_DIR)" ]; then \
		echo "Moving generated .v files to $(SV2V_OUT_DIR)..."; \
		mkdir -p "$(SV2V_OUT_DIR)"; \
		for f in $(SV2V_FILES); do \
			outf="$${f%.sv}.v"; \
			if [ -f "$$outf" ]; then \
				mv "$$outf" "$(SV2V_OUT_DIR)/"; \
			else \
				echo "Warning: Output file $$outf not found."; \
			fi; \
		done; \
	fi

endif # TOOL_FLOWS_MK