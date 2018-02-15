//
//  BoardView.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Cocoa

class BoardView: NSView {

    var board: Board = Board() {
        didSet {
            needsDisplay = true
        }
    }
    var fixturePath: NSBezierPath = NSBezierPath() {
        didSet {
            needsDisplay = true
        }
    }
    var mirror: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    func setLayerColors(layer: Board.Layer) {
        var layer = layer
        if mirror {
            if layer == 1 {
                layer = 16
            } else
            if layer == 16 {
                layer = 1
            }
        }

        var color: NSColor
        switch layer {
            case 1: // Top
                color = NSColor.red
            case 2: // Ground
                color = NSColor.cyan
            case 15: // Power
                color = NSColor.magenta
            case 16: // Bottom
                color = NSColor.blue
            default:
                color = NSColor.black
        }
        color.setStroke()
        color.setFill()
    }

    func drawContainer(container: Board.Container) {
        for wire in container.wires {
            setLayerColors(layer: wire.layer)
            let path = wire.bezierPath()
            path.stroke()
        }
        
        for polygon in container.polygons {
            setLayerColors(layer: polygon.layer)
            let path = polygon.bezierPath()
            path.fill()
            path.stroke()
        }
        
        NSColor.black.setStroke()
        for hole in container.holes {
            let x = hole.x
            let y = hole.y
            let drill = hole.drill
            let x1 = x - drill / 2.0
            let y1 = y - drill / 2.0
            let path = NSBezierPath()
            path.appendOval(in: NSRect(x: x1, y: y1, width: drill, height: drill))
            path.lineWidth = 0.01
            path.stroke()
        }
        
        NSColor.green.setFill()
        for via in container.vias {
            let x = via.x
            let y = via.y
            let drill = via.drill
            let x1 = x - drill / 2.0
            let y1 = y - drill / 2.0
            let path = NSBezierPath()
            path.appendOval(in: NSRect(x: x1, y: y1, width: drill, height: drill))
            path.fill()
        }
        
        for circle in container.circles {
            let x = circle.x
            let y = circle.y
            let radius = circle.radius
            let width = circle.width
            setLayerColors(layer: circle.layer)
            if width == 0.0 {
                let x1 = x - radius;
                let y1 = y - radius;
                let path = NSBezierPath()
                path.appendOval(in: NSRect(x: x1, y: y1, width: radius * 2.0, height: radius * 2.0))
                path.fill()
            } else {
                let path = NSBezierPath()
                path.appendArc(withCenter: NSPoint(x: x, y: y), radius: radius, startAngle: 0.0, endAngle: 360.0)
                path.lineWidth = width
                path.stroke()
            }
        }
        
        for smd in container.smds {
            setLayerColors(layer: smd.layer)
            
            let dx = smd.dx
            let dy = smd.dy
            let x1 = -dx / 2.0
            let y1 = -dy / 2.0
            let radius = (smd.roundness / 100.0) * min(dx, dy) / 2.0
            
            let xform = NSAffineTransform()
            xform.translateX(by: smd.x, yBy: smd.y)
            if smd.mirror {
                xform.scaleX(by: -1.0, yBy: 1.0)
            }
            xform.rotate(byDegrees: smd.rotate)
            xform.concat()
            
            let path = NSBezierPath()
            path.appendRoundedRect(NSRect(x: x1, y: y1, width: dx, height: dy), xRadius: radius, yRadius: radius)
            path.fill()
            
            xform.invert()
            xform.concat()
        }
        
        NSColor.green.setFill()
        for pad in container.pads {
            let radius = pad.drill / 2.0
            var dx = pad.drill
            let dy = pad.drill
            if "long" == pad.shape {
                dx *= 2.0
            }
            
            let xform = NSAffineTransform()
            xform.translateX(by: pad.x, yBy: pad.y)
            if pad.mirror {
                xform.scaleX(by: -1, yBy: 1)
            }
            xform.rotate(byDegrees: pad.rotate)
            xform.concat()

            let path = NSBezierPath()
            path.appendRoundedRect(NSRect(x: -dx / 2.0, y: -dy / 2.0, width: dx, height: dy), xRadius: radius, yRadius: radius)
            path.fill()
            
            xform.invert()
            xform.concat()
        }
        
        NSColor.gray.setFill()
        for instance in container.instances {
            guard let package = board.packages[instance.package] else {
                continue
            }

            let xform = NSAffineTransform()
            xform.translateX(by: instance.x, yBy: instance.y)
            if instance.mirror {
                xform.scaleX(by: -1.0, yBy: 1.0)
            }
            xform.rotate(byDegrees: instance.rotate)
            xform.concat()
            
            mirror = instance.mirror
            drawContainer(container: package.container)

            xform.invert()
            xform.concat()
        }
        mirror = false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.setFill()
        dirtyRect.fill()
        
        let xform = NSAffineTransform()
        if !fixturePath.isEmpty {
            let bounds = fixturePath.bounds
            let margin: CGFloat = 10.0
            let scaleX = (frame.width - margin) / bounds.width
            let scaleY = (frame.height - margin) / bounds.height
            let scale = min(scaleX, scaleY)
            xform.scaleX(by: scale, yBy: scale)
            let dx = (frame.width / scale) - bounds.width
            let dy = (frame.height / scale) - bounds.height
            xform.translateX(by: (dx / 2.0) - bounds.minX, yBy: (dy / 2.0) - bounds.minY)
        }
        xform.concat()
        
        drawContainer(container: board.container)
        
        NSColor.blue.setStroke()
        fixturePath.lineWidth = 0.1
        fixturePath.stroke()
        
        xform.invert()
        xform.concat()
    }

}
