//
//  MirrorStream.swift
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation

class MirrorStream {
    init() {
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
        
        let image : CGImage = CGDisplayCreateImage( displayIDS[0] )!
        
        harry_test( Int32(image.width), Int32(image.height), CFDataGetBytePtr(image.dataProvider?.data)!, UInt32(CFDataGetLength( image.dataProvider?.data )) )
        
    }
    
}
