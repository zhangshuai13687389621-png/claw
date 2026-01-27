#!/bin/bash

echo -e "\n=== Node.js 环境检查 ==="

# Check Node.js
if command -v node >/dev/null 2>&1; then
    NODE_VERSION_FULL=$(node -v)
    # Extract major version number (e.g., v22.5.0 -> 22)
    NODE_VERSION_MAJOR=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
    
    echo "Node.js 已安装: $NODE_VERSION_FULL"
    
    if [ "$NODE_VERSION_MAJOR" -gt 22 ]; then
        echo "✅ Node.js 版本符合要求 (>22)"
    else
        echo "❌ Node.js 版本过低 (需要 >22, 当前: $NODE_VERSION_MAJOR)"
    fi
else
    echo "❌ 未检测到 Node.js"
fi

# Check pnpm
if command -v pnpm >/dev/null 2>&1; then
    PNPM_VERSION=$(pnpm -v)
    echo "✅ pnpm 已安装: $PNPM_VERSION"
else
    echo "❌ 未检测到 pnpm"
fi
