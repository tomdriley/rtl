#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# RTL Test Script
# 
# This script runs the core tests for RTL examples, mirroring what the CI does.
# It can be run locally or in a container with the same results.
# -----------------------------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "\n${BLUE}[STEP]${NC} $1"
    echo -e "${BLUE}=====${NC}${BLUE}=====${NC}"
}

# Verify setup
verify_setup() {
    log_step "Verifying environment setup"
    
    # Run setup script if it exists
    if [ -f "./setup.sh" ]; then
        ./setup.sh
    else
        log_error "setup.sh not found"
        return 1
    fi
}

# Test hello example
test_hello() {
    log_step "Testing hello example"
    
    if [ ! -d "./hello" ]; then
        log_error "hello directory not found"
        return 1
    fi
    
    (
        cd hello
        log_info "Building hello project..."
        make build
        
        log_info "Running hello simulation..."
        make run
    )
    
    log_info "✅ Hello example test passed"
}

# Test waves example
test_waves() {
    log_step "Testing waves example"
    
    if [ ! -d "./waves" ]; then
        log_error "waves directory not found"
        return 1
    fi
    
    (
        cd waves
        log_info "Building waves project..."
        make build
        
        log_info "Running waves simulation..."
        make run
        
        # Verify VCD file was generated
        if [ ! -f "waves.vcd" ]; then
            log_error "waves.vcd file not generated"
            exit 1  # Exit the subshell with error
        fi
    )
    
    log_info "✅ Waves example test passed"
}

# Test formal verification
test_formal() {
    log_step "Testing formal verification"
    
    if [ ! -d "./formal" ]; then
        log_error "formal directory not found"
        return 1
    fi
    
    (
        cd formal
        log_info "Running formal verification checks..."
        make formal
        
        log_info "Running cover analysis..."
        make cover
        
        # List generated trace files
        log_info "Generated trace files:"
        find . -name "*.vcd" -type f | sort
    )
    
    log_info "✅ Formal verification test passed"
}

# Run all tests
run_all_tests() {
    local failed_tests=0
    
    verify_setup || failed_tests=$((failed_tests+1))
    test_hello || failed_tests=$((failed_tests+1))
    test_waves || failed_tests=$((failed_tests+1))
    test_formal || failed_tests=$((failed_tests+1))
    
    log_step "Test Summary"
    
    if [ $failed_tests -eq 0 ]; then
        log_info "🎉 All tests passed successfully!"
        return 0
    else
        log_error "❌ $failed_tests test(s) failed"
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    case "${1:-all}" in
        all)
            run_all_tests
            ;;
        setup)
            verify_setup
            ;;
        hello)
            test_hello
            ;;
        waves)
            test_waves
            ;;
        formal)
            test_formal
            ;;
        *)
            echo "Usage: $0 [all|setup|hello|waves|formal]"
            echo ""
            echo "Options:"
            echo "  all    - Run all tests (default)"
            echo "  setup  - Only verify environment setup"
            echo "  hello  - Only test hello example"
            echo "  waves  - Only test waves example"
            echo "  formal - Only test formal verification"
            exit 1
            ;;
    esac
}

# Main entry point
parse_args "$@"
