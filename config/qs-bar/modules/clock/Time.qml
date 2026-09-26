pragma Singleton

import QtQuick
import Quickshell

// Shared wall clock for the bar and the calendar panel.
Singleton {
    readonly property date now: clock.date

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }
}
