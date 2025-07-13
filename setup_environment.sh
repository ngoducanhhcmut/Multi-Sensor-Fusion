#!/bin/bash
# Setup script for Multi-Sensor Fusion Testing Environment

echo "🚀 Setting up Multi-Sensor Fusion Testing Environment"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running on supported OS
check_os() {
    print_header "Checking Operating System"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "Linux detected"
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "macOS detected"
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        print_status "Windows detected"
        OS="windows"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

# Check Python installation
check_python() {
    print_header "Checking Python Installation"
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
        print_status "Python 3 found: $PYTHON_VERSION"
        
        # Check if version is 3.7 or higher
        if python3 -c "import sys; exit(0 if sys.version_info >= (3, 7) else 1)"; then
            print_status "Python version is compatible"
        else
            print_error "Python 3.7 or higher required"
            exit 1
        fi
    else
        print_error "Python 3 not found. Please install Python 3.7 or higher"
        exit 1
    fi
}

# Install Python dependencies
install_python_deps() {
    print_header "Installing Python Dependencies"
    
    # Check if pip is available
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 not found. Please install pip"
        exit 1
    fi
    
    # Install required packages
    print_status "Installing Python packages..."
    pip3 install --user numpy matplotlib pytest cocotb cocotb-test
    
    if [ $? -eq 0 ]; then
        print_status "Python dependencies installed successfully"
    else
        print_warning "Some Python packages may have failed to install"
    fi
}

# Check SystemVerilog simulator
check_simulator() {
    print_header "Checking SystemVerilog Simulator"
    
    SIMULATOR_FOUND=false
    
    # Check for Questa/ModelSim
    if command -v vsim &> /dev/null; then
        VSIM_VERSION=$(vsim -version | head -n1)
        print_status "Found simulator: $VSIM_VERSION"
        SIMULATOR_FOUND=true
    fi
    
    # Check for VCS
    if command -v vcs &> /dev/null; then
        VCS_VERSION=$(vcs -ID | grep "VCS version" | head -n1)
        print_status "Found VCS: $VCS_VERSION"
        SIMULATOR_FOUND=true
    fi
    
    # Check for Verilator (open source)
    if command -v verilator &> /dev/null; then
        VERILATOR_VERSION=$(verilator --version | head -n1)
        print_status "Found Verilator: $VERILATOR_VERSION"
        SIMULATOR_FOUND=true
    fi
    
    # Check for Icarus Verilog (open source)
    if command -v iverilog &> /dev/null; then
        IVERILOG_VERSION=$(iverilog -V | head -n1)
        print_status "Found Icarus Verilog: $IVERILOG_VERSION"
        SIMULATOR_FOUND=true
    fi
    
    if [ "$SIMULATOR_FOUND" = false ]; then
        print_warning "No SystemVerilog simulator found"
        print_warning "You can still run Python tests, but SystemVerilog simulation will not work"
        print_warning "Consider installing one of the following:"
        echo "  - Questa/ModelSim (commercial)"
        echo "  - VCS (commercial)"
        echo "  - Verilator (open source)"
        echo "  - Icarus Verilog (open source)"
    fi
}

# Check for Make
check_make() {
    print_header "Checking Build Tools"
    
    if command -v make &> /dev/null; then
        MAKE_VERSION=$(make --version | head -n1)
        print_status "Found Make: $MAKE_VERSION"
    else
        print_error "Make not found. Please install build tools"
        if [ "$OS" = "linux" ]; then
            echo "  Ubuntu/Debian: sudo apt-get install build-essential"
            echo "  CentOS/RHEL: sudo yum groupinstall 'Development Tools'"
        elif [ "$OS" = "macos" ]; then
            echo "  Install Xcode command line tools: xcode-select --install"
        fi
        exit 1
    fi
}

# Create directory structure
setup_directories() {
    print_header "Setting up Directory Structure"
    
    # Create build directory
    mkdir -p build
    print_status "Created build directory"
    
    # Create logs directory
    mkdir -p logs
    print_status "Created logs directory"
    
    # Create results directory
    mkdir -p results
    print_status "Created results directory"
}

# Set up environment variables
setup_environment() {
    print_header "Setting up Environment Variables"
    
    # Create environment setup script
    cat > setup_env.sh << 'EOF'
#!/bin/bash
# Environment setup for Multi-Sensor Fusion

# Add current directory to Python path
export PYTHONPATH="$PWD:$PYTHONPATH"

# Set up simulator paths (modify as needed)
# export QUESTA_HOME="/path/to/questa"
# export VCS_HOME="/path/to/vcs"
# export PATH="$QUESTA_HOME/bin:$VCS_HOME/bin:$PATH"

# Set up license servers (modify as needed)
# export LM_LICENSE_FILE="port@server:$LM_LICENSE_FILE"

echo "Environment variables set up for Multi-Sensor Fusion testing"
EOF
    
    chmod +x setup_env.sh
    print_status "Created setup_env.sh script"
}

# Run basic tests to verify setup
verify_setup() {
    print_header "Verifying Setup"
    
    # Test Python imports
    print_status "Testing Python imports..."
    python3 -c "import numpy, random, math, time" 2>/dev/null
    if [ $? -eq 0 ]; then
        print_status "Python imports successful"
    else
        print_error "Python import test failed"
        return 1
    fi
    
    # Test basic Python test
    print_status "Running basic Python test..."
    python3 -c "
import sys
sys.path.append('testbench')
print('Python test environment ready')
"
    
    if [ $? -eq 0 ]; then
        print_status "Python test environment verified"
    else
        print_error "Python test environment verification failed"
        return 1
    fi
    
    return 0
}

# Main setup function
main() {
    print_header "Multi-Sensor Fusion Testing Environment Setup"
    
    check_os
    check_python
    install_python_deps
    check_simulator
    check_make
    setup_directories
    setup_environment
    
    if verify_setup; then
        print_header "Setup Complete"
        print_status "Environment setup completed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. Source the environment: source setup_env.sh"
        echo "2. Run Python tests: make python_tests"
        echo "3. Run SystemVerilog simulation: make sim"
        echo "4. Run all tests: make all_tests"
        echo ""
        echo "For help: make help"
    else
        print_error "Setup verification failed"
        exit 1
    fi
}

# Run main function
main "$@"
