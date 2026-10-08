#!/bin/sh
# Waybar RAM module: values rounded to one decimal in GB (1024-based, same as free -h).
export LC_NUMERIC=C
awk '
/^MemTotal:/     { total = $2 }
/^MemAvailable:/ { avail = $2 }
/^SwapTotal:/    { swt = $2 }
/^SwapFree:/     { swf = $2 }
END {
    used = total - avail
    pct = int(used * 100 / total + 0.5)
    swu = swt - swf
    swpct = (swt > 0) ? int(swu * 100 / swt + 0.5) : 0
    cls = ""
    if (pct >= 90) cls = "critical"
    else if (pct >= 75) cls = "warning"
    printf "{\"text\": \"🧠%d%%\", \"class\": \"%s\", \"tooltip\": \"Memory Allocation:\\n•Physical RAM Used: %.1f GB / %.1f GB (%d%%)\\n•Available Memory: %.1f GB\\n•Swap Allocation: %.1f GB / %.1f GB (%d%%)\\n\\nAction: Click to launch btop.\"}\n", pct, cls, used / 1048576, total / 1048576, pct, avail / 1048576, swu / 1048576, swt / 1048576, swpct
}' /proc/meminfo
