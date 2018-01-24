//
//  SocketHack.h
//  MirrorStream
//
//  Created by Harry on 1/24/18.
//  Copyright © 2018 Harry. All rights reserved.
//

#ifndef SocketHack_h
#define SocketHack_h

#include <stdbool.h>
#include <stdio.h>
#include <netinet/in.h>
#include <sys/socket.h>

bool StartSocketHack( unsigned int port );
bool WriteSocketHack( const void* ptr, size_t len );

#endif /* SocketHack_h */
