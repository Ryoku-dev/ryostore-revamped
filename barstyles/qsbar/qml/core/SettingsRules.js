.pragma library

// Pure rules behind the qsbar IPC target: layout placement and value checks,
// kept free of QML state so they read the same as the CLI they replace.

var SECTIONS = ["left", "center", "right"];
var FORMS = ["full", "fit", "dock", "notch", "islands"];

function validSection(section) {
    return SECTIONS.indexOf(section) >= 0;
}

function quote(value) {
    return JSON.stringify(String(value));
}

function strings(value) {
    var out = [];
    if (!Array.isArray(value)) return out;
    for (var i = 0; i < value.length; i++)
        if (typeof value[i] === "string") out.push(value[i]);
    return out;
}

// raw is the stored qsbar.layout; shipped is used while none was written yet.
function storedLayout(raw, shipped) {
    if (!raw || typeof raw !== "object") raw = shipped || {};
    return {
        version: Number(raw.version) || 1,
        left: strings(raw.left),
        center: strings(raw.center),
        right: strings(raw.right)
    };
}

// A plugin lands in its manifest defaults.bar.section, a built-in on the right.
function pluginSection(plugin) {
    var manifest = (plugin && plugin.manifest) || {};
    var bar = manifest.defaults && manifest.defaults.bar;
    var section = bar ? bar.section : "";
    return validSection(section) ? section : "right";
}

// known: [{id, section}]. Keeps the first copy of each known id and appends
// every known id the layout omits to its default section.
function normalize(layout, known) {
    var sectionOf = {};
    var order = [];
    for (var i = 0; i < known.length; i++) {
        if (sectionOf[known[i].id] === undefined) order.push(known[i].id);
        sectionOf[known[i].id] = validSection(known[i].section) ? known[i].section : "right";
    }
    var seen = {};
    var out = { version: layout.version || 1, left: [], center: [], right: [] };
    for (var s = 0; s < SECTIONS.length; s++) {
        var ids = layout[SECTIONS[s]] || [];
        for (var j = 0; j < ids.length; j++) {
            var id = ids[j];
            if (seen[id] || sectionOf[id] === undefined) continue;
            seen[id] = true;
            out[SECTIONS[s]].push(id);
        }
    }
    for (var k = 0; k < order.length; k++) {
        if (seen[order[k]]) continue;
        seen[order[k]] = true;
        out[sectionOf[order[k]]].push(order[k]);
    }
    return out;
}

// "" appends, an integer is a 0-based index, before:<id> / after:<id> anchor.
function parsePlacement(spec) {
    var text = String(spec === undefined || spec === null ? "" : spec).trim();
    if (text === "") return { ok: true };
    if (/^[+-]?\d+$/.test(text)) return { ok: true, index: Number(text) };
    var separator = text.indexOf(":");
    var kind = separator >= 0 ? text.substring(0, separator) : "";
    var anchor = separator >= 0 ? text.substring(separator + 1) : "";
    if ((kind === "before" || kind === "after") && anchor !== "") {
        var out = { ok: true };
        out[kind] = anchor;
        return out;
    }
    return { ok: false, error: "placement expects an index, before:<id> or after:<id>" };
}

function move(layout, id, section, placement) {
    var out = { version: layout.version || 1, left: [], center: [], right: [] };
    for (var s = 0; s < SECTIONS.length; s++)
        out[SECTIONS[s]] = (layout[SECTIONS[s]] || []).filter(function (x) { return x !== id; });
    var target = out[section];
    var index = target.length;
    if (placement.before !== undefined) {
        index = target.indexOf(placement.before);
        if (index < 0) return { ok: false, error: "unknown anchor " + quote(placement.before) + " in section " + section };
    } else if (placement.after !== undefined) {
        index = target.indexOf(placement.after);
        if (index < 0) return { ok: false, error: "unknown anchor " + quote(placement.after) + " in section " + section };
        index += 1;
    } else if (placement.index !== undefined) {
        index = Math.max(0, Math.min(placement.index, target.length));
    }
    target.splice(index, 0, id);
    return { ok: true, layout: out };
}

function parseBool(raw) {
    var value = String(raw === undefined || raw === null ? "" : raw).trim().toLowerCase();
    if (["true", "on", "yes", "1"].indexOf(value) >= 0) return { ok: true, value: true };
    if (["false", "off", "no", "0"].indexOf(value) >= 0) return { ok: true, value: false };
    return { ok: false, error: quote(raw) + " is not a boolean (use on/off or true/false)" };
}

function parseInt10(raw) {
    var text = String(raw).trim();
    if (!/^[+-]?\d+$/.test(text)) return { ok: false, error: quote(raw) + " is not an integer" };
    return { ok: true, value: Number(text) };
}

function splitList(raw) {
    return String(raw).split(",").map(function (part) { return part.trim(); })
        .filter(function (part) { return part !== ""; });
}

// A widgets.json settings row: choice, toggle, multi, int (min/max) or text.
function builtinValue(row, raw) {
    var options = strings(row.options);
    switch (row.type) {
    case "choice":
        if (options.indexOf(raw) < 0) return { ok: false, error: quote(raw) + " is not one of: " + options.join(", ") };
        return { ok: true, value: raw };
    case "toggle":
        return parseBool(raw);
    case "multi":
        var parts = splitList(raw);
        for (var i = 0; i < parts.length; i++)
            if (options.indexOf(parts[i]) < 0) return { ok: false, error: quote(parts[i]) + " is not one of: " + options.join(", ") };
        return { ok: true, value: parts };
    case "int":
        var n = parseInt10(raw);
        if (!n.ok) return n;
        if (typeof row.min === "number" && n.value < row.min) return { ok: false, error: n.value + " is below the minimum " + row.min };
        if (typeof row.max === "number" && n.value > row.max) return { ok: false, error: n.value + " is above the maximum " + row.max };
        return n;
    case "text":
        return { ok: true, value: raw };
    }
    return { ok: false, error: "unsupported setting type " + quote(row.type) };
}

function choiceValues(options) {
    var out = [];
    if (!Array.isArray(options)) return out;
    for (var i = 0; i < options.length; i++) {
        var option = options[i];
        if (typeof option === "string") out.push(option);
        else if (option && typeof option.value === "string") out.push(option.value);
    }
    return out;
}

// A plugin manifest setting: toggle, choice, slider (min/max), int; any other
// type carries the string as given.
function pluginValue(row, raw) {
    switch (row.type) {
    case "toggle":
        return parseBool(raw);
    case "choice":
        var options = choiceValues(row.options);
        if (options.indexOf(raw) < 0) return { ok: false, error: quote(raw) + " is not one of: " + options.join(", ") };
        return { ok: true, value: raw };
    case "slider":
        var text = String(raw).trim();
        var f = Number(text);
        if (text === "" || !isFinite(f)) return { ok: false, error: quote(raw) + " is not a number" };
        if (typeof row.min === "number" && f < row.min) return { ok: false, error: f + " is below the minimum " + row.min };
        if (typeof row.max === "number" && f > row.max) return { ok: false, error: f + " is above the maximum " + row.max };
        return { ok: true, value: f };
    case "int":
        return parseInt10(raw);
    }
    return { ok: true, value: raw };
}

function findByKey(rows, key) {
    if (!Array.isArray(rows)) return null;
    for (var i = 0; i < rows.length; i++)
        if (rows[i] && rows[i].key === key) return rows[i];
    return null;
}

// The public settings row shape; the catalogue's own visKey flag stays inside.
function settingsView(rows) {
    var out = [];
    if (!Array.isArray(rows)) return out;
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var view = { key: row.key, type: row.type };
        if (row.label) view.label = row.label;
        var options = strings(row.options);
        if (options.length > 0) view.options = options;
        if (typeof row.min === "number") view.min = row.min;
        if (typeof row.max === "number") view.max = row.max;
        out.push(view);
    }
    return out;
}
