//
//  ViewController.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var button: NSButton!
    let ms = MirrorStream()
    
    @IBAction func buttonclick(_ sender: NSButton) {
        if ( ms.isrunning() ) {
            ms.stop();
            button.title = "Start"
        } else {
            ms.start();
            button.title = "Stop"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        button.title = "Start"
    }

    override func viewWillDisappear() {
        NSApplication.shared.terminate(self)
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    


}

