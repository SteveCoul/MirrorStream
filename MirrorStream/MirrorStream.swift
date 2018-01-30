//
//  MirrorStream.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//


// How to move the cursor (later)
//      CGDisplayMoveCursorToPoint( displayIDS[0], CGPoint( x: 0, y: 0 ) )

import Foundation
import QuartzCore

class MirrorStream {
    
    var counter : Int = 0
    var status_callback : ((String)->Void )?
    var output : Output?
    var running : Bool
    var has_stopped : Bool;
    var m_width : Int;
    var m_height : Int;
    
    var vwidth : Int;
    var vheight : Int;

    init() {
        running = false
        has_stopped = false
        output = Output()
        m_width = 0
        m_height = 0
        vwidth = 0
        vheight = 0
    }

    func isrunning() -> Bool {
        return running
    }
    
    func start( width: Int, height: Int, status_callback: @escaping ( String ) -> Void ) {
        m_width = width
        m_height = height
        self.status_callback = status_callback
        stop()
        status_callback( "starting" )
        Thread( target: self, selector: #selector(MirrorStream.run), object: nil ).start()
    }
    
    func dummy( text: String ) {
    }
    
    func start() {
        start( width: 0, height: 0, status_callback: dummy )
    }
    
    func stop() {
        if ( running ) {
            print("Stopping")
            has_stopped = false;
            running = false;
            while ( has_stopped == false ) { };
            print("Stopped")
        }
    }
    
    @objc func run() {
    
        var count : UInt32 = 0
        CGGetActiveDisplayList( 0, nil, &count )
        
        if ( count == 0 ) {
            status_callback!("No displays - forget it")
            return
        }
        
        if ( count != 1 ) {
            print("Mirroring only the first display")
        }
        
        let _displayID = Int( count )
        let displayIDS = UnsafeMutablePointer<CGDirectDisplayID>.allocate( capacity: _displayID )
        
        if ( CGGetActiveDisplayList(count, displayIDS, &count ) != CGError.success ) {
            status_callback!("Failed to get display list")
            return;
        }

        running = true
        
        var image : CGImage = CGDisplayCreateImage( displayIDS[0] )!

        if ( m_width == 0 ) {
            vwidth = image.width;
        } else if ( m_width < 0 ) {
            vwidth = image.width / ( -m_width );
        } else {
            vwidth = m_width;
        }
        
        if ( m_height == 0 ) {
            vheight = image.height;
        } else if ( m_height < 0 ) {
            vheight = image.height / ( -m_height );
        } else {
            vheight = m_height;
        }
        
        var vid = VideoEncoder( width: image.width, height: image.height, output_width: vwidth, output_height: vheight, write_callback: output!.write )
 
        status_callback!("Mirroring")
        
        while running {
            image = CGDisplayCreateImage( displayIDS[0] )!
            
            // TODO - create a context. render this image to it, render a mouse pointer to it, use makeImage() to get an image back that has the cursor on it!
         
            let d : CFData = (image.dataProvider?.data)!
            vid.encode(image: d as Data )
            
        }
        has_stopped = true
    }
    
}
