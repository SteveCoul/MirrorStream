//
//  Output.swift
//  MirrorStream
//
//  Created by Harry on 1/24/18.
//  Copyright © 2018 Harry. All rights reserved.
//

import Foundation

class Output {

    var m_client_queue      = DispatchQueue( label: "OutputClientQueue" )
    var m_buffer_queue      = DispatchQueue( label: "OutputBufferQueue" )
    
    var m_server_fd : Int32 = -1
    var m_clients           = [Int32]()
    var m_buffer            = Data()
    
    init() {
        stopServer()
        startServer()
    }
    
    deinit {
        stopServer()
    }
    
    func stopServer() {
        m_client_queue.sync {
            for client in m_clients {
                if ( client != -1 ) {
                    close( client )
                }
            }
            m_clients = [Int32]()
        }
        close( m_server_fd )
        m_server_fd = -1
        m_buffer_queue.sync {
            m_buffer.removeAll()
            self.process()
        }
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
                        m_buffer_queue.sync { self.process() }
                    }
                }
            }
        }
    }
    
    func tryAccept( initial_data : Data ) -> Bool {
        var sai = sockaddr_in( sin_len: 0,  sin_family: UInt8(0), sin_port: UInt16( 0 ).bigEndian, sin_addr: in_addr( s_addr: 0),  sin_zero: (0,0,0,0,0,0,0,0) )
        var sai_len : socklen_t = socklen_t(MemoryLayout.size(ofValue: sai ))

        let ret = withUnsafeMutablePointer(to: &sai) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(m_server_fd, $0, &sai_len)
            } }

        if ( ret >= 0 ) {
            print("Incoming client " + String(ret) )
            
            
            /*
                    Argh. Swift string literals seem to collapse the sequence \r\n into a single character???
 
                    "\r\n\r\n" has a count of 2 when passed to C
 
                    let response = "HTTP/1.0 200 Okay\r\n\r\n"
            
                    send( ret, response, response.count, 0 )
 
                    fails miserably.
            */

            var response = [UInt8]()
            response += "HTTP/1.0 200 Okay".utf8
            response.append( UInt8(13) )
            response.append( UInt8(10) )
            response.append( UInt8(13) )
            response.append( UInt8(10) )
            send( ret, response, response.count, 0 )

            
            var flag : Int32 = 1
            setsockopt( ret, SOL_SOCKET, SO_NOSIGPIPE, &flag, socklen_t( MemoryLayout.size(ofValue: flag ) ) );
            flag = 1*1024*1024
            setsockopt( ret, SOL_SOCKET, SO_SNDBUF, &flag, socklen_t( MemoryLayout.size(ofValue: flag ) ) );

            flag = 1
            setsockopt( ret, IPPROTO_TCP, TCP_NODELAY, &flag, socklen_t( MemoryLayout.size(ofValue: flag ) ) );

            if ( initial_data.count > 0 ) {
                if ( sendData( fd: ret, data: initial_data ) ) {
                    /* client went immediately away, ignore it */
                    close( ret )
                    return false
                }
            }

            m_client_queue.sync {
                self.m_clients.append( ret )
            }

            return true
        }
        return false
    }
    
    func sendData( fd: Int32, data: Data ) -> Bool {
        var ret : Int = 0
        var rc : Bool = false
    
        rc = data.withUnsafeBytes { ( bptr: UnsafePointer<UInt8> ) -> Bool in
            let raw = UnsafeRawPointer( bptr )
            ret = send( fd, raw, data.count, 0 )
            if ( ret < 0 ) {
                if ( errno == EPIPE ) {
                    print("Client " + String( fd ) + " gone" )
                    return true
                } else {
                    print("Lost some data sending to " + String( fd ) )
                }
            }
            return false
        }
        return rc
    }
    
    func write( data: Data ) -> Int {
        m_buffer_queue.sync {
            self.m_buffer.append( data )
        }
        m_buffer_queue.async {
            self.process()
        }
        return data.count
    }
    
    func process() {
        var to_send = Data()
        
        if ( m_buffer.count > 0 ) {
            // For now, take all the data and block on sending, later may just take chunks
            to_send = m_buffer
            m_buffer = Data()
        }
        
        if ( to_send.count > 0 ) {
            m_client_queue.sync {
                if ( m_clients.count > 0 ) {
                    for idx in 0...m_clients.count-1 {
                        if ( sendData( fd: m_clients[ idx ], data: to_send ) == true ) {
                            close( m_clients[idx] )
                            m_clients[idx] = -1
                        }
                    }
                    m_clients = m_clients.filter { $0 != -1 }
                }
            }
        }
        
    }
}
