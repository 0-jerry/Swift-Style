#!/usr/bin/env bash
set -e

# Find script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure SwiftStyleFormatTool and binary dependencies are built
if [ ! -d ".build/artifacts" ]; then
    echo "[SwiftStyleFormat] Initializing package dependencies..."
    swift build --target SwiftStyleFormatTool > /dev/null 2>&1 || true
fi

# Locate swiftformat binary
SWIFTFORMAT_BIN=""
FOUND_SWIFTFORMAT=$(find .build/artifacts -name "swiftformat" -type f 2>/dev/null | grep -E "(bin/swiftformat|macos/swiftformat)$" | head -n 1)
if [ -n "$FOUND_SWIFTFORMAT" ]; then
    SWIFTFORMAT_BIN="$FOUND_SWIFTFORMAT"
elif command -v swiftformat &> /dev/null; then
    SWIFTFORMAT_BIN="$(command -v swiftformat)"
fi

# Locate swiftlint binary
SWIFTLINT_BIN=""
FOUND_SWIFTLINT=$(find .build/artifacts -name "swiftlint" -type f 2>/dev/null | grep -E "macos/swiftlint$" | head -n 1)
if [ -n "$FOUND_SWIFTLINT" ]; then
    SWIFTLINT_BIN="$FOUND_SWIFTLINT"
elif command -v swiftlint &> /dev/null; then
    SWIFTLINT_BIN="$(command -v swiftlint)"
fi

# If binaries are not found, attempt building
if [ -z "$SWIFTFORMAT_BIN" ] || [ -z "$SWIFTLINT_BIN" ]; then
    echo "[SwiftStyleFormat] Building dependencies..."
    swift build --target SwiftStyleFormatTool > /dev/null
    FOUND_SWIFTFORMAT=$(find .build/artifacts -name "swiftformat" -type f 2>/dev/null | grep -E "(bin/swiftformat|macos/swiftformat)$" | head -n 1)
    [ -n "$FOUND_SWIFTFORMAT" ] && SWIFTFORMAT_BIN="$FOUND_SWIFTFORMAT"

    FOUND_SWIFTLINT=$(find .build/artifacts -name "swiftlint" -type f 2>/dev/null | grep -E "macos/swiftlint$" | head -n 1)
    [ -n "$FOUND_SWIFTLINT" ] && SWIFTLINT_BIN="$FOUND_SWIFTLINT"
fi

if [ -z "$SWIFTFORMAT_BIN" ]; then
    echo "Error: swiftformat binary could not be found." >&2
    exit 2
fi

if [ -z "$SWIFTLINT_BIN" ]; then
    echo "Error: swiftlint binary could not be found." >&2
    exit 2
fi

# Convert relative binary path to absolute path if needed
if [[ "$SWIFTFORMAT_BIN" != /* ]]; then
    SWIFTFORMAT_BIN="$PROJECT_ROOT/$SWIFTFORMAT_BIN"
fi
if [[ "$SWIFTLINT_BIN" != /* ]]; then
    SWIFTLINT_BIN="$PROJECT_ROOT/$SWIFTLINT_BIN"
fi

# Determine input targets/paths
ARGS=("$@")
PATHS=()
OPTIONS=()

for arg in "${ARGS[@]}"; do
    if [[ "$arg" == -* ]]; then
        OPTIONS+=("$arg")
    else
        PATHS+=("$arg")
    fi
done

if [ ${#PATHS[@]} -eq 0 ]; then
    while IFS= read -r -d '' item; do
        PATHS+=("$item")
    done < <(find . -maxdepth 1 -not -name "." -not -name ".*" \( -type d -o -name "*.swift" \) -print0)
fi

mkdir -p .build/cache

echo "[SwiftStyleFormat] Running SwiftStyleFormatTool..."
exec swift run SwiftStyleFormatTool \
    "${PATHS[@]}" \
    --swift-format-path "$SWIFTFORMAT_BIN" \
    --swift-lint-path "$SWIFTLINT_BIN" \
    --swift-format-cache-path "$PROJECT_ROOT/.build/cache/swiftformat.cache" \
    --swift-lint-cache-path "$PROJECT_ROOT/.build/cache/swiftlint.cache" \
    "${OPTIONS[@]}"
