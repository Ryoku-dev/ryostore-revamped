import QtQuick
import Quickshell.Io
import "SettingsRules.js" as Rules

// The qsbar IPC target: QS Bar's settings API, present only while QS Bar is the
// active bar style. Reads come from the live Theme; every write goes through
// the Theme setters, which reach shell.json over the daemon's settings.patch
// and plugin placement over ryoku-plugins-place.
Item {
    id: root

    required property var theme
    required property var controlCenter

    width: 0
    height: 0

    function fail(message) {
        return "err qsbar: " + message
    }

    // The Theme drops writes made before its own settings have loaded.
    function ready() {
        return theme._widgetsLoaded === true && theme.barLayoutReady === true
    }

    function builtin(id) {
        const rows = theme.barCatalogEntries || []
        for (let i = 0; i < rows.length; i++)
            if (rows[i] && rows[i].id === id) return rows[i]
        return null
    }

    function plugin(id) {
        const rows = theme.barPluginCatalog || []
        for (let i = 0; i < rows.length; i++)
            if (rows[i] && rows[i].id === id) return rows[i]
        return null
    }

    function manifest(entry) {
        return (entry && entry.manifest) || ({})
    }

    function known() {
        const out = []
        const rows = theme.barCatalogEntries || []
        for (let i = 0; i < rows.length; i++)
            if (rows[i] && rows[i].id) out.push({ id: rows[i].id, section: "right" })
        const plugins = theme.barPluginCatalog || []
        for (let j = 0; j < plugins.length; j++)
            out.push({ id: plugins[j].id, section: Rules.pluginSection(plugins[j]) })
        return out
    }

    function isKnown(list, id) {
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id) return true
        return false
    }

    // Placement over every bar-capable plugin, enabled or not, like the CLI.
    function fullLayout(list) {
        return Rules.normalize(Rules.storedLayout(theme._storedLayout, theme._shippedLayout()), list)
    }

    function pluginShown(entry) {
        const placement = (entry && entry.placement) || ({})
        return placement.enabled === true && placement.host === "topbarGlyph"
    }

    function listRows() {
        const meta = ({})
        const rows = theme.barCatalogEntries || []
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            meta[row.id] = {
                label: String(row.label || ""),
                kind: "builtin",
                shown: row.visKey ? theme._modForVisKey(row.visKey) === true : true
            }
        }
        const plugins = theme.barPluginCatalog || []
        for (let j = 0; j < plugins.length; j++) {
            const p = plugins[j]
            meta[p.id] = { label: manifest(p).name || p.id, kind: "plugin", shown: pluginShown(p) }
        }

        const layout = fullLayout(known())
        const out = []
        for (let s = 0; s < Rules.SECTIONS.length; s++) {
            const section = Rules.SECTIONS[s]
            const ids = layout[section]
            for (let k = 0; k < ids.length; k++) {
                const m = meta[ids[k]]
                if (!m) continue
                out.push({ id: ids[k], label: m.label, kind: m.kind, section: section, index: k, shown: m.shown })
            }
        }
        return out
    }

    function catalogRows() {
        const out = []
        const rows = theme.barCatalogEntries || []
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i]
            out.push({
                id: row.id, label: String(row.label || ""), gloss: String(row.gloss || ""),
                category: String(row.category || ""), desc: String(row.desc || ""),
                kind: "builtin", official: true, pluginDir: "",
                settings: Rules.settingsView(row.settings)
            })
        }
        const plugins = theme.barPluginCatalog || []
        for (let j = 0; j < plugins.length; j++) {
            const p = plugins[j]
            const man = manifest(p)
            out.push({
                id: p.id, label: man.name || p.id, gloss: "", category: "Plugin",
                desc: String(man.description || ""), kind: "plugin", official: man.official === true,
                author: String(man.author || ""), version: String(man.version || ""),
                pluginDir: String(p.dir || ""), hosts: Rules.strings(man.hosts),
                settings: (man.metadata && Array.isArray(man.metadata.settings)) ? man.metadata.settings : []
            })
        }
        return out
    }

    function moveWidget(id, section, placement) {
        if (!Rules.validSection(section))
            return fail("unknown section " + section)
        const spec = Rules.parsePlacement(placement)
        if (!spec.ok)
            return fail(spec.error)
        const list = known()
        if (!isKnown(list, id))
            return fail("unknown widget " + id)
        if (!ready())
            return fail("settings not ready")
        const moved = Rules.move(fullLayout(list), id, section, spec)
        if (!moved.ok)
            return fail(moved.error)
        theme.barLayoutPlace(moved.layout)
        return "ok"
    }

    function showWidget(id, on) {
        if (!id)
            return fail("expected a widget id")
        const row = builtin(id)
        if (row && !row.visKey)
            return fail(id + " is always shown and has no visibility toggle")
        if (!row && !plugin(id))
            return fail("unknown widget " + id)
        if (!ready())
            return fail("settings not ready")
        theme.barLayoutShow(id, on)
        return "ok"
    }

    function setWidget(id, key, raw) {
        const row = builtin(id)
        const entry = row ? null : plugin(id)
        if (!row && !entry)
            return fail("unknown widget " + id)
        const settingRow = Rules.findByKey(row ? row.settings : (manifest(entry).metadata || ({})).settings, key)
        if (!settingRow)
            return fail("unknown setting " + key + " for " + id)
        const value = row ? Rules.builtinValue(settingRow, raw) : Rules.pluginValue(settingRow, raw)
        if (!value.ok)
            return fail(value.error)
        if (!ready())
            return fail("settings not ready")
        theme.barWidgetSet(id, key, value.value)
        return "ok"
    }

    IpcHandler {
        target: "qsbar"

        function list(): string {
            return JSON.stringify(root.listRows())
        }

        function catalog(): string {
            return JSON.stringify(root.catalogRows())
        }

        function layout(): string {
            return JSON.stringify(root.theme.barLayout || {})
        }

        function layoutAdd(id: string, section: string, placement: string): string {
            const row = root.builtin(id)
            const shown = row && !row.visKey ? "ok" : root.showWidget(id, true)
            return shown === "ok" ? root.moveWidget(id, section, placement) : shown
        }

        function layoutRemove(id: string): string {
            return root.showWidget(id, false)
        }

        function layoutMove(id: string, section: string, placement: string): string {
            return root.moveWidget(id, section, placement)
        }

        function move(id: string, section: string, placement: string): string {
            return root.moveWidget(id, section, placement)
        }

        function show(id: string): string {
            return root.showWidget(id, true)
        }

        function hide(id: string): string {
            return root.showWidget(id, false)
        }

        function visibility(id: string, visible: string): string {
            const value = Rules.parseBool(visible)
            return value.ok ? root.showWidget(id, value.value) : root.fail(value.error)
        }

        function set(id: string, key: string, value: string): string {
            return root.setWidget(id, key, value)
        }

        function position(edge: string): string {
            if (edge !== "top" && edge !== "bottom")
                return root.fail("position expects top or bottom")
            if (!root.ready())
                return root.fail("settings not ready")
            root.theme.barPosition = edge
            return "ok"
        }

        function form(value: string): string {
            if (Rules.FORMS.indexOf(value) < 0)
                return root.fail("form expects full|fit|dock|notch|islands")
            if (!root.ready())
                return root.fail("settings not ready")
            root.theme.barShellStyle = value
            return "ok"
        }

        function defaults(): string {
            if (!root.ready())
                return root.fail("settings not ready")
            root.theme.barLayoutReset()
            return "ok"
        }

        function settings(route: string): void {
            if (route === "close")
                root.controlCenter.close()
            else
                root.controlCenter.open(route)
        }
    }
}
