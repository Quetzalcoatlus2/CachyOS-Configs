#!/bin/sh
# Launcher listing PATH executables, most-launched first.
# Launch counts live in ~/.local/state/wmenu-usage as "count name" lines.
usage="$HOME/.local/state/wmenu-usage"
mkdir -p "$(dirname "$usage")"
touch "$usage"

names=$(
    IFS=:
    for d in $PATH; do
        [ -d "$d" ] && find -L "$d" -maxdepth 1 -type f -executable -printf '%f\n' 2>/dev/null
    done | sort -u
)

sorted=$(printf '%s\n' "$names" | awk -v usage="$usage" '
    BEGIN { while ((getline line < usage) > 0) { split(line, a, " "); if (a[2] != "") count[a[2]] = a[1] } }
    NF { print ((($1) in count) ? count[$1] : 0), $1 }
' | sort -k1,1nr -k2,2 | cut -d' ' -f2-)

choice=$(printf '%s\n' "$sorted" | wmenu -i -p 'Run:' \
    -N 000000 -n 888888 -M 000000 -m ffffff -S 000000 -s ffffff)

[ -n "$choice" ] || exit 0

awk -v name="$choice" '
    BEGIN { found = 0 }
    { if ($2 == name) { $1 = $1 + 1; found = 1 } print $1, $2 }
    END { if (!found) print 1, name }
' "$usage" > "$usage.tmp" && mv "$usage.tmp" "$usage"

exec setsid -f sh -c "$choice" >/dev/null 2>&1
