# Makefile for Multi-Sensor Fusion SystemVerilog Testing
# Supports ModelSim, Questa, and open-source simulators

# Default simulator
SIM ?= questa

# Directories
SRC_DIR = .
TB_DIR = testbench
BUILD_DIR = build

# Source files
DESIGN_FILES = \
	$(SRC_DIR)/MultiSensorFusionTop.v \
	$(SRC_DIR)/Fusion\ Core/FusionCoreFull.v \
	$(SRC_DIR)/Fusion\ Core/QKV\ Generator/QKVGenerator.v \
	$(SRC_DIR)/Fusion\ Core/Attention\ Calculator/AttentionCalculator.v \
	$(SRC_DIR)/Fusion\ Core/Feature\ Fusion/FeatureFusion.v \
	$(SRC_DIR)/Fusion\ Core/Data\ Adapter/DataAdapter.v \
	$(SRC_DIR)/Camera\ Decoder/CameraDecoderFull.v \
	$(SRC_DIR)/LiDAR\ Decoder/LiDARDecoderFull.v \
	$(SRC_DIR)/Radar\ Filter/Radar_Filter_Full.v \
	$(SRC_DIR)/IMU\ Synchronizer/IMUSynchronizerFull.v \
	$(SRC_DIR)/Camera\ Feature\ Extractor/CameraFeatureExtractorFull.v \
	$(SRC_DIR)/LiDAR\ Feature\ Extractor/LiDAR_Feature_Extractor_Full.v \
	$(SRC_DIR)/Radar\ Feature\ Extractor/RadarFeatureExtractorFull.v \
	$(SRC_DIR)/Temporal\ Alignment/temporal_alignment_full.v

# Testbench files
TB_FILES = \
	$(TB_DIR)/tb_advanced_system.sv

# Python test files
PYTHON_TESTS = \
	$(TB_DIR)/test_advanced_edge_cases.py \
	$(TB_DIR)/test_fusion_core_advanced.py \
	$(TB_DIR)/test_system_stress.py \
	$(TB_DIR)/test_corrected_system.py

# Simulation parameters
TOP_MODULE = tb_advanced_system
VSIM_FLAGS = -voptargs=+acc -t ps
VLOG_FLAGS = -sv +incdir+$(SRC_DIR) +incdir+$(TB_DIR)

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile design files
compile: $(BUILD_DIR)
	@echo "Compiling design files..."
	cd $(BUILD_DIR) && vlib work
	cd $(BUILD_DIR) && vlog $(VLOG_FLAGS) $(addprefix ../,$(DESIGN_FILES))
	cd $(BUILD_DIR) && vlog $(VLOG_FLAGS) $(addprefix ../,$(TB_FILES))

# Run SystemVerilog simulation
sim: compile
	@echo "Running SystemVerilog simulation..."
	cd $(BUILD_DIR) && vsim $(VSIM_FLAGS) -c $(TOP_MODULE) -do "run -all; quit"

# Run with GUI
sim_gui: compile
	@echo "Running SystemVerilog simulation with GUI..."
	cd $(BUILD_DIR) && vsim $(VSIM_FLAGS) $(TOP_MODULE) -do "add wave -radix hex /*; run -all"

# Run Python tests
python_tests:
	@echo "Running Python test suite..."
	python3 $(TB_DIR)/run_all_tests.py

# Run advanced edge case tests
edge_cases:
	@echo "Running advanced edge case tests..."
	python3 $(TB_DIR)/test_advanced_edge_cases.py

# Run fusion core advanced tests
fusion_advanced:
	@echo "Running fusion core advanced tests..."
	python3 $(TB_DIR)/test_fusion_core_advanced.py

# Run stress tests
stress_tests:
	@echo "Running system stress tests..."
	python3 $(TB_DIR)/test_system_stress.py

# Run corrected system verification
corrected_system:
	@echo "Running corrected system verification..."
	python3 $(TB_DIR)/test_corrected_system.py

# Run all tests (Python + SystemVerilog)
all_tests: python_tests sim
	@echo "All tests completed!"

# Coverage analysis (if supported)
coverage: compile
	@echo "Running coverage analysis..."
	cd $(BUILD_DIR) && vsim $(VSIM_FLAGS) -coverage -c $(TOP_MODULE) -do "coverage save coverage.ucdb; run -all; quit"
	cd $(BUILD_DIR) && vcover report coverage.ucdb

# Synthesis check with Quartus (if available)
synthesis:
	@echo "Running synthesis check..."
	@if command -v quartus_map >/dev/null 2>&1; then \
		quartus_map --read_settings_files=on --write_settings_files=off MultiSensorFusion -c MultiSensorFusion; \
	else \
		echo "Quartus not found, skipping synthesis"; \
	fi

# Lint check with Verilator (if available)
lint:
	@echo "Running lint check..."
	@if command -v verilator >/dev/null 2>&1; then \
		verilator --lint-only --top-module MultiSensorFusionTop $(DESIGN_FILES); \
	else \
		echo "Verilator not found, skipping lint check"; \
	fi

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd *.wlf *.log
	find . -name "*.bak" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Help target
help:
	@echo "Multi-Sensor Fusion Testing Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  compile        - Compile SystemVerilog design files"
	@echo "  sim           - Run SystemVerilog simulation (command line)"
	@echo "  sim_gui       - Run SystemVerilog simulation with GUI"
	@echo "  python_tests  - Run Python test suite"
	@echo "  edge_cases    - Run advanced edge case tests"
	@echo "  fusion_advanced - Run fusion core advanced tests"
	@echo "  stress_tests  - Run system stress tests"
	@echo "  corrected_system - Run corrected system verification"
	@echo "  all_tests     - Run all tests (Python + SystemVerilog)"
	@echo "  coverage      - Run coverage analysis"
	@echo "  synthesis     - Run synthesis check (Quartus)"
	@echo "  lint          - Run lint check (Verilator)"
	@echo "  clean         - Clean build artifacts"
	@echo "  help          - Show this help"
	@echo ""
	@echo "Environment variables:"
	@echo "  SIM           - Simulator to use (questa, modelsim, vcs)"
	@echo ""
	@echo "Examples:"
	@echo "  make sim                    # Run basic simulation"
	@echo "  make sim_gui               # Run with GUI"
	@echo "  make python_tests          # Run Python tests only"
	@echo "  make all_tests             # Run everything"
	@echo "  make SIM=modelsim sim      # Use ModelSim"

# Alternative simulator support
ifeq ($(SIM),modelsim)
    VSIM_FLAGS += -modelsim
endif

ifeq ($(SIM),vcs)
    compile:
	@echo "Compiling with VCS..."
	vcs -sverilog +incdir+$(SRC_DIR) +incdir+$(TB_DIR) $(DESIGN_FILES) $(TB_FILES) -o $(BUILD_DIR)/simv
    
    sim: compile
	@echo "Running VCS simulation..."
	cd $(BUILD_DIR) && ./simv
endif

# Phony targets
.PHONY: compile sim sim_gui python_tests edge_cases fusion_advanced stress_tests corrected_system all_tests coverage synthesis lint clean help

# Default target
.DEFAULT_GOAL := help
