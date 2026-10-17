import QtQuick
import QtQuick.Effects
import qs.config

RectangularShadow {
    offset.y: Appearance.padding.small
    blur: Appearance.padding.huge
    color: Appearance.withAlpha(Appearance.colour.scrim, 0.55)
}
