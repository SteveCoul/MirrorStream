//
//  ffmpegbridge.h
//  MirrorStream
//
//  Created by Harry on 1/23/18.
//  Copyright © 2018 Harry. All rights reserved.
//

#ifndef ffmpegbridge_h
#define ffmpegbridge_h

#include <stdio.h>

typedef int(*WRITE_DATA_CALLBACK)( void* self, uint8_t* data, size_t length );

int CreateFFMPEGx264( const int width, const int height, const int video_width, const int video_height, void* callback_object, WRITE_DATA_CALLBACK callback_function );
int FeedFFMPEGx264( const unsigned char* data, const size_t length );
void DestroyFFMPEGx264( void );

#endif /* ffmpegbridge_h */
