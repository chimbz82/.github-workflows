#!/usr/bin/env bash
set -euo pipefail
shopt -s globstar

# Usage: ./fix-import-exports.sh
# Creates .bak backups next to any files it edits.

mapfile -t matches < <(grep -R --line-number --exclude-dir=node_modules --exclude-dir=.git -E "from ['\"]\./components/[^'\";]+['\"]" . || true)

if [ ${#matches[@]} -eq 0 ]; then
  echo "No ./components/ imports found."
  exit 0
fi

for entry in "${matches[@]}"; do
  file=$(echo "$entry" | cut -d: -f1)
  code=$(echo "$entry" | cut -d: -f3-)
  module=$(echo "$code" | sed -n "s/.*from ['\"]\([^'\"]*\)['\"].*/\1/p")
  base=$(basename "$module")
  dir=$(dirname "$file")
  comp1="$dir/${module##*/}.tsx"
  comp2="./${module#./}.tsx"
  comp3="src/${module#./}.tsx"
  comp=""

  if [ -f "$comp1" ]; then comp="$comp1"; fi
  if [ -z "$comp" ] && [ -f "$comp2" ]; then comp="$comp2"; fi
  if [ -z "$comp" ] && [ -f "$comp3" ]; then comp="$comp3"; fi

  if [ -z "$comp" ]; then
    echo "WARN: Could not locate component file for import in $file -> $module (skipping)"
    continue
  fi

  if grep -qE "export\s+default" "$comp"; then
    perl -0777 -pe "s/import\s+\{\s*$base\s*\}\s+from\s+(['\"]$module['\"]\s*;)/import $base from $1/smg" -i.bak "$file"
    echo "Updated import to default in $file (component uses default export): $module"
  elif grep -qE "export\s+(function|const|class)\s+$base" "$comp"; then
    perl -0777 -pe "s/import\s+$base\s+from\s+(['\"]$module['\"]\s*;)/import { $base } from $1/smg" -i.bak "$file"
    echo "Updated import to named in $file (component uses named export): $module"
  else
    echo "INFO: Ambiguous export style for $comp — manual review suggested (skipped): $module"
  fi
done

echo
echo "Done. Review changes and .bak backups before committing:"
echo "  git status"
echo "  git diff"
