//
//  Fixture.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Foundation

class Fixture {

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


    class TestPoint {
        var x: Board.PhysicalUnit = 0
        var y: Board.PhysicalUnit = 0
        var name: String = ""
        var diameter: Board.PhysicalUnit = 0
    }

    func probeTestPoints(mirrored: Bool, defaultDiameter: Board.PhysicalUnit) -> [TestPoint] {
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
                    testPoint.diameter = defaultDiameter
                    if let pogoDiameterString = instance.attributes["POGO_DIAMETER"] {
                        if let pogoDiameter = Float(pogoDiameterString) {
                            testPoint.diameter = Board.PhysicalUnit(pogoDiameter)
                        }
                    }
                    points.append(testPoint)

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
    
    func ledTestPoints(mirrored: Bool, defaultDiameter: Board.PhysicalUnit) -> [TestPoint] {
        var points: [TestPoint] = []

        var transform = AffineTransform()

        for instance in board.container.instances {
            guard let package = board.packages[instance.package] else {
                continue
            }

            if (package.name == "SML-LX0404SIUPGUSB") {
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


                let p = transform.transform(NSPoint(x: 0, y: 0))
                let testPoint = TestPoint()
                testPoint.x = p.x
                testPoint.y = p.y
                testPoint.name = instance.name
                testPoint.diameter = defaultDiameter
                if let pipeDiameterString = instance.attributes["PIPE_DIAMETER"] {
                    if let pipeDiameter = Float(pipeDiameterString) {
                        testPoint.diameter = Board.PhysicalUnit(pipeDiameter)
                    }
                }
                points.append(testPoint)

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
                        lines += String(format: "curves.append(rs.AddLine((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f)))\n", c.x, c.y, z, p.x, p.y, z)
                    }
                    c = p
                case .curveToBezierPathElement:
                    let p0 = c // starting point
                    let p1 = points[0] // first control point
                    let p2 = points[1] // second control point
                    let p3 = points[2] // ending point
                    
                    lines += "cvs = []\n"
                    lines += String(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p0.x, p0.y, z)
                    lines += String(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p1.x, p1.y, z)
                    lines += String(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p2.x, p2.y, z)
                    lines += String(format: "cvs.append(Rhino.Geometry.Point3d(%0.3f, %0.3f, %0.3f))\n", p3.x, p3.y, z)
                    
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
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                case .lineToBezierPathElement:
                    let p = points[0]
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                case .curveToBezierPathElement:
                    let p = points[2]
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                case .closePathBezierPathElement:
                    break
            }
        }
        return lines;
    }

    func derivedFileName(postfix: String, bottom: Bool) -> String {
        let base = (boardName as NSString).deletingPathExtension
        return String(format: "%@/%@_%@_%@", boardPath, base, bottom ? "bottom" : "top", postfix)
    }

    func extrude(curve: String, asSurface surface: String, from: (x: Board.PhysicalUnit, y: Board.PhysicalUnit, z: Board.PhysicalUnit), to: (x: Board.PhysicalUnit, y: Board.PhysicalUnit, z: Board.PhysicalUnit)) -> String {
        return String(format: "\(surface) = rs.ExtrudeCurveStraight(\(curve), (%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f))\n", from.x, from.y, from.z, to.x, to.y, to.z)
    }

    func extrude(curve: String, asSurface surface: String, fromZ: Board.PhysicalUnit, toZ: Board.PhysicalUnit) -> String {
        return extrude(curve: curve, asSurface: surface, from: (x: 0.0, y: 0.0, z: fromZ), to: (x: 0.0, y: 0.0, z: toZ))
    }

    func point(x: Board.PhysicalUnit, y: Board.PhysicalUnit, z: Board.PhysicalUnit) -> String {
        return String(format: "(%0.3f, %0.3f, %0.3f)", x, y, z)
    }

    func circle(asCurve curve: String, cx: Board.PhysicalUnit, cy: Board.PhysicalUnit, r: Board.PhysicalUnit, z: Board.PhysicalUnit) -> String {
        let p1 = point(x: cx - r, y: cy, z: z)
        let p2 = point(x: cx + r, y: cy, z: z)
        let p3 = point(x: cx, y: cy + r, z: z)
        return "\(curve) = rs.AddCircle3Pt(\(p1), \(p2), \(p3))\n"
    }

    func cut(surface: String, fromSurface: String) -> String {
        var lines = ""
        lines += "result = rs.SplitBrep(\(fromSurface), \(surface), False)\n"
        lines += "rs.DeleteObject(\(fromSurface))\n"
        lines += "rs.DeleteObject(result[1])\n"
        lines += "\(fromSurface) = result[0]\n"
        return lines
    }

    func rhinoHeader() -> String {
        var lines = ""
        lines += "import Rhino\n"
        lines += "import scriptcontext\n"
        lines += "import rhinoscriptsyntax as rs\n"
        return lines
    }

    func cutProbeHoles(testPoints: [TestPoint], surface0: String, z0: Board.PhysicalUnit, surface1: String, z1: Board.PhysicalUnit, display: inout NSBezierPath) -> String {
        var lines = "probes = []\n"
        for testPoint in testPoints {
            let x = testPoint.x
            let y = testPoint.y
            let r = testPoint.diameter / 2.0
            lines += circle(asCurve: "curve", cx: x, cy: y, r: r, z: z0)
            lines += extrude(curve: "curve", asSurface: "probe", fromZ: z0, toZ: z1)
            lines += "probes.append(probe)\n"

            lines += cut(surface: "probe", fromSurface: "out0")
            lines += cut(surface: "probe", fromSurface: "out1")

            display.appendOval(in: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        return lines
    }

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
    class Properties {
        let pcbThickness: Board.PhysicalUnit = 0.4
        let pcbTopComponentClearance: Board.PhysicalUnit = 1.5
        let pcbBottomComponentClearance: Board.PhysicalUnit = 1.0 // no components - just leave a little space for solder blobs
        let probeSupportThickness: Board.PhysicalUnit = 4.7 - 0.64 // ideal thickness based on matching the probe outer sleeve length
        let probeHeight: Board.PhysicalUnit = 6.27 - 0.64
        let probeStroke: Board.PhysicalUnit = 0.7 // 0.0 to 1.4
        let ledgeOverage: Board.PhysicalUnit = 0.0
        let standardBottomPlateThickness: Board.PhysicalUnit = 4.0
        let standardTopPlateThickness: Board.PhysicalUnit = 4.0

        let defaultLedHoleRadius: Board.PhysicalUnit = 3.25 / 2.0
        let defaultProbeHoleRadius: Board.PhysicalUnit = 1.0 / 2.0
        let pcbOutlineTolerance: Board.PhysicalUnit = 0.25
        let wallThickness: Board.PhysicalUnit = 4.0
        let ledgeThickness: Board.PhysicalUnit = 2.0
    }

    func generateTestFixtureTopPlastic(properties: Properties, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint], display: inout NSBezierPath) throws {
        let bps: Board.PhysicalUnit = 0.0
        let bpi: Board.PhysicalUnit = bps + properties.pcbThickness + properties.probeStroke + properties.ledgeOverage

        let tps: Board.PhysicalUnit = bps + properties.pcbThickness
        let tpi: Board.PhysicalUnit = bpi
        let tpn: Board.PhysicalUnit = tps + properties.pcbTopComponentClearance
        let tpo: Board.PhysicalUnit = tpn + properties.probeSupportThickness

        var lines = rhinoHeader()
        
        // 20: "Dimension" (AKA Outline) layer
        let dimension = bezierPathForWires(wires: wiresForLayer(layer: 20))

        let clipper = FDClipper()
        let bounds = clipper.path(dimension, offset: properties.wallThickness + properties.pcbOutlineTolerance)
        let outline = clipper.path(bounds, offset: -properties.wallThickness)

        // bottom fixture main body
        lines += rhino3D(path: bounds, z: tpi, name: "bounds")
        lines += rhino3D(path: bounds, z: tpo, name: "bounds2")
        lines += rhino3D(path: outline, z: tpi, name: "outline")
        lines += rhino3D(path: outline, z: tpn, name: "outline2")
        //
        lines += "rs.AddPlanarSrf([bounds, outline])\n"
        lines += extrude(curve: "bounds", asSurface: "boundsWall", fromZ: tpi, toZ: tpo)
        lines += extrude(curve: "outline", asSurface: "outlineWall", fromZ: tpi, toZ: tpn)
        lines += "out0 = rs.AddPlanarSrf([outline2])\n"
        lines += "out1 = rs.AddPlanarSrf([bounds2])\n"
        
        // cut out test point openings
        lines += cutProbeHoles(testPoints: probeTestPoints, surface0: "out0", z0: tpn, surface1: "out1", z1: tpo, display: &display)
        lines += cutProbeHoles(testPoints: ledTestPoints, surface0: "out0", z0: tpn, surface1: "out1", z1: tpo, display: &display)

        NSLog(String(format: "test fixture %@ plastic:\n%@", "top", lines))
        let fileName = derivedFileName(postfix: "plate.py", bottom: false)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)

        // fixture display outline
        display.append(outline)
        display.append(bounds)
    }

    func generateTestFixtureBottomPlastic(properties: Properties, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint], display: inout NSBezierPath) throws {
        let bps: Board.PhysicalUnit = 0.0
        let bpi: Board.PhysicalUnit = bps + properties.pcbThickness + properties.probeStroke + properties.ledgeOverage
        let bpn: Board.PhysicalUnit = bps - properties.pcbBottomComponentClearance
        let bpo: Board.PhysicalUnit = bpn - properties.probeSupportThickness

        var lines = rhinoHeader()

        // 20: "Dimension" (AKA Outline) layer
        let dimension = bezierPathForWires(wires: wiresForLayer(layer: 20))

        let clipper = FDClipper()
        let bounds = clipper.path(dimension, offset: properties.wallThickness + properties.pcbOutlineTolerance)
        let outline = clipper.path(dimension, offset: properties.pcbOutlineTolerance)
        let ledge = clipper.path(dimension, offset: -(properties.ledgeThickness - properties.pcbOutlineTolerance))

        // bottom fixture main body
        lines += rhino3D(path: bounds, z: bpi, name: "bounds")
        lines += rhino3D(path: bounds, z: bpo, name: "bounds2")
        lines += rhino3D(path: outline, z: bpi, name: "outline")
        lines += rhino3D(path: outline, z: bps, name: "outline2")
        lines += rhino3D(path: ledge, z: bps, name: "ledge")
        lines += rhino3D(path: ledge, z: bpn, name: "ledge2")
        //
        lines += "rs.AddPlanarSrf([bounds, outline])\n"
        lines += extrude(curve: "bounds", asSurface: "boundsWall", fromZ: bpi, toZ: bpo)
        lines += extrude(curve: "outline", asSurface: "outlineWall", fromZ: bpi, toZ: bps)
        lines += "rs.AddPlanarSrf([outline2, ledge])\n"
        lines += extrude(curve: "ledge", asSurface: "ledgeWall", fromZ: bps, toZ: bpn)
        lines += "out0 = rs.AddPlanarSrf([ledge2])\n"
        lines += "out1 = rs.AddPlanarSrf([bounds2])\n"

        // cut out test point openings
        lines += cutProbeHoles(testPoints: probeTestPoints, surface0: "out0", z0: bpn, surface1: "out1", z1: bpo, display: &display)
        lines += cutProbeHoles(testPoints: ledTestPoints, surface0: "out0", z0: bpn, surface1: "out1", z1: bpo, display: &display)

        NSLog(String(format: "test fixture %@ plastic:\n%@", "bottom", lines))
        let fileName = derivedFileName(postfix: "plate.py", bottom: true)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)

        // fixture display outline
        display.append(outline)
        display.append(bounds)
        display.append(ledge)
    }

    func generateTestFixtureSchematic(properties: Properties, bottom: Bool, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint]) throws {
        var lines = ""
        var countByName: [String: Int] = [:]
        let x = 2.0
        var y = 8.0
        for testPoint in probeTestPoints {
            var name = testPoint.name
            let count = countByName[name] ?? 0
            countByName[name] = count + 1
            if count > 0 {
                name = String(format: "%@%ld", name, count + 1)
                countByName[name] = 1
            }
            testPoint.name = name
            lines += String(format: "add TARGET-PINPROBE-0985@firefly '%@' (%f %f);\n", name, x, y)
            y -= 0.4
        }
        
        NSLog(String(format: "test fixture top schematic:\n%@", lines))
        let fileName = derivedFileName(postfix: "plate_schematic.scr", bottom: bottom)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)
    }

    func generateTestFixtureLayout(properties: Properties, bottom: Bool, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint]) throws {
        var lines = ""
        lines += "LAYER bDocu;\n"
        lines += "SET WIRE_BEND 2;"
        lines += "WIRE 0.1"
        let outline = bezierPathForWires(wires: wiresForLayer(layer: 20)) // 20: "Dimension" layer
        lines += eagle(bezierPath: outline)
        lines += ";\n"

        for testPoint in probeTestPoints {
            lines += String(format: "move '%@' (%f %f);\n", testPoint.name, testPoint.x, testPoint.y)
        }

        for testPoint in ledTestPoints {
            lines += String(format: "hole %0.3f (%f %f);\n", testPoint.diameter, testPoint.x, testPoint.y)
        }

        NSLog(String(format: "test fixture top layout:\n%@", lines))
        let fileName = derivedFileName(postfix: "plate_layout.scr", bottom: bottom)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)
    }

    func generateTestFixture() throws -> NSBezierPath {
        // fixture display path
        var all = NSBezierPath()
        
        let properties = Properties()

        let topProbeTestPoints = probeTestPoints(mirrored: false, defaultDiameter: properties.defaultProbeHoleRadius)
        let topLedTestPoints = ledTestPoints(mirrored: false, defaultDiameter: properties.defaultLedHoleRadius)
        try generateTestFixtureTopPlastic(properties: properties, probeTestPoints: topProbeTestPoints, ledTestPoints: topLedTestPoints, display: &all)
        try generateTestFixtureSchematic(properties: properties, bottom: false, probeTestPoints: topProbeTestPoints, ledTestPoints: topLedTestPoints)
        try generateTestFixtureLayout(properties: properties, bottom: false, probeTestPoints: topProbeTestPoints, ledTestPoints: topLedTestPoints)

        let bottomProbeTestPoints = probeTestPoints(mirrored: true, defaultDiameter: properties.defaultProbeHoleRadius)
        let bottomLedTestPoints = ledTestPoints(mirrored: true, defaultDiameter: properties.defaultLedHoleRadius)
        try generateTestFixtureBottomPlastic(properties: properties, probeTestPoints: bottomProbeTestPoints, ledTestPoints: bottomLedTestPoints, display: &all)
        try generateTestFixtureSchematic(properties: properties, bottom: true, probeTestPoints: bottomProbeTestPoints, ledTestPoints: bottomLedTestPoints)
        try generateTestFixtureLayout(properties: properties, bottom: true, probeTestPoints: bottomProbeTestPoints, ledTestPoints: bottomLedTestPoints)
        
        return all
    }

}
