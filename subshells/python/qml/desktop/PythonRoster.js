.pragma library

var faces = [
    { id: "visualizer", prefix: "pythonVisualizer", label: "Python Visualizer", icon: "graphic_eq",         gloss: "音波", sizes: ["bars", "continuous"] },
    { id: "time",       prefix: "pythonTime",       label: "Python Clock",      icon: "schedule",           gloss: "時計", sizes: ["digital", "analog", "minimal", "material", "materialAnalog", "lumen", "stretched"] },
    { id: "music",      prefix: "pythonMusic",      label: "Python Music",      icon: "music_note",         gloss: "音楽", sizes: ["full", "round", "lyrics", "simpleLyrics"] },
    { id: "notes",      prefix: "pythonNotes",      label: "Python Notes",      icon: "notes",              gloss: "付箋", sizes: ["default"] },
    { id: "weather",    prefix: "pythonWeather",    label: "Python Weather",    icon: "partly_cloudy_day",  gloss: "天気", sizes: ["compact", "full", "round"] },
    { id: "image",      prefix: "pythonImage",      label: "Python Image",      icon: "image",              gloss: "画像", sizes: ["rect", "rounded", "round"] },
    { id: "user",       prefix: "pythonUser",       label: "Python User",       icon: "account_circle",     gloss: "人物", sizes: ["default"] },
    { id: "cpu",        prefix: "pythonCpu",        label: "Python CPU",        icon: "developer_board",    gloss: "演算", sizes: ["default", "circle"] },
    { id: "ram",        prefix: "pythonRam",        label: "Python RAM",        icon: "memory",             gloss: "主存", sizes: ["default", "circle"] },
    { id: "temp",       prefix: "pythonTemp",       label: "Python Temperature",icon: "device_thermostat",  gloss: "温度", sizes: ["default", "circle"] },
    { id: "disk",       prefix: "pythonDisk",       label: "Python Disk",       icon: "hard_drive",         gloss: "磁盤", sizes: ["default", "circle"] },
    { id: "battery",    prefix: "pythonBattery",    label: "Python Battery",    icon: "battery_full",       gloss: "電池", sizes: ["default", "circle"] },
    { id: "github",     prefix: "pythonGithub",     label: "Python GitHub",     icon: "code",               gloss: "貢献", sizes: ["default"] }
];

function byPrefix(prefix) {
    for (var i = 0; i < faces.length; i++)
        if (faces[i].prefix === prefix)
            return faces[i];
    return null;
}

function isPython(prefix) {
    return byPrefix(prefix) !== null;
}
