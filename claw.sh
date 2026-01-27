#!/bin/bash

echo "启动 Claw 系统信息检测..."
echo "当前时间: $(date)"
echo "--------------------------------"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Execute sub-scripts
bash "$SCRIPT_DIR/scripts/info_os.sh"
bash "$SCRIPT_DIR/scripts/info_hardware.sh"
bash "$SCRIPT_DIR/scripts/info_node.sh"

echo "--------------------------------"
echo "检测完成。"
