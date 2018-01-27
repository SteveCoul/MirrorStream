//
//  ViewController.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var status: NSTextField!
    @IBOutlet weak var scalewidth: NSTextField!
    @IBOutlet weak var scaleheight: NSTextField!
    @IBOutlet weak var scalemodeenabled: NSButton!
    @IBOutlet weak var pixelmodeenabled: NSButton!
    @IBOutlet weak var pixelheight: NSTextField!
    @IBOutlet weak var pixelwidth: NSTextField!
    @IBOutlet weak var button: NSButton!
    
    let ms = MirrorStream()
    
    @IBAction func onModeSelectChange(_ sender: Any) {
    }
    
    func statusUpdate( text: String ) {
        DispatchQueue.main.async(execute: {
            self.status.stringValue = text
        })
    }
    
    @IBAction func buttonclick(_ sender: NSButton) {
        if ( ms.isrunning() ) {
            ms.stop();
            button.title = "Start"
            status.stringValue = "Idle"
        } else {
            var width : Int;
            var height: Int;
            if ( pixelmodeenabled.state == NSControl.StateValue.on ) {
                width = pixelwidth.integerValue
                height = pixelheight.integerValue
            } else {
                width = 0-scalewidth.integerValue
                height = 0-scaleheight.integerValue
            }
            ms.start( width: width, height: height, status_callback: statusUpdate )
            button.title = "Stop"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        button.title = "Start"
        
        pixelwidth.integerValue = 640
        pixelheight.integerValue = 480
        pixelmodeenabled.state = NSControl.StateValue.on
        scalewidth.integerValue = 1
        scaleheight.integerValue = 1
        status.stringValue = "Idle"
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

