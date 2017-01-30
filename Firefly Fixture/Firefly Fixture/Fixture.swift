//
//  Fixture.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Foundation

class Fixture {

    var board: Board
    var scriptPath: String

    init(board: Board, scriptPath: String) {
        self.board = board
        self.scriptPath = scriptPath
    }

    struct Point3D {

        let x: CGFloat
        let y: CGFloat
        let z: CGFloat

        init(x: CGFloat, y: CGFloat, z: CGFloat) {
            self.x = x
            self.y = y
            self.z = z
        }

        init(xy: NSPoint, z: CGFloat) {
            self.x = xy.x
            self.y = xy.y
            self.z = z
        }

    }

    class Path3D {

        var points: [Point3D] = []

    }

    static func lastPoint(path: NSBezierPath) -> NSPoint {
        var first: NSPoint? = nil
        var last = NSPoint(x: 0, y: 0)
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
            case .moveToBezierPathElement:
                last = points[0]
                first = last
            case .lineToBezierPathElement:
                last = points[0]
            case .curveToBezierPathElement:
                last = points[2]
            case .closePathBezierPathElement:
                if let first = first {
                    last = first
                }
            }
        }
        return last
    }

    static func firstPoint(path: NSBezierPath) -> NSPoint {
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
            case .moveToBezierPathElement:
                return points[0]
            default:
                break
            }
        }
        return NSPoint(x: 0, y: 0)
    }

    static func equal(point1: NSPoint, point2: NSPoint) -> Bool {
        return (point1.x == point2.x) && (point1.y == point2.y)
    }

    static func distance(point1: NSPoint, point2: NSPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }

    static func canCombine(path1: NSBezierPath, path2: NSBezierPath) -> Bool {
        let last1 = Fixture.lastPoint(path: path1)
        let first2 = Fixture.firstPoint(path: path2)
        return Fixture.equal(point1: last1, point2: first2)
    }

    static func combine(path1: NSBezierPath, path2: NSBezierPath) -> NSBezierPath {
        let newPath = NSBezierPath()
        for i in 0 ..< path1.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path1.element(at: i, associatedPoints: &points)
            switch (kind) {
            case .moveToBezierPathElement:
                newPath.move(to: points[0])
            case .lineToBezierPathElement:
                newPath.line(to: points[0])
            case .curveToBezierPathElement:
                newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
            case .closePathBezierPathElement:
                newPath.close()
            }
        }
        for i in 0 ..< path2.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path2.element(at: i, associatedPoints: &points)
            switch (kind) {
            case .moveToBezierPathElement:
                if i == 0 {
                    newPath.line(to: points[0])
                } else {
                    newPath.move(to: points[0])
                }
            case .lineToBezierPathElement:
                newPath.line(to: points[0])
            case .curveToBezierPathElement:
                newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
            case .closePathBezierPathElement:
                newPath.close()
            }
        }
        return newPath
    }

    static func combine(paths: [NSBezierPath]) -> [NSBezierPath] {
        let path1 = paths[0]
        let path2 = paths[paths.count - 1]
        if canCombine(path1: path1, path2: path2) {
            var newPaths: [NSBezierPath] = []
            let combined = combine(path1: path1, path2: path2)
            newPaths.append(combined)
            if paths.count > 2 {
                for i in 1 ... paths.count - 2 {
                    newPaths.append(paths[i])
                }
            }
            return newPaths
        } else
        if canCombine(path1: path2, path2: path1) {
            var newPaths: [NSBezierPath] = []
            let combined = combine(path1: path2, path2: path1)
            for i in 1 ... paths.count - 2 {
                newPaths.append(paths[i])
            }
            newPaths.append(combined)
            return newPaths
        } else {
            return paths
        }
    }

    static func sortByX(paths: [NSBezierPath]) -> [NSBezierPath] {
        return paths.sorted() {
            let p0 = firstPoint(path: $0)
            let p1 = firstPoint(path: $1)
            return p0.x < p1.x
        }
    }

    static func orderByY(paths: [NSBezierPath]) -> [NSBezierPath] {
        var sortedPaths: [NSBezierPath] = []
        for path in paths {
            let first = firstPoint(path: path)
            let last = lastPoint(path: path)
            var sortedPath = path
            if last.y < first.y {
                sortedPath = path.reversed
            }
            sortedPaths.append(sortedPath)
        }
        return sortedPaths
    }

    static func join(path: NSBezierPath) -> NSBezierPath {
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
        return newPath
    }

    static func intersection(p0_x: CGFloat, p0_y: CGFloat, p1_x: CGFloat, p1_y: CGFloat, p2_x: CGFloat, p2_y: CGFloat, p3_x: CGFloat, p3_y: CGFloat) -> NSPoint? {
        let s1_x = p1_x - p0_x
        let s1_y = p1_y - p0_y
        let s2_x = p3_x - p2_x
        let s2_y = p3_y - p2_y
        let s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y)) / (-s2_x * s1_y + s1_x * s2_y)
        let t = ( s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x)) / (-s2_x * s1_y + s1_x * s2_y)
        if (s >= 0) && (s <= 1) && (t >= 0) && (t <= 1) {
            let x = p0_x + (t * s1_x)
            let y = p0_y + (t * s1_y)
            return NSPoint(x: x, y: y)
        }
        return nil
    }

    static func intersection(p0: NSPoint, p1: NSPoint, x: CGFloat) -> NSPoint? {
        let big: CGFloat = 1e20
        return intersection(p0_x: p0.x, p0_y: p0.y, p1_x: p1.x, p1_y: p1.y, p2_x: x, p2_y: -big, p3_x: x, p3_y: big)
    }

    static func slice(p0: CGPoint, p1: CGPoint, x0: CGFloat, x1: CGFloat) -> NSBezierPath {
        let newPath = NSBezierPath()
        if (p1.x <= x0) || (p0.x >= x1) {
            // line is completely outside slice area
            newPath.move(to: p0)
            newPath.line(to: p1)
        } else
        if (x0 <= p0.x) && (p1.x <= x1) {
            // line is completely inside slice area
        } else {
            // only handle horizontal line splitting
            if (p0.x < x0) && (p1.x > x0) && (p1.x <= x1) {
                // line only crosses x0
                // split line at x0. keep left segment
                if let p = intersection(p0: p0, p1: p1, x: x0) {
                    newPath.move(to: p0)
                    newPath.line(to: p)
                } else {
                    NSLog("should not happen")
                }
            } else
            if (p0.x < x0) && (p1.x > x1) {
                // line crosses both x0 and x1
                // split line at x0 and x1.  keep left and right segments
                if
                    let pa = intersection(p0: p0, p1: p1, x: x0),
                    let pb = intersection(p0: p0, p1: p1, x: x1)
                {
                    newPath.move(to: p0)
                    newPath.line(to: pa)
                    newPath.move(to: pb)
                    newPath.line(to: p1)
                } else {
                    NSLog("should not happen")
                }
            } else
            if (x0 <= p0.x) && (p0.x < x1) && (x1 < p1.x) {
                // line only crosses x1
                // split line at x1.  keep right segment
                if let p = intersection(p0: p0, p1: p1, x: x1) {
                    newPath.move(to: p)
                    newPath.line(to: p1)
                } else {
                    NSLog("should not happen")
                }
            } else {
                NSLog("should not happen")
            }
        }
        return newPath
    }

    static func slice(pa: CGPoint, pb: CGPoint, x0: CGFloat, x1: CGFloat) -> NSBezierPath {
        if pa.x < pb.x {
            return Fixture.slice(p0: pa, p1: pb, x0: x0, x1: x1)
        } else {
            let path = Fixture.slice(p0: pb, p1: pa, x0: x0, x1: x1)
            var subpaths = Fixture.segments(path: path)
            for i in 0 ..< subpaths.count {
                subpaths[i] = subpaths[i].reversed
            }
            subpaths.reverse()
            let reversed = NSBezierPath()
            for subpath in subpaths {
                reversed.append(subpath)
            }
            return reversed
        }
    }

    static func slice(path: NSBezierPath, x0: CGFloat, x1: CGFloat) -> NSBezierPath {
        var last = NSPoint(x: 0, y: 0)
        let newPath = NSBezierPath()
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
            case .moveToBezierPathElement:
                last = points[0]
            case .lineToBezierPathElement:
                let path = slice(pa: last, pb: points[0], x0: x0, x1: x1)
                if !path.isEmpty {
                    newPath.append(path)
                    last = lastPoint(path: path)
                } else {
                    last = points[0]
                }
            case .curveToBezierPathElement:
                let p = points[2]
                if (p.x < x0) || (p.x > x1) {
                    newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
                    last = points[2]
                }
            case .closePathBezierPathElement:
                break
            }
        }
        return join(path: newPath)
    }

    static func segments(path: NSBezierPath) -> [NSBezierPath] {
        var paths: [NSBezierPath] = []
        var newPath = NSBezierPath()
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
            case .moveToBezierPathElement:
                if !newPath.isEmpty {
                    paths.append(newPath)
                    newPath = NSBezierPath()
                }
                newPath.move(to: points[0])
            case .lineToBezierPathElement:
                newPath.line(to: points[0])
            case .curveToBezierPathElement:
                newPath.curve(to: points[2], controlPoint1: points[0], controlPoint2: points[1])
            case .closePathBezierPathElement:
                newPath.close()
                break
            }
        }
        if !newPath.isEmpty {
            paths.append(newPath)
        }
        return paths
    }

    // Take two concentric continuous curves and split off the left and right segments (removing the segments in the middle).  Return:
    // path - the complete path made by joining the resulting left and right segments (as two subpaths)
    // leftOuterPath - the left outer path with points from min y to max y
    // leftInnerPath - the left inner path with points from min y to max y
    // rightInnerPath - the right inner path with points from min y to max y
    // rightOuterPath - the right outer path with points from min y to max y
    func split(path1: NSBezierPath, path2: NSBezierPath, x0: CGFloat, x1: CGFloat) -> (path: NSBezierPath, leftOuterPath: NSBezierPath, leftInnerPath: NSBezierPath, rightInnerPath: NSBezierPath, rightOuterPath: NSBezierPath) {
        let sliced1 = Fixture.slice(path: path1, x0: x0, x1: x1)
        let segments1 = Fixture.segments(path: Fixture.join(path: sliced1))
        let segs1 = Fixture.combine(paths: segments1)
        let ordered1 = Fixture.orderByY(paths: segs1)
        let sorted1 = Fixture.sortByX(paths: ordered1)
        let sliced2 = Fixture.slice(path: path2, x0: x0, x1: x1)
        let segments2 = Fixture.segments(path: Fixture.join(path: sliced2))
        let segs2 = Fixture.combine(paths: segments2)
        let ordered2 = Fixture.orderByY(paths: segs2)
        let sorted2 = Fixture.sortByX(paths: ordered2)
        let final = NSBezierPath()
        for i in 0 ..< sorted1.count {
            let a = sorted1[i].reversed
            let b = sorted2[i]
            let b0 = Fixture.firstPoint(path: b)
            a.line(to: b0)
            let path = Fixture.combine(paths: [a, b])[0]
            path.close()
            final.append(path)
        }
        return (path: final, leftOuterPath: sorted1[0], leftInnerPath: sorted2[0], rightInnerPath: sorted2[1], rightOuterPath: sorted1[1])
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
        return Fixture.join(path: path)
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
        var diameter: Board.PhysicalUnit = 0
        var name: String = ""

        init() {
        }

        init(x: Board.PhysicalUnit = 0, y: Board.PhysicalUnit = 0, diameter: Board.PhysicalUnit = 0, name: String = "") {
            self.x = x
            self.y = y
            self.diameter = diameter
            self.name = name
        }

    }

    func diameter(name: String, fallback: Board.PhysicalUnit) -> Board.PhysicalUnit {
        if name.hasSuffix("MM") {
            if let range = name.range(of: "-", options: [], range: nil, locale: nil) {
                let lower = name.index(range.upperBound, offsetBy: 0)
                let upper = name.index(name.endIndex, offsetBy: -2)
                let token = name.substring(with: lower ..< upper)
                if let diameter = Float(token) {
                    return Board.PhysicalUnit(diameter)
                }
            }
        }
        return fallback
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

    func holeTestPoints() -> [TestPoint] {
        var points: [TestPoint] = []

        var transform = AffineTransform()

        for instance in board.container.instances {
            guard let package = board.packages[instance.package] else {
                continue
            }

            var xform = AffineTransform()
            xform.translate(x: instance.x, y: instance.y)
            if instance.mirror {
                xform.scale(x: -1, y: 1)
            }
            xform.rotate(byDegrees: instance.rotate)
            transform.prepend(xform)

            for hole in package.container.holes {
                var xform = AffineTransform()
                xform.translate(x: hole.x, y: hole.y)
                transform.prepend(xform)

                let p = transform.transform(NSPoint(x: 0, y: 0))
                let testPoint = TestPoint()
                testPoint.x = p.x
                testPoint.y = p.y
                testPoint.name = "\(instance.name).hole"
                testPoint.diameter = hole.drill
                points.append(testPoint)

                xform.invert()
                transform.prepend(xform)

                // NSLog(@"  %@ %0.3f, %0.3f %0.3f, %0.3f", smd.name, smd.x, smd.y, p.x, p.y);
            }

            xform.invert()
            transform.prepend(xform)
        }
        
        return points
    }
    
    func testPoints(packageNamePrefix: String, mirrored: Bool, defaultDiameter: Board.PhysicalUnit) -> [TestPoint] {
        var points: [TestPoint] = []

        var transform = AffineTransform()

        for instance in board.container.instances {
            guard let package = board.packages[instance.package] else {
                continue
            }

            if package.name.hasPrefix(packageNamePrefix) {
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
                testPoint.diameter = diameter(name: package.name, fallback: defaultDiameter)
                points.append(testPoint)

                xform.invert()
                transform.prepend(xform)
            }
        }
        
        return points
    }

    func rhino(path: Path3D, name: String) -> String {
        var n = 0
        var lines = "curves = []\n"
        for i in 0 ..< path.points.count {
            let p0 = path.points[i]
            let p1 = path.points[(i + 1) % path.points.count]
            lines += String(format: "curves.append(rs.AddLine((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f)))\n", p0.x, p0.y, p0.z, p1.x, p1.y, p1.z)
            n += 1
        }
        if n < 2 {
            lines += "\(name) = curves\n"
        } else {
            lines += "\(name) = rs.JoinCurves(curves, True)\n"
        }
        return lines
    }

    func rhino3D(path: NSBezierPath, z: Board.PhysicalUnit, name: String) -> String {
        var n = 0
        var lines = "curves = []\n"
        var c: NSPoint = NSPoint(x: 0, y: 0)
        var origin: NSPoint = NSPoint(x: 0, y: 0)
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    c = points[0]
                    origin = c
                case .lineToBezierPathElement:
                    let p = points[0]
                    if c != p {
                        lines += String(format: "curves.append(rs.AddLine((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f)))\n", c.x, c.y, z, p.x, p.y, z)
                        n += 1
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
                    n += 1
                    
                    c = p3
                case .closePathBezierPathElement:
                    if c != origin {
                        let p = origin
                        lines += String(format: "curves.append(rs.AddLine((%0.3f, %0.3f, %0.3f), (%0.3f, %0.3f, %0.3f)))\n", c.x, c.y, z, p.x, p.y, z)
                        n += 1
                        c = p
                    }
                    break
            }
        }
        if n < 2 {
            lines += "\(name) = curves\n"
        } else {
            lines += "\(name) = rs.JoinCurves(curves, True)\n"
        }
        return lines
    }

    func eagle(bezierPath: NSBezierPath) -> String {
        let tx = CGFloat(0.0)
        let ty = CGFloat(0.0)
        let flatness = NSBezierPath.defaultFlatness()
        NSBezierPath.setDefaultFlatness(0.01)
        let path = bezierPath.flattened
        NSBezierPath.setDefaultFlatness(flatness)
        var origin = NSPoint()
        var hasOrigin = false
        var lines = ""
        for i in 0 ..< path.elementCount {
            var points: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let kind = path.element(at: i, associatedPoints: &points)
            switch (kind) {
                case .moveToBezierPathElement:
                    let p = points[0]
                    if !hasOrigin {
                        hasOrigin = true
                        origin = p
                    }
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                case .lineToBezierPathElement:
                    let p = points[0]
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                case .curveToBezierPathElement:
                    let p = points[2]
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                case .closePathBezierPathElement:
                    let p = origin
                    lines += String(format: " (%0.3f %0.3f)", p.x + tx, p.y + ty)
                    break
            }
        }
        return lines;
    }

    func derivedFileName(postfix: String, bottom: Bool) -> String {
        return String(format: "%@/%@_%@_%@", board.path, board.name, bottom ? "bottom" : "top", postfix)
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

            lines += cut(surface: "probe", fromSurface: surface0)
            lines += cut(surface: "probe", fromSurface: surface1)

            display.appendOval(in: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        return lines
    }
    
    func cut(path: NSBezierPath, surface0: String, z0: Board.PhysicalUnit, surface1: String, z1: Board.PhysicalUnit, display: inout NSBezierPath) -> String {
        var lines = rhino3D(path: path, z: z0, name: "curve")
        lines += extrude(curve: "curve", asSurface: "cutout", fromZ: z0, toZ: z1)
        lines += cut(surface: "cutout", fromSurface: surface0)
        lines += cut(surface: "cutout", fromSurface: surface1)
        display.append(path)
        return lines
    }

    func core(path: NSBezierPath, surface0: String, z0: Board.PhysicalUnit, z1: Board.PhysicalUnit, display: inout NSBezierPath) -> String {
        var lines = rhino3D(path: path, z: z1, name: "curve")
        lines += "rs.AddPlanarSrf([curve])\n"
        lines += extrude(curve: "curve", asSurface: "cutout", fromZ: z1, toZ: z0)
        lines += cut(surface: "cutout", fromSurface: surface0)
        display.append(path)
        return lines
    }

    func addPosts(testPoints: [TestPoint], surface0: String, z0: Board.PhysicalUnit, z1: Board.PhysicalUnit, display: inout NSBezierPath) -> String {
        var lines = "posts = []\n"
        for testPoint in testPoints {
            let x = testPoint.x
            let y = testPoint.y
            let r = testPoint.diameter / 2.0
            lines += circle(asCurve: "curve", cx: x, cy: y, r: r, z: z1)
            lines += "rs.AddPlanarSrf([curve])\n"
            lines += extrude(curve: "curve", asSurface: "post", fromZ: z1, toZ: z0)
            lines += "posts.append(post)\n"

            lines += cut(surface: "post", fromSurface: surface0)

            display.appendOval(in: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        return lines
    }

    func addAlignmentPosts(testPoints: [TestPoint], outset: Board.PhysicalUnit, inset: Board.PhysicalUnit, within: NSBezierPath, surface0: String, z0: Board.PhysicalUnit, z1: Board.PhysicalUnit, z2: Board.PhysicalUnit, display: inout NSBezierPath) -> String {
        var lines = "alignmentPosts = []\n"
        let clipper = FDClipper()
        for testPoint in testPoints {
            let x = testPoint.x
            let y = testPoint.y
            let r1 = (testPoint.diameter + outset) / 2.0
            let open: Board.PhysicalUnit = 0.5
            let bounds = clipper.path(within, offset: -(r1 + open))
            if !bounds.contains(NSPoint(x: x, y: y)) {
                continue
            }

            lines += circle(asCurve: "curve", cx: x, cy: y, r: r1, z: z1)
            lines += "plane = rs.AddPlanarSrf([curve])\n"
            lines += extrude(curve: "curve", asSurface: "post", fromZ: z1, toZ: z0)
            lines += cut(surface: "post", fromSurface: surface0)

            let r2 = (testPoint.diameter - inset) / 2.0
            lines += circle(asCurve: "curve", cx: x, cy: y, r: r2, z: z2)
            lines += "rs.AddPlanarSrf([curve])\n"
            lines += extrude(curve: "curve", asSurface: "mount", fromZ: z2, toZ: z1)
            lines += cut(surface: "mount", fromSurface: "plane")

            lines += "alignmentPosts.append(post)\n"


            display.appendOval(in: NSRect(x: x - r1, y: y - r1, width: r1 * 2, height: r1 * 2))
            display.appendOval(in: NSRect(x: x - r2, y: y - r2, width: r2 * 2, height: r2 * 2))
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
    // locating pins: MISUMI JPRBPB6-8 8mm
    // fixture PCB mounting screws: M2 8mm (1.5mm drive) McMaster-Carr 91290A015
    // fixture mounting screws: M3 20mm (2mm drive) McMaster-Carr 93070A076
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
        let mountingWidth: Board.PhysicalUnit = 100.0
        let mountingHeight: Board.PhysicalUnit = 80.0
        let mountingThickness: Board.PhysicalUnit = 3.0
        let mountingScrewHole: Board.PhysicalUnit = 3.4
        let mountingScrewOffset: Board.PhysicalUnit = 8.0
        let locators = [
            TestPoint(x: 0.0, y: -31.0, diameter: 8.0, name: "LP1"),
            TestPoint(x: 0.0, y: +31.0, diameter: 8.0, name: "LP2"),
            ]
        let pcbMountingWidth: Board.PhysicalUnit = 80.0
        let pcbMountingHeight: Board.PhysicalUnit = 44.0
        let pcbMountingScrewHole: Board.PhysicalUnit = 2.2
        let pcbMountingScrewOffsetX: Board.PhysicalUnit = 28
        let pcbMountingScrewOffsetY: Board.PhysicalUnit = 18.5
        let pcbHeader = NSBezierPath(rect: NSRect(x: -(36.0 + 9.0 / 2.0), y: -(0.0 + 38.0 / 2.0), width: 9.0, height: 38.0))
        let pcbHeaderClearance: Board.PhysicalUnit = 2.0

        let defaultSupportPostDiameter: Board.PhysicalUnit = 2.0
        let defaultLedHoleDiameter: Board.PhysicalUnit = 3.25
        let defaultProbeHoleDiameter: Board.PhysicalUnit = 1.0
        let pcbOutlineTolerance: Board.PhysicalUnit = 0.25
        let wallThickness: Board.PhysicalUnit = 4.0
        let ledgeThickness: Board.PhysicalUnit = 2.0
        let postOutset: Board.PhysicalUnit = 0.4
        let postInset: Board.PhysicalUnit = 0.1
    }

    func mountingFeatures(dimension: NSBezierPath, properties: Properties) -> (path: NSBezierPath, holes: [TestPoint]) {
        let extents = dimension.bounds
        let middleX = extents.midX
        let middleY = extents.midY
        let origin = NSPoint(x: middleX - properties.mountingWidth / 2.0, y: middleY - properties.mountingHeight / 2.0)
        let size = NSSize(width: properties.mountingWidth, height: properties.mountingHeight)
        let rect = NSRect(origin: origin, size: size)
        let path = NSBezierPath(rect: rect)

        let holes = [
            TestPoint(x: rect.minX + properties.mountingScrewOffset, y: rect.minY + properties.mountingScrewOffset, diameter: properties.mountingScrewHole, name: "minxminy"),
            TestPoint(x: rect.minX + properties.mountingScrewOffset, y: rect.maxY - properties.mountingScrewOffset, diameter: properties.mountingScrewHole, name: "minxmaxy"),
            TestPoint(x: rect.maxX - properties.mountingScrewOffset, y: rect.maxY - properties.mountingScrewOffset, diameter: properties.mountingScrewHole, name: "maxxmaxy"),
            TestPoint(x: rect.maxX - properties.mountingScrewOffset, y: rect.minY + properties.mountingScrewOffset, diameter: properties.mountingScrewHole, name: "maxxminy"),
            ]

        return (path: path, holes: holes)
    }

    func pcbMountingFeatures(dimension: NSBezierPath, properties: Properties) -> (path: NSBezierPath, holes: [TestPoint]) {
        let extents = dimension.bounds
        let middleX = extents.midX
        let middleY = extents.midY
        let origin = NSPoint(x: middleX - properties.pcbMountingWidth / 2.0, y: middleY - properties.pcbMountingHeight / 2.0)
        let size = NSSize(width: properties.pcbMountingWidth, height: properties.pcbMountingHeight)
        let rect = NSRect(origin: origin, size: size)
        let path = NSBezierPath(rect: rect)

        let holes = [
            TestPoint(x: middleX - properties.pcbMountingScrewOffsetX, y: middleY - properties.pcbMountingScrewOffsetY, diameter: properties.pcbMountingScrewHole, name: "minxminy"),
            TestPoint(x: middleX - properties.pcbMountingScrewOffsetX, y: middleY + properties.pcbMountingScrewOffsetY, diameter: properties.pcbMountingScrewHole, name: "minxmaxy"),
            TestPoint(x: middleX + properties.pcbMountingScrewOffsetX, y: middleY + properties.pcbMountingScrewOffsetY, diameter: properties.pcbMountingScrewHole, name: "maxxmaxy"),
            TestPoint(x: middleX + properties.pcbMountingScrewOffsetX, y: middleY - properties.pcbMountingScrewOffsetY, diameter: properties.pcbMountingScrewHole, name: "maxxminy"),
            ]

        return (path: path, holes: holes)
    }

    func generateTestFixtureTopPlastic(properties: Properties, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint], supportPoints: [TestPoint], display: inout NSBezierPath) throws {
        let bps: Board.PhysicalUnit = 0.0
        let bpi: Board.PhysicalUnit = bps + properties.pcbThickness + properties.probeStroke + properties.ledgeOverage

        let tps: Board.PhysicalUnit = bps + properties.pcbThickness
        let tpi: Board.PhysicalUnit = bpi
        let tpn: Board.PhysicalUnit = tps + properties.pcbTopComponentClearance
        let tpo: Board.PhysicalUnit = tpn + properties.probeSupportThickness
        let tpm: Board.PhysicalUnit = tpo - properties.mountingThickness

        var lines = rhinoHeader()
        
        // 20: "Dimension" (AKA Outline) layer
        let dimension = bezierPathForWires(wires: wiresForLayer(layer: 20))

        let clipper = FDClipper()
        let bounds = clipper.path(dimension, offset: properties.wallThickness + properties.pcbOutlineTolerance)
        let outline = clipper.path(bounds, offset: -properties.wallThickness)

        let (mounting, holes) = mountingFeatures(dimension: dimension, properties: properties)

        // main body
        lines += rhino3D(path: mounting, z: tpm, name: "mounting")
        lines += rhino3D(path: mounting, z: tpo, name: "mounting2")
        lines += rhino3D(path: bounds, z: tpi, name: "bounds")
        lines += rhino3D(path: bounds, z: tpm, name: "bounds2")
        lines += rhino3D(path: outline, z: tpi, name: "outline")
        lines += rhino3D(path: outline, z: tpn, name: "outline2")
        //
        lines += "out1 = rs.AddPlanarSrf([mounting2])\n"
        lines += extrude(curve: "mounting", asSurface: "mountingWall", fromZ: tpm, toZ: tpo)
        lines += "out2 = rs.AddPlanarSrf([mounting, bounds2])\n"
        lines += extrude(curve: "bounds", asSurface: "boundsWall", fromZ: tpi, toZ: tpm)
        lines += "rs.AddPlanarSrf([bounds, outline])\n"
        lines += extrude(curve: "outline", asSurface: "outlineWall", fromZ: tpi, toZ: tpn)
        lines += "out0 = rs.AddPlanarSrf([outline2])\n"

        // cut out test point openings
        lines += cutProbeHoles(testPoints: probeTestPoints, surface0: "out0", z0: tpn, surface1: "out1", z1: tpo, display: &display)
        lines += cutProbeHoles(testPoints: ledTestPoints, surface0: "out0", z0: tpn, surface1: "out1", z1: tpo, display: &display)

        // add supports
        lines += addPosts(testPoints: supportPoints, surface0: "out0", z0: tpn, z1: tps, display: &display)

        // cut out mounting holes
        lines += cutProbeHoles(testPoints: holes, surface0: "out2", z0: tpm, surface1: "out1", z1: tpo, display: &display)

        // add locating post holes
        lines += cutProbeHoles(testPoints: properties.locators, surface0: "out2", z0: tpm, surface1: "out1", z1: tpo, display: &display)

        // cut out fixture pcba mounting holes
        let (_, pcbHoles) = pcbMountingFeatures(dimension: dimension, properties: properties)
        lines += cutProbeHoles(testPoints: pcbHoles, surface0: "out2", z0: tpm, surface1: "out1", z1: tpo, display: &display)

        // cut out fixture pcba clearance openings
        lines += core(path: properties.pcbHeader, surface0: "out1", z0: tpo, z1: tpo - properties.pcbHeaderClearance, display: &display)

        NSLog(String(format: "test fixture %@ plastic:\n%@", "top", lines))
        let fileName = derivedFileName(postfix: "plate.py", bottom: false)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)

        // fixture display outline
        display.append(outline)
        display.append(bounds)
    }

    func generateTestFixtureBottomPlastic(properties: Properties, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint], supportPoints: [TestPoint], alignmentSupportPoints: [TestPoint], display: inout NSBezierPath) throws {
        let bps: Board.PhysicalUnit = 0.0
        let bpi: Board.PhysicalUnit = bps + properties.pcbThickness + properties.probeStroke + properties.ledgeOverage
        let bpn: Board.PhysicalUnit = bps - properties.pcbBottomComponentClearance
        let bpo: Board.PhysicalUnit = bpn - properties.probeSupportThickness
        let bpm: Board.PhysicalUnit = bpo + properties.mountingThickness

        var lines = rhinoHeader()

        // 20: "Dimension" (AKA Outline) layer
        let dimension = bezierPathForWires(wires: wiresForLayer(layer: 20))

        let clipper = FDClipper()
        let bounds = clipper.path(dimension, offset: properties.wallThickness + properties.pcbOutlineTolerance)
        let outline = clipper.path(dimension, offset: properties.pcbOutlineTolerance)
        let ledge = clipper.path(dimension, offset: -(properties.ledgeThickness - properties.pcbOutlineTolerance))
        let boundsToOutline = split(path1: bounds, path2: outline, x0: 14.0, x1: 28.0)
        let outlineToLedge = split(path1: outline, path2: ledge, x0: 14.0, x1: 28.0)
        let boundsToLedge = split(path1: bounds, path2: ledge, x0: 14.0, x1: 28.0)

        let boundsToOutlineCut = NSBezierPath()
        boundsToOutlineCut.append(boundsToOutline.leftOuterPath)
        boundsToOutlineCut.line(to: Fixture.lastPoint(path: boundsToOutline.leftInnerPath))
        boundsToOutlineCut.line(to: Fixture.lastPoint(path: boundsToOutline.rightInnerPath))
        boundsToOutlineCut.line(to: Fixture.lastPoint(path: boundsToOutline.rightOuterPath))
        boundsToOutlineCut.append(boundsToOutline.rightOuterPath.reversed)
        boundsToOutlineCut.line(to: Fixture.firstPoint(path: boundsToOutline.rightInnerPath))
        boundsToOutlineCut.line(to: Fixture.firstPoint(path: boundsToOutline.leftInnerPath))
        boundsToOutlineCut.line(to: Fixture.firstPoint(path: boundsToOutline.leftOuterPath))

        let outlineBottom = NSBezierPath()
        outlineBottom.move(to: Fixture.firstPoint(path: boundsToOutline.leftInnerPath))
        outlineBottom.line(to: Fixture.firstPoint(path: boundsToOutline.rightInnerPath))
        let outlineTop = NSBezierPath()
        outlineTop.move(to: Fixture.lastPoint(path: boundsToOutline.leftInnerPath))
        outlineTop.line(to: Fixture.lastPoint(path: boundsToOutline.rightInnerPath))

        let outlineToLedgeFill = NSBezierPath()
        outlineToLedgeFill.append(outlineToLedge.leftInnerPath)
        outlineToLedgeFill.line(to: Fixture.lastPoint(path: outlineToLedge.leftOuterPath))
        outlineToLedgeFill.line(to: Fixture.lastPoint(path: outlineToLedge.rightOuterPath))
        outlineToLedgeFill.line(to: Fixture.lastPoint(path: outlineToLedge.rightInnerPath))
        outlineToLedgeFill.append(outlineToLedge.rightInnerPath.reversed)
        outlineToLedgeFill.line(to: Fixture.firstPoint(path: outlineToLedge.rightOuterPath))
        outlineToLedgeFill.line(to: Fixture.firstPoint(path: outlineToLedge.leftOuterPath))
        outlineToLedgeFill.line(to: Fixture.firstPoint(path: outlineToLedge.leftInnerPath))

        let bottomLeftSide = Path3D()
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.leftOuterPath), z: bpm))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.leftOuterPath), z: bpi))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.leftInnerPath), z: bpi))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.leftInnerPath), z: bps))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: outlineToLedge.leftInnerPath), z: bps))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: outlineToLedge.leftInnerPath), z: bpn))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.leftInnerPath), z: bpn))
        bottomLeftSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.leftInnerPath), z: bpm))

        let bottomRightSide = Path3D()
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.rightOuterPath), z: bpm))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.rightOuterPath), z: bpi))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.rightInnerPath), z: bpi))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.rightInnerPath), z: bps))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: outlineToLedge.rightInnerPath), z: bps))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: outlineToLedge.rightInnerPath), z: bpn))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.rightInnerPath), z: bpn))
        bottomRightSide.points.append(Point3D(xy: Fixture.firstPoint(path: boundsToOutline.rightInnerPath), z: bpm))

        let topLeftSide = Path3D()
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.leftOuterPath), z: bpm))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.leftOuterPath), z: bpi))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.leftInnerPath), z: bpi))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.leftInnerPath), z: bps))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: outlineToLedge.leftInnerPath), z: bps))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: outlineToLedge.leftInnerPath), z: bpn))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.leftInnerPath), z: bpn))
        topLeftSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.leftInnerPath), z: bpm))

        let topRightSide = Path3D()
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.rightOuterPath), z: bpm))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.rightOuterPath), z: bpi))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.rightInnerPath), z: bpi))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.rightInnerPath), z: bps))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: outlineToLedge.rightInnerPath), z: bps))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: outlineToLedge.rightInnerPath), z: bpn))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.rightInnerPath), z: bpn))
        topRightSide.points.append(Point3D(xy: Fixture.lastPoint(path: boundsToOutline.rightInnerPath), z: bpm))

        let (mounting, holes) = mountingFeatures(dimension: dimension, properties: properties)

        // main body
        lines += rhino3D(path: mounting, z: bpm, name: "mounting")
        lines += rhino3D(path: mounting, z: bpo, name: "mounting2")
        lines += rhino3D(path: boundsToOutline.path, z: bpi, name: "boundsToOutline")
        lines += rhino3D(path: boundsToOutlineCut, z: bpm, name: "boundsToOutlineCut")
        lines += rhino3D(path: boundsToOutline.leftOuterPath, z: bpm, name: "boundsLeft")
        lines += rhino3D(path: boundsToOutline.rightOuterPath, z: bpm, name: "boundsRight")
        lines += rhino3D(path: outlineToLedgeFill, z: bpn, name: "outlineToLedgeFill")
        lines += rhino3D(path: outlineToLedge.leftOuterPath, z: bps, name: "outlineLeft")
        lines += rhino3D(path: outlineToLedge.rightOuterPath, z: bps, name: "outlineRight")
        lines += rhino3D(path: outlineToLedge.path, z: bps, name: "outlineToLedge")
        lines += rhino3D(path: outlineToLedge.leftInnerPath, z: bpn, name: "ledgeLeft")
        lines += rhino3D(path: outlineToLedge.rightInnerPath, z: bpn, name: "ledgeRight")
        lines += rhino3D(path: outlineToLedge.leftOuterPath, z: bps, name: "outlineLeft")
        lines += rhino3D(path: outlineToLedge.rightOuterPath, z: bps, name: "outlineRight")
        lines += rhino3D(path: outlineBottom, z: bpm, name: "outlineBottom")
        lines += rhino3D(path: outlineTop, z: bpm, name: "outlineTop")
        lines += rhino(path: bottomLeftSide, name: "bottomLeftSide")
        lines += rhino(path: bottomRightSide, name: "bottomRightSide")
        lines += rhino(path: topLeftSide, name: "topLeftSide")
        lines += rhino(path: topRightSide, name: "topRightSide")
        //
        lines += "out1 = rs.AddPlanarSrf([mounting2])\n"
        lines += extrude(curve: "mounting", asSurface: "mountingWall", fromZ: bpm, toZ: bpo)
        lines += "out2 = rs.AddPlanarSrf([mounting, boundsToOutlineCut])\n"
        lines += "out0 = rs.AddPlanarSrf([outlineToLedgeFill])\n"
        lines += "rs.AddPlanarSrf(outlineToLedge)\n"
        lines += "rs.AddPlanarSrf(boundsToOutline)\n"
        lines += extrude(curve: "ledgeLeft", asSurface: "ledgeLeftWall", fromZ: bpn, toZ: bps)
        lines += extrude(curve: "ledgeRight", asSurface: "ledgeRightWall", fromZ: bpn, toZ: bps)
        lines += extrude(curve: "outlineLeft", asSurface: "outlineLeftWall", fromZ: bps, toZ: bpi)
        lines += extrude(curve: "outlineRight", asSurface: "outlineRightWall", fromZ: bps, toZ: bpi)
        lines += extrude(curve: "boundsLeft", asSurface: "boundsLeftWall", fromZ: bpm, toZ: bpi)
        lines += extrude(curve: "boundsRight", asSurface: "boundsRightWall", fromZ: bpm, toZ: bpi)
        lines += extrude(curve: "outlineBottom", asSurface: "outlineBottomWall", fromZ: bpm, toZ: bpn)
        lines += extrude(curve: "outlineTop", asSurface: "outlineTopWall", fromZ: bpm, toZ: bpn)
        lines += "rs.AddPlanarSrf(bottomLeftSide)\n"
        lines += "rs.AddPlanarSrf(bottomRightSide)\n"
        lines += "rs.AddPlanarSrf(topLeftSide)\n"
        lines += "rs.AddPlanarSrf(topRightSide)\n"

        // cut out test point openings
        lines += cutProbeHoles(testPoints: probeTestPoints, surface0: "out0", z0: bpn, surface1: "out1", z1: bpo, display: &display)
        lines += cutProbeHoles(testPoints: ledTestPoints, surface0: "out0", z0: bpn, surface1: "out1", z1: bpo, display: &display)

        // add supports
        lines += addPosts(testPoints: supportPoints, surface0: "out0", z0: bpn, z1: bps, display: &display)

        // add alignment supports
        lines += addAlignmentPosts(testPoints: alignmentSupportPoints, outset: properties.postOutset, inset: properties.postInset, within: ledge, surface0: "out0", z0: bpn, z1: bps, z2: bpi, display: &display)

        // cut out mounting holes
        lines += cutProbeHoles(testPoints: holes, surface0: "out2", z0: bpm, surface1: "out1", z1: bpo, display: &display)

        // add locating post holes
        lines += cutProbeHoles(testPoints: properties.locators, surface0: "out2", z0: bpm, surface1: "out1", z1: bpo, display: &display)

        // cut out pcb mounting holes
        let (_, pcbHoles) = pcbMountingFeatures(dimension: dimension, properties: properties)
        lines += cutProbeHoles(testPoints: pcbHoles, surface0: "out2", z0: bpm, surface1: "out1", z1: bpo, display: &display)

        // cut out fixture pcba clearance openings
        lines += core(path: properties.pcbHeader, surface0: "out1", z0: bpo, z1: bpo + properties.pcbHeaderClearance, display: &display)

        NSLog(String(format: "test fixture %@ plastic:\n%@", "bottom", lines))
        let fileName = derivedFileName(postfix: "plate.py", bottom: true)
        try lines.write(toFile: fileName, atomically: false, encoding: String.Encoding.utf8)

        // fixture display outline
        display.append(outline)
        display.append(bounds)
        display.append(ledge)
    }

    func maybeCopyTemplate(type: String, bottom: Bool) {
        let destinationURL = URL(fileURLWithPath: derivedFileName(postfix: "plate.\(type)", bottom: bottom))
        if !((try? destinationURL.checkResourceIsReachable()) ?? false) {
            let templateURL = URL(fileURLWithPath: "/Users/denis/sandbox/denisbohm/firefly-eagle-library/plate_template.\(type)")
            let fileManager = FileManager.default
            try? fileManager.copyItem(at: templateURL, to: destinationURL)
        }
    }

    func generateTestFixtureSchematic(properties: Properties, bottom: Bool, probeTestPoints: [TestPoint], ledTestPoints: [TestPoint]) throws {
        // template schematic has frame plus test instrument header & signals
        maybeCopyTemplate(type: "sch", bottom: bottom)

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
        // template schematic has frame plus test instrument header & signals
        maybeCopyTemplate(type: "brd", bottom: bottom)

        let dimension = bezierPathForWires(wires: wiresForLayer(layer: 20)) // 20: "Dimension" layer
        dimension.close()

        var lines = ""

        // This is in the template now...
        /*
        let (mounting, holes) = pcbMountingFeatures(dimension: dimension, properties: properties)

        // delete default board outline
        lines += "DISPLAY NONE Dimension;\n"
        lines += "GROUP ALL;\n"
        lines += "DELETE (C> 0 0);\n"
        lines += "DISPLAY LAST;\n"

        // add board outline
        lines += "LAYER Dimension;\n"
        lines += "SET WIRE_BEND 2;"
        lines += "WIRE 0.1"
        lines += eagle(bezierPath: mounting)
        lines += ";\n"

        for testPoint in holes {
            lines += String(format: "hole %0.3f (%f %f);\n", testPoint.diameter, testPoint.x, testPoint.y)
        }
         */

        // add silk for board location (makes it easy to check the probe holes...)
        lines += "LAYER " + (bottom ? "t" : "b") + "Place;\n"
        lines += "SET WIRE_BEND 2;"
        lines += "WIRE 0.1" + eagle(bezierPath: dimension) + ";\n"

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
        let dimension = bezierPathForWires(wires: wiresForLayer(layer: 20))
        let extents = dimension.bounds
        let dx = extents.midX
        let dy = extents.midY
        for locator in properties.locators {
            locator.x += dx
            locator.y += dy
        }
        let transform = AffineTransform(translationByX: dx, byY: dy)
        properties.pcbHeader.transform(using: transform)

        let (mounting, _) = mountingFeatures(dimension: dimension, properties: properties)
        all.append(mounting)
        let (pcbMounting, _) = pcbMountingFeatures(dimension: dimension, properties: properties)
        all.append(pcbMounting)

        let topProbeTestPoints = probeTestPoints(mirrored: false, defaultDiameter: properties.defaultProbeHoleDiameter)
        let topLedTestPoints = testPoints(packageNamePrefix: "LED_TEST_POINT", mirrored: false, defaultDiameter: properties.defaultLedHoleDiameter)
        let topSupportPoints = testPoints(packageNamePrefix: "SUPPORT", mirrored: false, defaultDiameter: properties.defaultSupportPostDiameter)
        try generateTestFixtureTopPlastic(properties: properties, probeTestPoints: topProbeTestPoints, ledTestPoints: topLedTestPoints, supportPoints: topSupportPoints, display: &all)
        try generateTestFixtureSchematic(properties: properties, bottom: false, probeTestPoints: topProbeTestPoints, ledTestPoints: topLedTestPoints)
        try generateTestFixtureLayout(properties: properties, bottom: false, probeTestPoints: topProbeTestPoints, ledTestPoints: topLedTestPoints)

        let bottomProbeTestPoints = probeTestPoints(mirrored: true, defaultDiameter: properties.defaultProbeHoleDiameter)
        let bottomLedTestPoints = testPoints(packageNamePrefix: "LED_TEST_POINT", mirrored: true, defaultDiameter: properties.defaultLedHoleDiameter)
        let bottomSupportPoints = testPoints(packageNamePrefix: "SUPPORT", mirrored: true, defaultDiameter: properties.defaultSupportPostDiameter)
        let alignmentSupportPoints = holeTestPoints()
        try generateTestFixtureBottomPlastic(properties: properties, probeTestPoints: bottomProbeTestPoints, ledTestPoints: bottomLedTestPoints, supportPoints: bottomSupportPoints, alignmentSupportPoints: alignmentSupportPoints, display: &all)
        try generateTestFixtureSchematic(properties: properties, bottom: true, probeTestPoints: bottomProbeTestPoints, ledTestPoints: bottomLedTestPoints)
        try generateTestFixtureLayout(properties: properties, bottom: true, probeTestPoints: bottomProbeTestPoints, ledTestPoints: bottomLedTestPoints)
        
        return all
    }

}
