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
    
    init() {
    }

    func test( data : UnsafeMutablePointer<UInt8>, length: Int ) -> Int {
        file?.write( NSData( bytes: data, length: length ) as Data )
        return length;
    }
    

    func run() {
    
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
        
        while true {
            image = CGDisplayCreateImage( displayIDS[0] )!
//TODO implement rate limiting based on this value            print("\(CACurrentMediaTime())")
            FeedFFMPEGx264(CFDataGetBytePtr(image.dataProvider?.data)!, Int(CFDataGetLength( image.dataProvider?.data )))
        }
    }
    
    deinit {
        DestroyFFMPEGx264()
    }
    
}
