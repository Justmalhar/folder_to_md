#!/bin/bash

# ==============================================================================
# folder_to_md.sh - Turn any folder into an LLM-ready markdown context file.
# ==============================================================================

VERSION="2.0.0"

# --- Colors & formatting ---
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

# --- Default Config ---
IGNORE_DIRS=(
    ".git"
    ".idea"
    ".vscode"
    "node_modules"
    "__pycache__"
    "venv"
    "env"
    "dist"
    "build"
    "coverage"
    ".next"
    ".nuxt"
    "target" # java/rust
    "bin"
    "obj"
)
IGNORE_FILES=(
    ".DS_Store"
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
    "Gemfile.lock"
    "composer.lock"
    "*.pyc"
    "*.log"
    ".env"
    "*.png"
    "*.jpg"
    "*.jpeg"
    "*.gif"
    "*.ico"
    "*.svg"
    "*.pdf"
    "*.zip"
    "*.tar.gz"
)

# User-configurable lists
USER_INCLUDES=()
USER_EXCLUDES=()
MAX_SIZE_BYTES="" # Empty means no limit

TARGET_DIR=""
OUTPUT_FILE=""
SHOW_TREE=true
VERBOSE=false

# --- Helper Functions ---

log_info() { echo "${BLUE}[INFO]${RESET} $1"; }
log_success() { echo "${GREEN}[SUCCESS]${RESET} $1"; }
log_warn() { echo "${YELLOW}[WARN]${RESET} $1"; }
log_error() { echo "${RED}[ERROR]${RESET} $1"; }
log_debug() { [[ "$VERBOSE" == "true" ]] && echo "${CYAN}[DEBUG]${RESET} $1"; }

print_banner() {
    echo "${BOLD}Folder to Markdown (Local GitIngest) v${VERSION}${RESET}"
    echo "------------------------------------------------"
}

usage() {
    echo "Usage: $0 [OPTIONS] [DIRECTORY]"
    echo ""
    echo "Arguments:"
    echo "  DIRECTORY           Path to the folder to process (default: current dir)"
    echo ""
    echo "Options:"
    echo "  -o, --output FILE   Specify output filename/path"
    echo "  -i, --include PATT  Include file pattern (e.g. '*.py'). Can be used multiple times."
    echo "  -e, --exclude PATT  Exclude file/dir pattern (e.g. 'tests/*'). Can be used multiple times."
    echo "  -s, --size BYTES    Max file size to process (e.g. 102400 for 100KB)"
    echo "  -n, --no-tree       Skip directory structure tree generation"
    echo "  -v, --verbose       Enable verbose logging"
    echo "  -h, --help          Show this help message"
    echo ""
    exit 0
}

is_binary() {
    local file="$1"
    
    # Fast mime check using 'file'
    if command -v file >/dev/null 2>&1; then
        local mime=$(file --mime-type -b "$file")
        if [[ "$mime" == text/* ]] || \
           [[ "$mime" == application/json ]] || \
           [[ "$mime" == application/xml ]] || \
           [[ "$mime" == application/javascript ]] || \
           [[ "$mime" == application/x-sh ]] || \
           [[ "$mime" == application/x-yaml ]] || \
           [[ "$mime" == inode/x-empty ]]; then
            echo "false"
        else
            echo "true"
        fi
        return
    fi
    
    # Fallback: Check for null bytes
    if grep -qP '\x00' "$file" 2>/dev/null; then echo "true"; else echo "false"; fi
}

# --- Argument Parsing ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)  OUTPUT_FILE="$2"; shift 2 ;;
        -i|--include) USER_INCLUDES+=("$2"); shift 2 ;;
        -e|--exclude) USER_EXCLUDES+=("$2"); shift 2 ;;
        -s|--size)    MAX_SIZE_BYTES="$2"; shift 2 ;;
        -n|--no-tree) SHOW_TREE=false; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help)    usage ;;
        -*)           log_error "Unknown option: $1"; usage ;;
        *) 
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            else
                log_error "Multiple directories specified. Only one allowed."
                exit 1
            fi
            shift 
            ;;
    esac
done

TARGET_DIR="${TARGET_DIR:-.}"
if [[ ! -d "$TARGET_DIR" ]]; then
    log_error "Directory '$TARGET_DIR' does not exist."
    exit 1
fi
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
FOLDER_NAME=$(basename "$TARGET_DIR")

# Determine Output File
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${TARGET_DIR}/${FOLDER_NAME}_context.md"
else
    # Resolve relative paths relative to CWD, not target dir, unless explicit
    # But usually user expects cli tool to output relative to where they ARE.
    # However we'll stick to absolute resolution.
    if [[ "$OUTPUT_FILE" != /* ]]; then
        OUTPUT_FILE="$(pwd)/${OUTPUT_FILE}"
    fi
    mkdir -p "$(dirname "$OUTPUT_FILE")"
fi

print_banner
log_info "Target Directory: $TARGET_DIR"
log_info "Output File:      $OUTPUT_FILE"

# --- Construct Find Logic ---
# Start find command
FIND_CMD=(find "$TARGET_DIR")

# 1. Always exclude the output file itself
FIND_CMD+=( -path "$OUTPUT_FILE" -prune -o )

# 2. Add Default Directory Exclusions (unless overridden? No, typically appended)
# Combine default ignores and user excludes for directories
# Note: user excludes like '*.log' are files, but 'node_modules' is dir. 
# find is tricky. simpler to have separate -type d excludes.

# Process Excludes (Types D & F mixed in arguments potentially)
# We will trust input patterns.
for ignore in "${IGNORE_DIRS[@]}"; do
    FIND_CMD+=( -type d -name "$ignore" -prune -o )
done

# User Excludes
for exclude in "${USER_EXCLUDES[@]}"; do
    # If it looks like a directory wildcard, we try both or just add name matching
    FIND_CMD+=( -name "$exclude" -prune -o )
done

# 3. Add Default File Exclusions (Prune/Skip)
for ignore in "${IGNORE_FILES[@]}"; do
    FIND_CMD+=( -type f -name "$ignore" -prune -o )
done

# 4. Inclusions (The most complex part)
# If user supplied includes, we MUST only print those.
# Find logic: ( <excludes> ) -o ( <includes> -print )
# But standard find prints everything not excluded unless we specify criteria.

if [[ ${#USER_INCLUDES[@]} -gt 0 ]]; then
    # We have specific includes.
    # Logic: Start a new group
    FIND_CMD+=( \( )
    first=true
    for include in "${USER_INCLUDES[@]}"; do
        if [ "$first" = true ]; then
            FIND_CMD+=( -name "$include" )
            first=false
        else
            FIND_CMD+=( -o -name "$include" )
        fi
    done
    FIND_CMD+=( \) -type f -print )
else
    # No inclusions specfied -> allow all remaining files
    FIND_CMD+=( -type f -print )
fi


# --- Execution ---

: > "$OUTPUT_FILE"

# Header
echo "# Repository: $FOLDER_NAME" >> "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 1. Tree
if [[ "$SHOW_TREE" == "true" ]]; then
    log_info "Generating structure..."
    echo "## Directory Structure" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
    if command -v tree &> /dev/null; then
        # Build ignore list for tree
        TREE_IGNORE=""
        for i in "${IGNORE_DIRS[@]}" "${IGNORE_FILES[@]}" "${USER_EXCLUDES[@]}"; do
            TREE_IGNORE="${TREE_IGNORE}|${i}"
        done
        TREE_IGNORE=${TREE_IGNORE:1} # trim first |
        
        # If includes are set, tree -P
        if [[ ${#USER_INCLUDES[@]} -gt 0 ]]; then
            TREE_MATCH=""
            for i in "${USER_INCLUDES[@]}"; do TREE_MATCH="${TREE_MATCH}|${i}"; done
            TREE_MATCH=${TREE_MATCH:1}
            tree -a -I "$TREE_IGNORE" -P "$TREE_MATCH" --prune --dirsfirst "$TARGET_DIR" >> "$OUTPUT_FILE"
        else
            tree -a -I "$TREE_IGNORE" --dirsfirst "$TARGET_DIR" >> "$OUTPUT_FILE"
        fi
    else
        ls -Rla "$TARGET_DIR" >> "$OUTPUT_FILE"
    fi
    echo '```' >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# 2. Content
log_info "Reading content..."
echo "## File Contents" >> "$OUTPUT_FILE"

# Count (approximate since we run find again, but safe enough)
TOTAL_FILES=$("${FIND_CMD[@]}" | wc -l | tr -d ' ')
CURRENT=0

"${FIND_CMD[@]}" | while read -r file; do
    ((CURRENT++))
    
    # Progress UI
    if [[ "$VERBOSE" != "true" ]]; then
       printf "\r${CYAN}Processing: [%d/%d]${RESET}" "$CURRENT" "$TOTAL_FILES" >&2
    fi

    # Check size if limit set
    if [[ -n "$MAX_SIZE_BYTES" ]]; then
        FILE_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null) # Mac/Linux compat
        if [[ "$FILE_SIZE" -gt "$MAX_SIZE_BYTES" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then log_warn "Skipping $file (Size $FILE_SIZE > $MAX_SIZE_BYTES)"; fi
            continue
        fi
    fi

    # Check binary
    if [[ "$(is_binary "$file")" == "true" ]]; then
        [[ "$VERBOSE" == "true" ]] && log_debug "Skipping binary: $file"
        continue
    fi
    
    REL_PATH=${file#$TARGET_DIR/}
    
    echo "================================================" >> "$OUTPUT_FILE"
    echo "FILE: $REL_PATH" >> "$OUTPUT_FILE"
    echo "================================================" >> "$OUTPUT_FILE"
    # Detect language for markdown fence? naive ext check
    EXT="${file##*.}"
    echo '```'"$EXT" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo '```' >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
done

echo ""
log_success "Done! Output: ${BOLD}$OUTPUT_FILE${RESET}"
