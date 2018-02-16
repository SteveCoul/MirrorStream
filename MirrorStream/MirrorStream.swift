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
   
    let video_pid = 512
    
    var counter : Int = 0
    var status_callback : ((String)->Void )?
    var output : Output?
    var running : Bool
    var has_stopped : Bool;
    var m_width : Int;
    var m_height : Int;
    var m_encoder : VideoEncoder?
    var vwidth : Int;
    var vheight : Int;
    var buffer : Data = Data()
    var capture_header = false
    
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
    
    /*
        The incoming stream will pass PAT/PMT ( and probably SDT knowing ffmpeg ) periodically.
        The incoming stream to this point may not be packet aligned.
        A connection can occur over HTTP at any point.
 
        We want, a connection to get a valid PAT and PMT, then data starting at at least a TS packet boundary and ideally an iframe.
 
        So, we're going to massage the stream.
 
        First, during initial startup we'll keep PAT and PMT packets ( basically buffer everything from the encoder until we see something other than PAT,PMT ). ( N.B actually, look for first video packet )
                This buffer will sent to the output chain if tryAccept() passes, meaning the new stream will get them. existing http connections will see an extra PAT/PMT ( probably with incorrect TS CC counters )
                but I can live with that for now. I don't want the output class to know anything about mpeg ts. Later I'll probably just filter PAT/PMT from the output after I get started, not technically mpeg but
                probably fine.
     */
    
    func write( data: Data ) -> Int {
     
        if ( ( data.count % 188 ) != 0 ) {
            print("FIXME - no packet aligned writes.")
        }

        if ( data[0] != 0x47 ) {
            print("Non MPEG")
        }
        
        if ( capture_header ) {
            for i in stride( from: 0, to: data.count, by: 188 ) {
                var pid : Int = Int( data[ i+1 ] & 0x1F )
                pid = ( pid << 8 ) | Int( data[ i+2 ] )
                
                if ( pid != video_pid ) {
                    print("Initial data, packet of pid \(pid) from source \(i)")
                    buffer.append( data.subdata( in: i..<(i+188)))
                } else {
                    capture_header = false
                    break
                }
            }
        }
        
        if ( output!.tryAccept( initial_data: buffer ) ) {
            m_encoder?.requestIFrame()
        }
        
        return output!.write( data: data )
    }
        
    @objc func run() {
    
        buffer.removeAll()
        capture_header = true
        
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
        
        m_encoder = VideoEncoder( pmt_pid: 256, video_pid: video_pid, width: image.width, height: image.height, output_width: vwidth, output_height: vheight, write_callback: write )
 
        status_callback!("Mirroring")
        
        var old_fps = m_encoder?.fps()
        
        while running {
            image = CGDisplayCreateImage( displayIDS[0] )!
            
            // TODO - create a context. render this image to it, render a mouse pointer to it, use makeImage() to get an image back that has the cursor on it!
         
            let d : CFData = (image.dataProvider?.data)!
            m_encoder?.input(image: d as Data )
            
            var fps = 0
            fps = (m_encoder?.fps())!
            if ( fps != old_fps ) {
                status_callback!("Mirroring : \(fps) fps" )
                old_fps = fps
            }
        }
        has_stopped = true
    }
    
}
