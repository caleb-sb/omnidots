pragma Singleton

import QtQuick
import Quickshell

// Tokyo Night (night). Single fixed palette; every module reads from here.
Singleton {
    readonly property QtObject c: QtObject {
        readonly property color bg: "#1a1b26"
        readonly property color bgDark: "#16161e"
        readonly property color bgHighlight: "#292e42"
        readonly property color terminalBlack: "#414868"
        readonly property color fg: "#c0caf5"
        readonly property color fgDark: "#a9b1d6"
        readonly property color fgGutter: "#3b4261"
        readonly property color dark3: "#545c7e"
        readonly property color comment: "#565f89"
        readonly property color dark5: "#737aa2"
        readonly property color blue: "#7aa2f7"
        readonly property color blue7: "#394b70"
        readonly property color cyan: "#7dcfff"
        readonly property color magenta: "#bb9af7"
        readonly property color green: "#9ece6a"
        readonly property color yellow: "#e0af68"
        readonly property color orange: "#ff9e64"
        readonly property color red: "#f7768e"
    }

    readonly property QtObject bar: QtObject {
        readonly property int height: 46
        // Gap between the bar edge and the pills, the same on all sides so
        // the pills' ends are concentric with the bar's.
        readonly property int padding: 6
        // Gap between the floating bar and the screen's top and sides.
        readonly property int margin: 10
        // Fully round ends, concentric with the pills inside (17 + padding).
        readonly property int radius: height / 2
        // Background opacity of the bar and its popout panels (not the pills
        // or cards on them); Hyprland blurs what's behind it (layer rule in
        // windowrules.lua).
        readonly property real opacity: 0.75
    }

    readonly property QtObject popout: QtObject {
        readonly property int radius: 24
        // Fillet radius where a popout meets the bar.
        readonly property int smoothing: 22
        // Jelly squash/stretch while moving; 0 disables.
        readonly property real deform: 0.15
        readonly property int screenMargin: 8
    }

    readonly property QtObject rounding: QtObject {
        readonly property int small: 8
        readonly property int normal: 14
        readonly property int large: 22
        readonly property int full: 1000
    }

    readonly property QtObject spacing: QtObject {
        readonly property int small: 6
        readonly property int normal: 10
        readonly property int large: 16
    }

    readonly property QtObject font: QtObject {
        readonly property string sans: "JetBrainsMono Nerd Font Propo"
        readonly property string icons: "Material Symbols Rounded"
        // Pixel sizes (logical px, before monitor scale).
        readonly property int small: 13
        readonly property int normal: 15
        readonly property int large: 17
        readonly property int title: 20
        // Bar text; matches waybar's 16px.
        readonly property int bar: 16
    }

    // Material 3 expressive motion, same curves caelestia uses.
    readonly property QtObject anim: QtObject {
        readonly property list<real> spatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> fastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property list<real> effects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]

        readonly property int spatialDuration: 500
        readonly property int fastDuration: 350
        readonly property int effectsDuration: 200
        readonly property int closeDuration: 250
    }
}
