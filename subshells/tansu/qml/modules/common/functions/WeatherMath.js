.pragma library


function splitTemp(text) {
    var m = /^\s*(-?\d+(?:\.\d+)?)\s*(°\s*[CF])?/.exec(String(text || ""));
    if (!m)
        return { num: "--", unit: "" };
    return { num: m[1], unit: (m[2] || "").replace(/\s/g, "") };
}

function firstNumber(text) {
    var m = /-?\d+(?:\.\d+)?/.exec(String(text || ""));
    return m ? parseFloat(m[0]) : 0;
}

var POINTS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
              "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];

function windArrow(text) {
    var m = /\b([NSEW]{1,3})\s*$/.exec(String(text || "").trim());
    if (!m)
        return null;
    var i = POINTS.indexOf(m[1]);
    if (i < 0)
        return null;
    return (i * 22.5 + 180) % 360;
}

// "9 km/h ENE" -> { speed: "9 km/h", dir: "ENE" }. No compass point -> dir "".
// The popup shows the speed big and the point as a small tag, so a long
// reading is never cut off with an ellipsis.
function windParts(text) {
    var s = String(text || "").trim();
    var m = /^(.*?)\s*\b([NSEW]{1,3})$/.exec(s);
    if (!m || POINTS.indexOf(m[2]) < 0 || m[1] === "")
        return { speed: s, dir: "" };
    return { speed: m[1], dir: m[2] };
}

function uvLit(uv) {
    var n = Math.round(Number(uv) || 0);
    if (n <= 0) return 0;
    if (n <= 2) return 1;
    if (n <= 5) return 2;
    if (n <= 7) return 3;
    if (n <= 10) return 4;
    return 5;
}

function curvePoints(temps, left, span, top, bottom) {
    var n = temps.length;
    if (n === 0)
        return [];
    var lo = Math.min.apply(null, temps);
    var hi = Math.max.apply(null, temps);
    var out = [];
    for (var i = 0; i < n; i++) {
        var x = n === 1 ? left + span / 2 : left + span * i / (n - 1);
        var y = hi === lo ? (top + bottom) / 2 : bottom - (temps[i] - lo) / (hi - lo) * (bottom - top);
        out.push({ x: x, y: y });
    }
    return out;
}

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
