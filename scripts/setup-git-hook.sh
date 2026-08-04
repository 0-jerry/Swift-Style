#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

if [ ! -d "$HOOKS_DIR" ]; then
    echo "Error: .git/hooks directory not found. Are you in a git repository?" >&2
    exit 1
fi

cat > "$PRE_COMMIT_HOOK" << 'HOOK'
#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Collect staged .swift files
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.swift$' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
    exit 0
fi

echo "[pre-commit] Formatting staged Swift files..."

# Run format.sh with only the staged Swift files
"$PROJECT_ROOT/scripts/format.sh" $STAGED_SWIFT_FILES

# Re-stage the (possibly reformatted) files
while IFS= read -r file; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        git add "$PROJECT_ROOT/$file"
    fi
done <<< "$STAGED_SWIFT_FILES"

echo "[pre-commit] Done."
HOOK

chmod +x "$PRE_COMMIT_HOOK"

echo "[setup-git-hook] ✅ Pre-commit hook installed at: $PRE_COMMIT_HOOK"
echo "[setup-git-hook] Staged Swift files will be automatically formatted before each commit."
