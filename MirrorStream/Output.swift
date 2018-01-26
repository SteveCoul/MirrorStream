//
//  Output.swift
//  MirrorStream
//
//  Created by Harry on 1/24/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation

class Output {

    init() {
        StartSocketHack( 32088 );
    }
    
    func write( data: Data ) -> Int {
        var rc : Int = -1
        data.withUnsafeBytes({ (u8Ptr: UnsafePointer<UInt8>) in
            if ( WriteSocketHack( u8Ptr, data.count ) ) {
                rc = data.count
            }
        })
        return rc
    }
    
    func bitrate() -> Int {
        return 0
    }
}
