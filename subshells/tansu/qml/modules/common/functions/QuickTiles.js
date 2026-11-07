.pragma library


// Every button that can live on the panel, each wired to a Ryoku service or a
// real local tool. Order here is only the order the "add" tray lists the unused
// ones in.
var catalog = ["network", "bluetooth", "keepAwake", "microphone", "speaker",
               "notifications", "nightLight", "powerProfile",
               "screenSnip", "colorPicker"]

function isAction(id) {
    return id === "screenSnip" || id === "colorPicker"
}

var defaultTiles = [
    { id: "network", size: "big" },
    { id: "bluetooth", size: "big" },
    { id: "keepAwake", size: "small" },
    { id: "microphone", size: "big" },
    { id: "speaker", size: "big" },
    { id: "notifications", size: "small" },
    { id: "nightLight", size: "small" },
    { id: "powerProfile", size: "small" }
]

var contentWidth = 514   // 67 .. 581 in the face's coordinates
var bigWidth = 200
var smallWidth = 74
var longWidth = 294      // big + a small's slot: long + big fills the 514 exactly
var gap = 20             // between buttons in a row
var rowGap = 12          // between rows
var baseHeight = 75
var sliderHeight = 97
var baseGridHeight = 184 // the old fixed layout: 75 + 12 + 97 — the panel's own layout assumes it
var maxHeight = 380      // beyond this the notifications card would get too short

// How many buttons a row may hold (edit mode's "Columns" setting), whatever
// their size. 5 is also the most that can physically fit — five small
// buttons fill 450 of the 514px, a sixth wouldn't — so the default of 5 is
// the old width-only flow. Fewer columns wrap sooner; widths don't change,
// so a 2-column row of two big buttons still leaves its right edge free.
var minColumns = 1
var maxColumns = 5
var defaultColumns = 5

function clampColumns(columns) {
    var c = Math.round(Number(columns))
    if (isNaN(c))
        return defaultColumns
    return Math.max(minColumns, Math.min(maxColumns, c))
}

function isSlider(id) {
    return id === "microphone" || id === "speaker"
}

function widthOf(size) {
    return size === "long" ? longWidth : (size === "big" ? bigWidth : smallWidth)
}

function unitsOf(size) {
    return size === "long" ? 3 : (size === "big" ? 2 : 1)
}

function heightOf(tile) {
    return isSlider(tile.id) && tile.size !== "small" ? sliderHeight : baseHeight
}

function nextSize(tiles, index, columns) {
    var order = ["small", "big", "long"]
    var cur = tiles[index].size
    for (var step = 1; step < order.length; step++) {
        var candidate = order[(order.indexOf(cur) + step) % order.length]
        var list = tiles.map(function (t) { return { id: t.id, size: t.size } })
        list[index].size = candidate
        if (fits(list, columns))
            return candidate
    }
    return cur
}

function pack(tiles, columns, topAlign) {
    var cols = clampColumns(columns === undefined ? maxColumns : columns)
    var slots = []
    var rowHeights = []
    var rowMembers = []
    var x = 0
    var row = 0
    var inRow = 0   // buttons so far in this row
    for (var i = 0; i < tiles.length; i++) {
        var w = widthOf(tiles[i].size)
        if (x > 0 && (x + w > contentWidth || inRow >= cols)) {
            row++
            x = 0
            inRow = 0
        }
        slots.push({ x: 0, w: w, row: row })
        rowMembers[row] = (rowMembers[row] || [])
        rowMembers[row].push(i)
        rowHeights[row] = Math.max(rowHeights[row] || 0, heightOf(tiles[i]))
        x += w + gap
        inRow++
    }
    for (var r0 = 0; r0 < rowMembers.length; r0++) {
        var members = rowMembers[r0]
        var n = members.length
        var baseSum = 0
        for (var m = 0; m < n; m++)
            baseSum += slots[members[m]].w
        var full = r0 < rowMembers.length - 1 || n >= cols
        var factor = full ? (contentWidth - gap * (n - 1)) / baseSum : 1
        var done = 0      // base width handled so far
        var used = 0      // drawn width handed out so far
        var rx = 0
        for (var k = 0; k < n; k++) {
            var slot = slots[members[k]]
            done += slot.w
            var drawn = Math.round(done * factor) - used
            used += drawn
            slot.x = rx
            slot.w = drawn
            rx += drawn + gap
        }
    }
    var rowY = []
    var y = 0
    for (var r = 0; r < rowHeights.length; r++) {
        rowY.push(y)
        y += rowHeights[r] + rowGap
    }
    for (var j = 0; j < slots.length; j++) {
        var rh = rowHeights[slots[j].row]
        var th = heightOf(tiles[j])
        slots[j].y = rowY[slots[j].row]
        slots[j].rowH = rh
        slots[j].oy = topAlign
            ? (tiles[j].size === "small" ? 2 : 0)
            : Math.floor((rh - th) / 2)
              + (rh === baseHeight && tiles[j].size === "small" ? 2 : 0)
    }
    return { slots: slots, rows: rowHeights.length, height: rowHeights.length === 0 ? 0 : y - rowGap }
}

function fits(tiles, columns) {
    return pack(tiles, columns).height <= maxHeight
}

// Turn whatever was read from disk into a safe list: known ids only, no
// repeats, valid sizes, and never taller than the panel can spare.
function sanitize(list, columns) {
    var seen = {}
    var out = []
    for (var i = 0; i < list.length; i++) {
        var t = list[i]
        if (!t || catalog.indexOf(t.id) < 0 || seen[t.id])
            continue
        seen[t.id] = true
        out.push({ id: t.id, size: (t.size === "big" || t.size === "long") ? t.size : "small" })
    }
    while (out.length > 0 && !fits(out, columns))
        out.pop()
    return out
}
