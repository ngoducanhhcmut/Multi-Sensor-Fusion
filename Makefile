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
	@if [ -f "venv/bin/activate" ]; then \
		echo "Using virtual environment..."; \
		. venv/bin/activate && python3 $(TB_DIR)/run_all_tests.py; \
	else \
		python3 $(TB_DIR)/run_all_tests.py; \
	fi

# Run basic tests (no external dependencies)
basic_tests:
	@echo "Running basic tests (no external dependencies)..."
	python3 run_basic_tests.py

# Setup for Ubuntu/Debian
setup_ubuntu:
	@echo "Setting up for Ubuntu/Debian..."
	chmod +x setup_ubuntu.sh
	./setup_ubuntu.sh

# Run advanced edge case tests
edge_cases:
	@echo "Running advanced edge case tests..."
	@if [ -f "venv/bin/activate" ]; then \
		. venv/bin/activate && python3 $(TB_DIR)/test_advanced_edge_cases.py; \
	else \
		python3 $(TB_DIR)/test_advanced_edge_cases.py; \
	fi

# Run fusion core advanced tests
fusion_advanced:
	@echo "Running fusion core advanced tests..."
	@if [ -f "venv/bin/activate" ]; then \
		. venv/bin/activate && python3 $(TB_DIR)/test_fusion_core_advanced.py; \
	else \
		python3 $(TB_DIR)/test_fusion_core_advanced.py; \
	fi

# Run stress tests
stress_tests:
	@echo "Running system stress tests..."
	@if [ -f "venv/bin/activate" ]; then \
		. venv/bin/activate && python3 $(TB_DIR)/test_system_stress.py; \
	else \
		python3 $(TB_DIR)/test_system_stress.py; \
	fi

# Run corrected system verification
corrected_system:
	@echo "Running corrected system verification..."
	@if [ -f "venv/bin/activate" ]; then \
		. venv/bin/activate && python3 $(TB_DIR)/test_corrected_system.py; \
	else \
		python3 $(TB_DIR)/test_corrected_system.py; \
	fi

# Run 500+ comprehensive test cases for Multi-Sensor Fusion System
fusion_system_500:
	@echo "Running 500+ Multi-Sensor Fusion System test cases..."
	@if [ -f "venv/bin/activate" ]; then \
		. venv/bin/activate && python3 $(TB_DIR)/test_multi_sensor_fusion_500.py; \
	else \
		python3 $(TB_DIR)/test_multi_sensor_fusion_500.py; \
	fi

# Run SystemVerilog testbench for Multi-Sensor Fusion System
sim_fusion_system: compile
	@echo "Running SystemVerilog simulation for Multi-Sensor Fusion System..."
	cd $(BUILD_DIR) && vlog $(VLOG_FLAGS) ../$(TB_DIR)/tb_multi_sensor_fusion_system.sv
	cd $(BUILD_DIR) && vsim $(VSIM_FLAGS) -c tb_multi_sensor_fusion_system -do "run -all; quit"

# Run all tests (Python + SystemVerilog)
all_tests: python_tests sim
	@echo "All tests completed!"

# Run all Python tests only
all_python_tests: basic_tests python_tests edge_cases fusion_advanced stress_tests corrected_system fusion_system_500
	@echo "All Python tests completed!"

# Run comprehensive testing (500+ tests + SystemVerilog)
comprehensive_test: fusion_system_500 sim_fusion_system
	@echo "Comprehensive testing completed!"

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
	@echo "  setup_ubuntu   - Setup environment for Ubuntu/Debian"
	@echo "  basic_tests    - Run basic tests (no external dependencies)"
	@echo "  compile        - Compile SystemVerilog design files"
	@echo "  sim           - Run SystemVerilog simulation (command line)"
	@echo "  sim_gui       - Run SystemVerilog simulation with GUI"
	@echo "  python_tests  - Run Python test suite"
	@echo "  edge_cases    - Run advanced edge case tests"
	@echo "  fusion_advanced - Run fusion core advanced tests"
	@echo "  stress_tests  - Run system stress tests"
	@echo "  corrected_system - Run corrected system verification"
	@echo "  fusion_system_500 - Run 500+ Multi-Sensor Fusion test cases"
	@echo "  sim_fusion_system - Run SystemVerilog testbench for Fusion System"
	@echo "  all_tests     - Run all tests (Python + SystemVerilog)"
	@echo "  all_python_tests - Run all Python tests only"
	@echo "  comprehensive_test - Run comprehensive testing (500+ tests + SV)"
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
	@echo "  make setup_ubuntu          # Setup for Ubuntu/Debian"
	@echo "  make basic_tests           # Run basic tests first"
	@echo "  make python_tests          # Run Python tests only"
	@echo "  make all_python_tests      # Run all Python tests"
	@echo "  make sim                   # Run basic simulation"
	@echo "  make sim_gui               # Run with GUI"
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
