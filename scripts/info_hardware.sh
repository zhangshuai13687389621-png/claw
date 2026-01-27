#!/bin/bash

echo -e "\n=== Hardware Information ==="

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "--- CPU & Memory ---"
    system_profiler SPHardwareDataType
    echo -e "\n--- Graphics ---"
    system_profiler SPDisplaysDataType

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "--- CPU ---"
    if command -v lscpu >/dev/null 2>&1; then
        lscpu
    else
        cat /proc/cpuinfo | grep "model name" | head -n 1
        cat /proc/cpuinfo | grep "cpu cores" | head -n 1
    fi

    echo -e "\n--- Memory ---"
    free -h

    echo -e "\n--- GPU ---"
    if command -v lspci >/dev/null 2>&1; then
        lspci | grep -i vga || echo "No VGA controller found."
    else
        echo "lspci not available."
    fi

elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash)
    if command -v powershell >/dev/null 2>&1; then
         echo "--- CPU ---"
         powershell -Command "Get-WmiObject Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List"
         
         echo -e "\n--- Memory ---"
         powershell -Command "Get-ComputerInfo | Select-Object @{Name='TotalPhysicalMemory(GB)';Expression={[math]::round(\$_.TotalPhysicalMemory/1GB, 2)}} | Format-List"

         echo -e "\n--- GPU ---"
         powershell -Command "Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM | Format-List"
    else
        echo "PowerShell not available, cannot retrieve detailed hardware info."
        wmic cpu get name
        wmic memorychip get capacity
    fi
else
    echo "Hardware detection not implemented for: $OSTYPE"
fi
