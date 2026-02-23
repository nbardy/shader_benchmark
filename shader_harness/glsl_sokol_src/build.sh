#!/bin/bash
#
# Build script for GLSL Sokol Harness
#
# This script compiles the GLSL Sokol harness executable for macOS.
# It downloads required header files (Sokol, stb_image_write) and compiles
# the C harness into a standalone executable.
#
# Usage:
#   ./build.sh
#
# Output:
#   ../glsl_sokol_build/glsl_sokol_harness (executable)
#

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../glsl_sokol_build"
HEADERS_DIR="$SCRIPT_DIR/headers"

echo "================================================"
echo "GLSL Sokol Harness Build Script"
echo "================================================"

# Create build and headers directories
mkdir -p "$BUILD_DIR"
mkdir -p "$HEADERS_DIR"

# Download Sokol headers if not present
echo ""
echo "Step 1: Downloading Sokol headers..."
if [ ! -f "$HEADERS_DIR/sokol_gfx.h" ]; then
    echo "  Downloading sokol_gfx.h..."
    curl -L -o "$HEADERS_DIR/sokol_gfx.h" \
        "https://raw.githubusercontent.com/floooh/sokol/master/sokol_gfx.h"
fi

if [ ! -f "$HEADERS_DIR/sokol_app.h" ]; then
    echo "  Downloading sokol_app.h..."
    curl -L -o "$HEADERS_DIR/sokol_app.h" \
        "https://raw.githubusercontent.com/floooh/sokol/master/sokol_app.h"
fi

if [ ! -f "$HEADERS_DIR/sokol_glue.h" ]; then
    echo "  Downloading sokol_glue.h..."
    curl -L -o "$HEADERS_DIR/sokol_glue.h" \
        "https://raw.githubusercontent.com/floooh/sokol/master/sokol_glue.h"
fi

if [ ! -f "$HEADERS_DIR/sokol_log.h" ]; then
    echo "  Downloading sokol_log.h..."
    curl -L -o "$HEADERS_DIR/sokol_log.h" \
        "https://raw.githubusercontent.com/floooh/sokol/master/sokol_log.h"
fi

# Download stb_image_write header
echo ""
echo "Step 2: Downloading stb_image_write.h..."
if [ ! -f "$HEADERS_DIR/stb_image_write.h" ]; then
    echo "  Downloading stb_image_write.h..."
    curl -L -o "$HEADERS_DIR/stb_image_write.h" \
        "https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h"
fi

echo "  ✓ All headers downloaded"

# Detect platform and configure compiler flags
echo ""
echo "Step 3: Detecting platform..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "  Platform: macOS"
    PLATFORM="macos"
    CC="clang"

    # Use OpenGL backend (better GLSL ES 3.0 compatibility)
    CFLAGS="-O2 -std=c11 -DSOKOL_GLCORE -I$HEADERS_DIR"
    LDFLAGS="-framework OpenGL -framework Cocoa"

    # Alternative: Use Metal backend (requires Objective-C compilation)
    # CFLAGS="-O2 -std=c11 -DSOKOL_METAL -I$HEADERS_DIR"
    # LDFLAGS="-framework Metal -framework Cocoa -framework QuartzCore -framework MetalKit"

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "  Platform: Linux"
    PLATFORM="linux"
    CC="gcc"
    CFLAGS="-O2 -std=c11 -DSOKOL_GLCORE -I$HEADERS_DIR"
    LDFLAGS="-lGL -lX11 -lXi -lXcursor -lpthread -lm"
else
    echo "  Error: Unsupported platform: $OSTYPE"
    exit 1
fi

# Compile the harness
echo ""
echo "Step 4: Compiling glsl_sokol_harness..."
echo "  Compiler: $CC"
echo "  Flags: $CFLAGS"
echo "  Linker flags: $LDFLAGS"

$CC $CFLAGS \
    "$SCRIPT_DIR/glsl_sokol_harness.m" \
    $LDFLAGS \
    -o "$BUILD_DIR/glsl_sokol_harness"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✓ Build successful!"
    echo "================================================"
    echo "Executable: $BUILD_DIR/glsl_sokol_harness"
    echo ""
    echo "Test it:"
    echo "  $BUILD_DIR/glsl_sokol_harness --help"
    echo ""
    echo "Example usage:"
    echo "  $BUILD_DIR/glsl_sokol_harness \\"
    echo "    --shader example.glsl \\"
    echo "    --output result.png \\"
    echo "    --width 1600 \\"
    echo "    --height 1600"
    echo ""
else
    echo ""
    echo "================================================"
    echo "✗ Build failed"
    echo "================================================"
    exit 1
fi
