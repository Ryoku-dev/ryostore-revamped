import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
import Ryoku.Ui.Singletons as Ui
import shell.services as Ryoku

GuideTab {
    id: dockTabRoot
    required property var rootObj
    required property int tabIndex

    function text(key, fallback) {
        const translated = I18n.t(key)
        return translated === key ? fallback : translated
    }

    property var themeSettings: Config.getSetting("theme", ({}))
    property string colorMode: {
        const mode = themeSettings.dockLauncherColorMode;
        return mode === "accent" || mode === "custom" ? mode : "bar";
    }
    property string customColor: {
        const value = themeSettings.dockLauncherCustomColor;
        return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)
            ? value : "#20242a";
    }

    function setColorMode(mode) {
        const current = Config.getSetting("theme", {});
        current.dockLauncherColorMode = mode;
        if (mode === "custom")
            current.dockLauncherCustomColor = dockTabRoot.customColor;
        Config.setSetting("theme", current);
    }

    function setCustomColor(value) {
        const normalized = String(value).trim();
        if (!/^#[0-9a-fA-F]{6}$/.test(normalized))
            return;
        dockTabRoot.customColor = normalized;
        const current = Config.getSetting("theme", {});
        current.dockLauncherColorMode = "custom";
        current.dockLauncherCustomColor = normalized;
        Config.setSetting("theme", current);
    }

    function refreshThemeSettings() {
        dockTabRoot.themeSettings = Config.getSetting("theme", {});
    }

    Connections {
        target: Config
        function onSettingsLoaded() { dockTabRoot.refreshThemeSettings(); }
        function onRawSettingsChanged() { dockTabRoot.refreshThemeSettings(); }
    }

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1 : 0

    // Python's own dock options live in shell.json dock.python; the Stage Editor
    // only edits the design-independent dock keys.
    readonly property var behaviourToggles: [
        { key: "floating", id: "floating", fallback: false },
        { key: "onTop", id: "on_top", fallback: true },
        { key: "exclusive", id: "exclusive", fallback: false },
        { key: "smartAutohide", id: "smart_autohide", fallback: true },
        { key: "cascadeScale", id: "cascade_scale", fallback: false },
        { key: "enableScrolling", id: "scrolling", fallback: false },
        { key: "overrideBoundsCorrection", id: "override_bounds", fallback: false }
    ]
    readonly property var behaviourSliders: [
        { key: "hoverScale", id: "hover_scale", fallback: 120, from: 100, to: 180, step: 5, unit: " %" },
        { key: "autohideTimeout", id: "timeout", fallback: 1000, from: 250, to: 5000, step: 250, unit: " ms" },
        { key: "visibleElements", id: "visible_elements", fallback: 7, from: 3, to: 15, step: 1, unit: "" }
    ]

    function dockValue(key, fallback) {
        return Ryoku.Dock.designCfg("python", key, fallback);
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentHeight: Math.max(height, dockColumn.implicitHeight + rootObj.s(48))
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: dockColumn
            x: (parent.width - width) / 2
            y: Math.max(rootObj.s(24), (parent.height - implicitHeight) / 2)
            width: Math.min(parent.width - rootObj.s(48), rootObj.s(620))
            spacing: rootObj.s(14)

            Text {
                Layout.fillWidth: true
                text: dockTabRoot.text("guide.dock.colour_heading", "Dock and launcher appearance")
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(22)
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Text {
                text: dockTabRoot.text("guide.dock.colour_desc", "Match the active bar by default, use the palette accent, or choose one colour for both surfaces.")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(12)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            SettingsRow {
                rootObj: dockTabRoot.rootObj
                settingId: "dock_launcher_colour"
                icon: "󰏘"
                title: dockTabRoot.text("guide.dock.colour_title", "Dock and launcher colour")
                description: dockTabRoot.text("guide.dock.colour_hint", "One palette choice keeps the Python dock and launcher together.")
                searchKeywords: "dock launcher color colour palette accent custom bar"

                Dropdown {
                    Layout.preferredWidth: rootObj.s(170)
                    Layout.preferredHeight: rootObj.s(32)
                    options: [
                        dockTabRoot.text("guide.dock.colour_bar", "Follow bar"),
                        dockTabRoot.text("guide.dock.colour_accent", "Accent"),
                        dockTabRoot.text("guide.dock.colour_custom", "Custom")
                    ]
                    currentIndex: ["bar", "accent", "custom"].indexOf(dockTabRoot.colorMode)
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        const modes = ["bar", "accent", "custom"];
                        if (index >= 0 && index < modes.length)
                            dockTabRoot.setColorMode(modes[index]);
                    }
                }

                bottomContent: RowLayout {
                    width: parent ? parent.width : implicitWidth
                    spacing: rootObj.s(10)
                    visible: dockTabRoot.colorMode === "custom"

                    Rectangle {
                        Layout.preferredWidth: rootObj.s(28)
                        Layout.preferredHeight: rootObj.s(28)
                        radius: ThemeBackend.borderRadius
                        color: dockTabRoot.customColor
                        border.width: 1
                        border.color: ThemeBackend.dockLauncherText
                    }

                    Input {
                        Layout.fillWidth: true
                        implicitHeight: rootObj.s(32)
                        text: dockTabRoot.customColor
                        placeholderText: "#20242a"
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onAccepted: function(value) { dockTabRoot.setCustomColor(value); }
                    }
                }
            }

            SettingsBlob {
                Repeater {
                    model: dockTabRoot.behaviourToggles
                    delegate: SettingsRow {
                        id: toggleRow
                        required property var modelData
                        rootObj: dockTabRoot.rootObj
                        title: dockTabRoot.text("guide.dock." + toggleRow.modelData.id + ".title", toggleRow.modelData.key)
                        description: dockTabRoot.text("guide.dock." + toggleRow.modelData.id + ".desc", "")

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: Boolean(dockTabRoot.dockValue(toggleRow.modelData.key, toggleRow.modelData.fallback))
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                Ryoku.Dock.setDesignCfg("python", toggleRow.modelData.key, c);
                            }
                        }
                    }
                }

                Repeater {
                    model: dockTabRoot.behaviourSliders
                    delegate: SettingsRow {
                        id: sliderRow
                        required property var modelData
                        property real pending: Number(dockTabRoot.dockValue(sliderRow.modelData.key, sliderRow.modelData.fallback))
                        rootObj: dockTabRoot.rootObj
                        title: dockTabRoot.text("guide.dock." + sliderRow.modelData.id + ".title", sliderRow.modelData.key)
                        description: dockTabRoot.text("guide.dock." + sliderRow.modelData.id + ".desc", "")

                        Draggable {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.rightMargin: rootObj.s(8)
                            implicitWidth: rootObj.s(200)
                            implicitHeight: rootObj.s(18)
                            from: sliderRow.modelData.from
                            to: sliderRow.modelData.to
                            stepSize: sliderRow.modelData.step
                            defaultValue: sliderRow.modelData.fallback
                            showValueBubble: true
                            valueFormatter: function(v) { return Math.round(v) + sliderRow.modelData.unit }
                            value: Number(dockTabRoot.dockValue(sliderRow.modelData.key, sliderRow.modelData.fallback))
                            backgroundColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            handleColor: ThemeBackend.text
                            handleBorderColor: ThemeBackend.mantle
                            onMoved: function(val) { sliderRow.pending = Math.round(val); }
                            onDragFinished: Ryoku.Dock.setDesignCfg("python", sliderRow.modelData.key, sliderRow.pending)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: dockTabRoot.text("guide.dock.stage_desc", "Design, placement, size and pinned apps remain in Stage Editor.")
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ClickButton {
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: rootObj.s(40)
                horizontalPadding: rootObj.s(18)
                buttonText: dockTabRoot.text("guide.dock.open_stage", "Open Stage Editor")
                buttonIcon: "󰏘"
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                cornerRadius: ThemeBackend.borderRadius
                onClicked: {
                    rootObj.closePopup()
                    Ui.Spawn.run(["qs", "-c", "shell", "ipc", "call", "desktop", "editSection", "dock", ""])
                }
            }
        }
    }
}
