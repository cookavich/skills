#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: repo-inventory.sh [repo-root] [output-dir]" >&2
}

repo_root="${1:-$(pwd)}"
output_dir="${2:-}"

if [ ! -d "$repo_root" ]; then
  echo "repo-inventory: repo root does not exist: $repo_root" >&2
  usage
  exit 2
fi

repo_root="$(cd "$repo_root" && pwd)"

if [ -z "$output_dir" ]; then
  output_dir="$repo_root/.codebase-wiki"
elif [ "${output_dir#/}" = "$output_dir" ]; then
  output_dir="$repo_root/$output_dir"
fi

mkdir -p "$output_dir"
inventory="$output_dir/_inventory.md"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/codebase-wiki.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

files="$tmp_dir/files.txt"
tracked="$tmp_dir/tracked.txt"

cd "$repo_root"

# Compute output-dir relative to repo root so we can exclude the wiki's own
# files from the scan. Empty when output-dir is outside repo-root.
case "$output_dir" in
  "$repo_root"/*)
    rel_output_dir="${output_dir#$repo_root/}"
    ;;
  *)
    rel_output_dir=""
    ;;
esac

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git ls-files > "$tracked"
else
  : > "$tracked"
fi

if [ -s "$tracked" ]; then
  cp "$tracked" "$files"
else
  find . \
    -path './.git' -prune -o \
    -path './node_modules' -prune -o \
    -path './vendor' -prune -o \
    -path './dist' -prune -o \
    -path './build' -prune -o \
    -path './coverage' -prune -o \
    -path './.next' -prune -o \
    -path './.turbo' -prune -o \
    -path './target' -prune -o \
    -path './DerivedData' -prune -o \
    -path './.venv' -prune -o \
    -path './venv' -prune -o \
    -type f -print | sed 's#^\./##' | sort > "$files"
fi

if [ -n "$rel_output_dir" ]; then
  awk -v p="$rel_output_dir/" 'index($0, p) != 1' "$files" > "$tmp_dir/files.filtered"
  mv "$tmp_dir/files.filtered" "$files"
fi

file_count="$(wc -l < "$files" | tr -d ' ')"

write_section() {
  printf '\n## %s\n\n' "$1" >> "$inventory"
}

{
  echo "# Repository Inventory"
  echo
  echo "- Repository: \`$(basename "$repo_root")\`"
  echo "- Root: repository root"
  echo "- Generated: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`"
  echo "- Files indexed: $file_count"
} > "$inventory"

write_section "Top-Level Files"
awk 'index($0, "/") == 0 { print "- `" $0 "`" }' "$files" | head -80 >> "$inventory"

write_section "Top-Level Directories"
awk 'index($0, "/") > 0 { split($0, parts, "/"); print parts[1] }' "$files" \
  | sort | uniq -c | sort -nr \
  | awk '{ count=$1; $1=""; sub(/^ /, ""); print "- `" $0 "` - " count " files" }' \
  | head -80 >> "$inventory"

write_section "File Types"
awk '
  {
    name=$0
    n=split(name, parts, "/")
    base=parts[n]
    if (base !~ /\./) {
      ext="[no extension]"
    } else {
      sub(/^.*\./, "", base)
      ext="." base
    }
    counts[ext]++
  }
  END {
    for (ext in counts) {
      print counts[ext], ext
    }
  }
' "$files" | sort -nr | head -60 | awk '{ count=$1; $1=""; sub(/^ /, ""); print "- `" $0 "` - " count " files" }' >> "$inventory"

write_section "Manifests and Build Configuration"
grep -E '(^|/)(package\.json|pnpm-lock\.yaml|yarn\.lock|package-lock\.json|bun\.lockb|tsconfig[^/]*\.json|vite\.config\.[^.]+|webpack\.config\.[^.]+|rollup\.config\.[^.]+|next\.config\.[^.]+|Dockerfile|docker-compose[^/]*\.ya?ml|Makefile|Cargo\.toml|go\.mod|pom\.xml|build\.gradle|settings\.gradle|pyproject\.toml|requirements[^/]*\.txt|Pipfile|Gemfile|composer\.json|pubspec\.yaml|Package\.swift|.*\.xcodeproj/project\.pbxproj)$' "$files" \
  | sed 's/.*/- `&`/' | head -120 >> "$inventory" || true

write_section "Repository Documentation"
grep -Ei '(^|/)(README|AGENTS|CLAUDE|CONTRIBUTING|ARCHITECTURE|CHANGELOG|SECURITY|CODEOWNERS|LICENSE)(\.[^/]*)?$|(^|/)docs/.*\.(md|mdx|txt|rst)$' "$files" \
  | sed 's/.*/- `&`/' | head -160 >> "$inventory" || true

write_section "Docs Site Configuration"
docs_output=$(grep -E '(^|/)(mkdocs\.ya?ml|book\.toml|typedoc\.json|\.readthedocs\.ya?ml|_config\.yml|docusaurus\.config\.[a-z]+|astro\.config\.[a-z]+|\.vitepress/config\.[a-z]+|docs/conf\.py)$' "$files" 2>/dev/null | sed 's/.*/- `&`/' | head -20 || true)
if [ -n "$docs_output" ]; then
  printf "%s\n" "$docs_output" >> "$inventory"
else
  echo "_None detected._" >> "$inventory"
fi

write_section "Likely Entrypoints and Routing"
grep -Ei '(^|/)(main|app|server|cli|routes?|router|worker|handler|lambda|bootstrap)\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|cs|swift|kt)$|^src/index\.(ts|tsx|js|jsx|mjs|cjs)$|^src/(main|app|server)\.(ts|tsx|js|jsx|mjs|cjs)$' "$files" \
  | sed 's/.*/- `&`/' | head -160 >> "$inventory" || true

write_section "Configuration and Environment"
grep -Ei '(^|/)(\.env(\..*)?\.example|env\.example|example\.env|config\.(ts|tsx|js|json|yaml|yml|toml)|.*config.*\.(ts|tsx|js|json|yaml|yml|toml)|terraform/.*|infra/.*|infrastructure/.*|\.github/workflows/.*|azure-pipelines\.ya?ml)$' "$files" \
  | sed 's/.*/- `&`/' | head -180 >> "$inventory" || true

write_section "Tests"
grep -Ei '(\.|/)(test|spec)\.(ts|tsx|js|jsx|py|go|rs|java|cs|kt|swift)$|(^|/)(__tests__|tests?|specs?)/' "$files" \
  | sed 's/.*/- `&`/' | head -220 >> "$inventory" || true

if [ -f package.json ] && command -v node >/dev/null 2>&1; then
  write_section "Package Scripts"
  node -e '
    const fs = require("fs");
    const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
    const scripts = pkg.scripts || {};
    for (const name of Object.keys(scripts).sort()) {
      console.log(`- \`${name}\` - \`${scripts[name]}\``);
    }
  ' >> "$inventory" 2>/dev/null || true
fi

if [ -f Cargo.toml ]; then
  write_section "Cargo Package"
  awk '
    /^\[package\]/ { p=1; next }
    /^\[/ { p=0 }
    p && /^(name|version|edition) *=/ { print "- " $0 }
  ' Cargo.toml >> "$inventory" || true

  cargo_deps=$(awk '
    /^\[dependencies\]/ { p=1; next }
    /^\[/ { p=0 }
    p && !/^#/ && NF > 0 && /=/ { print "- `" $1 "`" }
  ' Cargo.toml || true)
  if [ -n "$cargo_deps" ]; then
    printf "\nDependencies:\n\n%s\n" "$cargo_deps" >> "$inventory"
  fi
fi

if [ -f go.mod ]; then
  write_section "Go Module"
  grep -E '^module ' go.mod | head -1 | awk '{ print "- Module: `" $2 "`" }' >> "$inventory" || true
  grep -E '^go ' go.mod | head -1 | awk '{ print "- Go version: `" $2 "`" }' >> "$inventory" || true

  go_deps=$(awk '
    /^require[[:space:]]*\(/ { in_block=1; next }
    in_block && /^\)/ { in_block=0; next }
    in_block && NF >= 2 {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]*\/\/.*$/, "", line)
      if (length(line) > 0) print "- `" line "`"
    }
    /^require [^(]/ {
      line=$0
      sub(/^require[[:space:]]+/, "", line)
      sub(/[[:space:]]*\/\/.*$/, "", line)
      print "- `" line "`"
    }
  ' go.mod | head -80 || true)
  if [ -n "$go_deps" ]; then
    printf "\nDependencies:\n\n%s\n" "$go_deps" >> "$inventory"
  fi
fi

if [ -f pyproject.toml ]; then
  write_section "Python Project"
  awk '
    /^\[project\]/ { p=1; next }
    /^\[/ { p=0 }
    p && /^(name|version|requires-python) *=/ { print "- " $0 }
  ' pyproject.toml >> "$inventory" || true

  poetry_deps=$(awk '
    /^\[tool\.poetry\.dependencies\]/ { p=1; next }
    /^\[/ { p=0 }
    p && !/^#/ && NF > 0 && /=/ { print "- `" $1 "`" }
  ' pyproject.toml || true)
  if [ -n "$poetry_deps" ]; then
    printf "\nDependencies (Poetry):\n\n%s\n" "$poetry_deps" >> "$inventory"
  fi

  pep_deps=$(awk '
    /^\[project\]/ { in_proj=1; next }
    /^\[/ { in_proj=0; in_arr=0 }
    in_proj && /^dependencies *=/ {
      in_arr=1
      if (/\]/) in_arr=0
      next
    }
    in_arr && /\]/ { in_arr=0; next }
    in_arr {
      line=$0
      gsub(/[",]/, "", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (length(line) > 0) print "- `" line "`"
    }
  ' pyproject.toml || true)
  if [ -n "$pep_deps" ]; then
    printf "\nDependencies (PEP 621):\n\n%s\n" "$pep_deps" >> "$inventory"
  fi
fi

if [ -f pom.xml ]; then
  write_section "Maven Project"
  awk '
    /<dependencies>/ { stop=1 }
    !stop && /<groupId>/ && !got_g {
      line=$0; sub(/^.*<groupId>/, "", line); sub(/<\/groupId>.*$/, "", line)
      print "- groupId: `" line "`"; got_g=1
    }
    !stop && /<artifactId>/ && !got_a {
      line=$0; sub(/^.*<artifactId>/, "", line); sub(/<\/artifactId>.*$/, "", line)
      print "- artifactId: `" line "`"; got_a=1
    }
    !stop && /<version>/ && !got_v {
      line=$0; sub(/^.*<version>/, "", line); sub(/<\/version>.*$/, "", line)
      print "- version: `" line "`"; got_v=1
    }
  ' pom.xml >> "$inventory" || true

  maven_deps=$(awk '
    /<dependency>/ { in_dep=1; g=""; a=""; v=""; next }
    /<\/dependency>/ {
      if (a) {
        if (v) print "- `" g ":" a ":" v "`"
        else print "- `" g ":" a "`"
      }
      in_dep=0
    }
    in_dep && /<groupId>/ {
      line=$0; sub(/^.*<groupId>/, "", line); sub(/<\/groupId>.*$/, "", line); g=line
    }
    in_dep && /<artifactId>/ {
      line=$0; sub(/^.*<artifactId>/, "", line); sub(/<\/artifactId>.*$/, "", line); a=line
    }
    in_dep && /<version>/ {
      line=$0; sub(/^.*<version>/, "", line); sub(/<\/version>.*$/, "", line); v=line
    }
  ' pom.xml | head -80 || true)
  if [ -n "$maven_deps" ]; then
    printf "\nDependencies:\n\n%s\n" "$maven_deps" >> "$inventory"
  fi
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  write_section "Recently Changed Files (last 6 months)"
  git log --name-only --pretty=format: --since='6 months ago' 2>/dev/null \
    | sed '/^$/d' \
    | awk -v exclude="$rel_output_dir" '
        exclude != "" && index($0, exclude "/") == 1 { next }
        { print }
      ' \
    | sort | uniq -c | sort -nr | head -80 \
    | awk '{ count=$1; $1=""; sub(/^ /, ""); print "- `" $0 "` - " count " commits" }' >> "$inventory" || true

  write_section "Hot-spots by Top-Level Directory (last 6 months)"
  git log --name-only --pretty=format: --since='6 months ago' 2>/dev/null \
    | sed '/^$/d' \
    | awk -v exclude="$rel_output_dir" '
        exclude != "" && index($0, exclude "/") == 1 { next }
        { print }
      ' \
    | awk -F'/' 'NF > 1 { print $1 } NF == 1 { print "(root)" }' \
    | sort | uniq -c | sort -nr | head -20 \
    | awk '{ count=$1; $1=""; sub(/^ /, ""); print "- `" $0 "` - " count " commits" }' >> "$inventory" || true
fi

write_section "Module Dependency Hints"
echo "_Hints, not authoritative — regex-extracted from top-of-file imports; misses dynamic imports and path-mapping edge cases._" >> "$inventory"
echo "" >> "$inventory"

grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs)$' "$files" > "$tmp_dir/source_files.txt" 2>/dev/null || true
src_count=$(wc -l < "$tmp_dir/source_files.txt" 2>/dev/null | tr -d ' ')
src_count="${src_count:-0}"

if [ "$src_count" -gt 3000 ]; then
  echo "_Skipped (source file count > 3000)._" >> "$inventory"
elif [ "$src_count" -eq 0 ]; then
  echo "_None extracted._" >> "$inventory"
else
  : > "$tmp_dir/imports.txt"

  while IFS= read -r dep_file; do
    case "$dep_file" in
      *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
        [ -f "$dep_file" ] && head -100 "$dep_file" 2>/dev/null | awk -v f="$dep_file" '
          /^[[:space:]]*import .* from / {
            line=$0
            sub(/^.*from[ \t]+/, "", line)
            sub(/^["\047]/, "", line)
            sub(/["\047].*$/, "", line)
            if (length(line) > 0) print f "\t" line
          }
          /require\(["\047][^)]+["\047]\)/ {
            line=$0
            sub(/^.*require\(["\047]/, "", line)
            sub(/["\047]\).*$/, "", line)
            if (length(line) > 0) print f "\t" line
          }
        ' >> "$tmp_dir/imports.txt" 2>/dev/null || true
        ;;
      *.py)
        [ -f "$dep_file" ] && head -100 "$dep_file" 2>/dev/null | awk -v f="$dep_file" '
          /^from [^ ]+ import / {
            line=$0
            sub(/^from[ \t]+/, "", line)
            sub(/[ \t]+import.*$/, "", line)
            gsub(/\./, "/", line)
            sub(/^\/+/, "", line)
            if (length(line) > 0) print f "\t" line
          }
          /^import [a-zA-Z_]/ {
            line=$0
            sub(/^import[ \t]+/, "", line)
            sub(/[ \t]+as[ \t].*$/, "", line)
            sub(/,.*$/, "", line)
            gsub(/\./, "/", line)
            if (length(line) > 0) print f "\t" line
          }
        ' >> "$tmp_dir/imports.txt" 2>/dev/null || true
        ;;
      *.go)
        [ -f "$dep_file" ] && head -100 "$dep_file" 2>/dev/null | awk -v f="$dep_file" '
          BEGIN { in_block=0 }
          /^import "/ {
            line=$0
            sub(/^import[ \t]+"/, "", line)
            sub(/".*$/, "", line)
            print f "\t" line
          }
          /^import \(/ { in_block=1; next }
          in_block && /^\)/ { in_block=0; next }
          in_block && /"/ {
            line=$0
            sub(/^[^"]*"/, "", line)
            sub(/".*$/, "", line)
            if (length(line) > 0) print f "\t" line
          }
        ' >> "$tmp_dir/imports.txt" 2>/dev/null || true
        ;;
      *.rs)
        [ -f "$dep_file" ] && head -100 "$dep_file" 2>/dev/null | awk -v f="$dep_file" '
          /^use / {
            line=$0
            sub(/^use[ \t]+/, "", line)
            sub(/[ ;{].*$/, "", line)
            gsub(/::/, "/", line)
            if (length(line) > 0) print f "\t" line
          }
        ' >> "$tmp_dir/imports.txt" 2>/dev/null || true
        ;;
    esac
  done < "$files"

  if [ -s "$tmp_dir/imports.txt" ]; then
    deps_output=$(awk -F'\t' '
      {
        src=$1
        imp=$2

        n=split(src, sparts, "/")
        src_dir=(n > 1) ? sparts[1] : "(root)"

        if (imp ~ /^\.\.?\//) {
          cleaned=imp
          while (cleaned ~ /^\.\.?\//) {
            sub(/^\.\.?\//, "", cleaned)
          }
          n2=split(cleaned, iparts, "/")
          imp_dir=(n2 > 0 && length(iparts[1]) > 0) ? iparts[1] : ""
        } else if (imp ~ /^[@~]\//) {
          cleaned=imp
          sub(/^[@~]\//, "", cleaned)
          n2=split(cleaned, iparts, "/")
          imp_dir=(n2 > 0) ? iparts[1] : ""
        } else if (imp ~ /\//) {
          n2=split(imp, iparts, "/")
          imp_dir=iparts[1]
        } else {
          next
        }

        if (length(imp_dir) > 0 && src_dir != imp_dir) {
          print src_dir "|" imp_dir
        }
      }
    ' "$tmp_dir/imports.txt" \
      | sort | uniq -c | sort -nr | head -30 \
      | awk '{
          count=$1
          n=split($2, parts, "|")
          if (n >= 2) print "- `" parts[1] "` -> `" parts[2] "` (" count " imports)"
        }')

    if [ -n "$deps_output" ]; then
      printf "%s\n" "$deps_output" >> "$inventory"
    else
      echo "_None extracted._" >> "$inventory"
    fi
  else
    echo "_None extracted._" >> "$inventory"
  fi
fi

write_section "TODO/FIXME/HACK Density by Top-Level Directory"
{
  if command -v rg >/dev/null 2>&1; then
    if [ -n "$rel_output_dir" ]; then
      rg --no-heading --line-number 'TODO|FIXME|HACK|XXX' \
        --glob '!.git/**' \
        --glob "!${rel_output_dir}/**" \
        . 2>/dev/null || true
    else
      rg --no-heading --line-number 'TODO|FIXME|HACK|XXX' \
        --glob '!.git/**' \
        . 2>/dev/null || true
    fi
  else
    if [ -n "$rel_output_dir" ]; then
      grep -RInE 'TODO|FIXME|HACK|XXX' \
        --exclude-dir=.git \
        --exclude-dir="$rel_output_dir" \
        . 2>/dev/null || true
    else
      grep -RInE 'TODO|FIXME|HACK|XXX' \
        --exclude-dir=.git \
        . 2>/dev/null || true
    fi
  fi
} > "$tmp_dir/markers.txt"

if [ -s "$tmp_dir/markers.txt" ]; then
  awk -F: '{ print $1 }' "$tmp_dir/markers.txt" \
    | sed 's#^\./##' \
    | awk -F'/' 'NF > 1 { print $1 } NF == 1 { print "(root)" }' \
    | sort | uniq -c | sort -nr | head -20 \
    | awk '$1 > 0 { count=$1; $1=""; sub(/^ /, ""); print "- `" $0 "` - " count " markers" }' >> "$inventory"
else
  echo "_None found._" >> "$inventory"
fi

write_section "Largest Source Files"
while IFS= read -r file; do
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.java|*.cs|*.swift|*.kt|*.rb|*.php|*.scala|*.sql|*.sh)
      if [ -f "$file" ]; then
        lines="$(wc -l < "$file" | tr -d ' ')"
        printf '%s\t%s\n' "$lines" "$file"
      fi
      ;;
  esac
done < "$files" | sort -nr | head -80 | awk -F '\t' '{ print "- `" $2 "` - " $1 " lines" }' >> "$inventory"

echo "Wrote $inventory"
