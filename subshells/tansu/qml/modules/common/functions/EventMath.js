.pragma library

// Pure logic for the desktop calendar card (CalendarCardWidget.qml,
// services/CalendarCardService.qml) — no QML, no Quickshell, so it can be
// checked on its own (tests/calendar-test/events_unit.js).
//
// An event is a plain object:
//
//   { id: "e1", title: "Rehearsal", date: "2026-10-23", time: "14:00",
//     note: "Studio B", color: 0..4, kind: "event" | "deadline", done: false }
//
//   date   "YYYY-MM-DD", a real calendar day (month is 1-based in the text,
//          like CalendarMath.dayKey writes it, so the two agree)
//   time   "HH:MM" (24 h) or "" for an all-day entry
//   color  index into Theme.attributeColors (Cool, Cute, Happy, Mysterious, Pure)
//   kind   a deadline can be ticked off (done); an event is just in the diary
//
// `today` arguments are JavaScript Dates; only their calendar day is used.

var MAX_EVENTS = 1000;
var MAX_TITLE = 80;
var MAX_NOTE = 240;
var COLORS = 5;

var SOON_DAYS = 3;

function pad2(n) {
    return (n < 10 ? "0" : "") + n;
}

function dateKey(y, m, d) {
    return y + "-" + pad2(m + 1) + "-" + pad2(d);
}

function keyOf(date) {
    return dateKey(date.getFullYear(), date.getMonth(), date.getDate());
}

function parseDate(text) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(text));
    if (!m)
        return null;
    var y = parseInt(m[1], 10);
    var mo = parseInt(m[2], 10) - 1;
    var d = parseInt(m[3], 10);
    var back = new Date(y, mo, d);
    if (back.getFullYear() !== y || back.getMonth() !== mo || back.getDate() !== d)
        return null;
    return { y: y, m: mo, d: d };
}

function normalizeTime(text) {
    var s = String(text === undefined || text === null ? "" : text).trim();
    if (s === "")
        return "";
    var h, mi;
    var m = /^(\d{1,2}):(\d{2})$/.exec(s);
    if (m) {
        h = parseInt(m[1], 10);
        mi = parseInt(m[2], 10);
    } else if ((m = /^(\d{1,2})(\d{2})$/.exec(s))) {
        h = parseInt(m[1], 10);
        mi = parseInt(m[2], 10);
    } else if ((m = /^(\d{1,2})$/.exec(s))) {
        h = parseInt(m[1], 10);
        mi = 0;
    } else {
        return null;
    }
    if (h > 23 || mi > 59)
        return null;
    return pad2(h) + ":" + pad2(mi);
}

function timeText(time, use24h) {
    if (!time)
        return "All day";
    if (use24h)
        return time;
    var h = parseInt(time.slice(0, 2), 10);
    var mi = time.slice(3, 5);
    var ap = h >= 12 ? "PM" : "AM";
    var h12 = h % 12 === 0 ? 12 : h % 12;
    return h12 + ":" + mi + " " + ap;
}

function clampColor(c) {
    var n = parseInt(c, 10);
    if (!(n >= 0 && n < COLORS))
        return 0;
    return n;
}

function clean(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    var title = String(raw.title === undefined || raw.title === null ? "" : raw.title)
        .replace(/\s+/g, " ").trim().slice(0, MAX_TITLE);
    if (title === "")
        return null;
    if (!parseDate(raw.date))
        return null;
    var time = normalizeTime(raw.time);
    var kind = raw.kind === "deadline" ? "deadline" : "event";
    return {
        id: typeof raw.id === "string" ? raw.id : "",
        title: title,
        date: String(raw.date),
        time: time === null ? "" : time,
        note: String(raw.note === undefined || raw.note === null ? "" : raw.note)
            .replace(/\s+/g, " ").trim().slice(0, MAX_NOTE),
        color: clampColor(raw.color),
        kind: kind,
        done: kind === "deadline" && raw.done === true
    };
}

function newId(list) {
    var used = {};
    for (var i = 0; i < list.length; i++)
        used[list[i].id] = true;
    var n = list.length + 1;
    while (used["e" + n])
        n++;
    return "e" + n;
}

function parseAll(raw) {
    var out = [];
    if (!Array.isArray(raw))
        return out;
    var used = {};
    var n = 1;
    for (var i = 0; i < raw.length && out.length < MAX_EVENTS; i++) {
        var ev = clean(raw[i]);
        if (!ev)
            continue;
        if (ev.id === "" || used[ev.id]) {
            while (used["e" + n])
                n++;
            ev.id = "e" + n;
        }
        used[ev.id] = true;
        out.push(ev);
    }
    return out;
}

function compare(a, b) {
    if (a.date !== b.date)
        return a.date < b.date ? -1 : 1;
    if (a.time !== b.time) {
        if (a.time === "")
            return -1;
        if (b.time === "")
            return 1;
        return a.time < b.time ? -1 : 1;
    }
    var ta = a.title.toLowerCase();
    var tb = b.title.toLowerCase();
    if (ta !== tb)
        return ta < tb ? -1 : 1;
    return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0);
}

function sorted(list) {
    return list.slice().sort(compare);
}

function byDay(list) {
    var out = {};
    var s = sorted(list);
    for (var i = 0; i < s.length; i++) {
        var k = s[i].date;
        if (!out[k])
            out[k] = [];
        out[k].push(s[i]);
    }
    return out;
}

function diffTo(today, key) {
    var p = parseDate(key);
    if (!p)
        return NaN;
    var a = Date.UTC(today.getFullYear(), today.getMonth(), today.getDate());
    var b = Date.UTC(p.y, p.m, p.d);
    return Math.round((b - a) / 86400000);
}

function dueState(ev, diff) {
    if (ev.kind !== "deadline")
        return "event";
    if (ev.done)
        return "done";
    if (diff < 0)
        return "overdue";
    if (diff === 0)
        return "today";
    if (diff <= SOON_DAYS)
        return "soon";
    return "later";
}

function countdown(ev, diff) {
    if (ev.kind === "deadline" && ev.done)
        return "Done";
    if (diff === 0)
        return "Today";
    if (diff === 1)
        return "Tomorrow";
    var n = Math.abs(diff);
    var unit;
    if (n < 21)
        unit = n + (n === 1 ? " day" : " days");
    else if (n < 120)
        unit = Math.round(n / 7) + " weeks";
    else
        unit = Math.round(n / 30.44) + " months";
    if (diff > 0)
        return "in " + unit;
    if (diff === -1)
        return ev.kind === "deadline" ? "1 day late" : "Yesterday";
    return unit + (ev.kind === "deadline" ? " late" : " ago");
}

function upcoming(list, today, limit) {
    var todayKey = keyOf(today);
    var late = [];
    var ahead = [];
    var s = sorted(list);
    for (var i = 0; i < s.length; i++) {
        var ev = s[i];
        if (ev.date < todayKey) {
            if (ev.kind === "deadline" && !ev.done)
                late.push(ev);
        } else if (!(ev.kind === "deadline" && ev.done)) {
            ahead.push(ev);
        }
    }
    var out = late.concat(ahead);
    if (limit > 0 && out.length > limit)
        out = out.slice(0, limit);
    return out;
}

function monthSummary(list, year, month, today) {
    var prefix = year + "-" + pad2(month + 1) + "-";
    var todayKey = keyOf(today);
    var events = 0;
    var open = 0;
    var late = 0;
    for (var i = 0; i < list.length; i++) {
        var ev = list[i];
        if (ev.date.indexOf(prefix) !== 0)
            continue;
        events++;
        if (ev.kind === "deadline" && !ev.done) {
            open++;
            if (ev.date < todayKey)
                late++;
        }
    }
    return { events: events, open: open, late: late };
}

var RANK = { overdue: 4, today: 3, soon: 2, later: 1 };

function dayMarks(entries, diff, max) {
    var colors = [];
    var worst = "";
    if (!entries)
        return { colors: colors, count: 0, deadline: worst };
    for (var i = 0; i < entries.length; i++) {
        var ev = entries[i];
        if (colors.length < max && colors.indexOf(ev.color) < 0)
            colors.push(ev.color);
        var st = dueState(ev, diff);
        if (RANK[st] && (!worst || RANK[st] > RANK[worst]))
            worst = st;
    }
    return { colors: colors, count: entries.length, deadline: worst };
}

function changed(ev, fields) {
    var next = {};
    var k;
    for (k in ev)
        next[k] = ev[k];
    for (k in fields)
        next[k] = fields[k];
    var c = clean(next);
    if (!c)
        return null;
    c.id = ev.id;
    return c;
}
