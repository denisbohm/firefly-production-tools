//
//  Rhino.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Foundation

class Rhino {

    var board: Board = Board()
    var lines: String = ""

    var transformStack: [AffineTransform] = []
    var transform: AffineTransform = AffineTransform()
    var mirror: Bool = false

    func addCurve(lines: inout String, x1: Board.PhysicalUnit, y1: Board.PhysicalUnit, x2: Board.PhysicalUnit, y2: Board.PhysicalUnit, curve: Board.PhysicalUnit, transform: AffineTransform) {
        let c = Board.Utilities.getCenterOfCircle(x1: x1, y1: y1, x2: x2, y2: y2, angle: curve)
        let radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y))
        let startAngle = atan2(y1 - c.y, x1 - c.x) * 180.0 / Board.PhysicalUnit.pi
        let radians = (startAngle + curve / 2.0) * Board.PhysicalUnit.pi / 180.0
        let xm = c.x + radius * cos(radians)
        let ym = c.y + radius * sin(radians)
        let p1 = transform.transform(NSPoint(x: x1, y: y1))
        let p2 = transform.transform(NSPoint(x: x2, y: y2))
        let pm = transform.transform(NSPoint(x: xm, y: ym))
        lines += ", (\(p1.x), \(p1.y), 0, \(p2.x), \(p2.y), 0, \(pm.x), \(pm.y), 0)"
    }

    func convert(container: Board.Container) {
        for circle in container.circles {
            let p = transform.transform(NSPoint(x: circle.x, y: circle.y))
            let s = transform.transform(NSSize(width: circle.radius, height: circle.width))
            if circle.width == 0.0 {
                let r0 = abs(s.width)
                lines += "PlaceCircle(\(p.x), \(p.y), \(r0), \(circle.layer))\n"
            } else {
                let r0 = abs(s.width) - abs(s.height) / 2.0
                let r1 = abs(s.width) + abs(s.height) / 2.0
                lines += "PlaceRing(\(p.x), \(p.y), \(r0), \(r1), \(circle.layer))\n"
            }
        }
        
        for pad in container.pads {
            transformStack.append(transform)
            var xform = AffineTransform()
            xform.translate(x: pad.x, y: pad.y)
            if pad.mirror {
                xform.scale(x: -1, y: 1)
            }
            xform.rotate(byDegrees: pad.rotate)
            transform.prepend(xform)

            let p = transform.transform(NSPoint(x: 0, y: 0))
            var dx = pad.drill
            let dy = pad.drill
            if "long" == pad.shape {
                dx *= 2.0
            }
            let s = transform.transform(NSSize(width: dx, height: dy))
            lines += "PlacePad(\(p.x), \(p.y), \(abs(s.width)), \(abs(s.height)), 1.0, 1)\n"
            lines += "PlacePad(\(p.x), \(p.y), \(abs(s.width)), \(abs(s.height)), 1.0, 16)\n"
            
            transform = transformStack.removeLast()
        }
        
        for smd in container.smds {
            transformStack.append(transform)
            var xform = AffineTransform()
            xform.translate(x: smd.x, y: smd.y)
            xform.rotate(byDegrees: smd.rotate)
            if smd.mirror {
                xform.scale(x: -1, y: 1)
            }
            transform.prepend(xform)

            var layer = smd.layer
            if mirror {
                if layer == 1 {
                    layer = 16
                } else
                if layer == 16 {
                    layer = 1
                }
            }

            let p = transform.transform(NSPoint(x: 0, y: 0))
            let s = transform.transform(NSSize(width: smd.dx, height: smd.dy))
            lines += "PlaceSmd(\(p.x), \(p.y), \(abs(s.width)), \(abs(s.height)), \(smd.roundness / 100.0), \(layer))\n"

            transform = transformStack.removeLast()
        }

        for polygon in container.polygons {
            var first = true
            lines += "PlacePolygon(["
            for i in 0 ..< polygon.vertices.count {
                let vertex = polygon.vertices[i]
                let p = transform.transform(NSPoint(x: vertex.x, y: vertex.y))
                if vertex.curve != 0 {
                    let v2 = polygon.vertices[(i + 1) % polygon.vertices.count]
                    if first {
                        first = false
                        lines += "(\(p.x), \(p.y), 0)"
                    }
                    addCurve(lines: &lines, x1: vertex.x, y1: vertex.y, x2: v2.x, y2: v2.y, curve: vertex.curve, transform: transform)
                } else {
                    if first {
                        first = false
                        lines += "(\(p.x), \(p.y), 0)"
                    } else {
                        lines += ", (\(p.x), \(p.y), 0)"
                    }
                }
            }
            let vertex = polygon.vertices[0]
            let p = transform.transform(NSPoint(x: vertex.x, y: vertex.y))
            lines += ", (\(p.x), \(p.y), 0)"
            lines += "], \(polygon.layer))\n"
        }
    }

    func curves(wires: [Board.Wire], z: Board.PhysicalUnit) -> String {
        var lines = ""
        for wire in wires {
            let x1 = wire.x1
            let y1 = wire.y1
            let x2 = wire.x2
            let y2 = wire.y2
            //            let width = wire.width
            let curve = wire.curve
            if curve == 0 {
                lines += "curves.append(rs.AddLine((\(x1), \(y1), \(z)), (\(x2), \(y2), \(z))))\n"
            } else {
                let c = Board.Utilities.getCenterOfCircle(x1: x1, y1: y1, x2: x2, y2: y2, angle: curve)
                let radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y));
                let startAngle = atan2(y1 - c.y, x1 - c.x);
                let angle = startAngle + curve * Board.PhysicalUnit.pi / (180 * 2.0);
                let xc = c.x + cos(angle) * radius;
                let yc = c.y + sin(angle) * radius;
                lines += "curves.append(rs.AddArc3Pt((\(x1), \(y1), \(z)), (\(x2), \(y2), \(z)), (\(xc), \(yc), \(z))))\n"
            }
        }
        return lines
    }

    func convert() {
        let container = board.container
        transform = AffineTransform()
        
        lines += "boardThickness = \(board.thickness)\n\n"
        
        convert(container: container)
        
        for instance in container.instances {
            guard let package = board.packages[instance.package] else {
                continue
            }

            let mirrorString = instance.mirror ? "True" : "False"
            lines += "PlaceInstance(\"\(package.name)\", \(instance.x), \(instance.y), \(mirrorString), \(instance.rotate))\n"
            
            transformStack = []
            transform = AffineTransform()
            transform.translate(x: instance.x, y: instance.y)
            if instance.mirror {
                transform.scale(x: -1, y: 1)
            }
            transform.rotate(byDegrees: instance.rotate)
            
            mirror = instance.mirror
            convert(container: package.container)
            
            transform.invert()
            NSAffineTransform(transform: transform).concat()
        }
        
        lines += "curves = []\n"
        lines += curves(wires: board.wires(layer: 20 /* dimension */), z: 0)
        for hole in container.holes {
            let x = hole.x
            let y = hole.y
            let r = hole.drill / 2.0
            lines += "curves.append(rs.AddCircle3Pt((\(x - r), \(y), 0), (\(x + r), \(y), 0), (\(x), \(y + r), 0)))\n"
        }
        lines += "PlacePCB(curves)\n"
    }

}
