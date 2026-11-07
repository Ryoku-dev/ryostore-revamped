import Quickshell
import QtQuick
import shell.services as Ryoku
import "."

// The system side of the weather pill, fed by Ryoku's Weather singleton. The
// fetch, geocoding, unit handling and WMO mapping all live in the daemon; this
// only reshapes the frame into the fields WeatherPopup / WeatherIndicator read.
Scope {
    id: root

    readonly property var frame: Ryoku.Weather.frame
    readonly property bool loading: Ryoku.Weather.status === "loading"
    readonly property bool failed: !Ryoku.Weather.hasData && Ryoku.Weather.errorText !== ""
    readonly property string problemText: Ryoku.Weather.errorText
    readonly property double lastFetchMs: 0

    readonly property string temperatureText: Ryoku.Weather.current
        ? Ryoku.Weather.current.temperature : ""
    readonly property string conditionText: Ryoku.Weather.current
        ? Ryoku.Weather.current.condition : ""
    readonly property string iconName: {
        const c = Ryoku.Weather.current
        if (!c)
            return "cloud"
        return glyph(c.code, c.isDay)
    }
    readonly property string feelsLikeText: Ryoku.Weather.current
        ? Ryoku.Weather.current.feelsLike : ""
    readonly property string humidityText: Ryoku.Weather.current
        ? Math.round(Ryoku.Weather.current.humidity) + "%" : ""
    readonly property string windText: {
        const c = Ryoku.Weather.current
        if (!c)
            return ""
        return c.wind + (c.windUnits || "") + (c.windDir ? " " + c.windDir : "")
    }
    readonly property string pressureText: Ryoku.Weather.current
        ? Ryoku.Weather.current.pressure : ""
    readonly property string visibilityText: Ryoku.Weather.current
        ? Ryoku.Weather.current.visibility : ""
    readonly property string uvText: {
        const c = Ryoku.Weather.current
        if (!c)
            return ""
        return Math.round(c.uvIndex) + " UV"
    }
    readonly property string precipText: Ryoku.Weather.current
        ? Ryoku.Weather.current.precip : ""
    readonly property string areaText: Ryoku.Weather.city || Ryoku.Weather.location || ""
    readonly property string sunriseText: Ryoku.Weather.current
        ? Ryoku.Weather.current.sunrise : ""
    readonly property string sunsetText: Ryoku.Weather.current
        ? Ryoku.Weather.current.sunset : ""
    readonly property string updatedText: Ryoku.Weather.updatedAt

    readonly property var hourly: {
        const list = Ryoku.Weather.hourly || []
        const out = []
        for (let i = 0; i < list.length; i++) {
            const h = list[i]
            out.push({
                iconName: glyph(h.code, h.isDay),
                temp: h.temperature,
                label: h.time,
                condition: condition(h.code),
                feels: h.temperature,
                rain: Math.round(h.precip || 0)
            })
        }
        return out
    }

    readonly property var forecast: {
        const list = Ryoku.Weather.daily || []
        const out = []
        for (let i = 0; i < list.length; i++) {
            const d = list[i]
            out.push({
                iconName: glyph(d.code, true),
                high: d.high,
                low: d.low,
                rain: Math.round((d.precipProb ?? 0)),
                label: d.weekday || d.day || "",
                date: "",
                condition: condition(d.code)
            })
        }
        return out
    }

    function glyph(code, isDay) {
        if (code === 0)
            return isDay ? "clear_day" : "clear_night"
        if (code === 1 || code === 2)
            return isDay ? "partly_cloudy_day" : "partly_cloudy_night"
        if (code === 3)
            return "cloud"
        if (code === 45 || code === 48)
            return "foggy"
        if (code >= 95)
            return "thunderstorm"
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "weather_snowy"
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "rainy"
        return "cloud"
    }

    function condition(code) {
        if (code === 0) return "Clear"
        if (code <= 3) return "Cloudy"
        if (code === 45 || code === 48) return "Fog"
        if (code >= 95) return "Thunder"
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow"
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "Rain"
        return "Cloudy"
    }

    function refresh() { Ryoku.Weather.retry() }
}
