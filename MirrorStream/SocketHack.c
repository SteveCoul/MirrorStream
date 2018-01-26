//
//  SocketHack.c
//  MirrorStream
//
//  Created by Harry on 1/24/18.
//  Copyright © 2018 Harry. All rights reserved.
//
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "SocketHack.h"

// Does not exist on Mac :-(
#define MSG_NOSIGNAL 0

static int server_fd = -1;
static int clients[ 1024 ];

bool StartSocketHack( unsigned int port ) {
    int i;
    int flag = 1;
    
    for ( i = 0; i < sizeof(clients)/sizeof(clients[0]); i++ ) {
        clients[i] = -1;
    }
    
    struct sockaddr_in sai;
    memset( &sai, 0, sizeof(sai) );
    
    sai.sin_family = AF_INET;
    sai.sin_port = htons( port );
    sai.sin_addr.s_addr = htonl( INADDR_ANY );
    
    server_fd = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
    if ( server_fd < 0 ) {
        fprintf( stderr, "Failed to create server socket\n" );
    } else if ( bind( server_fd, (const struct sockaddr*)&sai, sizeof(sai))< 0 ) {
        fprintf( stderr, "Failed to bind server socket [%s]\n", strerror(errno) );
        (void)close( server_fd );
    } else if ( listen( server_fd, 1 ) < 0 ) {
        fprintf( stderr, "Failed to listen on socket\n" );
        (void)close( server_fd );
    } else if ( fcntl(server_fd, F_SETFL, fcntl(server_fd, F_GETFL, 0) | O_NONBLOCK) < 0 ) {
        fprintf( stderr, "Failed to make socket non blocking\n" );
        (void)close( server_fd );
    } else if ( setsockopt(server_fd, SOL_SOCKET, SO_REUSEPORT, &flag, sizeof(flag) ) < 0 ) {
        fprintf( stderr, "Failed to mark socket as reuseport\n" );
        (void)close( server_fd );
    } else {
        fprintf( stderr, "we have a server socket\n" );
    }
    return server_fd >= 0;
}

// hackery. Nobody can connect or should if we're not running anything and if we're running we'll call this pretty frequently
// so I'll look for new client connections here too and save me a thread.
bool WriteSocketHack( const void* ptr, size_t len ) {
    struct sockaddr_in sai;
    socklen_t sai_len = sizeof(sai);
    int cfd;
    int i;
    
    memset( &sai, 0, sizeof(sai) );
    
    cfd = accept( server_fd, (struct sockaddr*)&sai, &sai_len );
    if ( cfd >= 0 ) {
        fprintf( stderr, "Incoming client %d\n", cfd );
        for ( i = 0; i < sizeof(clients)/sizeof(clients[0]); i++ ) {
            if ( clients[i] == -1 ) {
                clients[i] = cfd;
                // TODO read/drain incoming http request.
                const char* resp = "HTTP/1.0 200 Okay\r\n\r\n";
                (void)write( clients[i], resp, strlen(resp) );
                
                int flag = 1; (void)setsockopt(cfd, SOL_SOCKET, SO_NOSIGPIPE, &flag, sizeof(flag) );  // because we don't have MSG_NOSIGNAL
                
                flag = 1*1024*1024; (void)setsockopt( cfd, SOL_SOCKET, SO_SNDBUF, &flag, sizeof(flag) );
                
                break;
            }
        }
        if ( i == sizeof(clients)/sizeof(clients[0]) ) {
            fprintf( stderr, "Ignoring client connect - too many active\n" );
        }
    }
    for ( i = 0; i < sizeof(clients)/sizeof(clients[0]); i++ ) {
        if ( clients[i] != -1 ) {
            if ( send( clients[i], ptr, len, MSG_NOSIGNAL ) < 0 ) {
                if ( errno == EPIPE ) {
                    fprintf( stderr, "client %d gone\n", clients[i] );
                    (void)close( clients[i] );
                    clients[i] = -1;
                } else {
                    fprintf( stderr, "socket error : %s : we've lost some data for now\n", strerror(errno) );
                }
            }
        }
    }
            
    return true;
}




