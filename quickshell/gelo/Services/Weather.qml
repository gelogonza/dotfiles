// Weather — temperature and precipitation.
//
// PRIVACY, READ THIS BEFORE ENABLING:
//
// There is no way to show local weather without telling somebody where you are.
// This queries wttr.in, and with no location set it geolocates by IP — meaning
// every poll tells a third-party server your approximate location and your
// address, on a timer, for as long as the shell runs.
//
// That is a real trade and not one to make silently, so it is OFF by default.
// Turn it on in design/tokens.json (`weather.enabled`) and preferably set an
// explicit `location` too — a city name is coarser than your IP and stops the
// request depending on geolocation at all.
//
// The failure mode is deliberately quiet: no network, no DNS, service down, or
// a parse failure all just leave the module hidden. A status bar should never
// show an error about the weather.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/Theme"

Singleton {
    id: root

    readonly property bool enabled: Tokens.weather.enabled
    readonly property string location: Tokens.weather.location

    property int temperature: -999
    property real precipitation: -1
    property string condition: ""

    readonly property bool valid: enabled && temperature > -900

    // Units come from Tokens.format, not from here, so the weather agrees with
    // the clock about which side of the Atlantic this desktop is on.
    readonly property string temperatureText: temperature + Tokens.format.degree

    // Inches want two decimals to say anything at all (a wet day is 0.30in);
    // millimetres are already whole numbers at that resolution.
    readonly property string precipitationText: Tokens.format.imperial
        ? precipitation.toFixed(2) + "in"
        : Math.round(precipitation) + "mm"

    // Gate on what will actually be *rendered*, not on the raw reading. 0.1mm
    // is greater than zero and displays as "0.00in", so testing the number
    // would put a permanent "no rain" readout in the bar under imperial —
    // exactly the thing the visibility rule exists to prevent.
    readonly property bool hasPrecipitation: Tokens.format.imperial
        ? precipitation >= 0.005
        : precipitation >= 0.5

    // Map wttr's free-text condition onto our own icon set.
    readonly property string icon: {
        const c = condition;
        if (c.indexOf("rain") >= 0 || c.indexOf("drizzle") >= 0)
            return "weather-showers";
        if (c.indexOf("snow") >= 0 || c.indexOf("sleet") >= 0)
            return "weather-snow";
        if (c.indexOf("thunder") >= 0)
            return "weather-storm";
        if (c.indexOf("fog") >= 0 || c.indexOf("mist") >= 0)
            return "weather-fog";
        if (c.indexOf("overcast") >= 0)
            return "weather-overcast";
        if (c.indexOf("cloud") >= 0 || c.indexOf("partly") >= 0)
            return "weather-clouds";
        return "weather-clear";
    }

    function refresh() {
        if (!enabled || proc.running)
            return;
        proc.command = ["bash", Quickshell.shellPath("scripts/weather.sh"),
                        location, Tokens.format.units];
        proc.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        // Fifteen minutes. Weather does not change faster than that, and each
        // poll is a request to somebody else's server.
        interval: 15 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    return;             // stay hidden, say nothing
                }
                if (!d || d.temp === undefined)
                    return;

                root.temperature = d.temp;
                root.precipitation = d.precip !== undefined ? d.precip : -1;
                root.condition = (d.condition || "").toLowerCase();
            }
        }
    }
}
