//
//  Eagle.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/9/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Foundation

class Eagle {

    enum LocalError: Error {
        case fileNotFound(String)
        case invalidDocument
        case invalidElements
        case attributeNotFound(String)
        case attributeValueNotFound(String)
        case attributeValueInvalid(String, String)
    }

    func loadWire(container: Board.Container, element: XMLElement) throws {
        let wire = Board.Wire()
        wire.x1 = try getAttribute(element: element, name: "x1")
        wire.y1 = try getAttribute(element: element, name: "y1")
        wire.x2 = try getAttribute(element: element, name: "x2")
        wire.y2 = try getAttribute(element: element, name: "y2")
        wire.width = try getAttribute(element: element, name: "width")
        wire.curve = try getOptionalAttribute(element: element, name: "curve") ?? 0
        wire.layer = try getAttribute(element: element, name: "layer")
        container.wires.append(wire)
    }

    func loadPolygon(container: Board.Container, element: XMLElement) throws {
        let polygon = Board.Polygon()
        polygon.width = try getAttribute(element: element, name: "width")
        polygon.layer = try getAttribute(element: element, name: "layer")
        let elements = try getElements(element: element, query: "vertex")
        for element in elements {
            let vertex = Board.Vertex()
            vertex.x = try getAttribute(element: element, name: "x")
            vertex.y = try getAttribute(element: element, name: "y")
            vertex.curve = try getOptionalAttribute(element: element, name: "curve") ?? 0
            polygon.vertices.append(vertex)
        }
        container.polygons.append(polygon)
    }

    func loadVia(container: Board.Container, element: XMLElement) throws {
        let via = Board.Via()
        via.x = try getAttribute(element: element, name: "x")
        via.y = try getAttribute(element: element, name: "y")
        via.drill = try getAttribute(element: element, name: "drill")
        container.vias.append(via)
    }

    func loadHole(container: Board.Container, element: XMLElement) throws {
        let hole = Board.Hole()
        hole.x = try getAttribute(element: element, name: "x")
        hole.y = try getAttribute(element: element, name: "y")
        hole.drill = try getAttribute(element: element, name: "drill")
        container.holes.append(hole)
    }

    func loadCircle(container: Board.Container, element: XMLElement) throws {
        let circle = Board.Circle()
        circle.x = try getAttribute(element: element, name: "x")
        circle.y = try getAttribute(element: element, name: "y")
        circle.radius = try getAttribute(element: element, name: "radius")
        circle.width = try getAttribute(element: element, name: "width")
        circle.layer = try getAttribute(element: element, name: "layer")
        container.circles.append(circle)
    }

    func parse(_ string: String) throws -> Board.PhysicalUnit {
        guard let value = Float(string) else {
            throw LocalError.attributeValueInvalid("rot", string)
        }
        return Board.PhysicalUnit(value)
    }

    func parseRot(rot: String?, mirror: inout Bool, rotate: inout Board.PhysicalUnit) throws {
        if let rot = rot {
            if rot.hasPrefix("M") {
                mirror = true
                let index = rot.index(rot.startIndex, offsetBy: 2)
                rotate = try parse(String(rot[index...]))
            } else {
                mirror = false
                let index = rot.index(rot.startIndex, offsetBy: 1)
                rotate = try parse(String(rot[index...]))
            }
        }
    }

    func loadSmd(container: Board.Container, element: XMLElement) throws {
        let smd = Board.Smd()
        smd.name = try getAttribute(element: element, name: "name")
        smd.x = try getAttribute(element: element, name: "x")
        smd.y = try getAttribute(element: element, name: "y")
        smd.dx = try getAttribute(element: element, name: "dx")
        smd.dy = try getAttribute(element: element, name: "dy")
        smd.roundness = try getOptionalAttribute(element: element, name: "roundness") ?? 0
        let rot: String? = try getOptionalAttribute(element: element, name: "rot")
        var mirror = false
        var rotate: Board.PhysicalUnit = 0.0
        try parseRot(rot: rot, mirror: &mirror, rotate: &rotate)
        smd.mirror = mirror
        smd.rotate = rotate
        smd.layer = try getAttribute(element: element, name: "layer")
        container.smds.append(smd)
    }

    func loadPad(container: Board.Container, element: XMLElement) throws {
        let pad = Board.Pad()
        pad.x = try getAttribute(element: element, name: "x")
        pad.y = try getAttribute(element: element, name: "y")
        pad.drill = try getAttribute(element: element, name: "drill")
        let rot: String? = try getOptionalAttribute(element: element, name: "rot")
        var mirror = false
        var rotate: Board.PhysicalUnit = 0.0
        try parseRot(rot: rot, mirror: &mirror, rotate: &rotate)
        pad.mirror = mirror
        pad.rotate = rotate
        pad.shape = try getOptionalAttribute(element: element, name: "shape") ?? "round"
        container.pads.append(pad)
    }

    func loadContactRef(container: Board.Container, element: XMLElement) throws {
        let contactRef = Board.ContactRef()
        guard let parent = element.parent as? XMLElement else {
            throw LocalError.invalidElements
        }
        contactRef.signal = try getAttribute(element: parent, name: "name")
        contactRef.element = try getAttribute(element: element, name: "element")
        contactRef.pad = try getAttribute(element: element, name: "pad")
        container.contactRefs.append(contactRef)
    }

    func loadInstance(container: Board.Container, element: XMLElement) throws {
        let instance = Board.Instance()
        instance.name = try getAttribute(element: element, name: "name")
        instance.x = try getAttribute(element: element, name: "x")
        instance.y = try getAttribute(element: element, name: "y")
        let rot: String? = try getOptionalAttribute(element: element, name: "rot")
        var mirror: Bool = false
        var rotate: Board.PhysicalUnit = 0.0
        try parseRot(rot: rot, mirror: &mirror, rotate: &rotate)
        instance.mirror = mirror
        instance.rotate = rotate
        instance.library = try getAttribute(element: element, name: "library")
        instance.package = try getAttribute(element: element, name: "package")
        for attributeElement in try getElements(element: element, query: "attribute") {
            let name: String = try getAttribute(element: attributeElement, name: "name")
            if let value: String = try getOptionalAttribute(element: attributeElement, name: "value") {
                instance.attributes[name] = value
            }
        }
        container.instances.append(instance)
    }

    func loadPackage(element: XMLElement) throws -> Board.Package {
        let package = Board.Package()
        package.name = try getAttribute(element: element, name: "name")
        let elements = try getElements(element: element, query: "*")
        try loadElements(elements: elements, container: package.container)
        return package
    }

    func loadElements(elements: [XMLElement], container: Board.Container) throws {
        for element in elements {
            let name = element.localName
            if "wire" == name {
                try loadWire(container: container, element: element)
            } else
            if "polygon" == name {
                try loadPolygon(container: container, element: element)
            } else
            if "hole" == name {
                try loadHole(container: container, element: element)
            } else
            if "circle" == name {
                try loadCircle(container: container, element: element)
            } else
            if "smd" == name {
                try loadSmd(container: container, element: element)
            } else
            if "pad" == name {
                try loadPad(container: container, element: element)
            } else
            if "contactref" == name {
                try loadContactRef(container: container, element: element)
            }
        }
    }

    func getAttribute(element: XMLElement, name: String) throws -> String {
        guard let node = element.attribute(forName: name) else {
            throw LocalError.attributeNotFound(name)
        }
        guard let value = node.stringValue else {
            throw LocalError.attributeValueNotFound(name)
        }
        return value
    }

    func getOptionalAttribute(element: XMLElement, name: String) throws -> String? {
        if element.attribute(forName: name) == nil {
            return nil
        }
        return try getAttribute(element: element, name: name)
    }

    func getAttribute(element: XMLElement, name: String) throws -> Int {
        let string: String = try getAttribute(element: element, name: name)
        guard let value = Int(string) else {
            throw LocalError.attributeValueInvalid(name, string)
        }
        return value
    }

    func getAttribute(element: XMLElement, name: String) throws -> Board.PhysicalUnit {
        let string: String = try getAttribute(element: element, name: name)
        guard let value = Float(string) else {
            throw LocalError.attributeValueInvalid(name, string)
        }
        return Board.PhysicalUnit(value)
    }

    func getOptionalAttribute(element: XMLElement, name: String) throws -> Board.PhysicalUnit? {
        if element.attribute(forName: name) == nil {
            return nil
        }
        let string: String = try getAttribute(element: element, name: name)
        guard let value = Float(string) else {
            throw LocalError.attributeValueInvalid(name, string)
        }
        return Board.PhysicalUnit(value)
    }

    func getElements(document: XMLDocument, query: String) throws -> [XMLElement] {
        guard let elements = try document.objects(forXQuery: query) as? [XMLElement] else {
            throw LocalError.invalidElements
        }
        return elements
    }

    func getElements(element: XMLElement, query: String) throws -> [XMLElement] {
        guard let elements = try element.objects(forXQuery: query) as? [XMLElement] else {
            throw LocalError.invalidElements
        }
        return elements
    }

    func loadBoard(path: String) throws -> Board {
        guard let xml = try? NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue) as String else {
            throw LocalError.fileNotFound(path)
        }
        guard let document = try? XMLDocument(xmlString: xml, options: XMLNode.Options(rawValue: 0)) else {
            throw LocalError.invalidDocument
        }
        let board = Board()
        let url = URL(fileURLWithPath: path)
        board.path = url.deletingLastPathComponent().path
        board.name = url.deletingPathExtension().lastPathComponent
        let layerElements = try getElements(document: document, query: "./eagle/drawing/board/layers/layer/*")
        for layerElement in layerElements {
            let number: Int = try getAttribute(element: layerElement, name: "number")
            let name: String = try getAttribute(element: layerElement, name: "name")
            NSLog("\(number): \(name)")
        }
        let plainElements = try getElements(document: document, query: "./eagle/drawing/board/plain/*")
        try loadElements(elements: plainElements, container: board.container)
        let signalElements = try getElements(document: document, query: "./eagle/drawing/board/signals/signal/*")
        try loadElements(elements: signalElements, container: board.container)
        let wireElements = try getElements(document: document, query: "./eagle/drawing/board/signals/signal/wire")
        for wireElement in wireElements {
            try loadWire(container: board.container, element: wireElement)
        }
        let viaElements = try getElements(document: document, query: "./eagle/drawing/board/signals/signal/via")
        for viaElement in viaElements {
            try loadVia(container: board.container, element: viaElement)
        }
        let packageElements = try getElements(document: document, query: "./eagle/drawing/board/libraries/library/packages/package")
        for packageElement in packageElements {
            let package = try loadPackage(element: packageElement)
            board.packages[package.name] = package
        }
        let instanceElements = try getElements(document: document, query: "./eagle/drawing/board/elements/element")
        for instanceElement in instanceElements {
            try loadInstance(container: board.container, element: instanceElement)
        }
        return board
    }

    static func load(path: String) throws -> Board {
        let eagle = Eagle()
        return try eagle.loadBoard(path: path)
    }

}
