import QtQuick

Canvas {
    id: cv

    property color dotColor: "#cccccc"
    property real spacing: 20
    property real maxRadius: 3.4
    property string corner: "tr"
    property real reach: 1.0

    onDotColorChanged: requestPaint()
    onSpacingChanged: requestPaint()
    onMaxRadiusChanged: requestPaint()
    onCornerChanged: requestPaint()
    onReachChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (width < 2 || height < 2)
            return
        ctx.fillStyle = cv.dotColor

        const cx = corner.indexOf("r") >= 0 ? width : 0
        const cy = corner.indexOf("b") >= 0 ? height : 0
        const diag = Math.sqrt(width * width + height * height) * reach

        let row = 0
        for (let y = spacing / 2; y < height; y += spacing * 0.866) {
            const off = (row % 2) * spacing / 2
            row++
            for (let x = spacing / 2 + off; x < width; x += spacing) {
                const t = 1 - Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / diag
                if (t <= 0)
                    continue
                const r = maxRadius * t
                if (r < 0.6)
                    continue
                ctx.beginPath()
                ctx.arc(x, y, r, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}
