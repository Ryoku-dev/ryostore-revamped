.pragma library


// How much bigger the Settings design is than the Quick Panel's once it has
// been turned a quarter turn: the smaller of 1440 / 1214 and 760 / 654. Using
// the smaller of the two means the Settings body is never smaller than the
// portrait body it replaces, in either direction, so it covers it completely
// at the moment they swap.
var SIZE_RATIO = 1.16

function clamp01(x) {
    return x < 0 ? 0 : (x > 1 ? 1 : x)
}

function lerp(a, b, t) {
    return a + (b - a) * t
}

function smooth(a, b, x) {
    var t = clamp01((x - a) / (b - a))
    return t * t * (3 - 2 * t)
}

// ===== angles =====
function quickRoll(p) {
    return -90 * p
}

function settingsRoll(p) {
    return 90 * (1 - p)
}

// ===== size =====
function dip(p, depth) {
    return 1 - depth * Math.sin(Math.PI * clamp01(p))
}

function quickScale(p, quickFit, settingsFit, depth) {
    return lerp(quickFit, SIZE_RATIO * settingsFit, p) * dip(p, depth)
}

// ===== the screens =====
// The two screens dissolve into each other while the body is on its way round. The
// Settings' comes in first and the Quick Panel's goes out after it, so the phone is never
// see-through in between (both bodies are the same size, one lies over the other).
//
// These windows are WIDE on purpose. The turn's curve (QuickPanel.flipCurve) is quickest
// through the middle, so a narrow window in `p` is over in a couple of frames and the swap
// reads as a cut. On the 260 ms turn each of these lasts roughly 70 - 100 ms: seen as a
// dissolve, without making the turn any slower.
//   settings: p 0.02 -> 0.55     quick: p 0.35 -> 0.92
// (They overlap a little at 0.35 - 0.55, where the Settings are already mostly solid.)
function quickAlpha(p) {
    return 1 - smooth(0.35, 0.92, p)
}

function settingsAlpha(p) {
    return smooth(0.02, 0.55, p)
}
