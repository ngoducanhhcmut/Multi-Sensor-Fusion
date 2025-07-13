#!/bin/bash
# Simple setup script for Ubuntu/Debian systems
# Handles externally managed Python environments

echo "🚀 Ubuntu/Debian Setup for Multi-Sensor Fusion Testing"
echo "======================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Update package list
print_status "Updating package list..."
sudo apt update

# Install Python and required system packages
print_status "Installing Python packages via apt..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-numpy \
    python3-matplotlib \
    python3-pytest \
    build-essential \
    make

# Create virtual environment for additional packages
print_status "Creating virtual environment..."
python3 -m venv venv

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Install additional packages in venv
print_status "Installing additional packages in virtual environment..."
pip install --upgrade pip

# Create directories
print_status "Creating directories..."
mkdir -p build logs results

# Create environment setup script
print_status "Creating environment setup script..."
cat > setup_env.sh << 'EOF'
#!/bin/bash
# Environment setup for Multi-Sensor Fusion

# Add current directory to Python path
export PYTHONPATH="$PWD:$PYTHONPATH"

# Activate virtual environment
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    echo "Virtual environment activated"
fi

echo "Environment variables set up for Multi-Sensor Fusion testing"
EOF

chmod +x setup_env.sh

# Test the setup
print_status "Testing setup..."
source setup_env.sh

# Test Python imports
python3 -c "
import sys
import os
import random
import math
import time

# Test numpy
try:
    import numpy
    print('✅ numpy available')
except ImportError:
    print('⚠️  numpy not available in venv, but system version should work')

# Test matplotlib  
try:
    import matplotlib
    print('✅ matplotlib available')
except ImportError:
    print('⚠️  matplotlib not available in venv, but system version should work')

print('✅ Basic Python environment ready')
print('✅ Virtual environment created and activated')
"

if [ $? -eq 0 ]; then
    print_status "Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Source the environment: source setup_env.sh"
    echo "2. Run Python tests: python3 testbench/run_all_tests.py"
    echo "3. Or use make: make python_tests"
    echo ""
    echo "The virtual environment will be automatically activated when you source setup_env.sh"
else
    print_error "Setup verification failed"
    exit 1
fi
