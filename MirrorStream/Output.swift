//
//  Output.swift
//  MirrorStream
//
//  Created by Harry on 1/24/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation

class Output {
    
    var file : FileHandle?
    
    init() {
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
    }
    
    deinit {
    }

    func write( data: Data ) -> Int {
        file!.write( data )
        return data.count;
    }
}
