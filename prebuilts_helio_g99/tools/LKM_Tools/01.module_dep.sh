#!/bin/bash

# ==============================================================================
#
#                    Stock Modules List Extractor
#
#   A simple script that extracts all module names from a stock modules.dep
#   file and outputs them to a clean text file. It supports both interactive
#   and non-interactive (argument-based) execution.
#
#   Purpose: Generate a master list of all LKM (.ko) files referenced
#           in the original modules.dep for Android GKI kernel builds.
#
#                              - ravindu644
# ==============================================================================

set -e  # Exit on any error

# --- Functions ---

print_header() {
    echo "========================================================================"
    echo "$1"
    echo "========================================================================"
}

sanitize_path() {
    # Remove quotes that might come from drag-and-drop or copy-paste
    echo "$1" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//'
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

show_help() {
    echo "Usage: $0 [OPTIONS] [ARGUMENTS...]"
    echo ""
    echo "Extracts all unique module (.ko) filenames from a modules.dep file."
    echo ""
    echo "Modes of Operation:"
    echo "  1. Interactive Mode: Run without any arguments to be prompted for paths."
    echo "     $0"
    echo ""
    echo "  2. Non-Interactive (Argument) Mode: Provide the input and output paths as arguments."
    echo "     $0 <path_to_modules.dep> <output_directory>"
    echo ""
    echo "Arguments:"
    echo "  <path_to_modules.dep>  Path to the stock modules.dep file."
    echo "  <output_directory>     Directory where 'modules_list.txt' will be saved."
    echo ""
    echo "Options:"
    echo "  -h, --help             Show this help message and exit."
    echo ""
}

# --- Main Script ---

# --- Argument Parsing ---

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

print_header "Stock Modules List Extractor"

# --- Input Collection ---

# Non-Interactive (Argument) Mode
if [ "$#" -eq 2 ]; then
    log_info "Running in Non-Interactive Mode."
    MODULES_DEP_RAW="$1"
    OUTPUT_DIR_RAW="$2"

# Interactive Mode
elif [ "$#" -eq 0 ]; then
    log_info "Running in Interactive Mode."
    echo "This script extracts all module names from a stock modules.dep file."
    echo ""
    read -e -p "Enter the path to your stock modules.dep file: " MODULES_DEP_RAW
    read -e -p "Enter output directory (press Enter for current directory): " OUTPUT_DIR_RAW

# Invalid arguments
else
    log_error "Invalid number of arguments. Use 0 for interactive mode or 2 for non-interactive."
    show_help
    exit 1
fi

# --- Input Validation and Setup ---

MODULES_DEP=$(sanitize_path "$MODULES_DEP_RAW")
OUTPUT_DIR=$(sanitize_path "$OUTPUT_DIR_RAW")

# Validate input file
if [ ! -f "$MODULES_DEP" ]; then
    log_error "modules.dep file not found at: '$MODULES_DEP'"
    exit 1
fi

# Use current directory if output directory is empty
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$(pwd)"
fi

# Validate output directory
if [ ! -d "$OUTPUT_DIR" ]; then
    log_error "Output directory not found: '$OUTPUT_DIR'"
    exit 1
fi

OUTPUT_FILE="$OUTPUT_DIR/modules_list.txt"

print_header "Processing modules.dep file"

log_info "Input file: $MODULES_DEP"
log_info "Output file: $OUTPUT_FILE"
echo ""

# --- Extraction Logic ---

# The modules.dep format: "module.ko: dependency1.ko dependency2.ko ..."
# We need to extract both the main modules and their dependencies.
log_info "Extracting module names..."

# Process the modules.dep file:
# 1. Replace colons and spaces with newlines to separate all modules
# 2. Filter lines containing '.ko' (actual module files)
# 3. Extract just the filename using basename
# 4. Sort and remove duplicates
tr ' :' '\n' < "$MODULES_DEP" | \
    grep '\.ko' | \
    xargs -n1 basename | \
    sort -u > "$OUTPUT_FILE"

# Count the results
MODULE_COUNT=$(wc -l < "$OUTPUT_FILE")

print_header "Extraction Complete"

echo "Successfully extracted $MODULE_COUNT unique module names"
echo "Output saved to: $OUTPUT_FILE"
echo ""

# Show a preview of the first 10 modules
echo "Preview (first 10 modules):"
echo "----------------------------"
head -10 "$OUTPUT_FILE"

if [ "$MODULE_COUNT" -gt 10 ]; then
    echo "..."
    echo "(and $((MODULE_COUNT - 10)) more modules)"
fi

echo ""
echo "Done! Your modules list is ready for use."
