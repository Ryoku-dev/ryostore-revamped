import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from urllib.parse import quote


ITEM = Path(__file__).resolve().parents[1]
QS = shutil.which("qs")
METRIC = {
    "current": {"temperature_2m": 21.6, "apparent_temperature": 20.4,
                "visibility": 12345, "time": "2001-01-01T15:30", "weather_code": 0},
    "current_units": {"temperature_2m": "°C", "apparent_temperature": "°C"},
    "hourly": {"time": ["2001-01-01T14:00", "2001-01-01T15:00", "2001-01-01T16:00"],
               "temperature_2m": [18, 21, 22], "weather_code": [0, 0, 0]},
}


@unittest.skipUnless(QS, "weather runtime tests need Quickshell")
class WeatherTest(unittest.TestCase):
    def run_weather(self, *, mode="success", city="Fixture", coordinates=True, direct=None, cooldown=False):
        with tempfile.TemporaryDirectory(prefix="shima-weather-") as directory:
            root = Path(directory)
            for path in ("inir/services", "inir/modules/common", "Ryoku/Ui/Singletons", "bin", "home/cache", "runtime"):
                (root / path).mkdir(parents=True, exist_ok=True)
            (root / "runtime").chmod(0o700)
            shutil.copyfile(ITEM / "qml/inir/services/Weather.qml", root / "inir/services/Weather.qml")
            modules = {
                "inir/services": {
                    "Config": "property var options: ({}); property bool ready: false",
                    "Network": "property bool online: false",
                    "Directories": 'property string weatherCachePath: Quickshell.env("HOME") + "/cache/weather.json"',
                },
                "inir/modules/common": {"Translation": "function tr(text) { return text; }"},
                "Ryoku/Ui/Singletons": {"TimeFormat": 'function format(date) { return Qt.formatTime(date, "HH:mm"); }'},
            }
            for module, singletons in modules.items():
                entries = ["module " + module.replace("/", ".")]
                if module == "inir/services":
                    entries.append("singleton Weather 1.0 Weather.qml")
                for name, body in singletons.items():
                    entries.append(f"singleton {name} 1.0 {name}.qml")
                    (root / module / (name + ".qml")).write_text(
                        "pragma Singleton\nimport QtQuick\nimport Quickshell\nQtObject { " + body + " }\n")
                (root / module / "qmldir").write_text("\n".join(entries) + "\n")
            curl = root / "bin/curl"
            curl.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
with Path(os.environ["WEATHER_CALLS"]).open("a") as handle:
    handle.write(json.dumps(sys.argv[1:]) + "\\n")
url = sys.argv[-1]
if url.startswith("https://api.open-meteo.com/"):
    if os.environ["WEATHER_MODE"] == "failure":
        sys.exit(22)
    print(os.environ["WEATHER_RESPONSE"])
elif "wttr.in/" in url:
    print(json.dumps({"current_condition": [{"temp_C": "9", "FeelsLikeC": "8"}], "weather": []}))
else:
    print("{}")
''')
            curl.chmod(0o700)
            location = dict(valid=True, lat=48 if coordinates else 0, lon=2 if coordinates else 0, name=city)
            action = "Weather.fetchWeather();"
            if direct is not None:
                action = "accepted = Weather.refineOpenMeteoData(" + json.dumps(direct, ensure_ascii=False) + ");"
            if cooldown:
                action = "Weather._primaryFailCount = 3; Weather._primaryFailUntil = Date.now() + 60000; " + action
            probe = root / "probe.qml"
            probe.write_text('''import QtQuick
import Quickshell
import inir.services
ShellRoot {
    property bool accepted: false
    Timer { interval: 100; running: true; onTriggered: {
        Weather.location = LOCATION;
        ACTION
    } }
    Timer { interval: 1200; running: true; onTriggered: {
        console.log("WEATHER_RESULT " + JSON.stringify({data: Weather.data, accepted: accepted}));
        Qt.quit();
    } }
}
'''.replace("LOCATION", json.dumps(location)).replace("ACTION", action))
            env = {"PATH": str(root / "bin") + ":/usr/bin:/bin", "HOME": str(root / "home"),
                   "XDG_RUNTIME_DIR": str(root / "runtime"), "XDG_CONFIG_HOME": str(root / "home/config"),
                   "XDG_DATA_HOME": str(root / "home/data"), "XDG_CACHE_HOME": str(root / "home/cache"),
                   "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software", "LANG": "C.UTF-8",
                   "QML_IMPORT_PATH": str(root), "QML2_IMPORT_PATH": str(root),
                   "WEATHER_CALLS": str(root / "calls.jsonl"), "WEATHER_MODE": mode,
                   "WEATHER_RESPONSE": json.dumps(METRIC)}
            result = subprocess.run([QS, "-p", str(probe)], env=env, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            rows = [line.split("WEATHER_RESULT ", 1)[1] for line in output.splitlines() if "WEATHER_RESULT " in line]
            self.assertEqual(len(rows), 1, output)
            calls = root / "calls.jsonl"
            requests = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
            return json.loads(rows[0]), requests

    def test_coordinates_use_open_meteo_before_wttr(self):
        result, requests = self.run_weather()
        self.assertIn("api.open-meteo.com/", requests[0][-1])
        self.assertFalse(any("wttr.in/" in args[-1] for args in requests))
        self.assertEqual(result["data"]["temp"], "22°C")

    def test_primary_failure_falls_back_once(self):
        result, requests = self.run_weather(mode="failure")
        weather = [args[-1] for args in requests if "air-quality" not in args[-1]]
        self.assertEqual(len(weather), 2)
        self.assertIn("api.open-meteo.com/", weather[0])
        self.assertIn("wttr.in/", weather[1])
        self.assertEqual(result["data"]["temp"], "9°C")

    def test_city_only_is_one_curl_argument(self):
        city = "O'Fallon; $(touch unexpected)"
        result, requests = self.run_weather(city=city, coordinates=False)
        self.assertEqual(requests, [["-s", "--max-time", "15", "https://wttr.in/" + quote(city, safe="-_.!~*'()") + "?format=j1"]])
        self.assertEqual(result["data"]["temp"], "9°C")

    def test_primary_cooldown_uses_wttr(self):
        result, requests = self.run_weather(cooldown=True)
        self.assertIn("wttr.in/", requests[0][-1])
        self.assertFalse(any(args[-1].startswith("https://api.open-meteo.com/") for args in requests))
        self.assertEqual(result["data"]["temp"], "9°C")

    def test_metric_readings_and_location_clock(self):
        result, _ = self.run_weather(direct=METRIC)
        self.assertTrue(result["accepted"])
        self.assertEqual(result["data"]["temp"], "22°C")
        self.assertEqual(result["data"]["tempFeelsLike"], "20°C")
        self.assertEqual(result["data"]["visib"], "12.3 km")
        self.assertEqual([row["minuteOfDay"] for row in result["data"]["hourly"]], [900, 960])

    def test_imperial_readings_and_invalid_response(self):
        imperial = {"current": {"temperature_2m": 68.6, "visibility": 5280, "wind_speed_10m": 5},
                    "current_units": {"temperature_2m": "°F", "apparent_temperature": "°F", "wind_speed_10m": "mp/h"}}
        result, _ = self.run_weather(direct=imperial)
        self.assertTrue(result["accepted"])
        self.assertEqual(result["data"]["temp"], "69°F")
        self.assertEqual(result["data"]["tempFeelsLike"], "69°F")
        self.assertEqual(result["data"]["visib"], "1 mi")
        self.assertEqual(result["data"]["wind"], "5 mph")
        invalid, _ = self.run_weather(direct={"current": {}})
        self.assertFalse(invalid["accepted"])


if __name__ == "__main__":
    unittest.main()
