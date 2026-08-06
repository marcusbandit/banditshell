pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.modules
import qs.services

// What the screen looks like while it is locked.
//
// THE MACHINE STILL LOOKS LIKE ITSELF. The chassis is drawn here exactly as
// ShellWindow draws it, so locking reads as the shell closing over the desktop
// rather than as a different program taking the screen. That is the whole idea:
// any other lock screen on this box would be a black sheet with a box in the
// middle of it, and this one is banditshell with nothing in it.
//
// A plain Item, so it can be dropped into an ordinary window and looked at
// without locking anything. See modules/lock/LockSurface.qml.
//
// It is drawn on a surface that is NOT a layer surface, which has two
// consequences worth knowing before changing anything here:
//
//   - The compositor's blur rule matches `namespace banditshell` and cannot
//     reach a session lock surface, which has no namespace to match. Every other
//     panel in this shell is a translucent material because Hyprland blurs what
//     is behind it; this one has to blur its own ground, which is what the
//     MultiEffect below is for. Without it the chassis is a flat wash and the
//     shell looks cheap in exactly the way DESIGN.md section 8 is about.
//   - There is no Prompts dance and no keyboardFocus negotiation. A session lock
//     surface is handed the keyboard by the compositor, because while it is up
//     there is nothing else that could have it.
Item {
    id: root

    // Whether this is the real thing, on screen. Drives the arrival; a preview
    // sets it true and gets the settled state.
    property bool active: true

    // HARNESS ONLY, and zero everywhere that matters. The marks below cannot be
    // looked at without a keyboard, and the preview surface deliberately takes
    // no input, so it says how many to draw instead. The real surface never sets
    // this and counts what was actually typed. See lockpreview.qml.
    property int previewDots: 0

    readonly property int dots: root.previewDots > 0 ? root.previewDots : field.text.length

    // ONE value drives the whole arrival: the blur coming up, the wallpaper
    // going back, and the words rising into place. Exponential smoothing, so it
    // moves fast while it is far and settles rather than stopping.
    //
    // Nothing drives it back down. There is no exit animation on purpose; see
    // modules/lock/LockScreen.qml.
    Follow {
        id: reveal

        speed: Appearance.sizes.lockReveal
        target: root.active ? 1 : 0
        // The default epsilon is a quarter of a pixel, which is right for
        // something measured in pixels and far too coarse for a 0..1 ramp: it
        // would call this settled a third of the way up.
        epsilon: 0.002
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // The wallpaper the desktop had. Never drawn directly: it is the source the
    // effect reads, and drawing it as well would put a sharp copy under a
    // blurred one.
    //
    // Empty when the wallpaper is turned off, and the effect below goes with it:
    // an unset source never reaches Ready. What is left is LockSurface's black,
    // which is the same ground the desktop shows, and the clock has never had a
    // better one to stand on.
    Image {
        id: paper

        anchors.fill: parent
        source: Wallpaper.enabled ? Wallpaper.current : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: root.width
        sourceSize.height: root.height
        visible: false
    }

    // The blur this surface cannot ask the compositor for, and the two things
    // that turn a picture into a ground.
    //
    // Brightness carries the dim rather than a scrim laid on top: a black sheet
    // flattens the picture toward grey, and pulling the exposure down instead
    // keeps the wallpaper's own contrast, which is what stops the ground reading
    // as a sheet of plastic. It goes a long way down, because the clock is
    // Monocraft and Monocraft needs a dark ground wherever it lands; see the
    // note on `dim` in config/Config.qml.
    //
    // Saturation comes down with it, so a wallpaper in some other hue recedes
    // behind the chassis instead of arguing with it.
    MultiEffect {
        anchors.fill: parent
        source: paper
        visible: paper.status === Image.Ready

        blurEnabled: true
        blurMax: 64
        blur: reveal.value * Appearance.sizes.lockBlur
        brightness: -reveal.value * Appearance.sizes.lockDim
        saturation: -reveal.value * Appearance.sizes.lockDesaturate
        autoPaddingEnabled: false
    }

    // The shell's own body, with nothing open in it. `panels` is left empty:
    // everything that ever melts out of the band is something you asked for, and
    // you cannot ask for anything yet.
    Chassis {
        id: chassis

        anchors.fill: parent
    }

    // The sidebar, holding one glyph.
    //
    // Empty at rest is the rule, but a band that is COMPLETELY empty reads as
    // the shell having failed rather than as the shell being shut. One mark,
    // faint, centred in the slab: enough to say the bar is still there and is
    // deliberately holding nothing.
    Icon {
        x: (chassis.barWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter

        name: "lock"
        size: Appearance.font.iconSize
        color: Appearance.colour.textFaint
        opacity: reveal.value
    }

    // Everything you read, inside the CONTENT AREA rather than centred on the
    // screen. The hole is off-centre by the width of the sidebar, and a column
    // centred on the screen would sit visibly left of the space it is in.
    Item {
        id: content

        x: chassis.holeX
        y: chassis.holeY
        width: chassis.holeWidth
        height: chassis.holeHeight

        opacity: reveal.value

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            // Rises the last of the way in. Off the same ramp as the blur, so
            // the picture going back and the words coming forward are one
            // movement rather than two that happen to overlap.
            anchors.verticalCenterOffset: (1 - reveal.value) * Appearance.padding.huge

            spacing: Appearance.padding.small

            // THE TIME IS NOT BIG. This shell has three font sizes and `large`
            // is the largest thing in it, which is nowhere near the slab of
            // digits a lock screen usually wears. Adding a fourth size for one
            // label would be the beginning of the end of the scale, so the time
            // takes its weight from the air around it and from being the only
            // thing on the screen at full text colour.
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: Appearance.font.size.large
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }

            // The air that makes the time read as large without being large.
            Item {
                width: 1
                height: Appearance.padding.huge
            }

            // The field.
            //
            // It FLOATS, with convex corners, and does not melt into the band.
            // DESIGN.md section 14: melt where one thing emerges from another,
            // never between siblings. Nothing here is emerging from the chassis
            // - this is a control sitting in the content area - and fusing it to
            // the band because that is what the shell usually does would be
            // consistency with the technique rather than with the idea under it.
            G2Rect {
                anchors.horizontalCenter: parent.horizontalCenter

                width: Appearance.sizes.lockField
                height: Appearance.sizes.lockFieldHeight
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                // An outline is allowed on a control and never on the body, and
                // this is the only control on the screen. It is also the thing
                // that was refused, so it is the thing that says so: the accent
                // is spent here and on the line under it, and nowhere else.
                stroke: Lock.failed ? Appearance.colour.accent : Appearance.colour.separator
                strokeWidth: Appearance.font.stem

                // THE KEYBOARD, AND NOTHING YOU CAN SEE.
                //
                // NoEcho rather than Password. A TextInput's own bullets arrive
                // fully formed on the same frame the key goes down, which wastes
                // the one moment the screen has to acknowledge you; the marks
                // below are drawn instead. `text` still holds the real thing, so
                // this changes only what is painted, and the cursor goes with
                // the bullets because a caret in an empty line is a caret that
                // never moves.
                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal

                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.NoEcho
                    cursorVisible: false
                    clip: true

                    // Goes quiet while PAM is answering, and stays quiet once
                    // faillock has had enough. A box you can type into that
                    // cannot succeed is a lie about the state of the machine.
                    enabled: !Lock.busy && !Lock.exhausted

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText

                    // Cleared on the same keystroke that submits it. The shell
                    // holds a password for as long as it takes PAM to ask for
                    // it, and this field holds it no longer than that.
                    onAccepted: {
                        if (!field.text)
                            return;
                        Lock.submit(field.text);
                        field.text = "";
                    }

                    // The compositor hands the SURFACE the keyboard, not this
                    // item within it, and the surface exists a moment before it
                    // is mapped. Deferred for the reason every other field in
                    // this shell defers: asking for focus and having it are a
                    // round trip apart.
                    Component.onCompleted: Qt.callLater(field.forceActiveFocus)

                    // Retaken when this face becomes the live one, which is also
                    // what puts the cursor in the right field on the screen you
                    // actually walked up to.
                    Connections {
                        function onActiveChanged(): void {
                            if (root.active)
                                Qt.callLater(field.forceActiveFocus);
                        }

                        target: root
                    }

                    // WHOSE password. Not a "Password" label: the field is
                    // visibly a password field the moment you type into it, and
                    // the useful thing to say is which account is being asked
                    // about, which matters on the one occasion it is not the one
                    // you assumed.
                    StyledText {
                        anchors.centerIn: parent

                        visible: root.dots === 0
                        text: Lock.user
                        color: Appearance.colour.textGhost
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                // WHAT YOU TYPED, one mark per character, each one growing in.
                //
                // The point of drawing these by hand rather than letting the
                // TextInput echo bullets is the arrival: a mark that is simply
                // there on the next frame is the machine reporting a fact, and
                // one that grows into place is the machine answering you. It is
                // the only feedback this screen can give while you type, so it
                // is worth the fifteen lines.
                //
                // Clipped rather than shrunk or scrolled. A long password runs
                // out of field eventually, and the honest thing for it to do is
                // run off the ends: rescaling the marks to fit would turn the
                // length of what you typed into a thing you could read off the
                // screen from across the room.
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal
                    clip: true

                    Row {
                        anchors.centerIn: parent
                        spacing: Appearance.padding.small

                        Repeater {
                            model: root.dots

                            delegate: Icon {
                                name: "circle"
                                size: Appearance.sizes.lockDot
                                // Solid. An outlined ring is Material Symbols
                                // saying "off", and every mark here stands for a
                                // key that was definitely pressed.
                                fill: 1
                                color: Lock.failed ? Appearance.colour.accent : Appearance.colour.text

                                // Grown and faded in from nothing, once, on the
                                // frame it is created. A Behavior is right here
                                // and wrong almost everywhere else in this shell:
                                // nothing is already smoothing these, so there is
                                // no second ramp for it to fight with.
                                scale: 0
                                opacity: 0

                                Component.onCompleted: {
                                    scale = 1;
                                    opacity = 1;
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Appearance.anim.normal
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.anim.normal
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // What happened. ALWAYS here, faded rather than hidden, for the same
            // reason the power panel's confirm line is: a line that appeared
            // would move the field down at the exact moment you are about to
            // type into it again.
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Lock.message
                font.pixelSize: Appearance.font.size.small
                color: Lock.failed ? Appearance.colour.accent : Appearance.colour.textFaint
                opacity: Lock.message ? 1 : 0
            }
        }
    }
}
