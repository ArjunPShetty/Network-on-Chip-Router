# NoC Router Project Makefile
# Author: Your Name
# Date: $(shell date)

# Variables
RTL_DIR = rtl
TB_DIR = testbench
CONFIG_DIR = config
SYNTH_DIR = synthesis
SIM_DIR = simulation
LOG_DIR = logs
WAVE_DIR = waveforms

# Tools
VLOG = vlog
VSIM = vsim
VIVADO = vivado
DC_SHELL = dc_shell
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave

# Source Files
RTL_SOURCES = \
	$(RTL_DIR)/noc_router/router_core.v \
	$(RTL_DIR)/noc_router/input_port.v \
	$(RTL_DIR)/noc_router/output_port.v \
	$(RTL_DIR)/noc_router/switch_allocator.v \
	$(RTL_DIR)/noc_router/vc_allocator.v \
	$(RTL_DIR)/noc_router/crossbar.v \
	$(RTL_DIR)/noc_router/fifo_buffer.v \
	$(RTL_DIR)/network_interface/ni_master.v \
	$(RTL_DIR)/network_interface/ni_slave.v \
	$(RTL_DIR)/top_level/noc_top.v \
	$(RTL_DIR)/top_level/system_top.v \
	$(RTL_DIR)/utils/synchronizer.v

TB_SOURCES = \
	$(TB_DIR)/noc_router_tb.v \
	$(TB_DIR)/system_tb.v

CONFIG_SOURCES = \
	$(CONFIG_DIR)/router_params.vh \
	$(CONFIG_DIR)/network_config.vh

# Targets
.PHONY: all sim synth clean lint test coverage help

all: sim synth

# Simulation with ModelSim/QuestaSim
sim: $(SIM_DIR)/noc_router_tb
	cd $(SIM_DIR) && $(VSIM) -c -do "run -all; quit" noc_router_tb

$(SIM_DIR)/noc_router_tb: $(RTL_SOURCES) $(TB_SOURCES) $(CONFIG_SOURCES)
	mkdir -p $(SIM_DIR) $(LOG_DIR)
	$(VLOG) -work $(SIM_DIR) $(RTL_SOURCES) $(TB_DIR)/noc_router_tb.v

# Simulation with Icarus Verilog
sim-icarus: $(SIM_DIR)/noc_router_tb.fst
	$(GTKWAVE) $(SIM_DIR)/noc_router_tb.fst

$(SIM_DIR)/noc_router_tb.fst: $(RTL_SOURCES) $(TB_SOURCES) $(CONFIG_SOURCES)
	mkdir -p $(SIM_DIR) $(LOG_DIR)
	$(IVERILOG) -o $(SIM_DIR)/noc_router_tb.vvp \
		-g2005-sv \
		-D IVERILOG \
		-I$(CONFIG_DIR) \
		$(RTL_SOURCES) $(TB_DIR)/noc_router_tb.v
	cd $(SIM_DIR) && $(VVP) noc_router_tb.vvp -fst

# Synthesis with Vivado
synth: $(SYNTH_DIR)/noc_router_post_synth.dcp
	@echo "Synthesis complete"

$(SYNTH_DIR)/noc_router_post_synth.dcp: $(RTL_SOURCES) $(CONFIG_SOURCES)
	mkdir -p $(SYNTH_DIR) $(LOG_DIR)
	$(VIVADO) -mode batch -source scripts/synthesis.tcl -log $(LOG_DIR)/synth.log

# Linting
lint:
	verilator --lint-only -Wall -I$(CONFIG_DIR) $(RTL_SOURCES)

# Test all
test: sim
	@echo "Running all tests..."
	@cd scripts && ./run_all_tests.sh

# Coverage
coverage:
	mkdir -p coverage
	$(VLOG) -work $(SIM_DIR) -cover sbcef $(RTL_SOURCES) $(TB_DIR)/noc_router_tb.v
	$(VSIM) -c -coverage -do "coverage save -onexit coverage/coverage.ucdb; run -all; exit" noc_router_tb

# Clean
clean:
	rm -rf $(SIM_DIR) $(SYNTH_DIR) $(LOG_DIR) coverage
	rm -f *.vcd *.fst *.vvp *.log transcript
	rm -f vivado*.jou vivado*.log
	rm -f *.dcp *.edf *.edn *.cmd

# Help
help:
	@echo "Available targets:"
	@echo "  all      : Run simulation and synthesis"
	@echo "  sim      : Run simulation with ModelSim"
	@echo "  sim-icarus: Run simulation with Icarus Verilog"
	@echo "  synth    : Run synthesis with Vivado"
	@echo "  lint     : Run Verilator linting"
	@echo "  test     : Run all tests"
	@echo "  coverage : Run coverage analysis"
	@echo "  clean    : Clean generated files"
	@echo "  help     : Show this help"

# Dependencies
$(RTL_SOURCES): $(CONFIG_SOURCES)
$(TB_SOURCES): $(CONFIG_SOURCES)