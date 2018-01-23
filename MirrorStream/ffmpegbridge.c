//
//  ffmpegbridge.c
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

#include <stdint.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"

#include "libavformat/avformat.h"

#pragma clang diagnostic pop

#include "ffmpegbridge.h"

AVIOContext*            m_io_context;
unsigned char*          m_io_context_buffer;
static const size_t     ENCODER_BUFFER_SIZE = 4096*188;
AVOutputFormat*         m_output_format;
AVFormatContext*        m_format_context;
AVCodec*                m_codec;
AVCodecContext*         m_codec_context;
AVStream*               m_stream;
enum AVPixelFormat           m_pixel_format;
int                     m_width;
int                     m_height;
AVRational              m_time_base;
int                     m_quality;

static
void add_stream( enum AVCodecID codec_id) {
    
    /* find the encoder */
    m_codec = avcodec_find_encoder(codec_id);
    if (!m_codec) {
        fprintf( stderr, "Could not find encoder for '%s'\n", avcodec_get_name(codec_id));
        return;
    }
    
    m_stream = avformat_new_stream(m_format_context, NULL);
    if (!m_stream) {
        fprintf( stderr, "Could not allocate stream\n");
        return;
    }
    m_stream->id = m_format_context->nb_streams-1;
    m_codec_context = avcodec_alloc_context3(m_codec);
    if (!m_codec_context) {
        fprintf( stderr, "Could not alloc an encoding context\n");
        return;
    }
    
    m_codec_context->codec_id = codec_id;
    m_codec_context->width    = m_width;
    m_codec_context->height   = m_height;
    m_stream->time_base = m_time_base;
    m_codec_context->time_base       = (AVRational){1001, 30000};   /// \todo get the proper framerate/timing from source video and pass it into encoder
    m_codec_context->gop_size      = 99999;
    m_codec_context->pix_fmt       = m_pixel_format;
    
    /* Some formats want stream headers to be separate. */
    if (m_format_context->oformat->flags & AVFMT_GLOBALHEADER)
        m_codec_context->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
}

static
int aviowrite_wrapper(void *opaque, uint8_t *buf, int buf_size ) {
    fprintf( stderr, "TODO - write data\n");
    return -1;
}

static
int init( void ) {
    
    int ret;
    AVDictionary *opts = NULL;
    
    av_register_all();
    
    m_io_context_buffer = (uint8_t*)av_malloc( ENCODER_BUFFER_SIZE );
    if ( m_io_context_buffer == NULL ) {
        fprintf( stderr, "Failed to alloc context buffer\n" );
        ret = -1;
    } else {
        
        m_io_context = avio_alloc_context( m_io_context_buffer, ENCODER_BUFFER_SIZE, 1, NULL, NULL, &aviowrite_wrapper, NULL );
        if ( !m_io_context ) {
            fprintf( stderr, "Failed to allocate IO context\n" );
            ret = -1;
        } else {
            
            avformat_alloc_output_context2(&m_format_context, NULL, "mpegts", NULL );
            if (!m_format_context) {
                fprintf( stderr, "Failed to allocate output context\n");
                ret = -1;
            } else {
                
                m_format_context->pb = m_io_context;
                m_output_format = m_format_context->oformat;
                m_output_format->video_codec = AV_CODEC_ID_H264;
                //m_output_format->video_codec = AV_CODEC_ID_MPEG4;
                
                add_stream( m_output_format->video_codec);
                
                ret = avcodec_open2(m_codec_context, m_codec, &opts);
                if (ret < 0) {
                    fprintf( stderr, "Could not open video codec\n" );
                    ret = -1;
                } else {
                    
                    ret = avcodec_parameters_from_context(m_stream->codecpar, m_codec_context);
                    if (ret < 0) {
                        fprintf( stderr, "Could not copy the stream parameters\n");
                        ret = -1;
                    } else {
                        ret = avformat_write_header(m_format_context, &opts);
                        if (ret < 0) {
                            fprintf( stderr, "Error occurred when opening output file\n" );
                            ret = -1;
                        } else {
                            printf("I think I have a video encoder!\n");
                            ret = 0;
                        }
                    }
                }
            }
        }
    }
    return ret;
}

void newFrame( AVFrame* frame ) {
    int got_packet = 0;
    AVPacket pkt = { 0 };
    int ret;
    
    printf("Write frame\n");
    
    do {
        av_init_packet(&pkt);
        
        ret = avcodec_encode_video2(m_codec_context, &pkt, frame, &got_packet);
        if (ret < 0) {
            fprintf( stderr, "Error encoding video frame\n" );
            return;
        }
        
        if (got_packet) {
            pkt.stream_index = m_stream->index;
            ret = av_interleaved_write_frame(m_format_context, &pkt);
            // ERROR CHECK
        }
    } while ( got_packet && !frame );
}


void done() {
    av_write_trailer(m_format_context);
    
    avcodec_free_context(&m_codec_context);
    
    if ( m_io_context ) {
        av_freep( &(m_io_context->buffer) );
        av_freep( &m_io_context );
    }
    avformat_free_context(m_format_context);
    printf("Shutdown\n");
}

int harry_test( const int width, const int height, const unsigned char* data, const unsigned int length ) {

    const uint32_t* source = (const uint32_t*)data;
    
    printf("I'm in C - %d x %d : %p %u\n", width, height, data, length );
    
    printf("%08X %08X %08X %08X\n", source[0], source[1], source[2], source[3] );
    
    m_pixel_format = AV_PIX_FMT_YUV420P;
    m_width = width;
    m_height = height;
    
    init();
   
    AVFrame* frame = av_frame_alloc();
    frame->width = m_width;
    frame->height = m_height;
    frame->format = m_pixel_format;
    frame->pts = 0;
    av_frame_get_buffer( frame, 32 );
    
    /* Copy image data and convert from ARGB to YUV */
    
    newFrame( frame );
    
    av_frame_free( &frame );
        
        newFrame( NULL );
        
    
    done();
    
    return 0;
}
