#!/bin/bash
# =============================================================================
# build_macos_silicon.sh - Native Apple Silicon (arm64) Build Script for Cemu
# =============================================================================
#
# This script builds Cemu natively for Apple Silicon Macs (M1/M2/M3/M4).
# It configures CMake for arm64 architecture and uses Ninja as the generator.
#
# Prerequisites:
#   - Xcode 15 or later with Command Line Tools
#   - Homebrew (native arm64 version)
#   - Required packages: git cmake ninja nasm automake libtool boost molten-vk
#
# Usage:
#   ./build_macos_silicon.sh [options]
#
# Options:
#   --release     Build in release mode (default)
#   --debug       Build in debug mode
#   --clean       Clean the build directory before building
#   --bundle      Create a macOS application bundle
#   --jobs N      Number of parallel jobs (default: auto-detect)
#   --help        Show this help message
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
BUILD_TYPE="release"
CLEAN_BUILD=false
CREATE_BUNDLE=false
PARALLEL_JOBS=""

# Script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build_arm64"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

show_help() {
    echo "Cemu Apple Silicon (arm64) Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --release     Build in release mode (default)"
    echo "  --debug       Build in debug mode"
    echo "  --clean       Clean the build directory before building"
    echo "  --bundle      Create a macOS application bundle"
    echo "  --jobs N      Number of parallel jobs (default: auto-detect)"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Standard release build"
    echo "  $0 --debug            # Debug build"
    echo "  $0 --clean --release  # Clean release build"
    echo "  $0 --bundle           # Create .app bundle"
    exit 0
}

# -----------------------------------------------------------------------------
# Parse Command Line Arguments
# -----------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_TYPE="release"
            shift
            ;;
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --bundle)
            CREATE_BUNDLE=true
            shift
            ;;
        --jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Check Prerequisites
# -----------------------------------------------------------------------------

print_header "Checking Prerequisites"

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    print_warning "This script is designed for Apple Silicon (arm64)."
    print_warning "Current architecture: $ARCH"
    print_warning "Continuing anyway, but you may want to use arch -arm64 to run this script."
fi

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    print_error "Homebrew is not installed. Please install it first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi
print_success "Homebrew found"

# Check for required tools
REQUIRED_TOOLS=("cmake" "ninja" "git" "nasm")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        print_error "$tool is not installed. Please install it with:"
        echo "  brew install $tool"
        exit 1
    fi
    print_success "$tool found"
done

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    print_error "Xcode Command Line Tools not found. Install with:"
    echo "  xcode-select --install"
    exit 1
fi
print_success "Xcode Command Line Tools found"

# Check compiler version
CLANG_VERSION=$(clang --version | head -1)
print_success "Compiler: $CLANG_VERSION"

# -----------------------------------------------------------------------------
# Setup Build Directory
# -----------------------------------------------------------------------------

print_header "Setting Up Build Environment"

if [[ "$CLEAN_BUILD" == true ]] && [[ -d "$BUILD_DIR" ]]; then
    print_warning "Cleaning build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
print_success "Build directory: $BUILD_DIR"

# -----------------------------------------------------------------------------
# Configure CMake
# -----------------------------------------------------------------------------

print_header "Configuring CMake (${BUILD_TYPE})"

# Build CMake command
CMAKE_ARGS=(
    "-S" "$SCRIPT_DIR"
    "-B" "$BUILD_DIR"
    "-DCMAKE_BUILD_TYPE=${BUILD_TYPE}"
    "-DCMAKE_OSX_ARCHITECTURES=arm64"
    "-G" "Ninja"
)

# Add bundle option if requested
if [[ "$CREATE_BUNDLE" == true ]]; then
    CMAKE_ARGS+=("-DMACOS_BUNDLE=ON")
fi

# Find ninja path
NINJA_PATH=$(which ninja)
if [[ -n "$NINJA_PATH" ]]; then
    CMAKE_ARGS+=("-DCMAKE_MAKE_PROGRAM=${NINJA_PATH}")
fi

echo "Running: cmake ${CMAKE_ARGS[*]}"
cmake "${CMAKE_ARGS[@]}"

print_success "CMake configuration complete"

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

print_header "Building Cemu"

BUILD_ARGS=("--build" "$BUILD_DIR")

# Add parallel jobs if specified
if [[ -n "$PARALLEL_JOBS" ]]; then
    BUILD_ARGS+=("--parallel" "$PARALLEL_JOBS")
else
    # Auto-detect number of cores
    NUM_CORES=$(sysctl -n hw.ncpu)
    BUILD_ARGS+=("--parallel" "$NUM_CORES")
    echo "Using $NUM_CORES parallel jobs"
fi

echo "Running: cmake ${BUILD_ARGS[*]}"
cmake "${BUILD_ARGS[@]}"

print_success "Build complete"

# -----------------------------------------------------------------------------
# Post-Build Summary
# -----------------------------------------------------------------------------

print_header "Build Summary"

EXECUTABLE="${SCRIPT_DIR}/bin/Cemu_${BUILD_TYPE}"
if [[ "$CREATE_BUNDLE" == true ]]; then
    EXECUTABLE="${SCRIPT_DIR}/bin/Cemu.app"
fi

if [[ -e "$EXECUTABLE" ]]; then
    print_success "Build successful!"
    echo ""
    echo "Executable location:"
    echo "  $EXECUTABLE"
    echo ""
    if [[ "$CREATE_BUNDLE" == true ]]; then
        echo "To run Cemu:"
        echo "  open ${EXECUTABLE}"
    else
        echo "To run Cemu:"
        echo "  ${EXECUTABLE}"
    fi
else
    print_warning "Executable not found at expected location."
    echo "Check the bin/ directory for output files."
fi

echo ""
print_success "Done!"
