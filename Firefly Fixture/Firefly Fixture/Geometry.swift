//
//  Geometry.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/31/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Foundation

class Geometry {

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
        let last1 = Geometry.lastPoint(path: path1)
        let first2 = Geometry.firstPoint(path: path2)
        return Geometry.equal(point1: last1, point2: first2)
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
                let p0 = points[0]
                if (fabs(last.x - p0.x) > epsilon) || (fabs(last.y - p0.y) > epsilon) {
                    newPath.line(to: p0)
                    last = p0
                }
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
            return Geometry.slice(p0: pa, p1: pb, x0: x0, x1: x1)
        } else {
            let path = Geometry.slice(p0: pb, p1: pa, x0: x0, x1: x1)
            var subpaths = Geometry.segments(path: path)
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
    static func split(path1: NSBezierPath, path2: NSBezierPath, x0: CGFloat, x1: CGFloat) -> (path: NSBezierPath, leftOuterPath: NSBezierPath, leftInnerPath: NSBezierPath, rightInnerPath: NSBezierPath, rightOuterPath: NSBezierPath) {
        let sliced1 = Geometry.slice(path: path1, x0: x0, x1: x1)
        let segments1 = Geometry.segments(path: Geometry.join(path: sliced1))
        let segs1 = Geometry.combine(paths: segments1)
        let ordered1 = Geometry.orderByY(paths: segs1)
        let sorted1 = Geometry.sortByX(paths: ordered1)
        let sliced2 = Geometry.slice(path: path2, x0: x0, x1: x1)
        let segments2 = Geometry.segments(path: Geometry.join(path: sliced2))
        let segs2 = Geometry.combine(paths: segments2)
        let ordered2 = Geometry.orderByY(paths: segs2)
        let sorted2 = Geometry.sortByX(paths: ordered2)
        let final = NSBezierPath()
        for i in 0 ..< sorted1.count {
            let a = sorted1[i].reversed
            let b = sorted2[i]
            let b0 = Geometry.firstPoint(path: b)
            a.line(to: b0)
            let path = Geometry.combine(paths: [a, b])[0]
            path.close()
            final.append(path)
        }
        return (path: final, leftOuterPath: sorted1[0], leftInnerPath: sorted2[0], rightInnerPath: sorted2[1], rightOuterPath: sorted1[1])
    }

    static func bezierPathForWires(wires: [Board.Wire]) -> NSBezierPath {
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
        return Geometry.join(path: path)
    }

}
