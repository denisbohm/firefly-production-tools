//
//  Cortex.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/30/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import ARMSerialWireDebug

protocol Argument {
    
    func registerType() -> Cortex.RegisterType
    func registerValue() -> UInt32
    
}

class Cortex {

    enum RegisterType {
        case Integer // R0-15
        case Float // S0-31
    }
    
    let SWD_DHCSR_STAT_RESET_ST = UInt32(1 << 25)
    let SWD_DHCSR_STAT_RETIRE_ST = UInt32(1 << 24)
    let SWD_DHCSR_STAT_LOCKUP = UInt32(1 << 19)
    let SWD_DHCSR_STAT_SLEEP = UInt32(1 << 18)
    let SWD_DHCSR_STAT_HALT = UInt32(1 << 17)
    let SWD_DHCSR_STAT_REGRDY = UInt32(1 << 16)
    let SWD_DHCSR_CTRL_SNAPSTALL = UInt32(1 << 5)
    let SWD_DHCSR_CTRL_MASKINTS = UInt32(1 << 3)
    let SWD_DHCSR_CTRL_STEP = UInt32(1 << 2)
    let SWD_DHCSR_CTRL_HALT = UInt32(1 << 1)
    let SWD_DHCSR_CTRL_DEBUGEN = UInt32(1 << 0)

    var serialWireDebug = FDSerialWireDebug()
    
    func call(arguments: Argument...) {
        
    }
    
    func setupRegisters() throws {
        var transfers = [FDSerialWireDebugTransfer]()
        var dhcsr: UInt32 = SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN | SWD_DHCSR_CTRL_HALT
        transfers.append(FDSerialWireDebugTransfer.writeMemory(SWD_MEMORY_DHCSR, value: dhcsr)) // halt
        /*
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_R0, value: r0))
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_R1, value: r1))
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_R2, value: r2))
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_R3, value: r3))
        let sp = _stackRange.location + _stackRange.length
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_SP, value: sp))
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_PC, value: pc))
        let lr = _breakLocation | 0x00000001;
        transfers.append(FDSerialWireDebugTransfer.writeRegister(CORTEX_M_REGISTER_LR, value: lr))
        dhcsr = SWD_DHCSR_DBGKEY | SWD_DHCSR_CTRL_DEBUGEN
        if !run {
            dhcsr |= SWD_DHCSR_CTRL_HALT
        }
         */
        if serialWireDebug.maskInterrupts {
            dhcsr |= SWD_DHCSR_CTRL_MASKINTS
        }
        transfers.append(FDSerialWireDebugTransfer.writeMemory(SWD_MEMORY_DHCSR, value: dhcsr)) // run
        return try serialWireDebug.transfer(transfers)
    }
    
}
