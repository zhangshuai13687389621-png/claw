#!/bin/bash

echo "=== 操作系统信息 ==="

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sw_vers
elif [[ -f /etc/os-release ]]; then
    # Linux
    cat /etc/os-release
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash / MSYS)
    # Try using PowerShell to get info if available, or just ver
    if command -v powershell >/dev/null 2>&1; then
        powershell -Command "Get-ComputerInfo | Select-Object OsName, OsVersion | Format-List"
    else
        cmd //c ver
    fi
else
    echo "未知系统: $OSTYPE"
    uname -a
fi
