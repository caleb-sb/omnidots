pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// Popup toasts, top-right under the bar. They slide in from the screen edge
// and back out when they time out or are dismissed.
PanelWindow {
    id: root

    screen: Quickshell.screens[0]
    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.popout.screenMargin
        right: Theme.popout.screenMargin
    }
    implicitWidth: 380 + shadowPad * 2
    // Fixed height so cards sliding out are not clipped; the mask keeps the
    // empty part click-through.
    implicitHeight: Math.round((screen?.height ?? 1080) * 0.8)
    exclusiveZone: 0
    color: "transparent"
    visible: Notifs.popups.length > 0 || removing.running

    readonly property int shadowPad: 16

    WlrLayershell.namespace: "qs-bar-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    mask: Region {
        item: list.contentItem
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.margins: root.shadowPad
        spacing: Theme.spacing.normal
        interactive: false

        model: ScriptModel {
            values: [...Notifs.popups]
        }

        delegate: Item {
            id: slot

            required property var modelData

            width: ListView.view.width
            implicitHeight: card.implicitHeight
            height: implicitHeight

            NotifCard {
                id: card

                width: parent.width
                modelData: slot.modelData
                popup: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurMax: 24
                    shadowBlur: 0.8
                    shadowVerticalOffset: 3
                    shadowColor: Qt.alpha("#000000", 0.5)
                }
            }
        }

        add: Transition {
            ParallelAnimation {
                Anim {
                    property: "x"
                    from: list.width + root.shadowPad
                    to: 0
                }
                Anim {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.anim.fastDuration
                    easing.bezierCurve: Theme.anim.effects
                }
            }
        }

        remove: Transition {
            id: removing

            ParallelAnimation {
                Anim {
                    property: "x"
                    to: list.width + root.shadowPad
                    duration: Theme.anim.closeDuration
                    easing.bezierCurve: Theme.anim.standardAccel
                }
                Anim {
                    property: "opacity"
                    to: 0
                    duration: Theme.anim.closeDuration
                    easing.bezierCurve: Theme.anim.standardAccel
                }
            }
        }

        displaced: Transition {
            Anim {
                property: "y"
            }
        }
    }
}
