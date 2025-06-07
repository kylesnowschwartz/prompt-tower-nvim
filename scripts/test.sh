#!/usr/bin/env bash
# scripts/test.sh
# Test runner script for prompt-tower.nvim

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
NVIM="${NVIM:-nvim}"
TEST_PATTERN="*_spec.lua"
VERBOSE=false
COVERAGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -p|--pattern)
            TEST_PATTERN="$2"
            shift 2
            ;;
        --nvim)
            NVIM="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose      Enable verbose output"
            echo "  -c, --coverage     Run with coverage (if available)"
            echo "  -p, --pattern      Test file pattern (default: *_spec.lua)"
            echo "  --nvim PATH        Path to Neovim binary (default: nvim)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                 Run all tests"
            echo "  $0 -v              Run tests with verbose output"
            echo "  $0 -p config       Run only config tests"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🧪 Running tests for prompt-tower.nvim...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

cd "$PROJECT_ROOT"

# Check if Neovim is available
if ! command_exists "$NVIM"; then
    echo -e "${RED}❌ Neovim not found at: $NVIM${NC}"
    echo -e "${YELLOW}💡 Install Neovim or specify path with --nvim${NC}"
    exit 1
fi

# Check Neovim version
echo -e "\n${YELLOW}📋 Checking Neovim version...${NC}"
NVIM_VERSION=$($NVIM --version | head -n1)
echo -e "${GREEN}✅ Using: $NVIM_VERSION${NC}"

# Check if plenary is available (simple check, tests will fail gracefully if not available)
echo -e "\n${YELLOW}📦 Checking for plenary.nvim...${NC}"
echo -e "${GREEN}✅ Proceeding with test execution (plenary availability will be tested during run)${NC}"

# Find test files
echo -e "\n${YELLOW}🔍 Finding test files...${NC}"
TEST_FILES=$(find tests/ -name "$TEST_PATTERN" | sort)
TEST_COUNT=$(echo "$TEST_FILES" | wc -l)

if [ -z "$TEST_FILES" ] || [ "$TEST_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ No test files found matching pattern: $TEST_PATTERN${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found $TEST_COUNT test files${NC}"
if [ "$VERBOSE" = true ]; then
    echo "$TEST_FILES" | sed 's/^/  - /'
fi

# Run tests
echo -e "\n${BLUE}🚀 Running tests...${NC}"

# Set up test command
TEST_CMD="$NVIM --headless -u tests/minimal_init.lua"

if [ "$VERBOSE" = true ]; then
    TEST_CMD="$TEST_CMD -c 'lua require(\"plenary.test_harness\").test_directory(\"tests\", { minimal_init = \"tests/minimal_init.lua\" })'"
else
    TEST_CMD="$TEST_CMD -c 'PlenaryBustedDirectory tests { minimal_init = \"tests/minimal_init.lua\" }'"
fi

# Create temporary log file
LOG_FILE=$(mktemp)
trap 'rm -f "$LOG_FILE"' EXIT

# Run the tests
echo -e "${YELLOW}📝 Test output:${NC}"
echo "----------------------------------------"

if eval "$TEST_CMD" 2>&1 | tee "$LOG_FILE"; then
    echo "----------------------------------------"
    echo -e "${GREEN}✅ All tests passed!${NC}"

    # Extract test summary if available
    if grep -q "Success" "$LOG_FILE"; then
        SUMMARY=$(grep -E "(Success|Total|Passed|Failed)" "$LOG_FILE" | tail -n 3)
        echo -e "\n${BLUE}📊 Test Summary:${NC}"
        echo "$SUMMARY"
    fi

    TEST_EXIT=0
else
    echo "----------------------------------------"
    echo -e "${RED}❌ Some tests failed${NC}"

    # Show failure summary
    if grep -q "FAIL" "$LOG_FILE"; then
        echo -e "\n${RED}💥 Failed Tests:${NC}"
        grep "FAIL" "$LOG_FILE" || true
    fi

    TEST_EXIT=1
fi

# Performance check
echo -e "\n${YELLOW}⏱️  Performance check...${NC}"
START_TIME=$(date +%s%N)
$NVIM --headless \
    -c "lua vim.opt.rtp:prepend('.'); require('prompt-tower')" \
    -c "qall" 2>/dev/null
END_TIME=$(date +%s%N)
LOAD_TIME=$(( (END_TIME - START_TIME) / 1000000 )) # Convert to milliseconds

if [ $LOAD_TIME -lt 100 ]; then
    echo -e "${GREEN}✅ Plugin loads quickly (${LOAD_TIME}ms)${NC}"
elif [ $LOAD_TIME -lt 500 ]; then
    echo -e "${YELLOW}⚠️  Plugin load time: ${LOAD_TIME}ms${NC}"
else
    echo -e "${RED}❌ Plugin loads slowly (${LOAD_TIME}ms)${NC}"
fi

# Coverage report (if requested and available)
if [ "$COVERAGE" = true ]; then
    echo -e "\n${YELLOW}📈 Coverage analysis...${NC}"
    echo -e "${YELLOW}💡 Coverage analysis not yet implemented${NC}"
fi

# Final summary
echo -e "\n${BLUE}📊 Test Run Summary${NC}"
echo "Test files: $TEST_COUNT"
echo "Load time: ${LOAD_TIME}ms"

if [ $TEST_EXIT -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests completed successfully!${NC}"
else
    echo -e "${RED}💥 Test run failed${NC}"
fi

exit $TEST_EXIT
