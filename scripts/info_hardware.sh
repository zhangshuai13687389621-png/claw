#!/bin/bash

echo -e "\n=== 硬件检测 ==="

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "--- CPU & 内存 ---"
    system_profiler SPHardwareDataType
    echo -e "\n--- 显卡 ---"
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

    echo -e "\n--- 内存 ---"
    free -h

    echo -e "\n--- 显卡 ---"
    if command -v lspci >/dev/null 2>&1; then
        lspci | grep -i vga || echo "未找到显示控制器"
    else
        echo "lspci 命令不可用"
    fi

elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash)
    if command -v powershell >/dev/null 2>&1; then
         echo "--- CPU ---"
         powershell -Command "Get-WmiObject Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List"
         
         echo -e "\n--- 内存 ---"
         powershell -Command "Get-ComputerInfo | Select-Object @{Name='TotalPhysicalMemory(GB)';Expression={[math]::round(\$_.TotalPhysicalMemory/1GB, 2)}} | Format-List"

         echo -e "\n--- 显卡 ---"
         powershell -Command "Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM | Format-List"
    else
        echo "PowerShell 不可用，无法获取详细硬件信息。"
        wmic cpu get name
        wmic memorychip get capacity
    fi
else
    echo "暂不支持该系统的硬件检测: $OSTYPE"
fi
