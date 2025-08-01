#!/bin/bash
set -e

# Build script for overlaybd .deb packages
# Usage: ./build-deb.sh [OPTIONS]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
ARCH=$(uname -m)
VERSION=""
RELEASE_NO=$(date +%Y%m%d)
UBUNTU_VERSION="24.04"
BUILD_TYPE="Release"
JOBS=$(nproc)
CLEAN_BUILD=false
DOCKER_PLATFORM="amd64"

show_help() {
    cat << EOF
Build overlaybd .deb packages for Ubuntu 24.04 using Docker

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --version VERSION   Set package version (default: auto-detected from git)
    -r, --release RELEASE   Set release number (default: YYYYMMDD format)
    -u, --ubuntu VERSION    Ubuntu version (default: 24.04)
    -a, --arch ARCH         Target architecture (amd64|arm64, default: amd64)

Examples:
    $0                           # Build for amd64
    $0 -a arm64                  # Build for arm64
    $0 -v 1.2.3 -a amd64        # Build version 1.2.3 for amd64
    $0 -u 22.04 -a arm64        # Build for Ubuntu 22.04 arm64

EOF
}

detect_version() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Try to get latest tag
        local latest_tag=$(git tag --sort=v:refname -l v* | tail -1 2>/dev/null || echo "")
        if [[ -n "$latest_tag" ]]; then
            VERSION="${latest_tag#v}"
        else
            VERSION="0.1.0"
        fi
        local commit_id=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        VERSION="${VERSION}-${commit_id}"
    else
        VERSION="0.1.0-unknown"
    fi
}

docker_build() {
    local platform="linux/${DOCKER_PLATFORM}"
    echo "Building .deb package using Docker for ${platform}..."
    
    local commit_id="${VERSION}-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
    
    docker buildx build \
        --build-arg BUILD_IMAGE="ubuntu:${UBUNTU_VERSION}" \
        --build-arg OS="ubuntu:${UBUNTU_VERSION}" \
        --build-arg RELEASE_VERSION="${VERSION}" \
        --build-arg RELEASE_NO="${RELEASE_NO}" \
        --build-arg COMMIT_ID="${commit_id}" \
        -f .github/workflows/release/Dockerfile \
        --platform="${platform}" \
        -o releases/ .
    
    echo "Docker build completed. Package saved in releases/"
}


# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NO="$2"
            shift 2
            ;;
        -u|--ubuntu)
            UBUNTU_VERSION="$2"
            shift 2
            ;;
        -a|--arch)
            DOCKER_PLATFORM="$2"
            if [[ "$DOCKER_PLATFORM" != "amd64" && "$DOCKER_PLATFORM" != "arm64" ]]; then
                echo "Error: Architecture must be amd64 or arm64"
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Auto-detect version if not provided
if [[ -z "$VERSION" ]]; then
    detect_version
fi

echo "Build configuration:"
echo "  Version: $VERSION"
echo "  Release: $RELEASE_NO"
echo "  Ubuntu: $UBUNTU_VERSION"
echo "  Target Architecture: $DOCKER_PLATFORM"
echo "  Using Docker: yes"
echo

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    echo "Please install Docker Desktop and make sure it's running"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    echo "Please start Docker Desktop"
    exit 1
fi

# Build using Docker
docker_build