import QtQuick
import qs.config

SquircleRect {
    radius: pill !== "" ? Math.min(width, height) / 2 : Appearance.rounding.large
    color: Appearance.colour.readableSurface
    rim: 1
}
