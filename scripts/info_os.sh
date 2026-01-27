#!/bin/bash

echo "=== Operating System Information ==="

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
    echo "Unknown OS: $OSTYPE"
    uname -a
fi
