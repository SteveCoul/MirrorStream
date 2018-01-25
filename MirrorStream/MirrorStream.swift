//
//  MirrorStream.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//


// How to move the cursor (later)
//      CGDisplayMoveCursorToPoint( displayIDS[0], CGPoint( x: 0, y: 0 ) )

// TODO maybe use CGDisplayStream instead? It can do the YUV conversion for me I believe?

import Foundation
import QuartzCore

class MirrorStream {
    
    var output : Output?
    var running : Bool
    var has_stopped : Bool;
    var m_width : Int;
    var m_height : Int;
    
    init() {
        running = false
        has_stopped = false
        output = Output()
        m_width = 0
        m_height = 0
    }

    func isrunning() -> Bool {
        return running
    }
    
    func start( width: Int, height: Int ) {
        m_width = width
        m_height = height
        stop()
        Thread( target: self, selector: #selector(MirrorStream.run), object: nil ).start()
        print("Started")
    }
    
    func start() {
        start( width: 0, height: 0 )
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
        print("There are \(count) display(s)")
        
        if ( count == 0 ) {
            print("No displays - forget it")
            return
        }
        
        if ( count != 1 ) {
            print("Mirroring only the first display")
        }
        
        let _displayID = Int( count )
        let displayIDS = UnsafeMutablePointer<CGDirectDisplayID>.allocate( capacity: _displayID )
        
        if ( CGGetActiveDisplayList(count, displayIDS, &count ) != CGError.success ) {
            print("Failed to get display list")
            return;
        }

        running = true
        
        var image : CGImage = CGDisplayCreateImage( displayIDS[0] )!

        var vwidth : Int;
        var vheight : Int;

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
        
        CreateFFMPEGx264( Int32(image.width), Int32(image.height), Int32(vwidth), Int32(vheight),
                    Unmanaged.passUnretained(self).toOpaque(),
                    { ( rawSELF: UnsafeMutableRawPointer?, data : UnsafeMutablePointer<UInt8>?, length: Int ) -> (Int32) in
                        let SELF : MirrorStream = Unmanaged.fromOpaque( rawSELF! ).takeUnretainedValue()
                        let output : Data = NSData( bytes: data, length: length ) as Data
                        return (Int32)(SELF.output!.write( data: output ))
                    } )
        
        while running {
            image = CGDisplayCreateImage( displayIDS[0] )!
            
            // TODO - create a context. render this image to it, render a mouse pointer to it, use makeImage() to get an image back that has the cursor on it!
            
            FeedFFMPEGx264(CFDataGetBytePtr(image.dataProvider?.data)!, Int(CFDataGetLength( image.dataProvider?.data )))
        }
        has_stopped = true
    }
    
    deinit {
        DestroyFFMPEGx264()
    }
    
}
