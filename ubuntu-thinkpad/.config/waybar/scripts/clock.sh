#!/bin/sh
# Waybar clock; tooltip is a full-year calendar (today in blue, Belgian public holidays in red) built with date and awk.
now=$(date '+%H:%M:%S %a%d%bW%V')
day=$(date '+%A %d %B %Y')
year=$(date +%Y)
today=$(date +%m-%d)
# Easter Sunday as MM-DD (Meeus/Jones/Butcher algorithm)
easter=$(awk -v y="$year" 'BEGIN {
    a = y % 19; b = int(y / 100); c = y % 100; d = int(b / 4); e = b % 4
    f = int((b + 8) / 25); g = int((b - f + 1) / 3); h = (19 * a + b - d - g + 15) % 30
    i = int(c / 4); k = c % 4; l = (32 + 2 * e + 2 * i - h - k) % 7
    m = int((a + 11 * h + 22 * l) / 451); s = h + l - 7 * m + 114
    printf "%02d-%02d", int(s / 31), (s % 31) + 1
}')
# Belgian public holidays as "MM-DD Name", sorted by date and joined with |
holidays=$({
    printf '01-01 New Year\n05-01 Labour Day\n07-21 National Day\n08-15 Assumption\n11-01 All Saints\n11-11 Armistice\n12-25 Christmas\n'
    printf '%s Easter Monday\n' "$(date -d "$year-$easter +1 day" +%m-%d)"
    printf '%s Ascension\n' "$(date -d "$year-$easter +39 days" +%m-%d)"
    printf '%s Whit Monday\n' "$(date -d "$year-$easter +50 days" +%m-%d)"
} | sort | tr '\n' '|')
cal=$(awk -v y="$year" -v today="$today" -v hol="$holidays" -v q="'" '
function rep(s, n,   out, i) {
    out = ""
    for (i = 0; i < n; i++) out = out s
    return out
}
BEGIN {
    split("January February March April May June July August September October November December", names, " ")
    split("31 28 31 30 31 30 31 31 30 31 30 31", days, " ")
    split("0 3 2 5 0 3 5 1 4 6 2 4", off, " ")
    yr = y + 0
    if ((yr % 4 == 0 && yr % 100 != 0) || yr % 400 == 0) days[2] = 29
    hol_open = "<span foreground=" q "#f38ba8" q ">"
    today_open = "<span background=" q "#89b4fa" q " foreground=" q "#11111b" q ">"
    endspan = "</span>"
    n = split(hol, hl, "[|]")
    for (i = 1; i <= n; i++) if (hl[i] != "") hname[substr(hl[i], 1, 5)] = substr(hl[i], 7)
    for (m = 1; m <= 12; m++) {
        # Sakamoto weekday of the 1st (0 = Sunday)
        yy = yr - (m < 3)
        first = (yy + int(yy / 4) - int(yy / 100) + int(yy / 400) + off[m] + 1) % 7
        for (r = 0; r < 6; r++) for (c = 0; c < 7; c++) cell[r, c] = "  "
        for (d = 1; d <= days[m]; d++) {
            p = first + d - 1
            key = sprintf("%02d-%02d", m, d)
            txt = sprintf("%2d", d)
            if (key == today) txt = today_open txt endspan
            else if (key in hname) txt = hol_open txt endspan
            cell[int(p / 7), p % 7] = txt
        }
        pad = int((20 - length(names[m])) / 2)
        blk[m, 0] = rep(" ", pad) "<b>" names[m] "</b>" rep(" ", 20 - pad - length(names[m]))
        blk[m, 1] = "Su Mo Tu We Th Fr Sa"
        for (r = 0; r < 6; r++) {
            row = cell[r, 0]
            for (c = 1; c < 7; c++) row = row " " cell[r, c]
            blk[m, r + 2] = row
        }
    }
    printf "%s<b>%s</b>\\n\\n", rep(" ", int((89 - length(y)) / 2)), y
    for (R = 0; R < 3; R++) {
        if (R > 0) printf "\\n"
        for (L = 0; L < 8; L++) {
            line = ""
            for (C = 0; C < 4; C++) line = line (C ? "   " : "") blk[R * 4 + C + 1, L]
            printf "%s\\n", line
        }
    }
    printf "\\n%stoday%s   %spublic holiday%s\\n\\n", today_open, endspan, hol_open, endspan
    for (i = 1; i <= n; i++) if (hl[i] != "") {
        mo = substr(hl[i], 1, 2) + 0
        printf "%s%2d %s%s  %s\\n", hol_open, substr(hl[i], 4, 2) + 0, substr(names[mo], 1, 3), endspan, substr(hl[i], 7)
    }
}')
printf '{"text": "🕒%s", "tooltip": "%s\\n<tt>%s</tt>"}\n' "$now" "$day" "$cal"
