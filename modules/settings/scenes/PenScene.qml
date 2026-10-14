import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 220
    readonly property bool on: SettingsState.v("pen")
    readonly property string target: SettingsState.v("penScreen")
    readonly property var surface: Config.values.pen.surface
    readonly property real padAspect: root.surface.width / Math.max(1, root.surface.height)
    readonly property real targetAspect: {
        if (root.target === "all")
            return 3.6;
        const m = Monitors.active.find(o => o.name === root.target);
        if (!m)
            return root.padAspect;
        const l = Monitors.layoutOf(m);
        return l.w / Math.max(1, l.h);
    }
    readonly property bool locked: SettingsState.v("aspectLock")
    readonly property real wFrac: root.locked && root.targetAspect <= root.padAspect ? root.targetAspect / root.padAspect : 1
    readonly property real hFrac: root.locked && root.targetAspect > root.padAspect ? root.padAspect / root.targetAspect : 1

    Follow {
        id: fw

        target: root.wFrac
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Follow {
        id: fh

        target: root.hFrac
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    SceneClock {
        id: clock

        duration: 3200
        still: 0.7
    }

    readonly property var ink: [[0, {
                d: 1,
                o: 1
            }], [[60, 85], {
                d: 0,
                o: 1
            }], [100, {
                d: 0,
                o: 0
            }]]

    readonly property var curve: [[8, 40], [20, 8, 34, 8, 40, 30], [46, 52, 58, 54, 66, 30], [74, 6, 84, 6, 92, 22]]

    Item {
        id: pad

        x: 40
        y: 28
        width: parent.width - 80
        height: parent.height - 56

        SquircleRect {
            anchors.fill: parent
            radius: 10
            color: "transparent"
            stroke: Appearance.colour.fillStronger
            strokeWidth: 2
        }

        Item {
            id: area

            anchors.centerIn: parent
            width: pad.width * fw.value
            height: pad.height * fh.value
            clip: true

            SquircleRect {
                anchors.fill: parent
                radius: 6
                color: Appearance.colour.accentFill
                stroke: Appearance.colour.accent
                strokeWidth: 2
            }

            Shape {
                id: stroke

                readonly property real sx: area.width * 0.8 / 100
                readonly property real sy: area.height * 0.8 / 60
                readonly property var pts: {
                    const out = [];
                    const c = root.curve;
                    let p0 = c[0];
                    out.push(p0);
                    for (let i = 1; i < c.length; i++) {
                        const s = c[i];
                        for (let k = 1; k <= 12; k++) {
                            const t = k / 12;
                            const u = 1 - t;
                            out.push([u * u * u * p0[0] + 3 * u * u * t * s[0] + 3 * u * t * t * s[2] + t * t * t * s[4], u * u * u * p0[1] + 3 * u * u * t * s[1] + 3 * u * t * t * s[3] + t * t * t * s[5]]);
                        }
                        p0 = [s[4], s[5]];
                    }
                    return out.map(p => [p[0] * stroke.sx, p[1] * stroke.sy]);
                }
                readonly property real length: {
                    let l = 0;
                    for (let i = 1; i < stroke.pts.length; i++)
                        l += Math.hypot(stroke.pts[i][0] - stroke.pts[i - 1][0], stroke.pts[i][1] - stroke.pts[i - 1][1]);
                    return Math.max(1, l);
                }
                readonly property var f: Frames.at(root.ink, clock.value, Frames.STANDARD)

                x: area.width * 0.1
                y: area.height * 0.1
                width: area.width * 0.8
                height: area.height * 0.8
                visible: root.on
                opacity: f.o
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Appearance.colour.accent
                    strokeWidth: 3
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [stroke.length / 3, stroke.length / 3]
                    dashOffset: stroke.f.d * stroke.length / 3

                    PathPolyline {
                        path: stroke.pts.map(p => Qt.point(p[0], p[1]))
                    }
                }
            }

            StyledText {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 8
                anchors.bottomMargin: 4
                visible: root.on
                text: root.target
                color: Appearance.colour.accent
            }

            StyledText {
                anchors.centerIn: parent
                visible: !root.on
                text: "off"
                color: Appearance.colour.accent
            }
        }
    }

    SceneCaption {
        text: `${SettingsState.penName} · ${root.surface.width} × ${root.surface.height} mm${root.locked && (root.wFrac < 1 || root.hFrac < 1) ? " · edges trimmed" : ""}`
    }
}
