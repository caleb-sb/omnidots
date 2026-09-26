import QtQuick
import qs.config
import qs.components

// Bar surface + morphing popout host.
//
// Draws the bar strip and the open popout as ONE shape (SDF shader), so the
// popout grows out of the bar edge with concave fillets and melts back into
// it on close, the way caelestia's blob drawers do. One per bar window; any
// module can use it:
//     popout.toggle("name", anchorItem, someComponent)
Item {
    id: root

    property bool open
    property string current
    property Component content
    // Horizontal centre of the bar item the popout grows from, and its width.
    property real originX
    property real originW

    readonly property alias card: clip
    readonly property int padding: Theme.spacing.large
    // Keep the card clear of the bar's rounded ends.
    readonly property int screenMargin: Theme.bar.margin + Theme.bar.radius
    readonly property real barBottom: Theme.bar.margin + Theme.bar.height

    function toggle(name: string, anchor: Item, comp: Component): void {
        if (open && current === name) {
            close();
            return;
        }
        const p = anchor.mapToItem(root, 0, 0);
        // While hidden, jump to the new origin instead of sliding there from
        // wherever the card was last (or from x = 0 on the first open).
        geo.snap = !clip.visible;
        originX = p.x + anchor.width / 2;
        originW = anchor.width;
        geo.snap = false;
        current = name;
        content = comp;
        open = true;
        focusScope.forceActiveFocus();
    }

    function close(): void {
        open = false;
    }

    FocusScope {
        id: focusScope

        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root.close()
    }

    // Animated card geometry. `extent` is how far the card reaches below the
    // bar edge; negative values tuck it inside the bar where the fillet
    // cannot see it.
    QtObject {
        id: geo

        readonly property real fullW: loader.implicitWidth + root.padding * 2
        readonly property real fullH: loader.implicitHeight + root.padding * 2
        readonly property real hidden: -(Theme.popout.smoothing + 2)
        property bool snap

        property real w: root.open ? fullW : root.originW
        property real cx: root.open ? Math.max(root.screenMargin + fullW / 2, Math.min(root.width - root.screenMargin - fullW / 2, root.originX)) : root.originX
        // Edges clamped clear of the bar's rounded ends, including while
        // tucked away under an item near one end.
        readonly property real x: Math.max(root.screenMargin, cx - w / 2)
        readonly property real right: Math.min(root.width - root.screenMargin, cx + w / 2)
        property real extent: root.open ? fullH : hidden

        Behavior on w {
            enabled: !geo.snap
            Anim {}
        }
        Behavior on cx {
            enabled: !geo.snap
            Anim {}
        }
        Behavior on extent {
            Anim {
                id: extentAnim
            }
        }
    }

    // Jelly: a damped spring driven by how fast the card is growing, turned
    // into a squash/stretch anchored at the bar edge.
    FrameAnimation {
        id: jelly

        property real lastExtent
        property real s
        property real v
        property bool settling

        running: Theme.popout.deform > 0 && (extentAnim.running || settling)
        onRunningChanged: if (running) {
            lastExtent = geo.extent;
            settling = true;
        }
        onTriggered: {
            const dt = Math.min(frameTime, 1 / 30);
            if (dt <= 0)
                return;
            const vel = (geo.extent - lastExtent) / dt;
            lastExtent = geo.extent;
            const target = Math.max(-0.25, Math.min(0.25, vel * Theme.popout.deform / 10000));
            const a = 260 * (target - s) - 22 * v;
            v += a * dt;
            s += v * dt;
            if (!extentAnim.running && Math.abs(s) < 0.0005 && Math.abs(v) < 0.0005) {
                s = 0;
                v = 0;
                settling = false;
            }
        }
    }

    ShaderEffect {
        anchors.fill: parent

        readonly property size size: Qt.size(width, height)
        // Floating bar, inset from the screen edges.
        readonly property rect bar: Qt.rect(Theme.bar.margin, Theme.bar.margin, width - Theme.bar.margin * 2, Theme.bar.height)
        // The card starts well above the bar so its top corners never show;
        // the shader cuts it off above the bar's middle.
        readonly property rect card: Qt.rect(geo.x, -200, Math.max(0, geo.right - geo.x), root.barBottom + 200 + geo.extent)
        readonly property color color: Theme.c.bg
        readonly property real radius: Theme.popout.radius
        readonly property real smoothing: Theme.popout.smoothing
        readonly property size stretch: Qt.size(1 - jelly.s * 0.5, 1 + jelly.s)
        readonly property point anchor: Qt.point(geo.x + geo.w / 2, root.barBottom)
        readonly property real barRadius: Theme.bar.radius
        readonly property real surfaceOpacity: Theme.bar.opacity

        fragmentShader: Qt.resolvedUrl("../shaders/surface.frag.qsb")
    }

    // Content lives in a clip that tracks the visible part of the card.
    Item {
        id: clip

        x: geo.x
        y: root.barBottom
        width: Math.max(0, geo.right - geo.x)
        height: Math.max(0, geo.extent)
        clip: true
        visible: height > 0

        Loader {
            id: loader

            // Fixed size, centred, so the growing card reveals it instead of
            // reflowing it.
            x: (clip.width - width) / 2
            y: root.padding
            width: implicitWidth
            height: implicitHeight

            active: root.open || clip.visible
            sourceComponent: root.content

            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.92
            transformOrigin: Item.Top

            Behavior on opacity {
                Anim {
                    duration: root.open ? Theme.anim.fastDuration : Theme.anim.effectsDuration
                    easing.bezierCurve: Theme.anim.effects
                }
            }
            Behavior on scale {
                Anim {}
            }
        }
    }
}
