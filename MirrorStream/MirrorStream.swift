//
//  MirrorStream.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation
import QuartzCore

class MirrorStream {
    
    var file : FileHandle?
    var running : Bool
    var has_stopped : Bool;
    
    init() {
        running = false
        has_stopped = false
    }

    func isrunning() -> Bool {
        return running
    }
    
    func start() {
        stop()
        Thread( target: self, selector: #selector(MirrorStream.run), object: nil ).start()
        print("Started")
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
    
    func test( data : UnsafeMutablePointer<UInt8>, length: Int ) -> Int {
        file?.write( NSData( bytes: data, length: length ) as Data )
        return length;
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

        CreateFFMPEGx264( Int32(image.width), Int32(image.height),
                    Unmanaged.passUnretained(self).toOpaque(),
                    { ( rawSELF: UnsafeMutableRawPointer?, data : UnsafeMutablePointer<UInt8>?, length: Int ) -> (Int32) in
                        let SELF : MirrorStream = Unmanaged.fromOpaque( rawSELF! ).takeUnretainedValue()
                        return (Int32)(SELF.test( data: data!, length: length ));
                    } )
    
        let url : URL = URL( fileURLWithPath: "output.ts" )
        let t = Data()
        if ( FileManager.default.createFile(atPath:  url.path, contents: t, attributes: nil ) == false ) {
            print("Failed to create file?")
        }
        do {
            try file = FileHandle( forWritingTo: url )
        } catch let error as NSError {
            print("File error \(error)")
        }
        
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
