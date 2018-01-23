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
extern int harry_test( const int width, const int height, const unsigned char* data, const unsigned int length, void* self, WRITE_DATA_CALLBACK callback );

#endif /* ffmpegbridge_h */
