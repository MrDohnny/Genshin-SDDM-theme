import QtQuick
import QtQuick.Controls

ToolButton {
    id: root
    width: 30
    height: 30
    padding: 5
    contentItem: Canvas {
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.enabled ? "#eaf7ff" : "#718096"
            ctx.fillStyle = root.enabled ? "#eaf7ff" : "#718096"
            ctx.lineWidth = 1.7
            ctx.strokeRect(1.5, 2.5, width - 3, height - 5)
            ctx.beginPath()
            ctx.arc(width * 0.72, height * 0.31, 2.1, 0, Math.PI * 2)
            ctx.fill()
            ctx.beginPath()
            ctx.moveTo(3.5, height - 4.5)
            ctx.lineTo(width * 0.42, height * 0.48)
            ctx.lineTo(width * 0.58, height * 0.66)
            ctx.lineTo(width * 0.72, height * 0.51)
            ctx.lineTo(width - 3.5, height - 4.5)
            ctx.closePath()
            ctx.stroke()
        }
    }
}
