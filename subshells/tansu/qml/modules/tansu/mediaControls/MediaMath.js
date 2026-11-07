.pragma library


function clamp01(t) {
    return t < 0 ? 0 : (t > 1 ? 1 : t);
}

function outBack(t, s) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    var c = (s === undefined ? 1.8 : s);
    var u = t - 1;
    return 1 + (c + 1) * u * u * u + c * u * u;
}

function fmt(sec) {
    sec = Math.max(0, Math.floor(Number(sec) || 0));
    var h = Math.floor(sec / 3600);
    var m = Math.floor((sec % 3600) / 60);
    var s = sec % 60;
    return (h > 0 ? h + ":" + (m < 10 ? "0" : "") + m : String(m)) + ":" + (s < 10 ? "0" : "") + s;
}

function ratio(position, length) {
    if (!(length > 0))
        return 0;
    return clamp01((Number(position) || 0) / length);
}

function left(position, length) {
    if (!(length > 0))
        return "";
    return "-" + fmt(Math.max(0, length - (Number(position) || 0)));
}

function youtubeThumb(url) {
    if (typeof url !== "string")
        return "";
    var m = url.match(/(?:[?&]v=|youtu\.be\/|\/shorts\/)([A-Za-z0-9_-]{11})/);
    return m ? "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg" : "";
}

function appLabel(raw) {
    var t = String(raw === undefined || raw === null ? "" : raw)
        .replace(/^mozilla\s+/i, "")
        .replace(/[-_]+/g, " ")
        .trim();
    if (t === "")
        return "Player";
    return t.replace(/\b([a-z])/g, function (c) { return c.toUpperCase(); });
}

function current(players, picked) {
    if (!players || players.length === 0)
        return null;
    if (picked !== null && picked !== undefined && players.indexOf(picked) >= 0)
        return picked;
    return players[0];
}

function prevPlayer(players, cur) {
    if (!players || players.length === 0)
        return null;
    var i = players.indexOf(cur);
    return players[(i <= 0 ? players.length : i) - 1];
}

function nextPlayer(players, cur) {
    if (!players || players.length === 0)
        return null;
    var i = players.indexOf(cur);
    return players[(i + 1) % players.length];
}

function bannerWord(playing, hasTrack) {
    if (!hasTrack)
        return "STANDBY";
    return playing ? "NOW PLAYING" : "PAUSED";
}

function fullCombo(r) {
    return r >= 0.97;
}

// ===== the chart =====

function hash(str) {
    var h = 2166136261 >>> 0;
    str = String(str === undefined || str === null ? "" : str);
    for (var i = 0; i < str.length; i++) {
        h ^= str.charCodeAt(i);
        h = Math.imul(h, 16777619) >>> 0;
    }
    return h >>> 0;
}

function rng(seed) {
    var a = seed >>> 0;
    return function () {
        a = (a + 0x6D2B79F5) >>> 0;
        var t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// The notes of a song: [{ t, lane, hold, len, word }], t and len as fractions
// of the song (0..1), in order of t. A note every ~6 s (12 at least, 36 at
// most); about one in five is a hold, which never runs into the next note.
// `word` picks its judgement: 0 PERFECT, 1 GREAT, 2 GOOD. [] when the song has
// no length (a live stream has nothing to chart).
function chart(seed, length, lanes) {
    if (!(length > 0))
        return [];
    lanes = lanes > 0 ? Math.floor(lanes) : 3;
    var n = Math.max(12, Math.min(36, Math.round(length / 6)));
    var r = rng(hash(String(seed) + "|" + Math.round(length)));
    var out = [];
    var lastLane = -1;
    for (var i = 0; i < n; i++) {
        var cell = (i + 0.5 + (r() - 0.5) * 0.6) / n;
        var t = 0.03 + 0.94 * cell;
        var lane = Math.floor(r() * lanes);
        if (lane === lastLane && r() < 0.6)
            lane = (lane + 1) % lanes;
        lastLane = lane;
        var hold = r() < 0.2;
        var len = 0.015 + r() * 0.03;
        var w = r();
        out.push({ t: t, lane: lane, hold: hold, len: hold ? len : 0, word: w < 0.7 ? 0 : (w < 0.9 ? 1 : 2) });
    }
    for (var j = 0; j < out.length; j++) {
        if (!out[j].hold)
            continue;
        var next = j + 1 < out.length ? out[j + 1].t : 1;
        out[j].len = Math.max(0.008, Math.min(out[j].len, (next - out[j].t) * 0.7));
    }
    return out;
}

// How many notes the playhead (0..1) has reached: the combo.
function combo(notes, head) {
    var c = 0;
    for (var i = 0; i < notes.length; i++) {
        if (notes[i].t <= head)
            c++;
        else
            break;
    }
    return c;
}

var JUDGE = ["PERFECT", "GREAT", "GOOD"];

function judgeWord(i) {
    return JUDGE[Math.max(0, Math.min(2, i | 0))];
}

function pickIndex(name, n) {
    return n > 0 ? hash(name) % n : 0;
}

// ===== the scrubber's bars =====

function wave(seed, n) {
    n = Math.max(1, Math.floor(Number(n)) || 1);
    var s = String(seed === undefined || seed === null ? "" : seed);
    var out = [];
    var k;
    if (s === "") {
        for (k = 0; k < n; k++)
            out.push(0.3);
        return out;
    }
    var r = rng(hash(s));
    var prev = 0.5;
    var raw = [];
    var top = 0.0001;
    for (k = 0; k < n; k++) {
        var t = n > 1 ? k / (n - 1) : 0.5;
        var v = prev * 0.4 + r() * 0.6;
        prev = v;
        var h = v * (0.55 + 0.45 * Math.sin(Math.PI * t));
        raw.push(h);
        top = Math.max(top, h);
    }
    for (k = 0; k < n; k++)
        out.push(Math.max(0.2, Math.min(1, 0.2 + 0.8 * raw[k] / top)));
    return out;
}

function barLit(i, n, ratio) {
    if (!(n > 0))
        return false;
    return (i + 0.5) / n <= ratio;
}

function ratioAt(x, x0, w) {
    if (!(w > 0))
        return 0;
    return clamp01((x - x0) / w);
}
