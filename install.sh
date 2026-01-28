#!/bin/bash
set -euo pipefail
NPM_REGISTRY="https://registry.npmmirror.com"

# Clawdbot Installer for macOS and Linux
# Usage: curl -fsSL --proto '=https' --tlsv1.2 https://clawd.bot/install.sh | bash

BOLD='\033[1m'
ACCENT='\033[38;2;255;90;45m'
# shellcheck disable=SC2034
ACCENT_BRIGHT='\033[38;2;255;122;61m'
ACCENT_DIM='\033[38;2;209;74;34m'
INFO='\033[38;2;255;138;91m'
SUCCESS='\033[38;2;47;191;113m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;226;61;45m'
MUTED='\033[38;2;139;127;119m'
NC='\033[0m' # No Color

DEFAULT_TAGLINE="所有聊天，一个 Clawdbot。"

ORIGINAL_PATH="${PATH:-}"
SUDO_CMD=""

TMPFILES=()
cleanup_tmpfiles() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

DOWNLOADER=""
detect_downloader() {
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl"
        return 0
    fi
    if command -v wget &> /dev/null; then
        DOWNLOADER="wget"
        return 0
    fi
    echo -e "${ERROR}错误：缺少下载工具（需要 curl 或 wget）${NC}"
    exit 1
}

download_file() {
    local url="$1"
    local output="$2"
    if [[ -z "$DOWNLOADER" ]]; then
        detect_downloader
    fi
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 --retry-connrefused -o "$output" "$url"
        return
    fi
    wget -q --https-only --secure-protocol=TLSv1_2 --tries=3 --timeout=20 -O "$output" "$url"
}

run_remote_bash() {
    local url="$1"
    local tmp
    tmp="$(mktempfile)"
    download_file "$url" "$tmp"
    /bin/bash "$tmp"
}

cleanup_legacy_submodules() {
    local repo_dir="$1"
    local legacy_dir="$repo_dir/Peekaboo"
    if [[ -d "$legacy_dir" ]]; then
        echo -e "${WARN}→${NC} 正在移除旧的子模块：${INFO}${legacy_dir}${NC}"
        rm -rf "$legacy_dir"
    fi
}

cleanup_npm_clawdbot_paths() {
    local npm_root=""
    npm_root="$(npm root -g 2>/dev/null || true)"
    if [[ -z "$npm_root" || "$npm_root" != *node_modules* ]]; then
        return 1
    fi
    rm -rf "$npm_root"/.clawdbot-* "$npm_root"/clawdbot 2>/dev/null || true
}

install_clawdbot_npm() {
    local spec="$1"
    local log
    log="$(mktempfile)"
    if ! SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" npm --loglevel "$NPM_LOGLEVEL" ${NPM_SILENT_FLAG:+$NPM_SILENT_FLAG} --no-fund --no-audit install -g --registry "$NPM_REGISTRY" "$spec" 2>&1 | tee "$log"; then
        if grep -q "ENOTEMPTY: directory not empty, rename .*clawdbot" "$log"; then
            echo -e "${WARN}→${NC} npm 留下了陈旧的 clawdbot 目录；正在清理并重试..."
            cleanup_npm_clawdbot_paths
            SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" npm --loglevel "$NPM_LOGLEVEL" ${NPM_SILENT_FLAG:+$NPM_SILENT_FLAG} --no-fund --no-audit install -g --registry "$NPM_REGISTRY" "$spec"
            return $?
        fi
        return 1
    fi
    return 0
}





pick_tagline() {
    echo "$DEFAULT_TAGLINE"
}

TAGLINE=$(pick_tagline)

NO_ONBOARD=${CLAWDBOT_NO_ONBOARD:-0}
NO_PROMPT=${CLAWDBOT_NO_PROMPT:-0}
DRY_RUN=${CLAWDBOT_DRY_RUN:-0}
INSTALL_METHOD=${CLAWDBOT_INSTALL_METHOD:-}
CLAWDBOT_VERSION=${CLAWDBOT_VERSION:-latest}
USE_BETA=${CLAWDBOT_BETA:-0}
GIT_DIR_DEFAULT="${HOME}/clawdbot"
GIT_DIR=${CLAWDBOT_GIT_DIR:-$GIT_DIR_DEFAULT}
GIT_UPDATE=${CLAWDBOT_GIT_UPDATE:-1}
SHARP_IGNORE_GLOBAL_LIBVIPS="${SHARP_IGNORE_GLOBAL_LIBVIPS:-1}"
NPM_LOGLEVEL="${CLAWDBOT_NPM_LOGLEVEL:-error}"
NPM_SILENT_FLAG="--silent"
VERBOSE="${CLAWDBOT_VERBOSE:-0}"
CLAWDBOT_BIN=""
HELP=0

print_usage() {
    cat <<EOF
Clawdbot 安装程序 (macOS + Linux)

用法:
  curl -fsSL --proto '=https' --tlsv1.2 https://clawd.bot/install.sh | bash -s -- [选项]

选项:
  --install-method, --method npm|git   通过 npm (默认) 或 git 源码安装
  --npm                                --install-method npm 的快捷方式
  --git, --github                     --install-method git 的快捷方式
  --version <version|dist-tag>         npm 安装版本 (默认: latest)
  --beta                               使用测试版 (如果可用)，否则使用 latest
  --git-dir, --dir <path>             代码检出目录 (默认: ~/clawdbot)
  --no-git-update                      跳过现有代码库的 git pull 更新
  --no-onboard                          跳过初始化向导 (非交互模式)
  --no-prompt                           禁用提示 (CI/自动化需要)
  --dry-run                             仅打印将要执行的操作 (不进行更改)
  --verbose                             打印调试输出 (set -x, npm verbose)
  --help, -h                            显示此帮助信息

环境变量:
  CLAWDBOT_INSTALL_METHOD=git|npm
  CLAWDBOT_VERSION=latest|next|<semver>
  CLAWDBOT_BETA=0|1
  CLAWDBOT_GIT_DIR=...
  CLAWDBOT_GIT_UPDATE=0|1
  CLAWDBOT_NO_PROMPT=1
  CLAWDBOT_DRY_RUN=1
  CLAWDBOT_NO_ONBOARD=1
  CLAWDBOT_VERBOSE=1
  CLAWDBOT_NPM_LOGLEVEL=error|warn|notice  默认: error (隐藏 npm 废弃警告)
  SHARP_IGNORE_GLOBAL_LIBVIPS=0|1    默认: 1 (避免 sharp 针对全局 libvips 构建)

示例:
  curl -fsSL --proto '=https' --tlsv1.2 https://clawd.bot/install.sh | bash
  curl -fsSL --proto '=https' --tlsv1.2 https://clawd.bot/install.sh | bash -s -- --no-onboard
  curl -fsSL --proto '=https' --tlsv1.2 https://clawd.bot/install.sh | bash -s -- --install-method git --no-onboard
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --onboard)
                NO_ONBOARD=0
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --no-prompt)
                NO_PROMPT=1
                shift
                ;;
            --help|-h)
                HELP=1
                shift
                ;;
            --install-method|--method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --version)
                CLAWDBOT_VERSION="$2"
                shift 2
                ;;
            --beta)
                USE_BETA=1
                shift
                ;;
            --npm)
                INSTALL_METHOD="npm"
                shift
                ;;
            --git|--github)
                INSTALL_METHOD="git"
                shift
                ;;
            --git-dir|--dir)
                GIT_DIR="$2"
                shift 2
                ;;
            --no-git-update)
                GIT_UPDATE=0
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

configure_verbose() {
    if [[ "$VERBOSE" != "1" ]]; then
        return 0
    fi
    if [[ "$NPM_LOGLEVEL" == "error" ]]; then
        NPM_LOGLEVEL="notice"
    fi
    NPM_SILENT_FLAG=""
    set -x
}

is_promptable() {
    if [[ "$NO_PROMPT" == "1" ]]; then
        return 1
    fi
    if [[ -r /dev/tty && -w /dev/tty ]]; then
        return 0
    fi
    return 1
}

prompt_choice() {
    local prompt="$1"
    local answer=""
    if ! is_promptable; then
        return 1
    fi
    echo -e "$prompt" > /dev/tty
    read -r answer < /dev/tty || true
    echo "$answer"
}

detect_clawdbot_checkout() {
    local dir="$1"
    if [[ ! -f "$dir/package.json" ]]; then
        return 1
    fi
    if [[ ! -f "$dir/pnpm-workspace.yaml" ]]; then
        return 1
    fi
    if ! grep -q '"name"[[:space:]]*:[[:space:]]*"clawdbot"' "$dir/package.json" 2>/dev/null; then
        return 1
    fi
    echo "$dir"
    return 0
}

echo -e "${ACCENT}${BOLD}"
echo "  🦞 Clawdbot Installer"
echo -e "${NC}${ACCENT_DIM}  ${TAGLINE}${NC}"
echo ""

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    OS="linux"
fi

if [[ "$OS" == "unknown" ]]; then
    echo -e "${ERROR}错误：不支持的操作系统${NC}"
    echo "此安装程序支持 macOS 和 Linux (包括 WSL)。"
    echo "Windows 用户请使用：iwr -useb https://clawd.bot/install.ps1 | iex"
    exit 1
fi

echo -e "${SUCCESS}✓${NC} 检测到系统：$OS"

# Check for Homebrew on macOS
install_homebrew() {
    if [[ "$OS" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${WARN}→${NC} 正在安装 Homebrew (使用中国镜像源)..."
            # 配置 Homebrew 镜像变量
            export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
            export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
            export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
            export HOMEBREW_PIP_INDEX_URL="https://pypi.tuna.tsinghua.edu.cn/simple"
            
            # 使用 jsDelivr 代理安装脚本
            run_remote_bash "https://cdn.jsdelivr.net/gh/Homebrew/install@HEAD/install.sh"

            # Add Homebrew to PATH for this session
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
            echo -e "${SUCCESS}✓${NC} Homebrew 已安装"
        else
            echo -e "${SUCCESS}✓${NC} Homebrew 已安装"
        fi
    fi
}

# Check Node.js version
check_node() {
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -ge 22 ]]; then
            echo -e "${SUCCESS}✓${NC} 发现 Node.js v$(node -v | cut -d'v' -f2)"
            return 0
        else
            echo -e "${WARN}→${NC} 发现 Node.js $(node -v)，但需要 v22+"
            return 1
        fi
    else
        echo -e "${WARN}→${NC} 未找到 Node.js"
        return 1
    fi
}

# Install Node.js
install_node() {
    if [[ "$OS" == "macos" ]]; then
        echo -e "${WARN}→${NC} 正在通过 Homebrew 安装 Node.js..."
        brew install node@22
        brew link node@22 --overwrite --force 2>/dev/null || true
        echo -e "${SUCCESS}✓${NC} Node.js 已安装"
	    elif [[ "$OS" == "linux" ]]; then
	        echo -e "${WARN}→${NC} 正在通过 NodeSource 安装 Node.js..."
            require_sudo
	        if command -v apt-get &> /dev/null; then
	            local tmp
	            tmp="$(mktempfile)"
	            download_file "https://deb.nodesource.com/setup_22.x" "$tmp"
                # 替换为华为云镜像源
                sed -i 's|deb.nodesource.com|mirrors.huaweicloud.com/nodesource/deb|g' "$tmp"
	            $SUDO_CMD ${SUDO_CMD:+-E} bash "$tmp"
	            $SUDO_CMD ${SUDO_CMD:+-E} bash "$tmp"
	            $SUDO_CMD apt-get install -y nodejs npm
	        elif command -v dnf &> /dev/null; then
	            local tmp
	            tmp="$(mktempfile)"
	            download_file "https://rpm.nodesource.com/setup_22.x" "$tmp"
                # 替换为华为云镜像源
                sed -i 's|rpm.nodesource.com|mirrors.huaweicloud.com/nodesource/rpm|g' "$tmp"
	            $SUDO_CMD bash "$tmp"
	            $SUDO_CMD bash "$tmp"
	            $SUDO_CMD dnf install -y nodejs npm
	        elif command -v yum &> /dev/null; then
	            local tmp
	            tmp="$(mktempfile)"
	            download_file "https://rpm.nodesource.com/setup_22.x" "$tmp"
                # 替换为华为云镜像源
                sed -i 's|rpm.nodesource.com|mirrors.huaweicloud.com/nodesource/rpm|g' "$tmp"
	            $SUDO_CMD bash "$tmp"
	            $SUDO_CMD bash "$tmp"
	            $SUDO_CMD yum install -y nodejs npm
	        else
	            echo -e "${ERROR}错误：无法检测到包管理器${NC}"
	            echo "请手动安装 Node.js 22+: https://nodejs.org"
            exit 1
        fi
        echo -e "${SUCCESS}✓${NC} Node.js 已安装"
    fi
}

# Check Git
check_git() {
    if command -v git &> /dev/null; then
        echo -e "${SUCCESS}✓${NC} Git 已安装"
        return 0
    fi
    echo -e "${WARN}→${NC} 未找到 Git"
    return 1
}

is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

require_sudo() {
    if [[ "$OS" != "linux" ]]; then
        return 0
    fi
    if is_root; then
        SUDO_CMD=""
        return 0
    fi
    if command -v sudo &> /dev/null; then
        SUDO_CMD="sudo"
        return 0
    fi
    echo -e "${ERROR}错误：Linux 系统安装需要 sudo${NC}"
    echo "请安装 sudo 或以 root 身份运行。"
    exit 1
}

install_git() {
    echo -e "${WARN}→${NC} 正在安装 Git..."
    if [[ "$OS" == "macos" ]]; then
        brew install git
    elif [[ "$OS" == "linux" ]]; then
        require_sudo
        if command -v apt-get &> /dev/null; then
            $SUDO_CMD apt-get update -y
            $SUDO_CMD apt-get install -y git
        elif command -v dnf &> /dev/null; then
            $SUDO_CMD dnf install -y git
        elif command -v yum &> /dev/null; then
            $SUDO_CMD yum install -y git
        else
            echo -e "${ERROR}错误：无法检测到 Git 的包管理器${NC}"
            exit 1
        fi
    fi
    echo -e "${SUCCESS}✓${NC} Git 已安装"
}

# Fix npm permissions for global installs (Linux)
fix_npm_permissions() {
    if [[ "$OS" != "linux" ]]; then
        return 0
    fi

    local npm_prefix
    npm_prefix="$(npm config get prefix 2>/dev/null || true)"
    if [[ -z "$npm_prefix" ]]; then
        return 0
    fi

    if [[ -w "$npm_prefix" || -w "$npm_prefix/lib" ]]; then
        return 0
    fi

    echo -e "${WARN}→${NC} 正在配置 npm 用户本地安装..."
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"

    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.npm-global/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q ".npm-global" "$rc"; then
            echo "$path_line" >> "$rc"
        fi
    done

    export PATH="$HOME/.npm-global/bin:$PATH"
    echo -e "${SUCCESS}✓${NC} npm 已配置为用户安装"
}

resolve_clawdbot_bin() {
    if command -v clawdbot &> /dev/null; then
        command -v clawdbot
        return 0
    fi
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ -n "$npm_bin" && -x "${npm_bin}/clawdbot" ]]; then
        echo "${npm_bin}/clawdbot"
        return 0
    fi
    return 1
}

ensure_clawdbot_bin_link() {
    local npm_root=""
    npm_root="$(npm root -g 2>/dev/null || true)"
    if [[ -z "$npm_root" || ! -d "$npm_root/clawdbot" ]]; then
        return 1
    fi
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ -z "$npm_bin" ]]; then
        return 1
    fi
    mkdir -p "$npm_bin"
    if [[ ! -x "${npm_bin}/clawdbot" ]]; then
        ln -sf "$npm_root/clawdbot/dist/entry.js" "${npm_bin}/clawdbot"
        echo -e "${WARN}→${NC} 已在 ${INFO}${npm_bin}/clawdbot${NC} 安装 clawdbot 二进制链接"
    fi
    return 0
}

# Check for existing Clawdbot installation
check_existing_clawdbot() {
    if [[ -n "$(type -P clawdbot 2>/dev/null || true)" ]]; then
        echo -e "${WARN}→${NC} 检测到现有的 Clawdbot 安装"
        return 0
    fi
    return 1
}

ensure_pnpm() {
    if command -v pnpm &> /dev/null; then
        return 0
    fi

    if command -v corepack &> /dev/null; then
        echo -e "${WARN}→${NC} 正在通过 Corepack 安装 pnpm..."
        corepack enable >/dev/null 2>&1 || true
        # Corepack prepare doesn't support registry flag easily, relies on npm setup but we can try setting env
        NPM_CONFIG_REGISTRY="$NPM_REGISTRY" corepack prepare pnpm@10 --activate
        echo -e "${SUCCESS}✓${NC} pnpm 已安装"
        return 0
    fi

    echo -e "${WARN}→${NC} 正在通过 npm 安装 pnpm..."
    fix_npm_permissions
    npm install -g pnpm@10 --registry "$NPM_REGISTRY"
    echo -e "${SUCCESS}✓${NC} pnpm 已安装"
    return 0
}

ensure_user_local_bin_on_path() {
    local target="$HOME/.local/bin"
    mkdir -p "$target"

    export PATH="$target:$PATH"

    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [[ -f "$rc" ]] && ! grep -q ".local/bin" "$rc"; then
            echo "$path_line" >> "$rc"
        fi
    done
}

npm_global_bin_dir() {
    local prefix=""
    prefix="$(npm prefix -g 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
        if [[ "$prefix" == /* ]]; then
            echo "${prefix%/}/bin"
            return 0
        fi
    fi

    prefix="$(npm config get prefix 2>/dev/null || true)"
    if [[ -n "$prefix" && "$prefix" != "undefined" && "$prefix" != "null" ]]; then
        if [[ "$prefix" == /* ]]; then
            echo "${prefix%/}/bin"
            return 0
        fi
    fi

    echo ""
    return 1
}

refresh_shell_command_cache() {
    hash -r 2>/dev/null || true
}

path_has_dir() {
    local path="$1"
    local dir="${2%/}"
    if [[ -z "$dir" ]]; then
        return 1
    fi
    case ":${path}:" in
        *":${dir}:"*) return 0 ;;
        *) return 1 ;;
    esac
}

warn_shell_path_missing_dir() {
    local dir="${1%/}"
    local label="$2"
    if [[ -z "$dir" ]]; then
        return 0
    fi
    if path_has_dir "$ORIGINAL_PATH" "$dir"; then
        return 0
    fi

    echo ""
    echo -e "${WARN}→${NC} PATH 警告：缺少 ${label}：${INFO}${dir}${NC}"
    echo -e "这可能会导致 ${INFO}clawdbot${NC} 在新终端中显示为“command not found”。"
    echo -e "修复 (zsh: ~/.zshrc, bash: ~/.bashrc):"
    echo -e "  export PATH=\"${dir}:\\$PATH\""
    echo -e "文档：${INFO}https://docs.clawd.bot/install#nodejs--npm-path-sanity${NC}"
}

ensure_npm_global_bin_on_path() {
    local bin_dir=""
    bin_dir="$(npm_global_bin_dir || true)"
    if [[ -n "$bin_dir" ]]; then
        export PATH="${bin_dir}:$PATH"
    fi
}

maybe_nodenv_rehash() {
    if command -v nodenv &> /dev/null; then
        nodenv rehash >/dev/null 2>&1 || true
    fi
}

warn_clawdbot_not_found() {
    echo -e "${WARN}→${NC} 已安装，但在当前 Shell 中找不到 ${INFO}clawdbot${NC}。"
    echo -e "尝试：${INFO}hash -r${NC} (bash) 或 ${INFO}rehash${NC} (zsh)，然后重试。"
    echo -e "文档：${INFO}https://docs.clawd.bot/install#nodejs--npm-path-sanity${NC}"
    local t=""
    t="$(type -t clawdbot 2>/dev/null || true)"
    if [[ "$t" == "alias" || "$t" == "function" ]]; then
        echo -e "${WARN}→${NC} 发现名为 ${INFO}clawdbot${NC} 的 Shell ${INFO}${t}${NC}；它可能会遮盖真正的二进制文件。"
    fi
    if command -v nodenv &> /dev/null; then
        echo -e "正在使用 nodenv？运行：${INFO}nodenv rehash${NC}"
    fi

    local npm_prefix=""
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir 2>/dev/null || true)"
    if [[ -n "$npm_prefix" ]]; then
        echo -e "npm prefix -g: ${INFO}${npm_prefix}${NC}"
    fi
    if [[ -n "$npm_bin" ]]; then
        echo -e "npm bin -g: ${INFO}${npm_bin}${NC}"
        echo -e "If needed: ${INFO}export PATH=\"${npm_bin}:\\$PATH\"${NC}"
    fi
}

resolve_clawdbot_bin() {
    refresh_shell_command_cache
    local resolved=""
    resolved="$(type -P clawdbot 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    ensure_npm_global_bin_on_path
    refresh_shell_command_cache
    resolved="$(type -P clawdbot 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ -n "$npm_bin" && -x "${npm_bin}/clawdbot" ]]; then
        echo "${npm_bin}/clawdbot"
        return 0
    fi

    maybe_nodenv_rehash
    refresh_shell_command_cache
    resolved="$(type -P clawdbot 2>/dev/null || true)"
    if [[ -n "$resolved" && -x "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    if [[ -n "$npm_bin" && -x "${npm_bin}/clawdbot" ]]; then
        echo "${npm_bin}/clawdbot"
        return 0
    fi

    echo ""
    return 1
}

install_clawdbot_from_git() {
    local repo_dir="$1"
    local repo_url="https://gitee.com/zhangs669/moltbot.git"

    echo -e "${WARN}→${NC} 正在从 Gitee 安装 Clawdbot (${repo_url})..."

    if ! check_git; then
        install_git
    fi

    ensure_pnpm

    if [[ ! -d "$repo_dir" ]]; then
        git clone "$repo_url" "$repo_dir"
    fi

    if [[ "$GIT_UPDATE" == "1" ]]; then
        if [[ -z "$(git -C "$repo_dir" status --porcelain 2>/dev/null || true)" ]]; then
            git -C "$repo_dir" pull --rebase || true
        else
            echo -e "${WARN}→${NC} 代码库不纯净；跳过 git pull"
        fi
    fi

    cleanup_legacy_submodules "$repo_dir"

    SHARP_IGNORE_GLOBAL_LIBVIPS="$SHARP_IGNORE_GLOBAL_LIBVIPS" pnpm -C "$repo_dir" install --registry "$NPM_REGISTRY"

    if ! pnpm -C "$repo_dir" ui:build; then
        echo -e "${WARN}→${NC} UI 构建失败；继续执行（CLI 可能仍可工作）"
    fi
    pnpm -C "$repo_dir" build

    ensure_user_local_bin_on_path

    cat > "$HOME/.local/bin/clawdbot" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec node "${repo_dir}/dist/entry.js" "\$@"
EOF
    chmod +x "$HOME/.local/bin/clawdbot"
    echo -e "${SUCCESS}✓${NC} Clawdbot 包装器已安装到 \$HOME/.local/bin/clawdbot"
    echo -e "${INFO}i${NC} 该检出代码使用 pnpm。要安装依赖，请运行：${INFO}pnpm install${NC} (避免在仓库中运行 npm install)。"
}

# Install Clawdbot
resolve_beta_version() {
    local beta=""
    beta="$(npm view clawdbot dist-tags.beta 2>/dev/null || true)"
    if [[ -z "$beta" || "$beta" == "undefined" || "$beta" == "null" ]]; then
        return 1
    fi
    echo "$beta"
}

install_clawdbot() {
    if [[ "$USE_BETA" == "1" ]]; then
        local beta_version=""
        beta_version="$(resolve_beta_version || true)"
        if [[ -n "$beta_version" ]]; then
            CLAWDBOT_VERSION="$beta_version"
            echo -e "${INFO}i${NC} 检测到 Beta 标签 (${beta_version})；正在安装 Beta 版。"
        else
            CLAWDBOT_VERSION="latest"
            echo -e "${INFO}i${NC} 未找到 Beta 标签；正在安装 latest 版。"
        fi
    fi

    if [[ -z "${CLAWDBOT_VERSION}" ]]; then
        CLAWDBOT_VERSION="latest"
    fi

    local resolved_version=""
    resolved_version="$(npm view "clawdbot@${CLAWDBOT_VERSION}" version 2>/dev/null || true)"
    if [[ -n "$resolved_version" ]]; then
        echo -e "${WARN}→${NC} 正在安装 Clawdbot ${INFO}${resolved_version}${NC}..."
    else
        echo -e "${WARN}→${NC} 正在安装 Clawdbot (${INFO}${CLAWDBOT_VERSION}${NC})..."
    fi
    local install_spec=""
    if [[ "${CLAWDBOT_VERSION}" == "latest" ]]; then
        install_spec="clawdbot@latest"
    else
        install_spec="clawdbot@${CLAWDBOT_VERSION}"
    fi

    if ! install_clawdbot_npm "${install_spec}"; then
        echo -e "${WARN}→${NC} npm install 失败；正在清理并重试..."
        cleanup_npm_clawdbot_paths
        install_clawdbot_npm "${install_spec}"
    fi

    if [[ "${CLAWDBOT_VERSION}" == "latest" ]]; then
        if ! resolve_clawdbot_bin &> /dev/null; then
            echo -e "${WARN}→${NC} npm install clawdbot@latest 失败；正在重试 clawdbot@next"
            cleanup_npm_clawdbot_paths
            install_clawdbot_npm "clawdbot@next"
        fi
    fi

    ensure_clawdbot_bin_link || true

    echo -e "${SUCCESS}✓${NC} Clawdbot 已安装"
}

# Run doctor for migrations (safe, non-interactive)
run_doctor() {
    echo -e "${WARN}→${NC} 正在运行 doctor 来迁移设置..."
    local claw="${CLAWDBOT_BIN:-}"
    if [[ -z "$claw" ]]; then
        claw="$(resolve_clawdbot_bin || true)"
    fi
    if [[ -z "$claw" ]]; then
        echo -e "${WARN}→${NC} 跳过 doctor: ${INFO}clawdbot${NC} 尚未在 PATH 中。"
        warn_clawdbot_not_found
        return 0
    fi
    "$claw" doctor --non-interactive || true
    echo -e "${SUCCESS}✓${NC} 迁移完成"
}

resolve_workspace_dir() {
    local profile="${CLAWDBOT_PROFILE:-default}"
    if [[ "${profile}" != "default" ]]; then
        echo "${HOME}/clawd-${profile}"
    else
        echo "${HOME}/clawd"
    fi
}

run_bootstrap_onboarding_if_needed() {
    if [[ "${NO_ONBOARD}" == "1" ]]; then
        return
    fi

    local workspace
    workspace="$(resolve_workspace_dir)"
    local bootstrap="${workspace}/BOOTSTRAP.md"

    if [[ ! -f "${bootstrap}" ]]; then
        return
    fi

    if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
        echo -e "${WARN}→${NC} 在 ${INFO}${bootstrap}${NC} 发现 BOOTSTRAP.md；无 TTY，跳过初始化。"
        echo -e "稍后请运行 ${INFO}clawdbot onboard${NC} 完成设置。"
        return
    fi

    echo -e "${WARN}→${NC} 在 ${INFO}${bootstrap}${NC} 发现 BOOTSTRAP.md；开始初始化..."
    local claw="${CLAWDBOT_BIN:-}"
    if [[ -z "$claw" ]]; then
        claw="$(resolve_clawdbot_bin || true)"
    fi
    if [[ -z "$claw" ]]; then
        echo -e "${WARN}→${NC} 发现 BOOTSTRAP.md，但 ${INFO}clawdbot${NC} 尚未在 PATH 中；跳过初始化。"
        warn_clawdbot_not_found
        return
    fi

    "$claw" onboard || {
        echo -e "${ERROR}初始化失败；BOOTSTRAP.md 仍然存在。请重新运行 ${INFO}clawdbot onboard${ERROR}。${NC}"
        return
    }
}

resolve_clawdbot_version() {
    local version=""
    local claw="${CLAWDBOT_BIN:-}"
    if [[ -z "$claw" ]] && command -v clawdbot &> /dev/null; then
        claw="$(command -v clawdbot)"
    fi
    if [[ -n "$claw" ]]; then
        version=$("$claw" --version 2>/dev/null | head -n 1 | tr -d '\r')
    fi
    if [[ -z "$version" ]]; then
        local npm_root=""
        npm_root=$(npm root -g 2>/dev/null || true)
        if [[ -n "$npm_root" && -f "$npm_root/clawdbot/package.json" ]]; then
            version=$(node -e "console.log(require('${npm_root}/clawdbot/package.json').version)" 2>/dev/null || true)
        fi
    fi
    echo "$version"
}

is_gateway_daemon_loaded() {
    local claw="$1"
    if [[ -z "$claw" ]]; then
        return 1
    fi

    local status_json=""
    status_json="$("$claw" daemon status --json 2>/dev/null || true)"
    if [[ -z "$status_json" ]]; then
        return 1
    fi

    printf '%s' "$status_json" | node -e '
const fs = require("fs");
const raw = fs.readFileSync(0, "utf8").trim();
if (!raw) process.exit(1);
try {
  const data = JSON.parse(raw);
  process.exit(data?.service?.loaded ? 0 : 1);
} catch {
  process.exit(1);
}
' >/dev/null 2>&1
}

# Main installation flow
main() {
    if [[ "$HELP" == "1" ]]; then
        print_usage
        return 0
    fi

    local detected_checkout=""
    detected_checkout="$(detect_clawdbot_checkout "$PWD" || true)"

    if [[ -z "$INSTALL_METHOD" && -n "$detected_checkout" ]]; then
        if ! is_promptable; then
            echo -e "${WARN}→${NC} 发现 Clawdbot 检出，但无 TTY；默认使用 npm 安装。"
            INSTALL_METHOD="npm"
        else
            local choice=""
            choice="$(prompt_choice "$(cat <<EOF
${WARN}→${NC} 在以下位置检测到 Clawdbot 源码检出：${INFO}${detected_checkout}${NC}
选择安装方式：
  1) 更新此检出 (git) 并使用它
  2) 通过 npm 全局安装 (从 git 迁移)
输入 1 或 2：
EOF
)" || true)"

            case "$choice" in
                1) INSTALL_METHOD="git" ;;
                2) INSTALL_METHOD="npm" ;;
                *)
                    echo -e "${ERROR}错误：未选择安装方式。${NC}"
                    echo "重新运行请使用：--install-method git|npm (或设置 CLAWDBOT_INSTALL_METHOD)。"
                    exit 2
                    ;;
            esac
        fi
    fi

    if [[ -z "$INSTALL_METHOD" ]]; then
        INSTALL_METHOD="npm"
    fi

    if [[ "$INSTALL_METHOD" != "npm" && "$INSTALL_METHOD" != "git" ]]; then
        echo -e "${ERROR}错误：无效的 --install-method: ${INSTALL_METHOD}${NC}"
        echo "使用：--install-method npm|git"
        exit 2
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        echo -e "${SUCCESS}✓${NC} 试运行 (Dry run)"
        echo -e "${SUCCESS}✓${NC} 安装方式: ${INSTALL_METHOD}"
        if [[ -n "$detected_checkout" ]]; then
            echo -e "${SUCCESS}✓${NC} 检测到代码库: ${detected_checkout}"
        fi
        if [[ "$INSTALL_METHOD" == "git" ]]; then
            echo -e "${SUCCESS}✓${NC} Git 目录: ${GIT_DIR}"
            echo -e "${SUCCESS}✓${NC} Git 更新: ${GIT_UPDATE}"
        fi
        echo -e "${MUTED}试运行完成（未做任何更改）。${NC}"
        return 0
    fi

    # Check for existing installation
    local is_upgrade=false
    if check_existing_clawdbot; then
        is_upgrade=true
    fi

    # Step 1: Homebrew (macOS only)
    install_homebrew

    # Step 2: Node.js
    if ! check_node; then
        install_node
    fi

    local final_git_dir=""
    if [[ "$INSTALL_METHOD" == "git" ]]; then
        # Clean up npm global install if switching to git
        if npm list -g clawdbot &>/dev/null; then
            echo -e "${WARN}→${NC} 正在移除 npm 全局安装 (切换到 git)..."
            npm uninstall -g clawdbot 2>/dev/null || true
            echo -e "${SUCCESS}✓${NC} npm 全局安装已移除"
        fi

        local repo_dir="$GIT_DIR"
        if [[ -n "$detected_checkout" ]]; then
            repo_dir="$detected_checkout"
        fi
        final_git_dir="$repo_dir"
        install_clawdbot_from_git "$repo_dir"
    else
        # Clean up git wrapper if switching to npm
        if [[ -x "$HOME/.local/bin/clawdbot" ]]; then
            echo -e "${WARN}→${NC} 正在移除 git 包装器 (切换到 npm)..."
            rm -f "$HOME/.local/bin/clawdbot"
            echo -e "${SUCCESS}✓${NC} git 包装器已移除"
        fi

        # Step 3: Git (required for npm installs that may fetch from git or apply patches)
        if ! check_git; then
            install_git
        fi

        # Step 4: npm permissions (Linux)
        fix_npm_permissions

        # Step 5: Clawdbot
        install_clawdbot
    fi

    CLAWDBOT_BIN="$(resolve_clawdbot_bin || true)"

    # PATH warning: installs can succeed while the user's login shell still lacks npm's global bin dir.
    local npm_bin=""
    npm_bin="$(npm_global_bin_dir || true)"
    if [[ "$INSTALL_METHOD" == "npm" ]]; then
        warn_shell_path_missing_dir "$npm_bin" "npm 全局 bin 目录"
    fi
    if [[ "$INSTALL_METHOD" == "git" ]]; then
        if [[ -x "$HOME/.local/bin/clawdbot" ]]; then
            warn_shell_path_missing_dir "$HOME/.local/bin" "用户本地 bin 目录 (~/.local/bin)"
        fi
    fi

    # Step 6: Run doctor for migrations on upgrades and git installs
    local run_doctor_after=false
    if [[ "$is_upgrade" == "true" || "$INSTALL_METHOD" == "git" ]]; then
        run_doctor_after=true
    fi
    if [[ "$run_doctor_after" == "true" ]]; then
        run_doctor
    fi

    # Step 7: If BOOTSTRAP.md is still present in the workspace, resume onboarding
    run_bootstrap_onboarding_if_needed

    local installed_version
    installed_version=$(resolve_clawdbot_version)

    echo ""
    if [[ -n "$installed_version" ]]; then
        echo -e "${SUCCESS}${BOLD}🦞 Clawdbot 安装成功 (${installed_version})！${NC}"
    else
        echo -e "${SUCCESS}${BOLD}🦞 Clawdbot 安装成功！${NC}"
    fi
    if [[ "$is_upgrade" == "true" ]]; then
        echo -e "${MUTED}升级完成。${NC}"
    else
        echo -e "${MUTED}安装完成。${NC}"
    fi
    echo ""

    if [[ "$INSTALL_METHOD" == "git" && -n "$final_git_dir" ]]; then
        echo -e "源码检出: ${INFO}${final_git_dir}${NC}"
        echo -e "包装器: ${INFO}\$HOME/.local/bin/clawdbot${NC}"
        echo -e "从源码安装。后续更新请运行：${INFO}clawdbot update --restart${NC}"
        echo -e "稍后切换到全局安装：${INFO}curl -fsSL --proto '=https' --tlsv1.2 https://clawd.bot/install.sh | bash -s -- --install-method npm${NC}"
    elif [[ "$is_upgrade" == "true" ]]; then
        echo -e "升级完成。"
        if [[ -r /dev/tty && -w /dev/tty ]]; then
            local claw="${CLAWDBOT_BIN:-}"
            if [[ -z "$claw" ]]; then
                claw="$(resolve_clawdbot_bin || true)"
            fi
            if [[ -z "$claw" ]]; then
                echo -e "${WARN}→${NC} 跳过 doctor: ${INFO}clawdbot${NC} 尚未在 PATH 中。"
                warn_clawdbot_not_found
                return 0
            fi
            local -a doctor_args=()
            if [[ "$NO_ONBOARD" == "1" ]]; then
                if "$claw" doctor --help 2>/dev/null | grep -q -- "--non-interactive"; then
                    doctor_args+=("--non-interactive")
                fi
            fi
            echo -e "正在运行 ${INFO}clawdbot doctor${NC}..."
            local doctor_ok=0
            if (( ${#doctor_args[@]} )); then
                CLAWDBOT_UPDATE_IN_PROGRESS=1 "$claw" doctor "${doctor_args[@]}" </dev/tty && doctor_ok=1
            else
                CLAWDBOT_UPDATE_IN_PROGRESS=1 "$claw" doctor </dev/tty && doctor_ok=1
            fi
            if (( doctor_ok )); then
                echo -e "正在更新插件 (${INFO}clawdbot plugins update --all${NC})..."
                CLAWDBOT_UPDATE_IN_PROGRESS=1 "$claw" plugins update --all || true
            else
                echo -e "${WARN}→${NC} Doctor 失败；跳过插件更新。"
            fi
        else
            echo -e "${WARN}→${NC} 无 TTY 可用；跳过 doctor。"
            echo -e "请运行 ${INFO}clawdbot doctor${NC}，然后运行 ${INFO}clawdbot plugins update --all${NC}。"
        fi
    else
        if [[ "$NO_ONBOARD" == "1" ]]; then
            echo -e "跳过初始化 (已请求)。稍后请运行 ${INFO}clawdbot onboard${NC}。"
        else
            echo -e "正在开始设置..."
            echo ""
            if [[ -r /dev/tty && -w /dev/tty ]]; then
                local claw="${CLAWDBOT_BIN:-}"
                if [[ -z "$claw" ]]; then
                    claw="$(resolve_clawdbot_bin || true)"
                fi
                if [[ -z "$claw" ]]; then
                    echo -e "${WARN}→${NC} 跳过初始化：${INFO}clawdbot${NC} 尚未在 PATH 中。"
                    warn_clawdbot_not_found
                    return 0
                fi
                exec </dev/tty
                exec "$claw" onboard
            fi
            echo -e "${WARN}→${NC} 无 TTY 可用；跳过初始化。"
            echo -e "稍后请运行 ${INFO}clawdbot onboard${NC}。"
            return 0
        fi
    fi

    if command -v clawdbot &> /dev/null; then
        local claw="${CLAWDBOT_BIN:-}"
        if [[ -z "$claw" ]]; then
            claw="$(resolve_clawdbot_bin || true)"
        fi
        if [[ -n "$claw" ]] && is_gateway_daemon_loaded "$claw"; then
            echo -e "${INFO}i${NC} 检测到 Gateway 守护进程；请重启：${INFO}clawdbot daemon restart${NC}"
        fi
    fi

    echo ""
    echo -e "FAQ: ${INFO}https://docs.clawd.bot/start/faq${NC}"
}

if [[ "${CLAWDBOT_INSTALL_SH_NO_RUN:-0}" != "1" ]]; then
    parse_args "$@"
    configure_verbose
    main
fi
