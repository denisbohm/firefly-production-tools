//
//  Firefly_FixtureTests.swift
//  Firefly FixtureTests
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import XCTest
@testable import Firefly_Fixture

class Firefly_FixtureTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func equals(aPoint: NSPoint, bPoint: NSPoint) -> Bool {
        return (aPoint.x == bPoint.x) && (aPoint.y == bPoint.y)
    }

    func equals(aPath: NSBezierPath, bPath: NSBezierPath) -> Bool {
        if aPath.elementCount != bPath.elementCount {
            return false
        }
        for i in 0 ..< aPath.elementCount {
            var aPoints: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let aKind = aPath.element(at: i, associatedPoints: &aPoints)
            var bPoints: [NSPoint] = [NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0), NSPoint(x: 0, y: 0)]
            let bKind = bPath.element(at: i, associatedPoints: &bPoints)
            if aKind != bKind {
                return false
            }
            for i in 0...2 {
                if !equals(aPoint: aPoints[i], bPoint: bPoints[i]) {
                    return false
                }
            }
        }
        return true
    }

    func testSliceOutsideLeft() {
        let p0 = CGPoint(x: 0, y: 0)
        let p1 = CGPoint(x: 1, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p0)
        expected.line(to: p1)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceOutsideLeftReverse() {
        let p0 = CGPoint(x: 0, y: 0)
        let p1 = CGPoint(x: 1, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p1)
        expected.line(to: p0)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchOutsideLeft() {
        let p0 = CGPoint(x: 1, y: 0)
        let p1 = CGPoint(x: 2, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p0)
        expected.line(to: p1)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchOutsideLeftReverse() {
        let p0 = CGPoint(x: 1, y: 0)
        let p1 = CGPoint(x: 2, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p1)
        expected.line(to: p0)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceCrossLeft() {
        let p0 = CGPoint(x: 1, y: 0)
        let p1 = CGPoint(x: 3, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p0)
        expected.line(to: NSPoint(x: x0, y: 0))
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceCrossLeftReverse() {
        let p0 = CGPoint(x: 1, y: 0)
        let p1 = CGPoint(x: 3, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: NSPoint(x: x0, y: 0))
        expected.line(to: p0)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchInsideLeft() {
        let p0 = CGPoint(x: 2, y: 0)
        let p1 = CGPoint(x: 3, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchInsideLeftReverse() {
        let p0 = CGPoint(x: 2, y: 0)
        let p1 = CGPoint(x: 3, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceInside() {
        let p0 = CGPoint(x: 2.5, y: 0)
        let p1 = CGPoint(x: 3, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceInsideReverse() {
        let p0 = CGPoint(x: 2.5, y: 0)
        let p1 = CGPoint(x: 3, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchInsideRight() {
        let p0 = CGPoint(x: 3, y: 0)
        let p1 = CGPoint(x: 4, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchInsideRightReverse() {
        let p0 = CGPoint(x: 3, y: 0)
        let p1 = CGPoint(x: 4, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchOutsideRight() {
        let p0 = CGPoint(x: 4, y: 0)
        let p1 = CGPoint(x: 5, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p0)
        expected.line(to: p1)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchOutsideRightReverse() {
        let p0 = CGPoint(x: 4, y: 0)
        let p1 = CGPoint(x: 5, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p1)
        expected.line(to: p0)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceCrossRight() {
        let p0 = CGPoint(x: 3, y: 0)
        let p1 = CGPoint(x: 5, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: NSPoint(x: x1, y: 0))
        expected.line(to: p1)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceCrossRightReverse() {
        let p0 = CGPoint(x: 3, y: 0)
        let p1 = CGPoint(x: 5, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p1)
        expected.line(to: NSPoint(x: x1, y: 0))
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceCrossLeftRight() {
        let p0 = CGPoint(x: 1, y: 0)
        let p1 = CGPoint(x: 5, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p0)
        expected.line(to: NSPoint(x: x0, y: 0))
        expected.move(to: NSPoint(x: x1, y: 0))
        expected.line(to: p1)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceCrossLeftRightReverse() {
        let p0 = CGPoint(x: 1, y: 0)
        let p1 = CGPoint(x: 5, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: p1)
        expected.line(to: NSPoint(x: x1, y: 0))
        expected.move(to: NSPoint(x: x0, y: 0))
        expected.line(to: p0)
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchLeftRight() {
        let p0 = CGPoint(x: 2, y: 0)
        let p1 = CGPoint(x: 4, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p0, pb: p1, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceTouchLeftRightReverse() {
        let p0 = CGPoint(x: 2, y: 0)
        let p1 = CGPoint(x: 4, y: 0)
        let x0: CGFloat = 2
        let x1: CGFloat = 4
        let path = Fixture.slice(pa: p1, pb: p0, x0: x0, x1: x1)
        let expected = NSBezierPath()
        XCTAssert(equals(aPath: path, bPath: expected))
    }

    func testSliceRect() {
        let rect = NSBezierPath()
        rect.move(to: NSPoint(x: 0, y: 0))
        rect.line(to: NSPoint(x: 3, y: 0))
        rect.line(to: NSPoint(x: 3, y: 1))
        rect.line(to: NSPoint(x: 3, y: 0))
        rect.line(to: NSPoint(x: 0, y: 0))
        let x0: CGFloat = 1
        let x1: CGFloat = 2
        let path = Fixture.slice(path: rect, x0: x0, x1: x1)
        let expected = NSBezierPath()
        expected.move(to: NSPoint(x: 0, y: 0))
        expected.line(to: NSPoint(x: 1, y: 0))
        expected.move(to: NSPoint(x: 2, y: 0))
        expected.line(to: NSPoint(x: 3, y: 0))
        expected.line(to: NSPoint(x: 3, y: 1))
        expected.line(to: NSPoint(x: 2, y: 1))
        expected.move(to: NSPoint(x: 1, y: 1))
        expected.line(to: NSPoint(x: 0, y: 1))
        expected.line(to: NSPoint(x: 0, y: 0))
        XCTAssert(equals(aPath: path, bPath: expected))
    }

}
