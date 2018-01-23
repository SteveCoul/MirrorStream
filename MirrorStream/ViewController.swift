//
//  ViewController.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @objc func thread() {
        let fred = MirrorStream()
        fred.run()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Thread( target: self, selector: #selector(ViewController.thread), object: nil ).start()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

