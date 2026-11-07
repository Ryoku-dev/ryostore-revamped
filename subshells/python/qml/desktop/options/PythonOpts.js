.pragma library
// The Python faces keep their own options in the widget's <prefix>Opts slot of
// widgets.json: one JSON object per widget, which the desktop host passes to
// Widget.qml as optionOverrides. Panels edit it through these helpers so every
// write is a whole-object replace (the adapter cannot see in-place key edits).
// The host binds `config` after the page loads, so it can still be null here.

// Contributed widget keys live in the desktop Config's per-key store, not on
// its properties, so reads go through get() for the monitor being edited.
function get(Config, key) {
    return Config ? Config.get(key, Config.writeMonitor) : undefined;
}

function read(Config, prefix) {
    const raw = get(Config, prefix + "Opts");
    if (raw && typeof raw === "object")
        return Object.assign({}, raw);
    if (!raw || String(raw).length === 0)
        return {};
    try {
        const parsed = JSON.parse(String(raw));
        return (parsed && typeof parsed === "object") ? parsed : {};
    } catch (e) {
        return {};
    }
}

function put(Config, prefix, key, value) {
    if (!Config)
        return;
    const o = read(Config, prefix);
    if (o[key] === value)
        return;
    o[key] = value;
    Config.set(prefix + "Opts", JSON.stringify(o));
}

// One write for several keys: back-to-back set() calls interleave file writes
// with the watcher's reloads and a stale reload can undo the earlier key.
function putMany(Config, prefix, values) {
    if (!Config)
        return;
    const o = read(Config, prefix);
    let dirty = false;
    for (const key in values)
        if (o[key] !== values[key]) {
            o[key] = values[key];
            dirty = true;
        }
    if (dirty)
        Config.set(prefix + "Opts", JSON.stringify(o));
}
