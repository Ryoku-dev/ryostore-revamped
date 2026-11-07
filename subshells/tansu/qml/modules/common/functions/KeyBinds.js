.pragma library

// Pure logic for Settings > Keys (no Quickshell imports; tests/keys-test runs it in node).
// Top-level values use `var` on purpose: QML JS libraries don't reliably export
// top-level const/let.
//
// What it does:
//   rows(binds, state)        `hyprctl -j binds` + the saved state -> one row per action
//   conflict(binds, combo, id) who else is on these keys (another action, or a Hyprland bind)
//   edit(...) / reset(...)    the new state
//   block(state, mode)        the lines saved in the override file (Lua or hyprland.conf)
//   comboFromKeyEvent(...)    a pressed key (Qt) -> a combination Hyprland understands
//
// The state is what this page changed, per action, and nothing else:
//   { "<action id>": { unbind: [combo], bind: [combo], cmd, locked } }
// `unbind` is what the user's own config had on the action before the first change
// (plus any Hyprland bind the action took over): the block unbinds those on every
// load, because the user's config still binds them. Resetting an action drops its
// entry, which brings them back.
//
// Every change is applied by writing the block and reloading Hyprland, never by
// live `hyprctl keyword` / `eval` calls: Hyprland reloads by itself when a sourced
// file changes (unless misc:disable_autoreload), so a live call on top of that bound
// everything twice. A reload applies exactly what the file says, in both formats. So "Default:" on a row shows
// `unbind`, the keys a reset gives back, which is the user's config, not
// keybinds.lua's (a hyprland.conf user may have moved them long ago).
//
// A combination is { mods: modmask, key: "<key as Hyprland names it>" }. The key
// string is kept exactly as Hyprland reported or was given it: `unbind` matches it
// case-sensitively ("f12" does not remove "F12"), in hyprland.conf and in Lua.

// ===== modifiers =====
// Hyprland's modmask bits. ORDER is how a combination is written and shown
// (CTRL + SUPER + SHIFT + ALT, as keybinds.lua writes them).
var SHIFT = 1, CTRL = 4, ALT = 8, SUPER = 64
var ORDER = [["CTRL", CTRL], ["SUPER", SUPER], ["SHIFT", SHIFT], ["ALT", ALT]]
// Bits Hyprland ignores when matching a bind (Caps Lock, Num Lock), and so do we.
var IGNORED = 2 | 16

function modNames(mask) {
    var out = []
    for (var i = 0; i < ORDER.length; i++)
        if (mask & ORDER[i][1]) out.push(ORDER[i][0])
    return out
}

function maskOf(words) {
    var mask = 0
    var w = String(words).toUpperCase().split(/[\s+]+/)
    for (var i = 0; i < w.length; i++) {
        var n = w[i] === "WIN" || w[i] === "MOD4" || w[i] === "META" ? "SUPER"
              : w[i] === "CONTROL" ? "CTRL" : w[i] === "MOD1" ? "ALT" : w[i]
        for (var j = 0; j < ORDER.length; j++)
            if (ORDER[j][0] === n) mask |= ORDER[j][1]
    }
    return mask
}

// ===== keys =====
// How a key is shown on a keycap. Anything not listed shows as Hyprland names it,
// a single letter upper-cased.
var SHOW = {
    period: ".", comma: ",", slash: "/", Slash: "/", Period: ".", Comma: ",",
    semicolon: ";", apostrophe: "'", bracketleft: "[", bracketright: "]",
    backslash: "\\", minus: "-", equal: "=", grave: "`", space: "Space",
    Return: "Enter", BackSpace: "Backspace", Prior: "PgUp", Next: "PgDn",
    Page_Up: "PgUp", Page_Down: "PgDn", Escape: "Esc", Delete: "Del", Insert: "Ins"
}

function showKey(key) {
    var k = String(key)
    if (SHOW[k] !== undefined) return SHOW[k]
    if (k.indexOf("code:") === 0) return "Key " + k.slice(5)
    return k.length === 1 ? k.toUpperCase() : k
}

function caps(combo) {
    var out = []
    var m = modNames(combo.mods)
    for (var i = 0; i < m.length; i++) out.push({ k: m[i], mod: true })
    if (combo.key !== "") out.push({ k: showKey(combo.key), mod: false })
    return out
}

function showCombo(combo) {
    return caps(combo).map(function (c) { return c.k }).join(" + ")
}

// Two combinations are the same keys when the modifiers match and the key names
// match regardless of case (Hyprland reads "f12" and "F12" as one key; only
// unbinding is fussy about the spelling).
function sameKeys(a, b) {
    return (a.mods & ~IGNORED) === (b.mods & ~IGNORED)
        && String(a.key).toLowerCase() === String(b.key).toLowerCase()
}

function comboOf(bind) {
    var key = bind.key !== undefined && bind.key !== "" ? String(bind.key)
            : (bind.keycode ? "code:" + bind.keycode : "")
    return { mods: (bind.modmask || 0) & ~IGNORED, key: key }
}

// Hardware keys (volume, brightness, media, power) are never an action's keys here:
// mute and mic share their command with XF86AudioMute, which stays put.
function isHardware(combo) {
    return /^XF86/i.test(combo.key)
}

// ===== the actions =====
// Tansu's own binds, as hypr/hyprland/keybinds.lua ships them. `call` is what
// follows `qs -c tansu ipc call` (how a hyprland.conf bind is recognised), `name`
// the sentence of its description (how a Lua bind is recognised: Hyprland reports
// every Lua bind as "__lua"), `cmd` the command a new bind runs when there is no
// existing bind to copy it from. `more` = listed under "+N more", like the cheat
// sheet. `bare` = ships without a key (commented out in keybinds.lua).
var QS = "qs -c tansu ipc call "
var ACTIONS = [
    { id: "launcherphone", group: "Shell", name: "Toggle apps", call: "launcherphone toggle" },
    { id: "quickpanel", group: "Shell", name: "Toggle quick panel", call: "quickpanel toggle" },
    { id: "overview", group: "Shell", name: "Toggle overview", call: "overview toggle" },
    { id: "settings", group: "Shell", name: "Toggle settings", call: "settings toggle" },
    { id: "cheatsheet", group: "Shell", name: "Toggle cheatsheet", call: "cheatsheet toggle" },
    { id: "keyboard", group: "Shell", name: "Toggle on-screen keyboard", call: "keyboard toggle" },
    { id: "eq", group: "Shell", name: "Toggle equalizer", call: "eq open" },
    { id: "gamemode", group: "Shell", name: "Toggle game mode", call: "gamemode toggle" },
    { id: "desktopedit", group: "Shell", name: "Edit desktop", call: "desktopedit toggle" },
    { id: "focus", group: "Shell", name: "Toggle focus mode", call: "focus toggle" },
    { id: "wallpaperpicker", group: "Shell", name: "Change wallpaper", call: "wallpaperpicker toggle" },
    { id: "theme", group: "Shell", name: "Toggle theme picker", call: "theme toggle" },
    { id: "darkmode", group: "Shell", name: "Toggle dark mode", call: "theme darkToggle" },
    { id: "restart", group: "Shell", name: "Restart shell", call: "",
      cmd: "pkill -x qs; pkill -x quickshell; sleep 0.5; setsid qs -c tansu >/dev/null 2>&1 &",
      match: /pkill[^;|&]*\bqs\b[\s\S]*tansu/ },
    { id: "welcome", group: "Shell", name: "Welcome tour", call: "welcome show", more: true },
    { id: "wallpaperrandom", group: "Shell", name: "Random wallpaper", call: "wallpaper random", more: true },
    { id: "clock", group: "Shell", name: "Next clock design", call: "clock nextDesign", bare: true },
    { id: "visualizer", group: "Shell", name: "Toggle visualizer", call: "visualizer toggle", bare: true },
    { id: "weathercard", group: "Shell", name: "Toggle weather card", call: "weathercard toggle", bare: true },
    { id: "discord", group: "Shell", name: "Discord mute", call: "discord mute", bare: true },
    { id: "presets", group: "Shell", name: "Desktop presets", call: "presets toggle", bare: true },
    { id: "snip", group: "Utilities", name: "Screen snip", call: "region screenshot",
      cmd: QS + "region screenshot || grim -g \"$(slurp)\" - | wl-copy" },
    { id: "snipfile", group: "Utilities", name: "Screen snip >> file", call: "region save" },
    { id: "ocr", group: "Utilities", name: "Character recognition >> clipboard", call: "region ocr" },
    { id: "lens", group: "Utilities", name: "Google Lens", call: "region search" },
    { id: "record", group: "Utilities", name: "Record region (no sound)", call: "region toggleRecord", locked: true },
    { id: "recordsound", group: "Utilities", name: "Record region (with sound)", call: "region recordSound", locked: true },
    { id: "clipboard", group: "Utilities", name: "Clipboard history", call: "launcherphone toggleMode clip" },
    { id: "emoji", group: "Utilities", name: "Emoji >> clipboard", call: "launcherphone toggleMode emoji" },
    { id: "mute", group: "Media", name: "Toggle mute", call: "osd toggleMute", locked: true,
      cmd: QS + "osd toggleMute || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { id: "mic", group: "Media", name: "Toggle mic", call: "osd toggleMicMute", locked: true,
      cmd: QS + "osd toggleMicMute || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { id: "lock", group: "Session", name: "Lock screen", call: "lock lock",
      cmd: QS + "lock lock || loginctl lock-session" }
]
var GROUPS = ["Shell", "Utilities", "Media", "Session"]

function action(id) {
    for (var i = 0; i < ACTIONS.length; i++)
        if (ACTIONS[i].id === id) return ACTIONS[i]
    return null
}

function defaultCmd(a) {
    return a.cmd !== undefined ? a.cmd : QS + a.call
}

function description(a) {
    return a.group + (a.more ? " (more)" : "") + ": " + a.name
}

function sentence(desc) {
    var m = /^\s*[A-Za-z]+(?:\s*\(more\))?\s*:\s*(.+?)\s*$/.exec(String(desc || ""))
    return m ? m[1] : ""
}

// Does this bind run action `a`? hyprland.conf binds by their command (the
// `ipc call` and its arguments as whole words), Lua binds by their description.
function runs(bind, a) {
    if (bind.submap) return false
    var arg = String(bind.arg || "")
    if (bind.dispatcher === "exec") {
        if (a.match) return a.match.test(arg)
        if (a.call === "") return false
        var at = arg.indexOf("ipc call ")
        while (at >= 0) {
            var rest = arg.slice(at + 9).replace(/^\s+/, "")
            if (rest === a.call || rest.indexOf(a.call + " ") === 0 || rest.indexOf(a.call + "|") === 0
                    || rest.indexOf(a.call + ";") === 0 || rest.indexOf(a.call + "&") === 0)
                return true
            at = arg.indexOf("ipc call ", at + 9)
        }
        return false
    }
    return bind.has_description === true && sentence(bind.description) === a.name
}

// ===== reading =====
// One row per action, in ACTIONS order:
//   { id, group, name, more, bare, combos: [combo], changed, before: [combo], none }
// `combos` are the keys it is on right now (as Hyprland reports them, so they can be
// unbound), `before` what a reset gives back.
function rows(binds, state) {
    var st = state || {}
    var out = []
    for (var i = 0; i < ACTIONS.length; i++) {
        var a = ACTIONS[i]
        var combos = []
        var cmd = ""
        for (var j = 0; j < binds.length; j++) {
            var b = binds[j]
            if (!runs(b, a)) continue
            var c = comboOf(b)
            if (isHardware(c) || c.key === "") continue
            if (!combos.some(function (x) { return sameKeys(x, c) })) combos.push(c)
            if (cmd === "" && b.dispatcher === "exec") cmd = String(b.arg)
        }
        var saved = st[a.id]
        out.push({
            id: a.id, group: a.group, name: a.name, more: a.more === true, bare: a.bare === true,
            combos: combos, cmd: cmd, locked: a.locked === true,
            changed: saved !== undefined,
            before: saved !== undefined ? saved.unbind.filter(function (u) { return !u.took }) : combos,
            none: combos.length === 0
        })
    }
    return out
}

// Who already uses these keys: { kind: "action", id, name } for another Tansu
// action, { kind: "hyprland", name } for any other bind (named by its description's
// sentence, or "<dispatcher> <arg>"), or null when they are free. Binds inside a
// submap and hardware keys don't count.
function conflict(binds, combo, selfId, rowList) {
    var list = rowList || rows(binds, {})
    for (var i = 0; i < list.length; i++) {
        if (list[i].id === selfId) continue
        for (var j = 0; j < list[i].combos.length; j++)
            if (sameKeys(list[i].combos[j], combo))
                return { kind: "action", id: list[i].id, name: list[i].name, combo: list[i].combos[j] }
    }
    var self = action(selfId)
    for (var k = 0; k < binds.length; k++) {
        var b = binds[k]
        if (b.submap || b.mouse) continue
        var c = comboOf(b)
        if (!sameKeys(c, combo)) continue
        if (self && runs(b, self)) continue
        var known = false
        for (var a = 0; a < ACTIONS.length; a++) if (runs(b, ACTIONS[a])) known = true
        if (known) continue
        var name = sentence(b.description)
        if (name === "") name = b.has_description ? String(b.description)
                              : (String(b.dispatcher) + " " + String(b.arg)).trim()
        return { kind: "hyprland", name: name, combo: c }
    }
    return null
}

// ===== changing =====
function clone(o) {
    return JSON.parse(JSON.stringify(o || {}))
}

function addUnbind(list, combo, took) {
    if (!list.some(function (u) { return sameKeys(u, combo) && u.key === combo.key }))
        list.push({ mods: combo.mods, key: combo.key, took: took === true })
}

// Put action `id` on `combo` (null = no key); `rowList` is rows() as it stands.
// `taken` is the conflict() answer for `combo` when the user chose to take the keys
// over (null otherwise). Returns the new state.
function edit(state, rowList, id, combo, taken) {
    var st = clone(state)
    var a = action(id)
    var row = null
    for (var i = 0; i < rowList.length; i++) if (rowList[i].id === id) row = rowList[i]
    if (!a || !row) return st

    var entry = st[id] || { unbind: [], bind: [], cmd: "", locked: a.locked === true }
    if (st[id] === undefined)
        for (var j = 0; j < row.combos.length; j++) addUnbind(entry.unbind, row.combos[j], false)
    if (entry.cmd === "") entry.cmd = row.cmd !== "" ? row.cmd : defaultCmd(a)
    // A Hyprland bind taken over for the previous keys gets them back once the
    // action moves on to other keys.
    entry.unbind = entry.unbind.filter(function (u) { return !u.took || (combo && sameKeys(u, combo)) })

    if (combo && taken) {
        if (taken.kind === "action")
            st = edit(st, rowList, taken.id, null, null)
        else
            addUnbind(entry.unbind, taken.combo, true)
    }
    entry.bind = combo ? [{ mods: combo.mods, key: combo.key }] : []

    if (entry.unbind.length === entry.bind.length && entry.unbind.every(function (u) {
            return !u.took && entry.bind.some(function (b) { return b.mods === u.mods && b.key === u.key })
        }))
        delete st[id]
    else
        st[id] = entry
    return st
}

function reset(state, id) {
    var st = clone(state)
    delete st[id]
    return st
}

function changedCount(state) {
    return Object.keys(state || {}).length
}

// ===== writing =====
// The saved block. Both config formats keep their bind lines between the begin
// and end markers, with the state as JSON on the line after begin (read back by
// readState). Whole-line comments only: hyprland.conf would take a `#` inside a
// value as the start of a comment.
var BEGIN = "tansu:keys:begin"
var END = "tansu:keys:end"
var STATE = "tansu:keys "

function luaStr(s) {
    return "[==[" + String(s) + "]==]"
}

function luaCombo(c) {
    return modNames(c.mods).concat([c.key]).join(" + ")
}

function confMods(c) {
    return modNames(c.mods).join(" ")
}

function luaLine(op) {
    if (op.op === "unbind")
        return "pcall(hl.unbind, " + luaStr(luaCombo(op.combo)) + ")"
    var opts = "{ description = " + luaStr(op.desc) + (op.locked ? ", locked = true" : "") + " }"
    return "pcall(hl.bind, " + luaStr(luaCombo(op.combo)) + ", hl.dsp.exec_cmd(" + luaStr(op.cmd) + "), " + opts + ")"
}

// hyprland.conf: a comma ends a field and `#` starts a comment, so neither may
// reach a value unescaped (`##` is a literal #).
function confValue(s) {
    return String(s).replace(/#/g, "##")
}

function confLine(op) {
    if (op.op === "unbind")
        return "unbind = " + confMods(op.combo) + ", " + op.combo.key
    return "bind" + (op.locked ? "l" : "") + "d = " + confMods(op.combo) + ", " + op.combo.key + ", "
        + String(op.desc).replace(/,/g, " ") + ", exec, " + confValue(op.cmd)
}

function savedOps(state) {
    var ops = []
    var ids = Object.keys(state || {})
    for (var i = 0; i < ids.length; i++)
        for (var j = 0; j < state[ids[i]].unbind.length; j++)
            ops.push({ op: "unbind", combo: state[ids[i]].unbind[j] })
    for (var k = 0; k < ids.length; k++) {
        var e = state[ids[k]]
        var a = action(ids[k])
        if (!a) continue
        for (var m = 0; m < e.bind.length; m++)
            ops.push({ op: "bind", combo: e.bind[m], desc: description(a), cmd: e.cmd, locked: e.locked })
    }
    return ops
}

function block(state, mode) {
    if (changedCount(state) === 0) return ""
    var c = mode === "lua" ? "-- " : "# "
    var line = mode === "lua" ? luaLine : confLine
    var out = [c + BEGIN + "  (Settings > Keys writes this part; change keys there)",
               c + STATE + JSON.stringify(state)]
    var ops = savedOps(state)
    for (var i = 0; i < ops.length; i++) out.push(line(ops[i]))
    out.push(c + END)
    return out.join("\n") + "\n"
}

function readState(text) {
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var at = lines[i].indexOf(STATE)
        if (at < 0 || !/^\s*(--|#)/.test(lines[i])) continue
        try {
            var s = JSON.parse(lines[i].slice(at + STATE.length))
            return s && typeof s === "object" ? s : {}
        } catch (e) {
            return {}
        }
    }
    return {}
}

// ===== pausing shortcuts while recording =====
// An empty submap whose only bind is Escape (back to normal), so whatever happens
// to the panel, Escape gives the shortcuts back. These two are live hyprctl calls
// (argument lists): nothing about them is saved.
var SUBMAP = "tansu_keys"

function pauseCalls(mode) {
    if (mode === "lua")
        return [["eval", "hl.define_submap(\"" + SUBMAP + "\", function() hl.bind(\"Escape\", hl.dsp.submap(\"reset\")) end)"],
                ["dispatch", "hl.dsp.submap(\"" + SUBMAP + "\")"]]
    return [["keyword", "submap", SUBMAP], ["keyword", "unbind", ", Escape"],
            ["keyword", "bind", ", Escape, submap, reset"], ["keyword", "submap", "reset"],
            ["dispatch", "submap", SUBMAP]]
}

function resumeCalls(mode) {
    return mode === "lua" ? [["dispatch", "hl.dsp.submap(\"reset\")"]] : [["dispatch", "submap", "reset"]]
}

// ===== recording =====
// Qt key codes -> the names Hyprland binds take. Letters and digits are their own
// characters. Shift changes what Qt reports for punctuation and digits ("?" for
// "/"), while Hyprland matches a bind on the unshifted key, so SHIFTED maps them
// back (US layout). Keys outside these come back as "code:<keycode>", which
// Hyprland binds by position, whatever the layout.
var NAMED = {
    0x01000001: "Tab", 0x01000002: "Tab", 0x01000004: "Return", 0x01000005: "KP_Enter",
    0x20: "space", 0x01000003: "BackSpace", 0x01000007: "Delete", 0x01000006: "Insert",
    0x01000010: "Home", 0x01000011: "End", 0x01000016: "Prior", 0x01000017: "Next",
    0x01000012: "Left", 0x01000013: "Up", 0x01000014: "Right", 0x01000015: "Down",
    0x01000009: "Print", 0x01000008: "Pause",
    0x2e: "period", 0x2c: "comma", 0x2f: "slash", 0x3b: "semicolon", 0x27: "apostrophe",
    0x5b: "bracketleft", 0x5d: "bracketright", 0x5c: "backslash", 0x2d: "minus",
    0x3d: "equal", 0x60: "grave"
}
var SHIFTED = {
    0x3f: "slash", 0x3e: "period", 0x3c: "comma", 0x3a: "semicolon", 0x22: "apostrophe",
    0x7b: "bracketleft", 0x7d: "bracketright", 0x7c: "backslash", 0x5f: "minus",
    0x2b: "equal", 0x7e: "grave",
    0x21: "1", 0x40: "2", 0x23: "3", 0x24: "4", 0x25: "5", 0x5e: "6", 0x26: "7",
    0x2a: "8", 0x28: "9", 0x29: "0"
}
var MODKEYS = {
    0x01000020: SHIFT, 0x01000021: CTRL, 0x01000023: ALT, 0x01001103: ALT,
    0x01000022: SUPER, 0x01000053: SUPER, 0x01000054: SUPER
}
var QT_SHIFT = 0x02000000, QT_CTRL = 0x04000000, QT_ALT = 0x08000000, QT_META = 0x10000000

function qtMods(modifiers) {
    return (modifiers & QT_SHIFT ? SHIFT : 0) | (modifiers & QT_CTRL ? CTRL : 0)
         | (modifiers & QT_ALT ? ALT : 0) | (modifiers & QT_META ? SUPER : 0)
}

function modOfKey(key) {
    return MODKEYS[key] || 0
}

function comboFromKeyEvent(key, modifiers, scanCode) {
    var mods = qtMods(modifiers) | modOfKey(key)
    if (modOfKey(key)) return { mods: mods, key: "" }
    var name = ""
    if (key >= 0x41 && key <= 0x5a) name = String.fromCharCode(key)
    else if (key >= 0x30 && key <= 0x39) name = String.fromCharCode(key)
    else if (key >= 0x01000030 && key <= 0x01000047) name = "F" + (key - 0x01000030 + 1)
    else if (NAMED[key] !== undefined) name = NAMED[key]
    else if (SHIFTED[key] !== undefined) name = SHIFTED[key]
    else if (scanCode > 0) name = "code:" + scanCode
    return { mods: mods, key: name }
}

var TYPING = ["space", "Tab", "Return", "KP_Enter", "BackSpace", "Delete", "period", "comma",
              "slash", "semicolon", "apostrophe", "bracketleft", "bracketright", "backslash",
              "minus", "equal", "grave", "Left", "Right", "Up", "Down", "Home", "End", "Prior", "Next"]

function needsModifier(combo) {
    if (combo.mods !== 0) return false
    var k = String(combo.key)
    return k.length === 1 || TYPING.indexOf(k) >= 0
}

// What "Set it by hand" makes of the key typed into its field: "y" -> "Y",
// "f5" -> "F5", "enter" -> "Return", "/" -> "slash", "pgup" -> "Prior". "" when
// it is no key Hyprland would know.
var WORDS = {
    space: "space", tab: "Tab", return: "Return", enter: "Return", print: "Print",
    prtsc: "Print", backspace: "BackSpace", delete: "Delete", del: "Delete",
    insert: "Insert", ins: "Insert", home: "Home", end: "End", pgup: "Prior",
    pageup: "Prior", prior: "Prior", pgdn: "Next", pagedown: "Next", next: "Next",
    left: "Left", right: "Right", up: "Up", down: "Down", pause: "Pause",
    period: "period", comma: "comma", slash: "slash", semicolon: "semicolon",
    apostrophe: "apostrophe", minus: "minus", equal: "equal", grave: "grave",
    backslash: "backslash", bracketleft: "bracketleft", bracketright: "bracketright"
}

function keyFromText(text) {
    var t = String(text || "").trim()
    if (t === "") return ""
    if (t.length === 1) {
        var c = t.charCodeAt(0)
        if (/[a-z]/i.test(t)) return t.toUpperCase()
        if (/[0-9]/.test(t)) return t
        if (NAMED[c] !== undefined) return NAMED[c]
        if (SHIFTED[c] !== undefined) return SHIFTED[c]
        return ""
    }
    var f = /^f([1-9]|1[0-9]|2[0-4])$/i.exec(t)
    if (f) return "F" + f[1]
    var w = WORDS[t.toLowerCase().replace(/[\s_-]/g, "")]
    return w !== undefined ? w : ""
}

var BY_HAND = ["space", "Tab", "Return", "Print", "F1", "F2", "F3", "F4", "F5", "F6",
               "F7", "F8", "F9", "F10", "F11", "F12", "slash", "period", "comma",
               "minus", "equal", "Left", "Right", "Up", "Down"]

// ===== finding =====
// "super v", "lock", "clip": every word must be in the action's name or keys.
function matches(row, query) {
    var q = String(query || "").toLowerCase().split(/[\s+]+/).filter(function (w) { return w !== "" })
    if (q.length === 0) return true
    var hay = (row.name + " " + row.combos.map(function (c) {
        return showCombo(c) + " " + c.key
    }).join(" ")).toLowerCase()
    return q.every(function (w) { return hay.indexOf(w) >= 0 })
}
