#!/bin/bash
# HLSL Unity Shader Pipeline Installation Script for macOS
# This script installs all required dependencies for the HLSL pipeline

set -e  # Exit on error

echo "=========================================="
echo "HLSL Unity Pipeline Installer"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script is designed for macOS only${NC}"
    exit 1
fi

echo "Step 1/4: Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
    echo -e "${GREEN}✓ Xcode Command Line Tools already installed${NC}"
else
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo "Please complete the Xcode installation dialog, then re-run this script."
    exit 1
fi

echo ""
echo "Step 2/4: Checking Homebrew..."
if command -v brew &>/dev/null; then
    echo -e "${GREEN}✓ Homebrew already installed${NC}"
    BREW_VERSION=$(brew --version | head -n 1)
    echo "  $BREW_VERSION"
else
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    echo -e "${GREEN}✓ Homebrew installed${NC}"
fi

echo ""
echo "Step 3/4: Checking DXC (DirectX Shader Compiler)..."
if command -v dxc &>/dev/null; then
    echo -e "${GREEN}✓ DXC already installed${NC}"
    DXC_PATH=$(which dxc)
    echo "  Location: $DXC_PATH"
else
    echo -e "${YELLOW}Installing DXC via Homebrew...${NC}"
    brew install directx-shader-compiler

    if command -v dxc &>/dev/null; then
        echo -e "${GREEN}✓ DXC installed successfully${NC}"
        DXC_PATH=$(which dxc)
        echo "  Location: $DXC_PATH"
    else
        echo -e "${RED}✗ DXC installation failed${NC}"
        echo "Try manual installation from: https://github.com/microsoft/DirectXShaderCompiler/releases"
        exit 1
    fi
fi

echo ""
echo "Step 4/4: Checking spirv-cross..."
if command -v spirv-cross &>/dev/null; then
    echo -e "${GREEN}✓ spirv-cross already installed${NC}"
    SPIRV_PATH=$(which spirv-cross)
    echo "  Location: $SPIRV_PATH"
else
    echo -e "${YELLOW}Installing spirv-cross via Homebrew...${NC}"
    brew install spirv-cross

    if command -v spirv-cross &>/dev/null; then
        echo -e "${GREEN}✓ spirv-cross installed successfully${NC}"
        SPIRV_PATH=$(which spirv-cross)
        echo "  Location: $SPIRV_PATH"
    else
        echo -e "${RED}✗ spirv-cross installation failed${NC}"
        echo "Try manual installation from: https://github.com/KhronosGroup/SPIRV-Cross"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

# Verify swiftc
echo "Checking Swift compiler..."
if command -v swiftc &>/dev/null; then
    SWIFT_VERSION=$(swiftc --version | head -n 1)
    echo -e "${GREEN}✓ Swift: $SWIFT_VERSION${NC}"
else
    echo -e "${RED}✗ Swift compiler not found${NC}"
    echo "Re-run: xcode-select --install"
    exit 1
fi

# Verify DXC
echo "Checking DXC..."
if command -v dxc &>/dev/null; then
    DXC_VERSION=$(dxc --version 2>&1 | head -n 1 || echo "DXC installed")
    echo -e "${GREEN}✓ DXC: $DXC_VERSION${NC}"
else
    echo -e "${RED}✗ DXC not found in PATH${NC}"
    exit 1
fi

# Verify spirv-cross
echo "Checking spirv-cross..."
if command -v spirv-cross &>/dev/null; then
    SPIRV_VERSION=$(spirv-cross --version 2>&1 | head -n 1 || echo "spirv-cross installed")
    echo -e "${GREEN}✓ spirv-cross: $SPIRV_VERSION${NC}"
else
    echo -e "${RED}✗ spirv-cross not found in PATH${NC}"
    exit 1
fi

# Verify Metal support
echo "Checking Metal support..."
if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Metal"; then
    echo -e "${GREEN}✓ Metal GPU support detected${NC}"
else
    echo -e "${YELLOW}⚠ Metal support not detected (may still work)${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Installation Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Read the setup guide: cat HLSL_SETUP.md"
echo "2. Test the toolchain:"
echo "   cd llm_harness"
echo "   python3 -c \"from hlsl_runtime import check_hlsl_toolchain; print(check_hlsl_toolchain()[1])\""
echo ""
echo "3. Run a test shader:"
echo "   python main.py --model 'anthropic/claude-3.5-sonnet-20241022' \\"
echo "                  --prompt-folder '../problems/base_set/geometric_cube' \\"
echo "                  --language-spec hlsl_unity"
echo ""
echo "For detailed documentation, see: HLSL_SETUP.md"
echo ""
