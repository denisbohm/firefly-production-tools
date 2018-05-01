//
//  ViewController.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/15/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa
import ARMSerialWireDebug
import FireflyInstruments

class ViewController: NSViewController, Presenter {

    @IBOutlet var messageTextView: NSTextView!
    
    let fixture = Fixture()
    var runner: Runner? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func cancel(_ sender: Any) {
        if let runner = runner {
            runner.cancel()
        }
    }
    
    @IBAction func swd1Identify(_ sender: Any) {
        NSLog("SWD 1 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func spiFlashTest(_ sender: Any) {
        NSLog("SPI flash test")
        run(script: SpiFlashTestScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire1"))
    }
    
    @IBAction func swd2Identify(_ sender: Any) {
        NSLog("SWD 2 identify")
        run(script: IdentifyScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire2"))
    }
    
    @IBAction func displayTest(_ sender: Any) {
        NSLog("display test")
        run(script: DisplayTestScript(fixture: fixture, presenter: self, serialWireInstrumentIdentifier: "SerialWire2"))
    }
    
    func run(script: Script) {
        messageTextView.string = ""
        
        runner = Runner(fixture: fixture, presenter: self, script: script)
        runner?.start()
    }
    
    func showOnMain(message: String) {
        messageTextView.textStorage?.append(NSAttributedString(string: message + "\n"))
        messageTextView.scrollToEndOfDocument(nil)
    }
    
    func show(message: String) {
        DispatchQueue.main.async() {
            self.showOnMain(message: message)
        }
    }
    
    func completedOnMain() {
        runner = nil
    }
    
    func completed() {
        DispatchQueue.main.async() {
            self.completedOnMain()
        }
    }
    
}
