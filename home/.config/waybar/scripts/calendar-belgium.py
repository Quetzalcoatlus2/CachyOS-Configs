#!/usr/bin/env python3
import json as _json_mod
import re as _re_mod
from datetime import datetime as _dt_cls, timezone as _tz_cls
from zoneinfo import ZoneInfo as _ZoneInfo

_orig_dumps = _json_mod.dumps
def _patched_dumps(obj, *args, **kwargs):
    if isinstance(obj, dict) and "tooltip" in obj and "WORLD CLOCK" not in obj["tooltip"]:
        _cache_file = "/dev/shm/waybar_cal_tooltip_cache"
        _min_key = _dt_cls.now().strftime("%Y-%m-%d %H:%M")
        try:
            with open(_cache_file, "r") as _cf:
                _cached_key, _cached_tip = _cf.read().split("\n", 1)
                if _cached_key == _min_key:
                    obj["tooltip"] = _cached_tip
                    return _orig_dumps(obj, *args, **kwargs)
        except Exception:
            pass
        _vis_len = lambda s: len(_re_mod.sub(r"<[^>]+>", "", s))
        _t_lines = obj["tooltip"].split("\n")

        _cal_w = max((_vis_len(l) for l in _t_lines if "Mo Tu We" in l or "January" in l), default=104)

        for _i, _l in enumerate(_t_lines[:5]):
            _plain = _re_mod.sub(r"<[^>]+>", "", _l).strip()
            if "202" in _plain and len(_plain) <= 12:
                _prefix = "<tt><small>" if _l.startswith("<tt><small>") else ""
                _t_lines[_i] = f"{_prefix}<span color='#ffead3'><b>{_plain.center(_cal_w)}</b></span>"
                break

        _hol_idx = [i for i, l in enumerate(_t_lines) if "• " in l or "▶ " in l]
        if len(_hol_idx) >= 2:
            _h_items = [_t_lines[i] for i in _hol_idx]
            _mid = (len(_h_items) + 1) // 2
            _left, _right = _h_items[:_mid], _h_items[_mid:]
            _col1_w = max(_vis_len(x) for x in _left) + 4
            _paired = []
            for _r in range(_mid):
                _l_item = _left[_r]
                _pad = " " * max(2, _col1_w - _vis_len(_l_item))
                if _r < len(_right):
                    _paired.append(f"{_l_item}{_pad}{_right[_r]}")
                else:
                    _paired.append(_l_item)
            _t_lines[_hol_idx[0] : _hol_idx[-1] + 1] = _paired

        obj["tooltip"] = "\n".join(_t_lines)

        _utc = _dt_cls.now(_tz_cls.utc)
        _hubs = [
            ("Honolulu", "Pacific/Honolulu"), ("Los Angeles", "America/Los_Angeles"),
            ("Chicago", "America/Chicago"), ("New York", "America/New_York"),
            ("Buenos Aires", "America/Argentina/Buenos_Aires"), ("São Paulo", "America/Sao_Paulo"),
            ("Lisbon", "Europe/Lisbon"), ("London", "Europe/London"),
            ("Brussels", "Europe/Brussels"), ("Bucharest", "Europe/Bucharest"),
            ("Cairo", "Africa/Cairo"), ("Istanbul", "Europe/Istanbul"),
            ("Dubai", "Asia/Dubai"), ("Karachi", "Asia/Karachi"),
            ("Bangkok", "Asia/Bangkok"), ("Jakarta", "Asia/Jakarta"),
            ("Beijing", "Asia/Shanghai"), ("Hong Kong", "Asia/Hong_Kong"),
            ("Perth", "Australia/Perth"), ("Singapore", "Asia/Singapore"),
            ("Taipei", "Asia/Taipei"), ("Seoul", "Asia/Seoul"),
            ("Tokyo", "Asia/Tokyo"), ("Sydney", "Australia/Sydney"),
        ]
        _resolved = []
        for _city, _tz in _hubs:
            _d = _utc.astimezone(_ZoneInfo(_tz))
            _off = int(_d.utcoffset().total_seconds())
            _sgn = "+" if _off >= 0 else "-"
            _h, _rem = divmod(abs(_off), 3600)
            _m = _rem // 60
            _ustr = f"UTC{_sgn}{_h}" + (f":{_m:02d}" if _m else "")
            _resolved.append((_off, _city, f"{_d:%H:%M}", _ustr))

        _resolved.sort(key=lambda x: (x[0], x[1]))
        _n_rows = 6
        _cols_data = [_resolved[i * _n_rows : (i + 1) * _n_rows] for i in range(4)]
        _col_specs = [
            (max(len(x[1]) for x in col), max(len(x[3]) for x in col))
            for col in _cols_data
        ]

        _wc = ["\n\n<span color='#ffead3'><b>WORLD CLOCK</b></span>"]
        for _r in range(_n_rows):
            _row_cells = []
            for _c in range(4):
                _off, _city, _tstr, _ustr = _cols_data[_c][_r]
                _cw, _uw = _col_specs[_c]
                _c_pad = _city.ljust(_cw).replace(" ", "\u00a0")
                _u_pad = _ustr.ljust(_uw).replace(" ", "\u00a0")
                _row_cells.append(
                    f"<span color='#ecc6d9'>{_c_pad}</span>\u00a0"
                    f"<span color='#99ffdd'><b>{_tstr}</b></span>\u00a0"
                    f"<span color='#ffcc66'>{_u_pad}</span>"
                )
            _wc.append("   ".join(_row_cells))
        _block = "\n".join(_wc)
        if obj["tooltip"].endswith("</small></tt>"):
            obj["tooltip"] = obj["tooltip"][:-13] + _block + "</small></tt>"
        else:
            obj["tooltip"] += _block
        try:
            with open(_cache_file, "w") as _cf:
                _cf.write(_min_key + "\n" + obj["tooltip"])
        except Exception:
            pass
    return _orig_dumps(obj, *args, **kwargs)
_json_mod.dumps = _patched_dumps
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
# Total line width is 78 characters (3 columns of 26: 24-char grid plus a 1-char edge each side)
lines.append(f"<span color='#ffead3'><b>{'Year ' + str(year):^78}</b></span>")
lines.append("")

BOX_COLOR = "#00e5ff"
weekday_header = "<span color='#99ffdd'>Wk</span>  <span color='#ffcc66'>Mo Tu We Th Fr Sa Su</span>"


def frame(content, is_current):
    edge = f"<span color='{BOX_COLOR}'>│</span>" if is_current else " "
    return edge + content + edge


def rule(left, right, is_current):
    if not is_current:
        return " " * 26
    return f"<span color='{BOX_COLOR}'>{left}{'─' * 24}{right}</span>"


for row in range(3):
    m_start = row * 4 + 1
    months = [m_start, m_start + 1, m_start + 2, m_start + 3]
    month_weeks = [calendar.monthcalendar(year, m) for m in months]
    max_weeks = max(len(w) for w in month_weeks)

    # Each month is a column; the current month is boxed
    columns = []
    for m_idx, m in enumerate(months):
        is_current = year == today.year and m == today.month
        column = [
            rule("┌", "┐", is_current),
            frame(f"<span color='#ffead3'><b>{month_names[m]:^24}</b></span>", is_current),
            frame(weekday_header, is_current),
        ]

        weeks = month_weeks[m_idx]
        for w_idx in range(max_weeks):
            if w_idx >= len(weeks):
                column.append(frame(" " * 24, is_current))
                continue

            days = weeks[w_idx]
            first_day = next(d for d in days if d != 0)
            w_num = datetime.date(year, m, first_day).isocalendar()[1]

            # Highlight the current active week
            if is_current and w_num == current_iso_week:
                w_tag = f"<span color='#ff6699'><b>W{w_num:02d}</b></span> "
            else:
                w_tag = f"<span color='#99ffdd'>W{w_num:02d}</span> "

            formatted_days = []
            for d in days:
                if d == 0:
                    formatted_days.append("  ")
                else:
                    d_date = datetime.date(year, m, d)
                    if d_date == today:
                        formatted_days.append(f"<span color='#ff6699'><b><u>{d:02d}</u></b></span>")
                    elif d_date in holidays:
                        formatted_days.append(f"<span color='#99ffdd'><b>{d:02d}</b></span>")
                    else:
                        formatted_days.append(f"<span color='#ecc6d9'>{d:02d}</span>")
            column.append(frame(w_tag + " ".join(formatted_days), is_current))

        column.append(rule("└", "┘", is_current))
        columns.append(column)

    for line_idx in range(len(columns[0])):
        lines.append("".join(column[line_idx] for column in columns))
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
display_text = f"<span font_features='tnum'>🕒{now.strftime('%H:%M:%S')} {now.strftime('%a%d%b')}W{now.isocalendar()[1]}</span>"

print(json.dumps({
    "text": display_text,
    "tooltip": tooltip_markup,
    "class": "custom-calendar"
}))
