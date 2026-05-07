#!/bin/bash
# ----------------------------------------------------------------------------
# 统信 UOS 桌面专业版 V20 多架构 DEB 包下载脚本（带授权降级）
#
#   用法:  download.sh <package[,pkg2,...]> [arch] [output_subdir] [--no-deps]
#     arch:      amd64 (默认) | arm64
#     --no-deps: 仅下载指定包本身，不解析依赖
#
# 行为:
#   1. apt-get update 时若 UOS 源返回 401（授权被拒），自动切到兜底模式
#      （仅 Debian buster archive），并提示用户。
#   2. 兜底模式下若用户尝试下载 UOS 桌面专有包（dde-/deepin-/uos-），
#      会因依赖解析为空而失败，给出明确提示。
# ----------------------------------------------------------------------------
set -u

PACKAGES_RAW="${1:-}"
ARCH="${2:-amd64}"
SUBDIR="${3:-}"
NO_DEPS=false
for arg in "$@"; do [ "$arg" = "--no-deps" ] && NO_DEPS=true; done

if [ -z "$PACKAGES_RAW" ]; then
    cat <<EOF
用法: $0 <package[,pkg2,...]> [arch] [output_subdir] [--no-deps]
  arch:      amd64 (默认) | arm64
  --no-deps: 仅下载指定包本身，不解析依赖
示例:
  $0 dde-control-center amd64           # UOS 专有包 (需授权)
  $0 deepin-terminal arm64              # arm64 专有包
  $0 nginx,curl,wget arm64 cli-tools    # 通用包，多包，自定义子目录
  $0 libssl3 amd64 libssl3 --no-deps    # 仅下载单包
EOF
    exit 1
fi

if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "[错误] arch 仅支持 amd64 或 arm64，当前: $ARCH" >&2
    exit 1
fi

IFS=',' read -r -a PACKAGES <<< "$PACKAGES_RAW"

if [ -z "$SUBDIR" ]; then
    SUBDIR="${PACKAGES[0]}_${ARCH}"
fi

OUTPUT_DIR="/downloads/${SUBDIR}"
FAILED_LOG="${OUTPUT_DIR}/.failed.log"
DEP_LIST="${OUTPUT_DIR}/.dep-list.txt"

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR" || exit 1
: > "$FAILED_LOG"
: > "$DEP_LIST"

# ---------- 1. 刷新源索引（带 401 自动降级） ----------
APT_LOG="/tmp/apt-update.log"
MODE="full"
if grep -q '^deb .*chinauos' /etc/apt/sources.list 2>/dev/null; then
    MODE="full"
else
    MODE="fallback"
fi

echo "==> 当前模式: $MODE  (full=UOS+Debian, fallback=仅 Debian)"
echo "==> 更新软件源索引..."
apt-get update 2>&1 | tee "$APT_LOG" || true

if [ "$MODE" = "full" ] && grep -q '401' "$APT_LOG"; then
    echo
    echo "[警告] UOS 源返回 401 Unauthorized —— 授权可能被服务端拒绝"
    echo "        （授权文件含本机硬件指纹，跨机器复用时服务端可能不认）"
    echo "        自动降级到 Debian 通用包模式，本次仅能下通用包。"
    echo
    cp /etc/apt/sources.list.debian-only /etc/apt/sources.list
    rm -f /etc/apt/auth.conf.d/uos.conf
    MODE="fallback"
    apt-get update -qq
fi

# ---------- 2. 解析依赖 ----------
if $NO_DEPS; then
    echo "==> 模式: 仅下载指定包（跳过依赖解析）..."
    printf '%s\n' "${PACKAGES[@]}" > "$DEP_LIST"
else
    echo "==> 解析依赖（架构: ${ARCH}，目标: ${PACKAGES[*]}）..."
    {
        for pkg in "${PACKAGES[@]}"; do
            apt-cache depends \
                --recurse \
                --no-recommends --no-suggests \
                --no-conflicts --no-breaks \
                --no-replaces --no-enhances \
                "${pkg}:${ARCH}" 2>/dev/null \
            | awk '/^[a-zA-Z0-9]/ {print $1}'
        done
    } | sort -u > "$DEP_LIST"
fi

DEP_COUNT=$(wc -l < "$DEP_LIST")

if [ "$DEP_COUNT" -eq 0 ]; then
    echo
    echo "[错误] 未解析到任何依赖。可能原因："
    echo "  - 包名拼写错误"
    if [ "$MODE" = "fallback" ]; then
        echo "  - 当前是兜底模式（仅 Debian buster archive），目标包可能是 UOS 桌面专有包"
        echo "    （dde-/deepin-/uos- 等），需要有效的 UOS 授权才能下载。"
    fi
    echo "  - 该包在当前启用的源中不存在"
    echo
    echo "  可尝试: apt-cache search <关键字>  /  apt-cache show <pkg>:${ARCH}"
    exit 4
fi

# ---------- 3. 下载 ----------
echo "==> 共解析出 ${DEP_COUNT} 个包，开始下载..."

SUCCESS=0
FAILED=0
CURRENT=0
while read -r dep; do
    [ -z "$dep" ] && continue
    CURRENT=$((CURRENT + 1))
    PERCENT=$((CURRENT * 100 / DEP_COUNT))
    FILLED=$((PERCENT / 2))
    BAR=$(printf '%0.s#' $(seq 1 $FILLED))$(printf '%0.s-' $(seq 1 $((50 - FILLED))))
    printf "\r  [%s] %3d%% (%d/%d) 正在下载: %-40s" "$BAR" "$PERCENT" "$CURRENT" "$DEP_COUNT" "$dep"
    if apt-get download "${dep}:${ARCH}" >/dev/null 2>&1; then
        SUCCESS=$((SUCCESS + 1))
    elif apt-get download "${dep}" >/dev/null 2>&1; then
        SUCCESS=$((SUCCESS + 1))
    else
        echo "$dep" >> "$FAILED_LOG"
        FAILED=$((FAILED + 1))
    fi
done < "$DEP_LIST"
echo

# ---------- 4. 总结 ----------
echo
echo "==================== 下载完成 ===================="
echo "  模式:    $MODE"
echo "  输出目录: $OUTPUT_DIR"
echo "  成功:    $SUCCESS"
echo "  失败:    $FAILED  ($([ "$FAILED" -gt 0 ] && echo "见 $FAILED_LOG" || echo "无"))"
echo "  .deb 数: $(ls -1 "$OUTPUT_DIR"/*.deb 2>/dev/null | wc -l)"
echo "  总大小:  $(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)"
echo "=================================================="

DEB_COUNT=$(ls -1 "$OUTPUT_DIR"/*.deb 2>/dev/null | wc -l)
if [ "$DEB_COUNT" -gt 0 ]; then
    echo
    echo "  抽样校验（文件名应含 _${ARCH}.deb 或 _all.deb）:"
    ls "$OUTPUT_DIR"/*.deb | head -5 | sed 's/^/    /'
fi
