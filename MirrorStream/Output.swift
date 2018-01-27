//
//  Output.swift
//  MirrorStream
//
//  Created by Harry on 1/24/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation

class Output {

    var m_server_fd : Int32 = -1
    var m_clients = [Int32]()
    
    init() {
        stopServer()
        startServer()
    }
    
    deinit {
        stopServer()
    }
    
    func stopServer() {
        for client in m_clients {
            if ( client != -1 ) {
                close( client )
            }
        }
        m_clients = [Int32]()
        close( m_server_fd )
        m_server_fd = -1
    }
    
    func startServer() {
        m_server_fd = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP )
        if ( m_server_fd < 0 ) {
            print("Failed to create server socket, nobody will get any video today")
        } else {
            var flag : Int32 = 1
            
            if ( setsockopt( m_server_fd, SOL_SOCKET, SO_REUSEPORT, &flag, socklen_t( MemoryLayout.size(ofValue: flag ) ) ) < 0 ) {
                print("Failed to set socket reuse")
                close( m_server_fd )
                m_server_fd = -1
            } else {
            
                var sai = sockaddr_in( sin_len: 0,  sin_family: UInt8(AF_INET), sin_port: UInt16( 32088 ).bigEndian, sin_addr: in_addr( s_addr: 0),  sin_zero: (0,0,0,0,0,0,0,0) )
            
                let ret = withUnsafeMutablePointer(to: &sai) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        bind(m_server_fd, $0, socklen_t(MemoryLayout.size(ofValue: sai)))
                    } }
                if ( ret < 0 ) {
                    print("Failed to bind socket")
                    close( m_server_fd )
                    m_server_fd = -1
                } else if ( listen( m_server_fd, 1 ) < 0 ) {
                    print("Server not listening")
                } else {
                    var flags = fcntl( m_server_fd, F_GETFL, 0 )
                    flags = flags | O_NONBLOCK
                    if ( fcntl( m_server_fd, F_SETFL, flags ) < 0 ) {
                        print("Failed to make server non blocking")
                    } else {
                        print("TCP Server socket established")
                    }
                }
            }
        }
    }
    
    func tryAccept() {
        var sai = sockaddr_in( sin_len: 0,  sin_family: UInt8(0), sin_port: UInt16( 0 ).bigEndian, sin_addr: in_addr( s_addr: 0),  sin_zero: (0,0,0,0,0,0,0,0) )
        var sai_len : socklen_t = socklen_t(MemoryLayout.size(ofValue: sai ))

        let ret = withUnsafeMutablePointer(to: &sai) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(m_server_fd, $0, &sai_len)
            } }

        if ( ret >= 0 ) {
            print("Incoming client " + String(ret) )
            
            var response = "HTTP/1.0 200 Okay\r\n\r\n".utf8
            
            send( ret, &response, response.count, 0 )
            
            var flag : Int32 = 1
            setsockopt( ret, SOL_SOCKET, SO_NOSIGPIPE, &flag, socklen_t( MemoryLayout.size(ofValue: flag ) ) );
            flag = 1*1024*1024
            setsockopt( ret, SOL_SOCKET, SO_SNDBUF, &flag, socklen_t( MemoryLayout.size(ofValue: flag ) ) );

            self.m_clients.append( ret )
        }
    }
    
    func write( data: Data ) -> Int {
        tryAccept()
        if ( m_clients.count > 0 ) {
            for idx in 0...m_clients.count-1 {
                let client = m_clients[ idx ]
                var ret : Int = 0
                data.withUnsafeBytes { ( bptr: UnsafePointer<UInt8> ) in
                    let raw = UnsafeRawPointer( bptr )
                    ret = send( client, raw, data.count, 0 )
                    if ( ret < 0 ) {
                        if ( errno == EPIPE ) {
                            print("Client " + String( client ) + " gone" )
                            close( client )
                            m_clients[ idx ] = -1
                        } else {
                            print("Lost some data sending to " + String( client ) )
                        }
                    }
                }
            }
            m_clients = m_clients.filter { $0 != -1 }
        }
        return data.count
    }
}
