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

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func reloadBoard(_ sender: AnyObject) {
        guard let boardPath = boardPathControl?.url?.path as NSString? else {
            return
        }
        let boardDirectory = boardPath.deletingLastPathComponent
        let boardName = boardPath.lastPathComponent

        let eagle = Eagle()
        guard let board = try? eagle.loadBoard(path: boardPath as String) else {
            return
        }

        let scriptPath = "/Users/denis/sandbox/denisbohm/firefly-ice-mechanical/scripts" as NSString
        let fixture = Fixture(scriptPath: scriptPath as String, boardPath: boardDirectory as String, boardName: boardName, board: board)
        guard let fixturePath = try? fixture.generateTestFixture() else {
            return
        }

        boardView?.board = board
        boardView?.fixturePath = fixturePath

        let rhino = Rhino()
        rhino.board = board
        let td = scriptPath.appendingPathComponent("3d") as NSString
        let tdf = td.appendingPathExtension("py")
        if let head = try? NSString(contentsOfFile: tdf!, encoding: String.Encoding.utf8.rawValue) {
            rhino.lines = head as String
        }
        rhino.convert()
        let rd = scriptPath.appendingPathComponent(boardName) as NSString
        let rde = rd.deletingPathExtension as NSString
        let output = rde.appendingPathExtension("py")!
        try? rhino.lines.write(toFile: output, atomically: false, encoding: String.Encoding.utf8)
    }

}
