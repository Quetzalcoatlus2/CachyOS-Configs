#!/usr/bin/env python3
import calendar
import datetime
import json

now = datetime.datetime.now()
year = now.year
month = now.month
today = now.date()

# Calculate Easter Sunday using Butcher's algorithm (Gregorian calendar)
def get_easter(y):
    a = y % 19
    b = y // 100
    c = y % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    mo = (h + l - 7 * m + 114) // 31
    da = ((h + l - 7 * m + 114) % 31) + 1
    return datetime.date(y, mo, da)

easter = get_easter(year)

# 10 Statutory Public Holidays in Belgium
holidays = {
    datetime.date(year, 1, 1): "New Year's Day (Nieuwjaar)",
    easter + datetime.timedelta(days=1): "Easter Monday (Paasmaandag)",
    datetime.date(year, 5, 1): "Labour Day (Dag van de Arbeid)",
    easter + datetime.timedelta(days=39): "Ascension Day (O.L.V. Hemelvaart)",
    easter + datetime.timedelta(days=50): "Whit Monday (Pinkstermaandag)",
    datetime.date(year, 7, 21): "Belgian National Day (Nationale feestdag)",
    datetime.date(year, 8, 15): "Assumption of Mary (Hemelvaart)",
    datetime.date(year, 11, 1): "All Saints' Day (Allerheiligen)",
    datetime.date(year, 11, 11): "Armistice Day (Wapenstilstand)",
    datetime.date(year, 25, 12): "Christmas Day (Kerstmis)",
}

# Calendar Grid Construction (Monday start)
cal = calendar.Calendar(firstweekday=0)
month_weeks = cal.monthdatescalendar(year, month)

header_title = f"{now.strftime('%B %Y')}".center(26)
grid_lines = [
    f"<span color='#ffead3'><b>{header_title}</b></span>",
    "<span color='#99ffdd'>Wk</span>  <span color='#ffcc66'>Mo Tu We Th Fr Sa Su</span>"
]

for week in month_weeks:
    wk_num = week[0].isocalendar()[1]
    week_str = f"<span color='#99ffdd'>{wk_num:02d}</span>  "
    day_entries = []
    for d in week:
        if d.month != month:
            day_entries.append("<span color='#45475a'>..</span>")
        elif d == today:
            day_entries.append(f"<span color='#ff6699'><b><u>{d.day:02d}</u></b></span>")
        elif d in holidays:
            day_entries.append(f"<span color='#fab387'><b>{d.day:02d}</b></span>")
        else:
            day_entries.append(f"<span color='#ecc6d9'>{d.day:02d}</span>")
    grid_lines.append(week_str + " ".join(day_entries))

calendar_markup = "\n".join(grid_lines)

# Holiday Summary List
holiday_lines = [
    "",
    "<span color='#99ffdd'><b>Belgian Public Holidays:</b></span>"
]

next_found = False
for h_date in sorted(holidays.keys()):
    h_name = holidays[h_date]
    delta = (h_date - today).days
    date_label = h_date.strftime("%d %b")

    if delta == 0:
        holiday_lines.append(f"<span color='#a6e3a1'><b>★ {date_label}: {h_name} (Today)</b></span>")
        next_found = True
    elif delta > 0 and not next_found:
        holiday_lines.append(f"<span color='#fab387'><b>▶ {date_label}: {h_name} (in {delta}d)</b></span>")
        next_found = True
    elif delta < 0:
        holiday_lines.append(f"<span color='#6c7086'>• {date_label}: {h_name}</span>")
    else:
        holiday_lines.append(f"<span color='#cdd6f4'>• {date_label}: {h_name}</span>")

tooltip_content = (
    "<tt><small>"
    + calendar_markup
    + "\n"
    + "\n".join(holiday_lines)
    + "\n\n<span color='#fab387'>■</span> Holiday  <span color='#ff6699'>■</span> Today"
    + "</small></tt>"
)

# Retain original bar formatting: 🕒HH:MM:SS DayDDMonWWeek
bar_text = f"🕒{now.strftime('%H:%M:%S %a%d%bW%V')}"

payload = {
    "text": bar_text,
    "tooltip": tooltip_content,
    "class": "custom-calendar"
}

print(json.dumps(payload))
