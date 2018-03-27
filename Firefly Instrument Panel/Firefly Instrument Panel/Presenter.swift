//
//  Presenter.swift
//  Firefly Instrument Panel
//
//  Created by Denis Bohm on 3/27/18.
//  Copyright © 2018 Firefly Design LLC. All rights reserved.
//

import Cocoa

protocol Presenter {
    
    func show(message: String)
    func completed()

}
