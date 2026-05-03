#!/bin/bash
echo "Ciallo~(∠・ω< )⌒★ - 小米内核编译脚本（使用 LLVM 18.1.8）"

starttime=`date +'%Y-%m-%d %H:%M:%S'`

# 配置参数
ARCH="arm64"
KERNEL_SOURCE="/data/user/0/com.termux/files/home/.local/share/tmoe-linux/containers/proot/ubuntu-noble_arm64/home/wyc/android_kernel_xiaomi_sm8350-miui/"
LLVM_HOME="${LLVM_HOME:-$HOME/llvm-18.1.8-aarch64}"  # LLVM 主目录
OUT_DIR="./out"
DEFCONFIG="vendor/star_defconfig"

# 日志文件
LOG_DIR="./build_logs"
mkdir -p "$LOG_DIR"
BUILD_LOG="$LOG_DIR/build_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="$LOG_DIR/errors_$(date +%Y%m%d_%H%M%S).log"

# ========== LLVM 18.1.8 工具链配置 ==========
LLVM_BIN="$LLVM_HOME/bin"

# 设置内核编译工具链
export CC="$LLVM_BIN/clang"
export LD="$LLVM_BIN/ld.lld"
export AR="$LLVM_BIN/llvm-ar"
export NM="$LLVM_BIN/llvm-nm"
export STRIP="$LLVM_BIN/llvm-strip"
export OBJCOPY="$LLVM_BIN/llvm-objcopy"
export OBJDUMP="$LLVM_BIN/llvm-objdump"
export READELF="$LLVM_BIN/llvm-readelf"
export RANLIB="$LLVM_BIN/llvm-ranlib"

# 内核编译配置
export ARCH=$ARCH
export SUBARCH=$ARCH
export LLVM=1
export CLANG_TRIPLE="aarch64-linux-gnu-"
export CROSS_COMPILE="aarch64-linux-gnu-"


# 添加到 PATH
export PATH="$LLVM_BIN:$PATH"

# 环境变量
export LOCALVERSION=
export LOCALVERSION_AUTO=n

# 编译参数
THREAD=$(nproc --all)
BUILD_ARGS="-j$THREAD O=$OUT_DIR LLVM=1"

# 日志函数
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$BUILD_LOG"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $1" | tee -a "$BUILD_LOG" >> "$ERROR_LOG"
    echo "[$timestamp] ERROR: $1" >&2
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SUCCESS: $1" | tee -a "$BUILD_LOG"
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command_name=$2
    
    log_error "在行号 $line_number 执行 '$command_name' 时失败 (退出码: $exit_code)"
    
    # 记录详细的错误信息
    echo "=== 环境信息 ===" >> "$ERROR_LOG"
    echo "时间: $(date)" >> "$ERROR_LOG"
    echo "目录: $(pwd)" >> "$ERROR_LOG"
    echo "架构: $ARCH" >> "$ERROR_LOG"
    echo "配置: $DEFCONFIG" >> "$ERROR_LOG"
    echo "LLVM路径: $LLVM_HOME" >> "$ERROR_LOG"
    
    # 记录工具链信息
    echo "=== 工具链检查 ===" >> "$ERROR_LOG"
    echo "CC: $CC" >> "$ERROR_LOG"
    echo "LD: $LD" >> "$ERROR_LOG"
    
    if [ -f "$CC" ]; then
        echo "clang文件存在: 是" >> "$ERROR_LOG"
        echo "clang可执行: $([ -x "$CC" ] && echo "是" || echo "否")" >> "$ERROR_LOG"
        "$CC" --version >> "$ERROR_LOG" 2>&1 || echo "clang无法执行" >> "$ERROR_LOG"
    else
        echo "clang文件不存在" >> "$ERROR_LOG"
    fi
    
    if [ -d "$LLVM_HOME" ]; then
        echo "LLVM目录内容:" >> "$ERROR_LOG"
        ls -la "$LLVM_HOME/bin/" 2>/dev/null | head -10 >> "$ERROR_LOG"
    fi
    
    # 如果有编译日志，提取错误
    if [ -f "$BUILD_LOG" ]; then
        echo "=== 最近错误 ===" >> "$ERROR_LOG"
        grep -i "error:\|undefined\|failed" "$BUILD_LOG" | tail -20 >> "$ERROR_LOG"
        
        echo "=== 最后30行日志 ===" >> "$ERROR_LOG"
        tail -30 "$BUILD_LOG" >> "$ERROR_LOG"
    fi
    
    exit $exit_code
}

# 设置错误陷阱
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

log_message "=== 开始内核编译（使用 LLVM 18.1.8）==="

echo "[+] 编译配置信息:"
echo "    - 架构: $ARCH"
echo "    - 设备配置: $DEFCONFIG"
echo "    - 线程数: $THREAD"
echo "    - 输出目录: $OUT_DIR"
echo "    - LLVM路径: $LLVM_HOME"
echo "    - CC编译器: $CC"
echo "    - LD链接器: $LD"
echo "    - 构建日志: $BUILD_LOG"
echo "    - 错误日志: $ERROR_LOG"

# 检查必要目录和工具
log_message "检查编译环境..."

# 1. 检查LLVM目录
if [ ! -d "$LLVM_HOME" ]; then
    log_error "LLVM 18.1.8目录不存在: $LLVM_HOME"
    echo "    请下载 llvm-18.1.8-aarch64 并解压到 ~/"
    echo "    下载链接: https://mirrors.edge.kernel.org/pub/tools/llvm/files/llvm-18.1.8-aarch64-linux.tar.gz"
    exit 1
fi

# 2. 检查LLVM bin目录
if [ ! -d "$LLVM_BIN" ]; then
    log_error "LLVM bin目录不存在: $LLVM_BIN"
    echo "    LLVM目录结构:"
    ls -la "$LLVM_HOME/" 2>/dev/null || echo "    无法访问LLVM目录"
    exit 1
fi

# 3. 直接检查clang文件是否存在
if [ ! -f "$CC" ]; then
    log_error "clang 可执行文件不存在: $CC"
    echo "    LLVM工具链目录内容:"
    ls -la "$LLVM_BIN/" | head -10
    exit 1
fi

# 4. 检查clang是否可执行
if [ ! -x "$CC" ]; then
    log_error "clang 不可执行: $CC"
    chmod +x "$CC" 2>/dev/null || echo "    无法添加执行权限"
    exit 1
fi

# 5. 检查其他必要工具
MISSING_TOOLS=()
for tool in clang ld.lld llvm-ar llvm-nm llvm-strip; do
    if [ ! -f "$LLVM_BIN/$tool" ]; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    log_error "缺少必要的工具: ${MISSING_TOOLS[*]}"
    echo "    可用的工具:"
    ls "$LLVM_BIN/" | head -15
    exit 1
fi

# 6. 测试clang版本
log_message "测试编译器..."
CLANG_VERSION=$("$CC" --version 2>&1 | head -1)
if [ $? -ne 0 ]; then
    log_error "clang 无法运行，可能缺少依赖库"
    echo "    依赖检查:"
    ldd "$CC" 2>/dev/null || echo "    无法检查依赖"
    exit 1
fi

log_success "编译器检查通过: $CLANG_VERSION"



# 步骤1: 彻底清理
log_message "[1/4] 执行彻底清理..."
make mrproper >> "$BUILD_LOG" 2>&1
rm -rf "$OUT_DIR" >> "$BUILD_LOG" 2>&1
log_success "清理完成"

# 步骤2: 创建输出目录
mkdir -p "$OUT_DIR"

# 步骤3: 生成配置
log_message "[2/4] 生成内核配置: $DEFCONFIG"
log_message "使用命令: make $BUILD_ARGS $DEFCONFIG"

# 创建配置命令（显式指定所有工具）
CONFIG_CMD="make ARCH=$ARCH LLVM=1 CC='$CC' LD='$LD' AR='$AR' NM='$NM' STRIP='$STRIP' O='$OUT_DIR' $DEFCONFIG"
log_message "配置命令: $CONFIG_CMD"

if ! eval "$CONFIG_CMD" >> "$BUILD_LOG" 2>&1; then
    log_error "配置生成失败"
    echo "=== 配置阶段错误 ===" >> "$ERROR_LOG"
    tail -50 "$BUILD_LOG" >> "$ERROR_LOG"
    
    # 检查配置文件是否存在
    if [ ! -f "arch/$ARCH/configs/$DEFCONFIG" ] && [ ! -f "$DEFCONFIG" ]; then
        log_error "配置文件不存在: $DEFCONFIG"
        echo "搜索配置文件..." >> "$ERROR_LOG"
        find . -name "*defconfig" -type f | grep -i star | head -10 >> "$ERROR_LOG"
    fi
    
    # 尝试直接编译配置
    log_message "尝试直接编译配置..."
    echo "尝试: make ARCH=arm64 defconfig" >> "$ERROR_LOG"
    make ARCH=arm64 defconfig >> "$ERROR_LOG" 2>&1 || true
    
    exit 1
fi
log_success "配置生成成功"

# 步骤4: 开始编译（带详细输出）
log_message "[3/4] 开始编译内核 (使用 $THREAD 线程)..."
log_message "详细编译日志保存至: $BUILD_LOG"

# 编译命令（显式指定所有工具）
BUILD_CMD="make ARCH=$ARCH LLVM=1 \
    CC='$CC' \
    LD='$LD' \
    AR='$AR' \
    NM='$NM' \
    STRIP='$STRIP' \
    OBJCOPY='$OBJCOPY' \
    OBJDUMP='$OBJDUMP' \
    O='$OUT_DIR' \
    -j$THREAD"

log_message "编译命令: $BUILD_CMD"

# 编译并实时显示进度，同时保存完整日志
{
    echo "=== 编译开始 ==="
    echo "命令: $BUILD_CMD"
    echo "时间: $(date)"
    echo "================="
    
    # 执行编译
    eval "$BUILD_CMD" 2>&1
    compile_exit=$?
    
    echo "================="
    echo "编译退出码: $compile_exit"
    echo "时间: $(date)"
    echo "=== 编译结束 ==="
} | tee -a "$BUILD_LOG"

if [ "${compile_exit:-1}" -eq 0 ]; then
    # 编译成功
    endtime=`date +'%Y-%m-%d %H:%M:%S'`
    start_seconds=$(date --date="$starttime" +%s)
    end_seconds=$(date --date="$endtime" +%s)
    build_time=$((end_seconds-start_seconds))
    
    log_success "[4/4] 编译完成!"
    log_message "开始时间: $starttime"
    log_message "结束时间: $endtime"
    log_message "编译耗时: ${build_time}s ($((build_time/60))分$((build_time%60))秒)"
    
    # 检查输出文件
    log_message "检查生成的文件:"
    
    KERNEL_IMAGE="$OUT_DIR/arch/$ARCH/boot/Image"
    KERNEL_IMAGE_GZ="$OUT_DIR/arch/$ARCH/boot/Image.gz"
    
    if [ -f "$KERNEL_IMAGE" ]; then
        log_success "找到内核镜像: $KERNEL_IMAGE ($(du -h "$KERNEL_IMAGE" | cut -f1))"
    elif [ -f "$KERNEL_IMAGE_GZ" ]; then
        log_success "找到压缩内核镜像: $KERNEL_IMAGE_GZ ($(du -h "$KERNEL_IMAGE_GZ" | cut -f1))"
    else
        log_message "警告: 未找到标准内核镜像，搜索其他文件..."
        find "$OUT_DIR/arch/$ARCH/boot/" -name "Image*" -type f 2>/dev/null | while read file; do
            log_success "找到: $file ($(du -h "$file" | cut -f1))"
        done
    fi
    
    # 检查设备树文件
    if [ -d "$OUT_DIR/arch/$ARCH/boot/dts/" ]; then
        DT_COUNT=$(find "$OUT_DIR/arch/$ARCH/boot/dts/" -name "*.dtb" -type f 2>/dev/null | wc -l)
        if [ "$DT_COUNT" -gt 0 ]; then
            log_success "找到 $DT_COUNT 个设备树文件 (.dtb)"
        fi
    fi
    
    # 生成编译报告
    REPORT_FILE="$LOG_DIR/build_report_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "=== 编译成功报告 ==="
        echo "内核版本: $(make kernelversion 2>/dev/null || echo "未知")"
        echo "编译时间: $build_time 秒"
        echo "开始时间: $starttime"
        echo "结束时间: $endtime"
        echo "架构: $ARCH"
        echo "配置: $DEFCONFIG"
        echo "LLVM工具链: $LLVM_HOME"
        echo "编译器: $("$CC" --version | head -1)"
        echo ""
        echo "=== 输出文件 ==="
        find "$OUT_DIR/arch/$ARCH/boot/" -name "Image*" -type f 2>/dev/null
        echo ""
        echo "=== 编译参数 ==="
        echo "线程数: $THREAD"
        echo "CC: $CC"
        echo "LD: $LD"
        echo "AR: $AR"
    } > "$REPORT_FILE"
    
    log_success "编译报告: $REPORT_FILE"
    
else
    log_error "编译失败 (退出码: $compile_exit)"
    
    # 提取和记录详细的错误信息
    {
        echo "=== 编译错误分析 ==="
        echo "退出码: $compile_exit"
        echo "时间: $(date)"
        echo "命令: $BUILD_CMD"
        
        echo ""
        echo "=== 错误汇总 ==="
        grep -i "error:" "$BUILD_LOG" | tail -30
        
        echo ""
        echo "=== 未定义符号 ==="
        grep -i "undefined" "$BUILD_LOG" | tail -20
        
        echo ""
        echo "=== 失败的任务 ==="
        grep -i "failed" "$BUILD_LOG" | tail -20
        
        echo ""
        echo "=== 警告信息 ==="
        grep -i "warning:" "$BUILD_LOG" | tail -20
        
        echo ""
        echo "=== 最后50行日志 ==="
        tail -50 "$BUILD_LOG"
    } >> "$ERROR_LOG"
    
    log_message "详细错误信息已保存至: $ERROR_LOG"
    log_message "完整编译日志: $BUILD_LOG"
    
    exit $compile_exit
fi

log_success "编译脚本执行完成"
echo "Ciallo~(∠・ω< )⌒★！编译完成！"