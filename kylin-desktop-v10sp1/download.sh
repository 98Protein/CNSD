#!/bin/bash
# ----------------------------------------------------------------------------
# 银河麒麟桌面 V10 SP1 多架构 DEB 包下载脚本
#
#   用法:  download.sh <package[,pkg2,...]> [arch] [output_subdir]
#     arch: amd64 (默认) | arm64
#
#   示例:
#     download.sh nginx amd64
#     download.sh nginx arm64
#     download.sh curl,wget,vim arm64 cli-tools-arm
#
# 关键点:
#   1. 用 apt-cache depends --recurse 解析指定架构完整依赖树。
#   2. 用 apt-get download <pkg>:<arch> 单包拉取，不触发安装。
#   3. 麒麟桌面源按架构分仓库，sources.list 已经为 amd64/arm64 各配一条
#      deb 行，所以这里只要给 apt-cache/apt-get 加 :<arch> 后缀即可。
# ----------------------------------------------------------------------------
set -u

PACKAGES_RAW="${1:-}"
ARCH="${2:-amd64}"
SUBDIR="${3:-}"

if [ -z "$PACKAGES_RAW" ]; then
    cat <<EOF
用法: $0 <package[,pkg2,...]> [arch] [output_subdir]
  arch: amd64 (默认) | arm64
示例:
  $0 nginx amd64
  $0 nginx arm64
  $0 curl,wget,vim arm64 cli-tools-arm
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

echo "==> 更新软件源索引..."
apt-get update -qq

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

DEP_COUNT=$(wc -l < "$DEP_LIST")
echo "==> 共解析出 ${DEP_COUNT} 个包，开始下载..."

SUCCESS=0
FAILED=0
while read -r dep; do
    [ -z "$dep" ] && continue
    if apt-get download "${dep}:${ARCH}" >/dev/null 2>&1; then
        SUCCESS=$((SUCCESS + 1))
    elif apt-get download "${dep}" >/dev/null 2>&1; then
        # 处理 architecture: all 的包
        SUCCESS=$((SUCCESS + 1))
    else
        echo "$dep" >> "$FAILED_LOG"
        FAILED=$((FAILED + 1))
    fi
done < "$DEP_LIST"

echo
echo "==================== 下载完成 ===================="
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
