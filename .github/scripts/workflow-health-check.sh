#!/usr/bin/env bash
#
# Workflow Health Check Script
# This script validates the GitHub Actions workflow configuration and environment
# to help diagnose startup issues.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in a GitHub Actions environment
check_github_environment() {
    log_info "Checking GitHub Actions environment..."
    
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        log_info "Running in GitHub Actions: ✓"
        log_info "Repository: ${GITHUB_REPOSITORY:-unknown}"
        log_info "Event: ${GITHUB_EVENT_NAME:-unknown}"
        log_info "Ref: ${GITHUB_REF:-unknown}"
        log_info "Actor: ${GITHUB_ACTOR:-unknown}"
        log_info "Runner OS: ${RUNNER_OS:-unknown}"
    else
        log_warn "Not running in GitHub Actions environment"
    fi
}

# Check required tools
check_required_tools() {
    log_info "Checking required tools..."
    
    local required_tools=("go" "node" "yarn" "docker" "git")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version
            case "$tool" in
                go)
                    version=$(go version 2>&1 || echo "unknown")
                    ;;
                node)
                    version=$(node --version 2>&1 || echo "unknown")
                    ;;
                yarn)
                    version=$(yarn --version 2>&1 || echo "unknown")
                    ;;
                docker)
                    version=$(docker --version 2>&1 || echo "unknown")
                    ;;
                git)
                    version=$(git --version 2>&1 || echo "unknown")
                    ;;
            esac
            log_info "$tool: ✓ ($version)"
        else
            log_error "$tool: ✗ (not found)"
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
}

# Check Go version compatibility
check_go_version() {
    log_info "Checking Go version compatibility..."
    
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed"
        return 1
    fi
    
    local go_version
    go_version=$(go version | awk '{print $3}' | sed 's/go//')
    local required_version="1.24.6"
    local toolchain_version="1.24.9"
    
    log_info "Installed Go version: $go_version"
    log_info "Required Go version: $required_version+"
    log_info "Toolchain Go version: $toolchain_version"
    
    # Version comparison: extract major.minor.patch and compare
    local go_major=$(echo "$go_version" | cut -d. -f1)
    local go_minor=$(echo "$go_version" | cut -d. -f2)
    local go_patch=$(echo "$go_version" | cut -d. -f3)
    local req_major=$(echo "$required_version" | cut -d. -f1)
    local req_minor=$(echo "$required_version" | cut -d. -f2)
    local req_patch=$(echo "$required_version" | cut -d. -f3)
    
    # Compare versions numerically
    if [ "$go_major" -lt "$req_major" ] || \
       ([ "$go_major" -eq "$req_major" ] && [ "$go_minor" -lt "$req_minor" ]) || \
       ([ "$go_major" -eq "$req_major" ] && [ "$go_minor" -eq "$req_minor" ] && [ "$go_patch" -lt "$req_patch" ]); then
        log_warn "Go version might be too old. Required: $required_version+, Found: $go_version"
    else
        log_info "Go version: ✓"
    fi
}

# Check Node version compatibility
check_node_version() {
    log_info "Checking Node version compatibility..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node is not installed"
        return 1
    fi
    
    local node_version
    node_version=$(node --version | sed 's/v//')
    local required_version="20"
    
    log_info "Installed Node version: $node_version"
    log_info "Required Node version: $required_version"
    
    local node_major
    node_major=$(echo "$node_version" | cut -d. -f1)
    
    if [ "$node_major" -lt "$required_version" ]; then
        log_error "Node version is too old. Required: $required_version, Found: $node_major"
        return 1
    else
        log_info "Node version: ✓"
    fi
}

# Check network connectivity
check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    local test_urls=(
        "https://github.com"
        "https://proxy.golang.org"
        "https://registry.npmjs.org"
        "https://hub.docker.com"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -s --max-time 5 --head "$url" > /dev/null 2>&1; then
            log_info "Connectivity to $url: ✓"
        else
            log_warn "Connectivity to $url: ✗ (may cause issues)"
        fi
    done
}

# Check Docker daemon
check_docker_daemon() {
    log_info "Checking Docker daemon..."
    
    if ! command -v docker &> /dev/null; then
        log_warn "Docker is not installed"
        return 0
    fi
    
    if docker info > /dev/null 2>&1; then
        log_info "Docker daemon: ✓"
        log_info "Docker info:"
        docker info 2>&1 | grep -E "Server Version|Operating System|OSType|Architecture" || true
    else
        log_warn "Docker daemon not running or not accessible"
    fi
}

# Check repository structure
check_repository_structure() {
    log_info "Checking repository structure..."
    
    local required_files=(
        "go.mod"
        "go.sum"
        "package.json"
        "yarn.lock"
        "Makefile"
        ".github/workflows/ci.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            log_info "$file: ✓"
        else
            log_error "$file: ✗ (missing)"
        fi
    done
}

# Check environment variables
check_environment_variables() {
    log_info "Checking important environment variables..."
    
    local env_vars=(
        "GITHUB_TOKEN"
        "GITHUB_REPOSITORY"
        "GITHUB_ACTOR"
        "RUNNER_OS"
        "GOPRIVATE"
    )
    
    for var in "${env_vars[@]}"; do
        if [ -n "${!var:-}" ]; then
            # Don't print token values
            if [[ "$var" == *"TOKEN"* ]] || [[ "$var" == *"PASSWORD"* ]]; then
                log_info "$var: ✓ (set, value hidden)"
            else
                log_info "$var: ✓ (${!var})"
            fi
        else
            log_warn "$var: not set"
        fi
    done
}

# Check workflow runner compatibility
check_runner_compatibility() {
    log_info "Checking runner compatibility..."
    
    local repository_owner="${GITHUB_REPOSITORY_OWNER:-unknown}"
    
    if [ "$repository_owner" = "grafana" ]; then
        log_info "Running in grafana organization: ✓"
        log_info "Custom runners (ubuntu-x64-large, etc.) should be available"
    else
        log_warn "Running in fork or non-grafana repository"
        log_warn "Custom runners not available, workflows will use standard GitHub runners"
        log_warn "Some jobs may be skipped or fail due to missing secrets/runners"
    fi
}

# Main execution
main() {
    echo "========================================"
    echo "Workflow Health Check"
    echo "========================================"
    echo ""
    
    check_github_environment
    echo ""
    
    check_required_tools
    echo ""
    
    check_go_version
    echo ""
    
    check_node_version
    echo ""
    
    check_network_connectivity
    echo ""
    
    check_docker_daemon
    echo ""
    
    check_repository_structure
    echo ""
    
    check_environment_variables
    echo ""
    
    check_runner_compatibility
    echo ""
    
    log_info "Health check complete!"
    echo ""
    echo "========================================"
    echo "For more information, see:"
    echo "  .github/docs/WORKFLOW_TROUBLESHOOTING.md"
    echo "========================================"
}

# Run the main function
main "$@"
