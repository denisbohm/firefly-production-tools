//
//  Fixture.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Foundation

class Fixture {

    class TestPoint {
        var x: Board.PhysicalUnit = 0
        var y: Board.PhysicalUnit = 0
        var name: String = ""
        var diameter: Board.PhysicalUnit = 0
    }

    class Properties {
        var d: Board.PhysicalUnit
        var pcbThickness: Board.PhysicalUnit
        var maxComponentHeight: Board.PhysicalUnit
        var midStroke: Board.PhysicalUnit
        var exposed: Board.PhysicalUnit
        var shaft: Board.PhysicalUnit
        var pcbOutlineTolerance: Board.PhysicalUnit
        var wallThickness: Board.PhysicalUnit
        var ledgeThickness: Board.PhysicalUnit

        init() {
            // Mill-Max Spring Loaded Pin 0985-0-15-20-71-14-11-0
            // 1 mm diameter mounting hole
            // 4.1 mm shaft (fits into plastic hole)
            // 0.15 exposed at max stroke
            // 1.4 mm max stroke
            // 0.7 mm mid stroke
            // PCB thickness 0.4 mm
            // tallest component 1.4 mm - use 1.5 mm
            // distance from PCBA to top of plastic: 4.1 + 0.15 + 0.7 = 4.95 mm - use 4.9 mm
            // thickness of plastic to clear components: 4.9 - 1.5 = 3.4 mm
            d = 1.0
            pcbThickness = 0.4
            maxComponentHeight = 1.4
            midStroke = 0.7
            exposed = 0.15
            shaft = 4.1
            pcbOutlineTolerance = 0.2
            wallThickness = 2.0
            ledgeThickness = 1.0
        }
    }

    var scriptPath: String
    var boardPath: String
    var boardName: String
    var board: Board

    init(scriptPath: String, boardPath: String, boardName: String, board: Board) {
        self.scriptPath = scriptPath
        self.boardPath = boardPath
        self.boardName = boardName
        self.board = board
    }

    func join(path: NSBezierPath) -> NSBezierPath {
        let epsilon: CGFloat = 0.001;
        
        var last = NSPoint(x: 0.123456, y: 0.123456)
        let newPath = NSBezierPath()
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    let p0 = points[0]
                    if (fabs(last.x - p0.x) > epsilon) || (fabs(last.y - p0.y) > epsilon) {
                        newPath.move(to: p0)
                        last = points[0]
                        // NSLog(@"keeping move to %0.3f, %0.3f", points[0].x, points[0].y);
                    } else {
                        // NSLog(@"discarding move to %0.3f, %0.3f", points[0].x, points[0].y);
                    }
                case .lineToBezierPathElement:
                    newPath.line(to: points[0])
                    last = points[0]
                case .curveToBezierPathElement:
                    newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
                    last = points[2]
                case .closePathBezierPathElement:
                    newPath.close()
            }
        }
        return newPath;
    }

    func simplify(path: NSBezierPath, distance: CGFloat) -> NSBezierPath {
        var c = NSPoint(x: 0.123456, y: 0.123456);
        let newPath = NSBezierPath()
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    let p = points[0]
                    newPath.move(to: p)
                    c = p
                case .lineToBezierPathElement:
                    let p = points[0]
                    let dx = c.x - p.x
                    let dy = c.y - p.y
                    let d = sqrt(dx * dx + dy * dy)
                    if d > distance {
                        newPath.line(to: p)
                        c = p
                    }
                case .curveToBezierPathElement:
                    newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
                    c = points[2]
                case .closePathBezierPathElement:
                    newPath.close()
            }
        }
        return newPath
    }

    func Det2(_ x1: CGFloat, _ x2: CGFloat, _ y1: CGFloat, _ y2: CGFloat) -> CGFloat {
        return x1 * y2 - y1 * x2
    }

    func LineIntersection(v1: NSPoint, v2: NSPoint, v3: NSPoint, v4: NSPoint, r: inout NSPoint) -> Bool {
        let epsilon = CGFloat(0.001)
        let tolerance = CGFloat(0.000001)
        
        let a = Det2(v1.x - v2.x, v1.y - v2.y, v3.x - v4.x, v3.y - v4.y)
        if fabs(a) < epsilon {
            return false // Lines are parallel
        }
        
        let d1 = Det2(v1.x, v1.y, v2.x, v2.y)
        let d2 = Det2(v3.x, v3.y, v4.x, v4.y)
        let x = Det2(d1, v1.x - v2.x, d2, v3.x - v4.x) / a
        let y = Det2(d1, v1.y - v2.y, d2, v3.y - v4.y) / a
        
        if (x < min(v1.x, v2.x) - tolerance || x > max(v1.x, v2.x) + tolerance) {
            return false
        }
        if (y < min(v1.y, v2.y) - tolerance || y > max(v1.y, v2.y) + tolerance) {
            return false
        }
        if (x < min(v3.x, v4.x) - tolerance || x > max(v3.x, v4.x) + tolerance) {
            return false
        }
        if (y < min(v3.y, v4.y) - tolerance || y > max(v3.y, v4.y) + tolerance) {
            return false
        }
        
        r = NSPoint(x: x, y: y);
        return true
    }

    func outline(path: NSBezierPath, of bounds: NSBezierPath, inside: Bool) -> NSBezierPath {
        let newPath = NSBezierPath()
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    let p = points[0]
                    if bounds.contains(p) == inside {
                        newPath.move(to: p)
                        // NSLog(@"keeping move to %0.3f, %0.3f", p.x, p.y);
                    } else {
                        // NSLog(@"discarding move to %0.3f, %0.3f", p.x, p.y);
                    }
                case .lineToBezierPathElement:
                    let p = points[0]
                    if bounds.contains(p) == inside {
                        newPath.line(to: points[0])
                        // NSLog(@"keeping line to %0.3f, %0.3f", p.x, p.y);
                    } else {
                        // NSLog(@"discarding line to %0.3f, %0.3f", p.x, p.y);
                    }
                case .curveToBezierPathElement:
                    let p = points[2]
                    if bounds.contains(p) == inside {
                        newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2:points[1])
                        // NSLog(@"keeping curve to %0.3f, %0.3f", p.x, p.y);
                    } else {
                        // NSLog(@"discarding curve to %0.3f, %0.3f", p.x, p.y);
                    }
                case .closePathBezierPathElement:
                    newPath.close()
            }
        }
        return newPath
    }

    let EPSILON = CGFloat(0.000001)

    struct LineSegment {
        var first: NSPoint
        var second: NSPoint
    }

    func crossProduct(_ a: NSPoint, _ b: NSPoint) -> CGFloat {
        return a.x * b.y - b.x * a.y
    }

    func isPointOnLine(_ a: LineSegment, _ b: NSPoint) -> Bool {
        let aTmp = LineSegment(first: NSPoint(x: 0, y: 0), second: NSPoint(x: a.second.x - a.first.x, y: a.second.y - a.first.y))
        let bTmp = NSPoint(x: b.x - a.first.x, y: b.y - a.first.y)
        let r = crossProduct(aTmp.second, bTmp)
        return fabs(r) < EPSILON
    }

    func isPointRightOfLine(_ a: LineSegment, _ b: NSPoint) -> Bool {
        let aTmp = LineSegment(first: NSPoint(x: 0, y: 0), second: NSPoint(x: a.second.x - a.first.x, y: a.second.y - a.first.y))
        let bTmp = NSPoint(x: b.x - a.first.x, y: b.y - a.first.y)
        return crossProduct(aTmp.second, bTmp) < 0
    }

    func lineSegmentTouchesOrCrossesLine(_ a: LineSegment, _ b: LineSegment) -> Bool {
        return isPointOnLine(a, b.first) || isPointOnLine(a, b.second) || (isPointRightOfLine(a, b.first) != isPointRightOfLine(a, b.second))
    }

    func doLinesIntersect(_ a: LineSegment, _ b: LineSegment) -> Bool {
        return lineSegmentTouchesOrCrossesLine(a, b) && lineSegmentTouchesOrCrossesLine(b, a)
    }

    func bezierPathForWires(wires: [Board.Wire]) -> NSBezierPath {
        let epsilon = CGFloat(0.001)

        var remaining = wires
        let path = NSBezierPath()
        let current = remaining.removeFirst()
        // NSLog(@"+ %0.3f, %0.3f - %0.3f, %0.3f", current.x1, current.y1, current.x2, current.y2);
        path.append(current.bezierPath())
        var cx = current.x2
        var cy = current.y2
        while remaining.count > 0 {
            var found = false
            for index in (0 ..< remaining.count).reversed() {
                let candidate = remaining[index]
                if ((fabs(candidate.x1 - cx) < epsilon) && (fabs(candidate.y1 - cy) < epsilon)) {
                    // NSLog(@"> %0.3f, %0.3f - %0.3f, %0.3f", candidate.x1, candidate.y1, candidate.x2, candidate.y2);
                    remaining.remove(at: index)
                    path.append(candidate.bezierPath())
                    cx = candidate.x2
                    cy = candidate.y2
                    found = true
                    break
                }
                if ((fabs(candidate.x2 - cx) < epsilon) && (fabs(candidate.y2 - cy) < epsilon)) {
                    // NSLog(@"< %0.3f, %0.3f - %0.3f, %0.3f", candidate.x1, candidate.y1, candidate.x2, candidate.y2);
                    remaining.remove(at: index)
                    path.append(candidate.bezierPath().reversed)
                    cx = candidate.x1
                    cy = candidate.y1
                    found = true
                    break
                }
            }
            if (!found) {
                break;
            }
        }
        return join(path: path)
    }

    func wiresForLayer(layer: Board.Layer) -> [Board.Wire] {
        var wires: [Board.Wire] = []
        for element in board.container.wires {
            if element.layer == layer {
                wires.append(element)
                // NSLog(@"Dimension %0.3f, %0.3f - %0.3f, %0.3f", element.x1, element.y1, element.x2, element.y2);
            }
        }
        return wires
    }


    func testPoints(mirrored: Bool) -> [TestPoint] {
        var signalFromElementPad: [String: String] = [:]
        for contactRef in board.container.contactRefs {
            let key = "\(contactRef.element).\(contactRef.pad)"
            signalFromElementPad[key] = contactRef.signal
        }
        
        var points: [TestPoint] = []
        
        var transform = AffineTransform()
        
        for instance in board.container.instances {
            guard let package = board.packages[instance.package] else {
                continue
            }
            
            if (package.name == "TARGET-PIN-1MM") || (package.name == "TP08R") || (package.name == "TC2030-MCP-NL") {
                // NSLog(@"%@ %0.3f, %0.3f", package.name, instance.x, instance.y);
                
                if instance.mirror != mirrored {
                    continue
                }
                
                var xform = AffineTransform()
                xform.translate(x: instance.x, y: instance.y)
                if instance.mirror {
                    xform.scale(x: -1, y: 1)
                }
                xform.rotate(byDegrees: instance.rotate)
                transform.prepend(xform)
                
                for smd in package.container.smds {
                    var xform = AffineTransform()
                    xform.translate(x: smd.x, y: smd.y)
                    if smd.mirror {
                        xform.scale(x: -1, y: 1)
                    }
                    xform.rotate(byDegrees: smd.rotate)
                    transform.prepend(xform)
      
                    let p = transform.transform(NSPoint(x: 0, y: 0))
                    let testPoint = TestPoint()
                    testPoint.x = p.x
                    testPoint.y = p.y
                    let key = "\(instance.name).\(smd.name)"
                    if let signal = signalFromElementPad[key] {
                        testPoint.name = signal
                    } else {
                        testPoint.name = instance.name
                    }
                    points.append(testPoint)
                    if let pogoDiameterString = instance.attributes["POGO_DIAMETER"] {
                        if let pogoDiameter = Float(pogoDiameterString) {
                            testPoint.diameter = Board.PhysicalUnit(pogoDiameter)
                        }
                    }
                    
                    xform.invert()
                    transform.prepend(xform)

                    // NSLog(@"  %@ %0.3f, %0.3f %0.3f, %0.3f", smd.name, smd.x, smd.y, p.x, p.y);
                }
                
                xform.invert()
                transform.prepend(xform)
            }
        }

        return points
    }

    func rhino3D(path: NSBezierPath, z: Board.PhysicalUnit, name: String) -> String {
        var lines = "curves = []\n"
        var c: NSPoint = NSPoint(x: 0, y: 0)
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    c = points[0]
                case .lineToBezierPathElement:
                    let p = points[0]
                    if c != p {
                        lines += NSString(format: "curves.append(rs.AddLine((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f)))\n", c.x, c.y, z, p.x, p.y, z) as String
                    }
                    c = p
                case .curveToBezierPathElement:
                    let p0 = c // starting point
                    let p1 = points[0] // first control point
                    let p2 = points[1] // second control point
                    let p3 = points[2] // ending point
                    
                    lines += "cvs = []\n"
                    lines += NSString(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p0.x, p0.y, z) as String
                    lines += NSString(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p1.x, p1.y, z) as String
                    lines += NSString(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p2.x, p2.y, z) as String
                    lines += NSString(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p3.x, p3.y, z) as String
                    
                    lines += "knots = []\n"
                    for _ in 0 ..< 3 {
                        lines += "knots.append(0.0)\n"
                    }
                    for _ in 0 ..< 3 {
                        lines += "knots.append(1.0)\n"
                    }
                    
                    lines += "curve = rs.AddNurbsCurve(cvs, knots, 3)\n"
                    lines += "curves.append(curve)\n"
                    
                    c = p3
                case .closePathBezierPathElement:
                    break
            }
        }
        lines += "\(name) = rs.JoinCurves(curves, True)\n"
        return lines
    }

    func eagle(bezierPath: NSBezierPath) -> String {
        let tx = CGFloat(0.0)
        let ty = CGFloat(0.0)
        let flatness = NSBezierPath.defaultFlatness()
        NSBezierPath.setDefaultFlatness(0.01)
        let path = bezierPath.flattened
        NSBezierPath.setDefaultFlatness(flatness)
        var lines = ""
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    let p = points[0]
                    lines += NSString(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty) as String
                case .lineToBezierPathElement:
                    let p = points[0]
                    lines += NSString(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty) as String
                case .curveToBezierPathElement:
                    let p = points[2]
                    lines += NSString(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty) as String
                case .closePathBezierPathElement:
                    break
            }
        }
        return lines;
    }

    func derivedFileName(postfix: String, bottom: Bool) -> String {
        let base = (boardName as NSString).deletingPathExtension
        return NSString(format: "%@/%@_%@_%@", boardPath, base, bottom ? "bottom" : "top", postfix) as String
    }

    func generateTestFixturePlastic(properties: Properties, bottom: Bool, testPoints: [TestPoint], display: inout NSBezierPath) throws {
        let wires = wiresForLayer(layer: 20) // 20: "Dimension" (AKA Outline) layer
        let path = bezierPathForWires(wires: wires)
        
        let clipper = FDClipper()
        let outline = clipper.path(path, offset: properties.pcbOutlineTolerance)
        let bounds = clipper.path(path, offset: properties.wallThickness + properties.pcbOutlineTolerance)
        let ledge = clipper.path(path, offset: -(properties.ledgeThickness - properties.pcbOutlineTolerance))
        
        let r = properties.d / 2.0
        
        var ceiling = properties.pcbThickness + properties.maxComponentHeight
        var top = properties.pcbThickness + properties.midStroke + properties.exposed + properties.shaft
        var pcb = properties.pcbThickness
        if bottom {
            ceiling = -ceiling
            top = -top
            pcb = -pcb
        }
        
        var lines = ""
        lines += "import Rhino\n"
        lines += "import scriptcontext\n"
        lines += "import rhinoscriptsyntax as rs\n"
        
        // Rhino 3D test fixture outline
        lines += rhino3D(path: bounds, z: 0.0, name: "bounds")
        lines += rhino3D(path: bounds, z: top, name: "bounds2")
        lines += rhino3D(path: outline, z: 0.0, name: "outline")
        lines += rhino3D(path: outline, z: pcb, name: "outline2")
        lines += rhino3D(path: ledge, z: pcb, name: "ledge")
        lines += rhino3D(path: ledge, z: ceiling, name: "ledge2")
        
        lines += "rs.AddPlanarSrf([bounds, outline])\n"
        lines += NSString(format: "boundsWall = rs.ExtrudeCurveStraight(bounds, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", 0.0, 0.0, 0.0, 0.0, 0.0, top) as String
        lines += NSString(format: "outlineWall = rs.ExtrudeCurveStraight(outline, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", 0.0, 0.0, 0.0, 0.0, 0.0, pcb) as String
        lines += "rs.AddPlanarSrf([outline2, ledge])\n"
        lines += NSString(format: "ledgeWall = rs.ExtrudeCurveStraight(ledge, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", 0.0, 0.0, pcb, 0.0, 0.0, ceiling) as String
        lines += "out0 = rs.AddPlanarSrf([ledge2])\n"
        lines += "out1 = rs.AddPlanarSrf([bounds2])\n"
        
        // Rhino 3D test point curves
        lines += "probes = []\n"
        for testPoint in testPoints {
            let x = testPoint.x
            let y = testPoint.y
            let z = ceiling
            var tpr = r
            if testPoint.diameter != 0.0 {
                tpr = testPoint.diameter / 2.0
            }
            lines += NSString(format: "curve = rs.AddCircle3Pt((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", x - tpr, y, z, x + tpr, y, z, x, y + tpr, z) as String
            lines += NSString(format: "probe = rs.ExtrudeCurveStraight(curve, (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", x, y, z, x, y, top) as String
            lines += "probes.append(probe)\n"
            
            lines += "result = rs.SplitBrep(out0, probe, False)\n"
            lines += "rs.DeleteObject(out0)\n"
            lines += "rs.DeleteObject(result[1])\n"
            lines += "out0 = result[0]\n"
            
            lines += "result = rs.SplitBrep(out1, probe, False)\n"
            lines += "rs.DeleteObject(out1)\n"
            lines += "rs.DeleteObject(result[1])\n"
            lines += "out1 = result[0]\n"
        }
        
        NSLog(NSString(format: "test fixture %@ plastic:\n%@", bottom ? "bottom" : "top", lines) as String)
        let fileName = derivedFileName(postfix: "plate.py", bottom: bottom)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)

        // fixture display outline
        display.append(outline)
        display.append(bounds)
        display.append(ledge)
        
        // fixture test point display
        for testPoint in testPoints {
            display.appendOval(in: NSRect(x: testPoint.x - r, y: testPoint.y - r, width: properties.d, height: properties.d))
        }
    }

    func generateTestFixtureSchematic(properties: Properties, bottom: Bool, testPoints: [TestPoint]) throws {
        var lines = ""
        var countByName: [String: Int] = [:]
        let x = 2.0
        var y = 8.0
        for testPoint in testPoints {
            var name = testPoint.name
            let count = countByName[name] ?? 0
            countByName[name] = count + 1
            if count > 0 {
                name = NSString(format: "%@%ld", name, count + 1) as String
                countByName[name] = 1
            }
            testPoint.name = name
            lines += NSString(format: "add TARGET-PINPROBE-0985@firefly '%@' (%f %f);\n", name, x, y) as String
            y -= 0.4
        }
        
        NSLog(NSString(format: "test fixture top schematic:\n%@", lines) as String)
        let fileName = derivedFileName(postfix: "plate_schematic.scr", bottom: bottom)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)
    }

    func generateTestFixtureLayout(properties: Properties, bottom: Bool, testPoints: [TestPoint]) throws {
        var lines = ""
        for testPoint in testPoints {
            lines += String(format: "move '%@' (%f %f);\n", testPoint.name, testPoint.x, testPoint.y)
        }
        lines += "LAYER bDocu;\n"
        lines += "SET WIRE_BEND 2;"
        lines += "WIRE 0.1"
        let outline = bezierPathForWires(wires: wiresForLayer(layer: 20)) // 20: "Dimension" layer
        lines += eagle(bezierPath: outline)
        lines += ";\n"
        
        NSLog(NSString(format: "test fixture top layout:\n%@", lines) as String)
        let fileName = derivedFileName(postfix: "plate_layout.scr", bottom: bottom)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)
    }

    func generateTestFixture() throws -> NSBezierPath {
        // fixture display path
        var all = NSBezierPath()
        
        let properties = Properties()

        let topTestPoints = testPoints(mirrored: false)
        try generateTestFixturePlastic(properties: properties, bottom: false, testPoints: topTestPoints, display: &all)
        try generateTestFixtureSchematic(properties: properties, bottom: false, testPoints: topTestPoints)
        try generateTestFixtureLayout(properties: properties, bottom: false, testPoints: topTestPoints)

        let bottomTestPoints = testPoints(mirrored: true)
        try generateTestFixturePlastic(properties: properties, bottom: true, testPoints: bottomTestPoints, display: &all)
        try generateTestFixtureSchematic(properties: properties, bottom: true, testPoints: bottomTestPoints)
        try generateTestFixtureLayout(properties: properties, bottom: true, testPoints: bottomTestPoints)
        
        return all
    }

}
