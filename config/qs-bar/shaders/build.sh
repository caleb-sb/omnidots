#!/bin/sh
# Recompile shaders after editing *.frag. Needs Qt's `qsb`
# (Fedora: sudo dnf install qt6-qtshadertools, binary in /usr/lib64/qt6/bin).
cd "$(dirname "$0")" || exit 1
QSB=${QSB:-$(command -v qsb || echo /usr/lib64/qt6/bin/qsb)}
for f in *.frag; do
    "$QSB" --qt6 -o "$f.qsb" "$f" || exit 1
done
