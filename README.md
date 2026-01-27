# Claw System Info Viewer

这是一个用于在多平台（Windows, macOS, Linux）上查看系统信息（OS, CPU, 内存, 显卡）的工具。

## 如何使用

这个项目主要通过 **GitHub Actions** 自动运行。

### 1. 自动运行 (GitHub Actions)
当你将代码推送到 GitHub 仓库时，工作流会自动触发。
1. 点击 GitHub 仓库上方的 **Actions** 标签。
2. 点击最新的 **System Info** 工作流运行记录。
3. 选择左侧的 `System Info (Linux)`, `System Info (macOS)` 或 `System Info (Windows)` 作业。
4. 展开步骤查看输出结果。

### 2. 本地运行 (手动)
你也可以在终端中直接运行以下命令来查看信息：

#### macOS / Linux (Terminal)
```bash
echo "=== 操作系统 ==="
sw_vers  # macOS
# 或者
cat /etc/os-release # Linux

echo -e "\n=== CPU 信息 ==="
sysctl -n machdep.cpu.brand_string # macOS
# 或者
lscpu # Linux

echo -e "\n=== 内存 信息 ==="
vm_stat # macOS (简单的概览)
# 或者
free -h # Linux

echo -e "\n=== 显卡/显示器 信息 ==="
system_profiler SPDisplaysDataType # macOS
# Linux通常使用 lspci | grep -i vga
```

#### Windows (PowerShell)
```powershell
Write-Host "=== 操作系统 ==="
Get-ComputerInfo | Select-Object OsName, OsVersion | Format-List

Write-Host "`n=== CPU 信息 ==="
Get-WmiObject Win32_Processor | Select-Object Name | Format-List

Write-Host "`n=== 内存 信息 ==="
Get-ComputerInfo | Select-Object @{Name="TotalPhysicalMemory(GB)";Expression={[math]::round($_.TotalPhysicalMemory/1GB, 2)}} | Format-List

Write-Host "`n=== 显卡 信息 ==="
Get-WmiObject Win32_VideoController | Select-Object Name, AdapterRAM | Format-List
```