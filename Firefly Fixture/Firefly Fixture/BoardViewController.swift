//
//  BoardViewController.swift
//  Firefly Fixture
//
//  Created by Denis Bohm on 1/10/17.
//  Copyright © 2017 Firefly Design LLC. All rights reserved.
//

import Cocoa

class BoardViewController: NSViewController {

    @IBOutlet var boardPathControl: NSPathControl?
    @IBOutlet var boardView: BoardView?

    let scriptPath = "/Users/denis/sandbox/denisbohm/firefly-ice-mechanical/scripts"

    override func viewDidLoad() {
        super.viewDidLoad()

        boardPathControl?.url = URL(fileURLWithPath: "/Users/denis/sandbox/lumo/hardware/LUMObackMod.brd")
    }

    func rhino(board: Board, scriptPath: String) {
        let rhino = Rhino()
        rhino.board = board
        let td = (scriptPath as NSString).appendingPathComponent("3d") as NSString
        let tdf = td.appendingPathExtension("py")
        if let head = try? NSString(contentsOfFile: tdf!, encoding: String.Encoding.utf8.rawValue) {
            rhino.lines = head as String
        }
        rhino.convert()
        let rd = (scriptPath as NSString).appendingPathComponent(board.name) as NSString
        let rde = rd.deletingPathExtension as NSString
        let output = rde.appendingPathExtension("py")!
        try? rhino.lines.write(toFile: output, atomically: false, encoding: String.Encoding.utf8)
    }
    
    @IBAction func reloadBoard(_ sender: AnyObject) {
        guard let path = boardPathControl?.url?.path else {
            return
        }

        guard let board = try? Eagle.load(path: path) else {
            return
        }
        rhino(board: board, scriptPath: scriptPath)

        let fixture = Fixture(board: board, scriptPath: scriptPath)
        guard let fixturePath = try? fixture.generateTestFixture() else {
            return
        }
        let topPath = "\(board.path)/\(board.name)_top_plate_layout.brd"
        if let topBoard = try? Eagle.load(path: topPath) {
            rhino(board: topBoard, scriptPath: scriptPath)
        }
        let bottomPath = "\(board.path)/\(board.name)_bottom_plate_layout.brd"
        if let bottomBoard = try? Eagle.load(path: bottomPath) {
            rhino(board: bottomBoard, scriptPath: scriptPath)
        }

        boardView?.board = board
        boardView?.fixturePath = fixturePath
    }

}