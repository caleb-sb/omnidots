pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Clock and month calendar. Scroll the month name to change month, the year
// to change year, or the grid to step through months.
Item {
    id: root

    signal closeRequested

    // Month being shown (month is 0-11).
    property int year: Time.now.getFullYear()
    property int month: Time.now.getMonth()
    readonly property bool showingToday: year === Time.now.getFullYear() && month === Time.now.getMonth()

    function shift(months: int): void {
        if (months === 0)
            return;
        const d = new Date(year, month + months, 1);
        year = d.getFullYear();
        month = d.getMonth();
        slide.dir = months > 0 ? 1 : -1;
        slide.restart();
    }
    function goToday(): void {
        const now = Time.now;
        shift((now.getFullYear() - year) * 12 + now.getMonth() - month);
    }

    // 6 weeks from the start of the week containing the 1st.
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
    readonly property var days: {
        const first = new Date(year, month, 1);
        const lead = (first.getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(year, month, 1 - lead + i));
        return out;
    }

    implicitWidth: 7 * cell + 6 * gap
    implicitHeight: column.implicitHeight

    readonly property int cell: 40
    readonly property int gap: 4

    ColumnLayout {
        id: column

        width: parent.width
        spacing: Theme.spacing.normal

        // ── Clock ─────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 0

            Row {
                spacing: 6

                StyledText {
                    id: bigTime

                    // "h" is only 12-hour when AP is in the same format string.
                    text: Time.format("h:mm AP").replace(/\s*[AP]M$/i, "")
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                    font.features: ({ tnum: 1 })
                }
                StyledText {
                    anchors.baseline: bigTime.baseline
                    text: Time.format("AP")
                    font.pixelSize: Theme.font.large
                    font.weight: Font.DemiBold
                    color: Theme.c.blue
                }
            }
            StyledText {
                text: Time.format("dddd, MMMM d, yyyy")
                color: Theme.c.comment
            }
        }

        // ── Month / year ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacing.small
            spacing: 2

            ScrollLabel {
                text: Qt.locale().standaloneMonthName(root.month)
                font.weight: Font.DemiBold
                onStep: dir => root.shift(dir)
            }
            ScrollLabel {
                text: root.year
                color: Theme.c.fgDark
                onStep: dir => root.shift(dir * 12)
            }

            Item {
                Layout.fillWidth: true
            }

            // Back to this month when scrolled away.
            Rectangle {
                implicitWidth: todayLabel.implicitWidth + 16
                implicitHeight: 24
                radius: Theme.rounding.full
                color: Qt.alpha(Theme.c.blue, 0.15)
                opacity: root.showingToday ? 0 : 1
                visible: opacity > 0

                Behavior on opacity {
                    Anim {
                        duration: Theme.anim.fastDuration
                        easing.bezierCurve: Theme.anim.effects
                    }
                }

                StateLayer {
                    color: Theme.c.blue
                    onClicked: root.goToday()
                }

                StyledText {
                    id: todayLabel

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round((parent.height - height) / 2)
                    text: "Today"
                    font.pixelSize: Theme.font.small
                    font.weight: Font.DemiBold
                    color: Theme.c.blue
                }
            }

            IconButton {
                size: 30
                icon: "chevron_left"
                iconColor: Theme.c.fgDark
                onClicked: root.shift(-1)
            }
            IconButton {
                size: 30
                icon: "chevron_right"
                iconColor: Theme.c.fgDark
                onClicked: root.shift(1)
            }
        }

        // ── Grid ──────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight
            clip: true

            // Scrolling anywhere on the grid steps months.
            Scroller {
                anchors.fill: parent
                onStep: dir => root.shift(dir)
            }

            ColumnLayout {
                id: grid

                width: parent.width
                spacing: root.gap

                // Weekday initials.
                Row {
                    spacing: root.gap

                    Repeater {
                        model: 7

                        StyledText {
                            required property int index
                            readonly property int dow: (root.firstDay + index) % 7

                            width: root.cell
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().dayName(dow, Locale.ShortFormat).slice(0, 2)
                            font.pixelSize: Theme.font.small
                            font.weight: Font.DemiBold
                            color: dow === 0 || dow === 6 ? Theme.c.magenta : Theme.c.comment
                        }
                    }
                }

                Grid {
                    id: days

                    columns: 7
                    spacing: root.gap

                    // Month changes slide the days in from the side scrolled to.
                    transform: Translate {
                        id: shiftX
                    }
                    ParallelAnimation {
                        id: slide

                        property int dir: 1

                        Anim {
                            target: shiftX
                            property: "x"
                            from: slide.dir * 28
                            to: 0
                            easing.bezierCurve: Theme.anim.standard
                        }
                        Anim {
                            target: days
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.anim.fastDuration
                            easing.bezierCurve: Theme.anim.effects
                        }
                    }

                    Repeater {
                        model: root.days

                        Day {}
                    }
                }
            }
        }
    }

    component Day: Item {
        id: day

        required property date modelData
        readonly property bool inMonth: modelData.getMonth() === root.month
        readonly property bool today: modelData.toDateString() === Time.now.toDateString()
        readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6

        width: root.cell
        height: root.cell - 4

        Rectangle {
            anchors.centerIn: parent
            width: parent.height
            height: parent.height
            radius: height / 2
            color: day.today ? Theme.c.blue : "transparent"
        }

        StyledText {
            // Rounded rather than centerIn so half-pixel offsets don't
            // leave the digits sitting high.
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((parent.height - height) / 2)
            text: day.modelData.getDate()
            font.features: ({ tnum: 1 })
            font.weight: day.today ? Font.Bold : Font.Normal
            color: day.today ? Theme.c.bgDark : !day.inMonth ? Theme.c.fgGutter : day.weekend ? Theme.c.magenta : Theme.c.fg
        }
    }

    // Text that steps a value when scrolled; highlights on hover.
    component ScrollLabel: StyledText {
        id: label

        signal step(int dir)

        leftPadding: 6
        rightPadding: 6
        font.pixelSize: Theme.font.large

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: -2
            anchors.bottomMargin: -2
            z: -1
            radius: Theme.rounding.small
            color: Theme.c.fg
            opacity: labelScroll.containsMouse ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    duration: Theme.anim.effectsDuration
                }
            }
        }

        Scroller {
            id: labelScroll

            anchors.fill: parent
            onStep: dir => label.step(dir)
        }
    }

    // Wheel -> discrete steps (+1 = scrolled down / forward). Accumulates
    // touchpad deltas into whole notches.
    component Scroller: MouseArea {
        signal step(int dir)
        property real acc

        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onWheel: e => {
            acc += e.angleDelta.y;
            while (Math.abs(acc) >= 120) {
                const dir = acc > 0 ? -1 : 1;
                acc += dir * 120;
                step(dir);
            }
        }
    }
}
