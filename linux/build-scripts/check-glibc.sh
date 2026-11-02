#!/bin/bash
# Fails if any ELF file under a prefix (default: the install root) needs a
# newer glibc than the build system's, i.e. wouldn't run on the oldest
# supported distribution.
#
#   check-glibc.sh [prefix] [max version, default: this system's glibc]
source "$(dirname "$0")/env.sh"

ROOT="${1:-$PREFIX_ROOT}"
MAX="GLIBC_${2:-$(getconf GNU_LIBC_VERSION | awk '{print $2}')}"

# Versioned glibc symbols each file needs (non-ELF files, e.g. scripts with
# the executable bit, are skipped).
needed() {
    local f
    while IFS= read -r -d '' f; do
        objdump -T "$f" 2>/dev/null | grep -oE 'GLIBC_[0-9]+(\.[0-9]+)+' | sort -Vu | sed "s|^|$f |" || true
    done < <(find "$ROOT" -type f \( -name '*.so*' -o -perm -u+x \) -print0)
}

LIST=$(needed)
NEWEST=$(awk '{print $2}' <<< "$LIST" | sort -Vu | tail -1)
echo "newest glibc symbol needed under $ROOT: ${NEWEST:-none} (limit $MAX)"
TOO_NEW=""
for v in $(awk '{print $2}' <<< "$LIST" | sort -Vu); do
    if [ "$(printf '%s\n' "$v" "$MAX" | sort -V | tail -1)" != "$MAX" ]; then
        TOO_NEW+="$(awk -v v="$v" '$2 == v' <<< "$LIST")"$'\n'
    fi
done
if [ -n "$TOO_NEW" ]; then
    echo "ERROR: these files need a newer glibc than $MAX:" >&2
    echo "$TOO_NEW" | sed 's/^/    /' >&2
    exit 1
fi
