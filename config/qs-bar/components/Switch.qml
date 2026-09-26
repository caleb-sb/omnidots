import QtQuick
import QtQuick.Shapes
import qs.config

// M3-style switch. Emits toggled(); the owner decides what `checked` is.
Item {
    id: root

    property bool checked
    property bool busy
    signal toggled

    implicitWidth: 48
    implicitHeight: 28

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.c.blue : Theme.c.bgHighlight
        border.width: root.checked ? 0 : 2
        border.color: Theme.c.dark3

        Behavior on color {
            CAnim {}
        }

        Rectangle {
            id: thumb

            readonly property real size: root.checked || area.pressed ? 20 : 14

            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - 4 : 4 + (20 - size) / 2
            width: area.pressed ? 24 : size
            height: size
            radius: height / 2
            color: root.checked ? Theme.c.bgDark : Theme.c.dark5

            Behavior on x {
                Anim {
                    duration: Theme.anim.fastDuration
                    easing.bezierCurve: Theme.anim.fastSpatial
                }
            }
            Behavior on width {
                Anim {
                    duration: Theme.anim.fastDuration
                }
            }
            Behavior on height {
                Anim {
                    duration: Theme.anim.fastDuration
                }
            }
            Behavior on color {
                CAnim {}
            }

            // Vector check (a font glyph sits off-centre from its metrics).
            Shape {
                anchors.centerIn: parent
                width: 10
                height: 8
                preferredRendererType: Shape.CurveRenderer
                opacity: root.checked ? 1 : 0
                scale: root.checked ? 1 : 0.4

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.effectsDuration
                    }
                }
                Behavior on scale {
                    Anim {
                        duration: Theme.anim.fastDuration
                        easing.bezierCurve: Theme.anim.fastSpatial
                    }
                }

                ShapePath {
                    strokeColor: Theme.c.blue
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: [Qt.point(0.5, 4), Qt.point(3.75, 7.25), Qt.point(9.5, 0.75)]
                    }
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: !root.busy
        onClicked: root.toggled()
    }
}
