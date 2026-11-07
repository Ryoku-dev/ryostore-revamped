.pragma library

var KINDS = {
    photo_camera: 0, screenshot_region: 0, screenshot: 0, content_copy: 0,
    content_paste: 0, image_search: 0, draw: 0, document_scanner: 0,
    text_snippet: 0, colorize: 0,
    videocam: 1, fiber_manual_record: 1, error: 1, warning: 1,
    image_not_supported: 1, report: 1,
    alarm: 2, timer: 2, schedule: 2, notifications: 2, bolt: 2,
    terminal: 3, vpn_lock: 3, vpn_key: 3, music_cast: 3, view_carousel: 3,
    memory: 3, extension: 3,
    system_update: 4, check_circle: 4, download: 4, done: 4, wallpaper: 4,
    palette: 4, update: 4
};

function index(glyph) {
    var g = String(glyph === undefined || glyph === null ? "" : glyph);
    if (Object.prototype.hasOwnProperty.call(KINDS, g))
        return KINDS[g];
    var h = 7;
    for (var i = 0; i < g.length; i++)
        h = (h * 31 + g.charCodeAt(i)) % 9973;
    return h % 5;
}
