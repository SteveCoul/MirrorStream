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
import AVFoundation


class MirrorStream: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
   
    let video_pid = 512
    
    var counter : Int = 0
    var status_callback : ((String)->Void )?
    var output : Output = Output()
    var running : Bool = false
    var has_stopped : Bool = false
    var m_width : Int = 0
    var m_height : Int = 0
    var m_encoder : VideoEncoder?
    var vwidth : Int = 0
    var vheight : Int = 0
    var buffer : Data = Data()
    var capture_header = false
    var audio_capture_session = AVCaptureSession()
    var audio_dispatch_queue = DispatchQueue( label: "audioq" )
    
    var audio_data = Data()
//NOTUSINGREALPTS    var audio_pts : Double = 0
    var audio_written : Int64 = 0
    var fake_audio_pts : Int64 = 0

    func getAudioDevice() -> AVCaptureDevice {
        for device in AVCaptureDevice.devices() {
            if ( device.localizedName == "Display Audio" ) {
                return device
            }
        }
        return AVCaptureDevice.default(for: AVMediaType.audio )!
    }
   
    func captureOutput(_ output: AVCaptureOutput, didOutput: CMSampleBuffer, from connection: AVCaptureConnection){
        var block_buffer : CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(didOutput, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, 0, &block_buffer)
        
        let buffers = UnsafeBufferPointer<AudioBuffer>(start: &audioBufferList.mBuffers, count: Int(audioBufferList.mNumberBuffers))
        
        for audioBuffer in buffers {
            let frame = audioBuffer.mData?.assumingMemoryBound(to: UInt8.self)
            if ( audio_data.count == 0 ) {
//NOTUSINGREALPTS                let pts = CMSampleBufferGetOutputPresentationTimeStamp( didOutput )
//NOTUSINGREALPTS                audio_pts = Double( pts.value ) / Double( pts.timescale )
            }
            audio_data.append(frame!, count: Int(audioBuffer.mDataByteSize))
        }
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
        
        if ( output.tryAccept( initial_data: buffer ) ) {
            m_encoder?.requestIFrame()
        }
        
        return output.write( data: data )
    }
        
    @objc func run() {
        
        var device_input : AVCaptureDeviceInput?
        var device_output : AVCaptureAudioDataOutput?
        
        do {
            device_input = try AVCaptureDeviceInput( device: getAudioDevice() )
            if ( audio_capture_session.canAddInput( device_input! ) ) {
                audio_capture_session.addInput( device_input! )
            } else {
                print("cannot add input")
            }
        
            device_output = AVCaptureAudioDataOutput()
            device_output?.setSampleBufferDelegate( self, queue: audio_dispatch_queue )
            if ( audio_capture_session.canAddOutput( device_output! ) ) {
                audio_capture_session.addOutput( device_output! )
            } else {
                print("cannot add output")
            }
        } catch {
            print("soemthing bad in audio setup" )
        }

        audio_capture_session.startRunning()
        
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
            
            audio_dispatch_queue.sync {
                
                audio_written = audio_written + Int64( audio_data.count )
                /* 48k 16bit stereo -- 192000 bytes per second */
                fake_audio_pts = ( audio_written * 90 ) / 192
                
                m_encoder?.inputAudio( data: audio_data, pts: fake_audio_pts )
                audio_data.removeAll()
            }
            
            var fps = 0
            fps = (m_encoder?.fps())!
            if ( fps != old_fps ) {
                status_callback!("Mirroring : \(fps) fps" )
                old_fps = fps
            }
        }
        
        audio_capture_session.stopRunning()
        audio_capture_session = AVCaptureSession()

        has_stopped = true
    }
    
}

/*
 
 
 print("Running audio....")
 session.startRunning()
 
 }
 
 */


