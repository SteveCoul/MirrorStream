//
//  VideoEncoder.swift
//  MirrorStream
//
//  Created by Harry on 1/27/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation


func NOW() -> Int64 {
    var tv = timeval( tv_sec: 0, tv_usec: 0 )
    var rc : Int64
    
    gettimeofday(UnsafeMutablePointer<timeval>(&tv), nil )
    
    rc = Int64(tv.tv_sec * 1000)
    rc = rc + Int64( tv.tv_usec / 1000 )
    return rc
}

func write_packet( opaque: UnsafeMutableRawPointer?, data: UnsafeMutablePointer<UInt8>?, length: Int32 ) -> Int32 {
    let SELF : VideoEncoder = Unmanaged<VideoEncoder>.fromOpaque( opaque! ).takeUnretainedValue()
    return SELF.writePacket( data: data, length: length )
}

class VideoEncoder {
    
    let ENCODER_BUFFER_SIZE : Int = 4096*188
    var m_width : Int;
    var m_height: Int;
    var m_output_width: Int;
    var m_output_height: Int;
    var m_callback : ( (Data) -> Int )?
    

    var m_io_context_buffer : UnsafeMutablePointer<UInt8>?
    var m_io_context : UnsafeMutablePointer<AVIOContext>?
    var m_format_context : UnsafeMutablePointer<AVFormatContext>?
    var m_output_format : UnsafeMutablePointer<AVOutputFormat>?
    var m_codec : UnsafeMutablePointer<AVCodec>?
    var m_stream : UnsafeMutablePointer<AVStream>?
    var m_codec_context : UnsafeMutablePointer<AVCodecContext>?
    var sws_ctx : OpaquePointer?
    
    var m_base_clock : Int64

    func writePacket( data: UnsafeMutablePointer<UInt8>?, length: Int32 ) -> Int32 {
        let data : Data = Data(bytesNoCopy: data!, count: Int(length), deallocator: .none )
        return Int32( m_callback!( data ) )
    }

    init( width: Int, height: Int, output_width: Int, output_height: Int, write_callback: @escaping ( Data ) -> Int ) {
    
        m_callback = write_callback
        
        m_width = width
        m_height = height
        m_output_width = output_width
        m_output_height = output_height
        
        m_base_clock = NOW()
        
        av_register_all()
        
        let opaque = UnsafeMutableRawPointer( Unmanaged.passUnretained(self).toOpaque())
        
        m_io_context_buffer = av_malloc( ENCODER_BUFFER_SIZE ).assumingMemoryBound( to: UInt8.self )
        m_io_context = avio_alloc_context( m_io_context_buffer, Int32(ENCODER_BUFFER_SIZE), Int32(1), /* opqaue */ opaque, nil, write_packet, nil )
        avformat_alloc_output_context2( &m_format_context, nil, "mpegts", nil )
        m_format_context?.pointee.pb = m_io_context
        m_output_format = m_format_context?.pointee.oformat
        m_output_format?.pointee.video_codec = AV_CODEC_ID_H264
        
        m_codec = avcodec_find_encoder( AV_CODEC_ID_H264 )
        m_stream = avformat_new_stream( m_format_context, nil )
        m_stream?.pointee.id = Int32((m_format_context?.pointee.nb_streams)!-1)
        m_codec_context = avcodec_alloc_context3(m_codec)
        
        m_codec_context?.pointee.codec_id = AV_CODEC_ID_H264
        m_codec_context?.pointee.width = Int32(m_output_width)
        m_codec_context?.pointee.height = Int32(m_output_height)
//        m_stream?.pointee.time_base = m_time_base
        m_codec_context?.pointee.time_base = AVRational( num: 1001, den: 30000 )
        m_codec_context?.pointee.pix_fmt = AV_PIX_FMT_YUV420P
        m_codec_context?.pointee.gop_size = 10
        // av_opt_set( m_codec_context->priv_data, "tune", "zerolatency", 0);
        av_opt_set( m_codec_context?.pointee.priv_data, "x264opts", "repeat-headers=1", 1) // x264 outputs SPS/PSS on each IFrame
        
        if ( avcodec_open2( m_codec_context, m_codec, nil ) < 0 ) {
            print("Failed too open video codec");
        } else if ( avcodec_parameters_from_context( m_stream?.pointee.codecpar, m_codec_context ) < 0 ) {
            print("Failed to copy stream parameters")
        } else if ( avformat_write_header( m_format_context, nil ) < 0 ) {
            print("Failed to setup output file")
        } else {
            print(" I have a video encoder I think" )
            sws_ctx = sws_getContext( Int32(m_width), Int32(m_height), AV_PIX_FMT_BGR0, Int32(m_output_width), Int32(m_output_height), AV_PIX_FMT_YUV420P, SWS_BILINEAR, nil, nil, nil )
        }
    }
    
    deinit {
        newFrame( frame: nil )
        av_write_trailer( m_format_context )
        
        avcodec_free_context( &m_codec_context )
        av_free( m_io_context?.pointee.buffer )
        av_free( m_io_context )
        avformat_free_context( m_format_context )
        sws_freeContext( sws_ctx )
    }
    
    func newFrame( frame:  UnsafeMutablePointer<AVFrame>? ) {
        var got_packet: Int32 = 0
        var pkt : AVPacket = AVPacket()
        var ret : Int32 = 0
        
        av_init_packet( UnsafeMutablePointer<AVPacket>(&pkt) )
        ret = avcodec_encode_video2( m_codec_context, UnsafeMutablePointer<AVPacket>(&pkt), frame, &got_packet )
        if ( ret < 0 ) {
            print("error encoding video frame")
            return
        }
            
        if ( got_packet != 0 ) {
            pkt.stream_index = (m_stream?.pointee.index)!
            ret = av_interleaved_write_frame( m_format_context, UnsafeMutablePointer<AVPacket>(&pkt) )
            if ( ret < 0 ) {
                print("something bad happended during frame write")
            }
        }
    }
    
    func performScaleSWS(  s_data: [UnsafePointer<UInt8>?], s_len: [Int32], d_data:  [UnsafeMutablePointer<UInt8>?], d_len: [Int32] ) {
        sws_scale( sws_ctx!, s_data, s_len, Int32(0), Int32(m_height), d_data, d_len )
    }
    
    func encode( image: Data ) -> Int {
        var frame : UnsafeMutablePointer<AVFrame>?
        
        frame = av_frame_alloc()
        frame?.pointee.width = Int32(m_output_width)
        frame?.pointee.height = Int32(m_output_height)
        frame?.pointee.format = Int32(AV_PIX_FMT_YUV420P.rawValue)
        frame?.pointee.pts = ( NOW() - m_base_clock ) * 90
    
        av_frame_get_buffer( frame, 32 )

        image.withUnsafeBytes { (ptr: UnsafePointer<UInt8> ) in
        
            var s_data = [UnsafePointer<UInt8>?]( repeating: nil, count: 8 )
            var s_len = [Int32]( repeating: 0, count: 8 )

            var d_data = [UnsafeMutablePointer<UInt8>?]( repeating: nil, count: 8 )
            var d_len = [Int32]( repeating: 0, count: 8 )
            
            s_data[0] = ptr
     
            s_len[0] = Int32( m_width * 4 )
            
            d_data.remove( at: 0 ); d_data.insert( frame?.pointee.data.0, at: 0 )
            d_data.remove( at: 1 ); d_data.insert( frame?.pointee.data.1, at: 1 )
            d_data.remove( at: 2 ); d_data.insert( frame?.pointee.data.2, at: 2 )

            d_len.remove( at: 0 ); d_len.insert( (frame?.pointee.linesize.0)!, at: 0 )
            d_len.remove( at: 1 ); d_len.insert( (frame?.pointee.linesize.1)!, at: 1 )
            d_len.remove( at: 2 ); d_len.insert( (frame?.pointee.linesize.2)!, at: 2 )

            performScaleSWS( s_data: s_data, s_len: s_len, d_data: d_data, d_len: d_len )
            
        }
        
        newFrame( frame: frame )
        av_frame_free( &frame )
        return image.count;
    }
    
}

