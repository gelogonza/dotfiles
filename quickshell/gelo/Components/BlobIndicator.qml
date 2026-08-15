// The blob. This is the signature micro-interaction of the whole system.
//
// A naive active-indicator animates x and width toward the target, which reads as
// a rectangle sliding. Instead this tracks the blob's two edges as INDEPENDENT
// animated values with different durations:
//
//   moving right ->  right edge is leading  (fast), left edge trails  (slow)
//   moving left  ->  left edge is leading   (fast), right edge trails (slow)
//
// The leading edge reaches the destination first, so the shape stretches across
// the gap, then the trailing edge catches up and it settles. Volume is conserved
// with a slight vertical squash while in motion, which is what sells it as liquid
// rather than as elastic.
//
// Parent supplies `targetX` / `targetWidth` in this item's coordinate space.

import QtQuick
import "root:/Theme"

Item {
    id: root

    property real targetX: 0
    property real targetWidth: 0
    property color color: Tokens.color.accent

    // True while either edge is still travelling.
    readonly property bool moving: leftAnim.running || rightAnim.running

    // Suppress the stretch for the very first placement — otherwise the blob
    // dramatically unfurls from x=0 on shell startup, which looks like a bug.
    property bool _primed: false

    property real edgeLeft: 0
    property real edgeRight: 0

    function _retarget() {
        const newLeft = targetX;
        const newRight = targetX + targetWidth;

        if (!_primed) {
            leftAnim.duration = 0;
            rightAnim.duration = 0;
            edgeLeft = newLeft;
            edgeRight = newRight;
            if (targetWidth > 0)
                _primed = true;
            return;
        }

        // Whichever edge is heading into open space leads.
        const movingRight = newRight > edgeRight;
        leftAnim.duration = movingRight ? Tokens.motion.duration.slow
                                        : Tokens.motion.duration.base;
        rightAnim.duration = movingRight ? Tokens.motion.duration.base
                                         : Tokens.motion.duration.slow;

        edgeLeft = newLeft;
        edgeRight = newRight;
    }

    onTargetXChanged: _retarget()
    onTargetWidthChanged: _retarget()
    Component.onCompleted: _retarget()

    Behavior on edgeLeft {
        NumberAnimation {
            id: leftAnim
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    Behavior on edgeRight {
        NumberAnimation {
            id: rightAnim
            duration: Tokens.motion.duration.base
            easing.type: Easing.Bezier
            easing.bezierCurve: Tokens.motion.easeBezier
        }
    }

    Rectangle {
        id: blob

        x: Math.min(root.edgeLeft, root.edgeRight)
        width: Math.abs(root.edgeRight - root.edgeLeft)
        height: parent.height
        color: root.color

        // Always a pill. A blob has no corners to relax — the stretch carries
        // the whole expression.
        radius: height / 2

        transform: Scale {
            origin.x: blob.width / 2
            origin.y: blob.height / 2
            yScale: root.moving ? Tokens.material.blob.squashY : 1.0

            Behavior on yScale {
                NumberAnimation {
                    duration: Tokens.motion.duration.fast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.motion.easeBezier
                }
            }
        }
    }
}
