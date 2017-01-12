//
//  Board.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import AppKit

class Board {

    typealias PhysicalUnit = CGFloat
    typealias Layer = Int

    class Utilities {

        static func ccwdiff(_ a1: PhysicalUnit, _ a2: PhysicalUnit) -> PhysicalUnit {
            var a2 = a2
            if a2 < a1 {
                a2 += 2.0 * PhysicalUnit.pi
            }
            return a2 - a1
        }

        static func getCenterOfCircle(x1: PhysicalUnit, y1: PhysicalUnit, x2: PhysicalUnit, y2: PhysicalUnit, angle: PhysicalUnit) -> NSPoint {
            let xm = (x1 + x2) / 2.0
            let ym = (y1 + y2) / 2.0
            let a = sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)) / 2.0
            let theta = (angle * PhysicalUnit.pi / 180.0) / 2.0
            let b = a / tan(theta)
            if y1 == y2 {
                return NSPoint(x: xm, y: ym + b)
            }
            if x1 == x2 {
                return NSPoint(x: xm + b, y: ym)
            }
            let im = (x2 - x1) / (y2 - y1)
            let xc1 = -b / sqrt(im * im + 1) + xm
            let yc1 = im * (xm - xc1) + ym
            let xc2 = b / sqrt(im * im + 1) + xm
            let yc2 = im * (xm - xc2) + ym

            var ar = angle * PhysicalUnit.pi / 180.0
            if ar < 0 {
                ar += 2.0 * PhysicalUnit.pi
            }

            let a1 = atan2(y1 - yc1, x1 - xc1)
            let a2 = atan2(y2 - yc1, x2 - xc1)
            let a12 = Utilities.ccwdiff(a1, a2)
            let ad = a12 - ar

            let b1 = atan2(y1 - yc2, x1 - xc2)
            let b2 = atan2(y2 - yc2, x2 - xc2)
            let b12 = Utilities.ccwdiff(b1, b2)
            let bd = b12 - ar
            
            if fabs(ad) < fabs(bd) {
                return NSPoint(x: xc1, y: yc1)
            } else {
                return NSPoint(x: xc2, y: yc2)
            }
        }
        
        static func addCurve(path: NSBezierPath, x1: PhysicalUnit, y1: PhysicalUnit, x2: PhysicalUnit, y2: PhysicalUnit, curve: PhysicalUnit) {
            let c = Utilities.getCenterOfCircle(x1: x1, y1: y1, x2: x2, y2: y2, angle: curve)
            let radius = sqrt((x1 - c.x) * (x1 - c.x) + (y1 - c.y) * (y1 - c.y))
            let startAngle = atan2(y1 - c.y, x1 - c.x) * 180.0 / PhysicalUnit.pi
            let endAngle = startAngle + curve
            path.appendArc(withCenter: c, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: curve < 0)
        }
    
    }

    class Wire {

        var x1: PhysicalUnit = 0
        var y1: PhysicalUnit = 0
        var x2: PhysicalUnit = 0
        var y2: PhysicalUnit = 0
        var width: PhysicalUnit = 0
        var curve: PhysicalUnit = 0
        var layer: Layer = 0

        func bezierPath() -> NSBezierPath {
            let path = NSBezierPath()
            path.lineWidth = width
            path.lineCapStyle = .roundLineCapStyle
            path.move(to: NSPoint(x: x1, y: y1))
            if curve == 0 {
                path.line(to: NSPoint(x: x2, y: y2))
            } else {
                Board.Utilities.addCurve(path: path, x1: x1, y1: y1, x2: x2, y2: y2, curve: curve)
            }
            return path
        }

    }

    class Vertex {

        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var curve: PhysicalUnit = 0

    }

    class Polygon {

        var width: PhysicalUnit = 0
        var layer: Layer = 0
        var vertices: [Vertex] = []

        func bezierPath() -> NSBezierPath {
            let path = NSBezierPath()
            path.lineWidth = width
            path.lineCapStyle = .roundLineCapStyle
            var first = true
            for i in 0 ..< vertices.count {
                let vertex = vertices[i]
                if vertex.curve != 0 {
                    let x1 = vertex.x
                    let y1 = vertex.y
                    let v2 = vertices[(i + 1) % vertices.count]
                    let x2 = v2.x;
                    let y2 = v2.y;
                    if first {
                        first = false
                        path.move(to: NSPoint(x: x1, y: y1))
                    }
                    Board.Utilities.addCurve(path: path, x1: x1, y1: y1, x2: x2, y2: y2, curve: vertex.curve)
                } else {
                    if first {
                        first = false
                        path.move(to: NSPoint(x: vertex.x, y: vertex.y))
                    } else {
                        path.line(to: NSPoint(x: vertex.x, y: vertex.y))
                    }
                }
            }
            path.close()
            return path
        }

    }

    class Via {
        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var drill: PhysicalUnit = 0
    }

    class Circle {
        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var radius: PhysicalUnit = 0
        var width: PhysicalUnit = 0
        var layer: Layer = 0
    }

    class Hole {
        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var drill: PhysicalUnit = 0
    }

    class Smd {
        var name: String = ""
        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var dx: PhysicalUnit = 0
        var dy: PhysicalUnit = 0
        var roundness: PhysicalUnit = 0
        var mirror: Bool = false
        var rotate: PhysicalUnit = 0
        var layer: Layer = 0
    }

    class Pad {
        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var drill: PhysicalUnit = 0
        var mirror: Bool = false
        var rotate: PhysicalUnit = 0
        var shape: String = ""
    }

    class ContactRef {
        var signal: String = ""
        var element: String = ""
        var pad: String = ""
    }

    class Instance {
        var name: String = ""
        var x: PhysicalUnit = 0
        var y: PhysicalUnit = 0
        var mirror: Bool = false
        var rotate: PhysicalUnit = 0
        var library: String = ""
        var package: String = ""
        var attributes: [String: String] = [:]
    }

    class Container {
        var wires: [Wire] = []
        var polygons: [Polygon] = []
        var vias: [Via] = []
        var circles: [Circle] = []
        var holes: [Hole] = []
        var smds: [Smd] = []
        var pads: [Pad] = []
        var contactRefs: [ContactRef] = []
        var instances: [Instance] = []
    }

    class Package {
        var name: String = ""
        var container: Container = Container()
    }

    var packages: [String: Package] = [:]
    var container: Container = Container()
    var thickness: PhysicalUnit = 0.4

}
