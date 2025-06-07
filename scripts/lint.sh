#!/usr/bin/env bash
# scripts/lint.sh
# Comprehensive linting script for prompt-tower.nvim

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
EXIT_CODE=0

echo -e "${BLUE}🔍 Running linting checks for prompt-tower.nvim...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run a linter and track results
run_linter() {
    local name="$1"
    local cmd="$2"
    local required="${3:-false}"

    echo -e "\n${YELLOW}📋 Running $name...${NC}"

    if ! command_exists "$(echo "$cmd" | cut -d' ' -f1)"; then
        if [ "$required" = "true" ]; then
            echo -e "${RED}❌ $name: Command not found${NC}"
            EXIT_CODE=1
            return 1
        else
            echo -e "${YELLOW}⚠️  $name: Skipped (command not found)${NC}"
            return 0
        fi
    fi

    if eval "$cmd"; then
        echo -e "${GREEN}✅ $name: Passed${NC}"
        return 0
    else
        echo -e "${RED}❌ $name: Failed${NC}"
        EXIT_CODE=1
        return 1
    fi
}

cd "$PROJECT_ROOT"

# 1. Lua syntax checking (required)
run_linter "Lua Syntax Check" "find lua/ tests/ -name '*.lua' -exec luac -p {} \;" true

# 2. Stylua formatting check (optional but recommended)
run_linter "StyLua Format Check" "stylua --check lua/ tests/" false

# 3. Selene linting (optional)
run_linter "Selene Linting" "selene lua/" false

# 4. Check for trailing whitespace
echo -e "\n${YELLOW}📋 Checking for trailing whitespace...${NC}"
if grep -r --include="*.lua" --include="*.md" --include="*.sh" '[[:space:]]$' .; then
    echo -e "${RED}❌ Trailing whitespace found${NC}"
    EXIT_CODE=1
else
    echo -e "${GREEN}✅ No trailing whitespace found${NC}"
fi

# 5. Check for tabs (we prefer spaces)
echo -e "\n${YELLOW}📋 Checking for tabs...${NC}"
if grep -r --include="*.lua" $'\t' lua/ tests/; then
    echo -e "${RED}❌ Tabs found (please use spaces)${NC}"
    EXIT_CODE=1
else
    echo -e "${GREEN}✅ No tabs found${NC}"
fi

# 6. Check file permissions
echo -e "\n${YELLOW}📋 Checking file permissions...${NC}"
if find . -name "*.lua" -executable | grep -q .; then
    echo -e "${RED}❌ Executable Lua files found (should not be executable)${NC}"
    find . -name "*.lua" -executable
    EXIT_CODE=1
else
    echo -e "${GREEN}✅ File permissions correct${NC}"
fi

# 7. Check for TODO/FIXME comments (informational)
echo -e "\n${YELLOW}📋 Checking for TODO/FIXME comments...${NC}"
TODO_COUNT=$(grep -r --include="*.lua" -i "TODO\|FIXME\|XXX\|HACK" lua/ tests/ | wc -l || echo "0")
if [ "$TODO_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $TODO_COUNT TODO/FIXME comments${NC}"
    grep -r --include="*.lua" -n -i "TODO\|FIXME\|XXX\|HACK" lua/ tests/ || true
else
    echo -e "${GREEN}✅ No TODO/FIXME comments found${NC}"
fi

# 8. Check for long lines (>120 characters)
echo -e "\n${YELLOW}📋 Checking for long lines (>120 chars)...${NC}"
LONG_LINES=$(find lua/ tests/ -name "*.lua" -exec awk 'length($0) > 120 { print FILENAME ":" NR ":" $0 }' {} \; | wc -l || echo "0")
if [ "$LONG_LINES" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $LONG_LINES lines longer than 120 characters${NC}"
    find lua/ tests/ -name "*.lua" -exec awk 'length($0) > 120 { print FILENAME ":" NR ": Line too long (" length($0) " chars)" }' {} \;
else
    echo -e "${GREEN}✅ No overly long lines found${NC}"
fi

# Summary
echo -e "\n${BLUE}📊 Linting Summary${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}🎉 All linting checks passed!${NC}"
else
    echo -e "${RED}💥 Some linting checks failed${NC}"
fi

exit $EXIT_CODE
