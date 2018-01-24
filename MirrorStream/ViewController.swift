//
//  ViewController.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    let ms = MirrorStream()
    
    @IBAction func buttonclick(_ sender: NSButton) {
        if ( ms.isrunning() ) {
            ms.stop();
        } else {
            ms.start();
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    


}

