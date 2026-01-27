#!/bin/bash

echo "Starting Claw System Info..."
echo "Date: $(date)"
echo "--------------------------------"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Execute sub-scripts
bash "$SCRIPT_DIR/scripts/info_os.sh"
bash "$SCRIPT_DIR/scripts/info_hardware.sh"

echo "--------------------------------"
echo "Done."
