#!/usr/bin/env python3
import calendar
import datetime
import json

def get_easter(year):
    a = year % 19
    b = year // 100
    c = year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = ((h + l - 7 * m + 114) % 31) + 1
    return datetime.date(year, month, day)

def get_belgian_holidays(year):
    easter = get_easter(year)
    return {
        datetime.date(year, 1, 1): "New Year's Day (Nieuwjaar)",
        easter + datetime.timedelta(days=1): "Easter Monday (Paasmaandag)",
        datetime.date(year, 5, 1): "Labour Day (Dag van de Arbeid)",
        easter + datetime.timedelta(days=39): "Ascension Day (O.L.V. Hemelvaart)",
        easter + datetime.timedelta(days=50): "Whit Monday (Pinkstermaandag)",
        datetime.date(year, 7, 21): "Belgian National Day (Nationale feestdag)",
        datetime.date(year, 8, 15): "Assumption of Mary (Hemelvaart)",
        datetime.date(year, 11, 1): "All Saints' Day (Allerheiligen)",
        datetime.date(year, 11, 11): "Armistice Day (Wapenstilstand)",
        datetime.date(year, 12, 25): "Christmas Day (Kerstmis)",
    }

now = datetime.datetime.now()
today = now.date()
year = now.year
current_iso_week = today.isocalendar()[1]
holidays = get_belgian_holidays(year)

month_names = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
]

lines = []
# Total line width is 78 characters (3 columns of 24 chars + 2 separators of 3 spaces)
lines.append(f"<span color='#ffead3'><b>{'Year ' + str(year):^78}</b></span>")
lines.append("")

for row in range(4):
    m_start = row * 3 + 1
    months = [m_start, m_start + 1, m_start + 2]

    # Month header row
    title_cols = [f"<span color='#ffead3'><b>{month_names[m]:^24}</b></span>" for m in months]
    lines.append("   ".join(title_cols))

    # Day-of-week header row (Wk + Mo to Su)
    weekday_col = "<span color='#99ffdd'>Wk</span>  <span color='#ffcc66'>Mo Tu We Th Fr Sa Su</span>"
    lines.append(f"{weekday_col}   {weekday_col}   {weekday_col}")

    # Week matrix per month
    month_weeks = [calendar.monthcalendar(year, m) for m in months]
    max_weeks = max(len(w) for w in month_weeks)

    for w_idx in range(max_weeks):
        row_segments = []
        for m_idx, m in enumerate(months):
            weeks = month_weeks[m_idx]
            if w_idx < len(weeks):
                days = weeks[w_idx]
                first_day = next(d for d in days if d != 0)
                w_num = datetime.date(year, m, first_day).isocalendar()[1]

                # Highlight the current active week
                if year == today.year and m == today.month and w_num == current_iso_week:
                    w_tag = f"<span color='#ff6699'><b>W{w_num:02d}</b></span> "
                else:
                    w_tag = f"<span color='#99ffdd'>W{w_num:02d}</span> "

                formatted_days = []
                for d in days:
                    if d == 0:
                        formatted_days.append("<span color='#45475a'>..</span>")
                    else:
                        d_date = datetime.date(year, m, d)
                        if d_date == today:
                            formatted_days.append(f"<span color='#ff6699'><b><u>{d:02d}</u></b></span>")
                        elif d_date in holidays:
                            formatted_days.append(f"<span color='#99ffdd'><b>{d:02d}</b></span>")
                        else:
                            formatted_days.append(f"<span color='#ecc6d9'>{d:02d}</span>")
                row_segments.append(w_tag + " ".join(formatted_days))
            else:
                row_segments.append(" " * 24)
        lines.append("   ".join(row_segments))
    lines.append("")

# Belgian public holidays list
lines.append("<span color='#99ffdd'><b>Belgian Public Holidays:</b></span>")
next_holiday_marked = False
for h_date in sorted(holidays.keys()):
    h_title = holidays[h_date]
    d_str = h_date.strftime("%d %b")
    if h_date < today:
        lines.append(f"<span color='#6c7086'>• {d_str}: {h_title}</span>")
    elif not next_holiday_marked and h_date >= today:
        diff = (h_date - today).days
        lines.append(f"<span color='#fab387'><b>▶ {d_str}: {h_title} (in {diff}d)</b></span>")
        next_holiday_marked = True
    else:
        lines.append(f"<span color='#cdd6f4'>• {d_str}: {h_title}</span>")

lines.append("")
lines.append("<span color='#99ffdd'>■</span> Holiday   <span color='#ff6699'>■</span> Today")

tooltip_markup = "<tt><small>" + "\n".join(lines) + "</small></tt>"
display_text = f"🕒{now.strftime('%H:%M:%S')} {now.strftime('%a%d%b')}W{now.isocalendar()[1]}"

print(json.dumps({
    "text": display_text,
    "tooltip": tooltip_markup,
    "class": "custom-calendar"
}))
