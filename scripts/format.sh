#!/usr/bin/env bash
# scripts/format.sh
# Code formatting script for prompt-tower.nvim

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
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --check)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run|--check] [-h|--help]"
            echo ""
            echo "Options:"
            echo "  --dry-run, --check  Check formatting without making changes"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🎨 Formatting prompt-tower.nvim code...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

cd "$PROJECT_ROOT"

# 1. StyLua formatting
if command_exists stylua; then
    echo -e "\n${YELLOW}🔧 Running StyLua...${NC}"

    if [ "$DRY_RUN" = true ]; then
        if stylua --check lua/ tests/; then
            echo -e "${GREEN}✅ StyLua: Code is properly formatted${NC}"
        else
            echo -e "${RED}❌ StyLua: Code needs formatting${NC}"
            echo -e "${YELLOW}💡 Run 'scripts/format.sh' to fix formatting${NC}"
            exit 1
        fi
    else
        stylua lua/ tests/
        echo -e "${GREEN}✅ StyLua: Formatted Lua files${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  StyLua not found, skipping Lua formatting${NC}"
    echo -e "${YELLOW}💡 Install with: cargo install stylua${NC}"
fi

# 2. Remove trailing whitespace
echo -e "\n${YELLOW}🧹 Checking/fixing trailing whitespace...${NC}"

if [ "$DRY_RUN" = true ]; then
    if grep -r --include="*.lua" --include="*.md" --include="*.sh" '[[:space:]]$' .; then
        echo -e "${RED}❌ Trailing whitespace found${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ No trailing whitespace found${NC}"
    fi
else
    # Remove trailing whitespace from relevant files
    find . -name "*.lua" -o -name "*.md" -o -name "*.sh" | \
        xargs sed -i '' 's/[[:space:]]*$//'
    echo -e "${GREEN}✅ Removed trailing whitespace${NC}"
fi

# 3. Ensure files end with newline
echo -e "\n${YELLOW}📝 Checking/fixing file endings...${NC}"

if [ "$DRY_RUN" = true ]; then
    MISSING_NEWLINE=0
    while IFS= read -r -d '' file; do
        if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
            echo -e "${RED}❌ Missing newline at end of file: $file${NC}"
            MISSING_NEWLINE=1
        fi
    done < <(find . -name "*.lua" -o -name "*.md" -o -name "*.sh" -print0)

    if [ $MISSING_NEWLINE -eq 0 ]; then
        echo -e "${GREEN}✅ All files end with newline${NC}"
    else
        exit 1
    fi
else
    # Ensure files end with newline
    find . -name "*.lua" -o -name "*.md" -o -name "*.sh" | while read -r file; do
        if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
            echo "" >> "$file"
            echo -e "${GREEN}✅ Added newline to: $file${NC}"
        fi
    done
    echo -e "${GREEN}✅ All files end with newline${NC}"
fi

# 4. Fix shell script permissions
if [ "$DRY_RUN" = false ]; then
    echo -e "\n${YELLOW}🔐 Setting script permissions...${NC}"
    find scripts/ -name "*.sh" -exec chmod +x {} \;
    echo -e "${GREEN}✅ Set executable permissions on shell scripts${NC}"
fi

# Summary
echo -e "\n${BLUE}📊 Formatting Summary${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}🔍 Formatting check completed${NC}"
else
    echo -e "${GREEN}🎉 Code formatting completed!${NC}"
fi
