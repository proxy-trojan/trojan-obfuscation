/*
 * This file is part of the trojan project.
 * Trojan is an unidentifiable mechanism that helps you bypass GFW.
 * Copyright (C) 2017-2020  The Trojan Authors.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "clientsession.h"
#include "proto/trojanrequest.h"
#include "proto/udppacket.h"
#include "ssl/sslsession.h"
#include "obfuscation/obfuscation_manager.h"
#include "core/rule_engine.h"
using namespace std;
using namespace boost::asio::ip;
using namespace boost::asio::ssl;

ClientSession::ClientSession(const Config &config, boost::asio::io_context &io_context, context &ssl_context) :
    Session(config, io_context),
    status(HANDSHAKE),
    is_direct(false),
    first_packet_recv(false),
    in_socket(io_context),
    out_socket(io_context, ssl_context),
    direct_socket(io_context),
    target_port(0) {}

tcp::socket& ClientSession::accept_socket() {
    return in_socket;
}

void ClientSession::start() {
    boost::system::error_code ec;
    start_time = time(nullptr);
    in_endpoint = in_socket.remote_endpoint(ec);
    if (ec) {
        destroy();
        return;
    }
    auto ssl = out_socket.native_handle();
    
    // Apply obfuscation if enabled
    if (config.obfuscation.enabled) {
        auto& obfuscation = get_obfuscation_manager();
        obfuscation.apply_client_obfuscation(ssl);
    }
    
    if (!config.ssl.sni.empty()) {
        SSL_set_tlsext_host_name(ssl, config.ssl.sni.c_str());
    }
    if (config.ssl.reuse_session) {
        SSL_SESSION *session = SSLSession::get_session();
        if (session) {
            SSL_set_session(ssl, session);
        }
    }
    in_async_read();
}

void ClientSession::in_async_read() {
    auto self = shared_from_this();
    in_socket.async_read_some(boost::asio::buffer(in_read_buf.data(), in_read_buf.size()), [this, self](const boost::system::error_code error, size_t length) {
        if (error == boost::asio::error::operation_aborted) {
            return;
        }
        if (error) {
            destroy();
            return;
        }
        in_recv(string((const char*)in_read_buf.data(), length));
    });
}

void ClientSession::in_async_write(const string &data) {
    auto self = shared_from_this();
    auto data_copy = make_shared<string>(data);
    boost::asio::async_write(in_socket, boost::asio::buffer(*data_copy), [this, self, data_copy](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        in_sent();
    });
}

void ClientSession::out_async_read() {
    auto self = shared_from_this();
    out_socket.async_read_some(boost::asio::buffer(out_read_buf.data(), out_read_buf.size()), [this, self](const boost::system::error_code error, size_t length) {
        if (error) {
            destroy();
            return;
        }
        out_recv(string((const char*)out_read_buf.data(), length));
    });
}

void ClientSession::out_async_write(const string &data) {
    auto self = shared_from_this();
    auto data_copy = make_shared<string>(data);
    boost::asio::async_write(out_socket, boost::asio::buffer(*data_copy), [this, self, data_copy](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        out_sent();
    });
}

// Direct connection methods
void ClientSession::direct_async_read() {
    auto self = shared_from_this();
    direct_socket.async_read_some(boost::asio::buffer(out_read_buf.data(), out_read_buf.size()), [this, self](const boost::system::error_code error, size_t length) {
        if (error) {
            destroy();
            return;
        }
        direct_recv(string((const char*)out_read_buf.data(), length));
    });
}

void ClientSession::direct_async_write(const string &data) {
    auto self = shared_from_this();
    auto data_copy = make_shared<string>(data);
    boost::asio::async_write(direct_socket, boost::asio::buffer(*data_copy), [this, self, data_copy](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        direct_sent();
    });
}

void ClientSession::direct_recv(const string &data) {
    if (data.length() > out_read_buf.size() * 0.75) {
        resize_buffer(out_read_buf, data.length() * 2);
    }
    
    if (status == DIRECT_FORWARD) {
        recv_len += data.length();
        in_async_write(data);
    }
}

void ClientSession::direct_sent() {
    if (status == DIRECT_FORWARD) {
        in_async_read();
    }
}

void ClientSession::udp_async_read() {
    auto self = shared_from_this();
    udp_socket.async_receive_from(boost::asio::buffer(udp_read_buf.data(), udp_read_buf.size()), udp_recv_endpoint, [this, self](const boost::system::error_code error, size_t length) {
        if (error == boost::asio::error::operation_aborted) {
            return;
        }
        if (error) {
            destroy();
            return;
        }
        udp_recv(string((const char*)udp_read_buf.data(), length), udp_recv_endpoint);
    });
}

void ClientSession::udp_async_write(const string &data, const udp::endpoint &endpoint) {
    auto self = shared_from_this();
    auto data_copy = make_shared<string>(data);
    udp_socket.async_send_to(boost::asio::buffer(*data_copy), endpoint, [this, self, data_copy](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        udp_sent();
    });
}

void ClientSession::in_recv(const string &data) {
    if (data.length() > in_read_buf.size() * 0.75) {
        resize_buffer(in_read_buf, data.length() * 2);
    }
    
    switch (status) {
        case HANDSHAKE: {
            if (data.length() < 2 || data[0] != 5 || data.length() != (unsigned int)(unsigned char)data[1] + 2) {
                Log::log_with_endpoint(in_endpoint, "unknown protocol", Log::ERROR);
                destroy();
                return;
            }
            bool has_method = false;
            for (int i = 2; i < data[1] + 2; ++i) {
                if (data[i] == 0) {
                    has_method = true;
                    break;
                }
            }
            if (!has_method) {
                Log::log_with_endpoint(in_endpoint, "unsupported auth method", Log::ERROR);
                in_async_write(string("\x05\xff", 2));
                status = INVALID;
                return;
            }
            in_async_write(string("\x05\x00", 2));
            break;
        }
        case REQUEST: {
            if (data.length() < 7 || data[0] != 5 || data[2] != 0) {
                Log::log_with_endpoint(in_endpoint, "bad request", Log::ERROR);
                destroy();
                return;
            }
            
            // Parse SOCKS5 request to get target address
            TrojanRequest req;
            string temp_buf = config.password.cbegin()->first + "\r\n" + data[1] + data.substr(3) + "\r\n";
            if (req.parse(temp_buf) == -1) {
                Log::log_with_endpoint(in_endpoint, "unsupported command", Log::ERROR);
                in_async_write(string("\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00", 10));
                status = INVALID;
                return;
            }
            
            target_host = req.address.address;
            target_port = req.address.port;
            is_udp = req.command == TrojanRequest::UDP_ASSOCIATE;
            
            // Check routing rules
            RuleAction action = get_rule_engine().match(target_host, target_port);
            
            if (action == RuleAction::REJECT) {
                Log::log_with_endpoint(in_endpoint, "REJECTED connection to " + target_host + ':' + to_string(target_port), Log::INFO);
                in_async_write(string("\x05\x02\x00\x01\x00\x00\x00\x00\x00\x00", 10));
                status = INVALID;
                return;
            }
            
            is_direct = (action == RuleAction::DIRECT);
            
            if (is_udp) {
                // UDP associate - always through proxy for now
                is_direct = false;
                udp::endpoint bindpoint(in_socket.local_endpoint().address(), 0);
                boost::system::error_code ec;
                udp_socket.open(bindpoint.protocol(), ec);
                if (ec) {
                    destroy();
                    return;
                }
                udp_socket.bind(bindpoint);
                Log::log_with_endpoint(in_endpoint, "requested UDP associate to " + target_host + ':' + to_string(target_port) + ", open UDP socket " + udp_socket.local_endpoint().address().to_string() + ':' + to_string(udp_socket.local_endpoint().port()) + " for relay", Log::INFO);
                in_async_write(string("\x05\x00\x00", 3) + SOCKS5Address::generate(udp_socket.local_endpoint()));
            } else {
                string route_type = is_direct ? "DIRECT" : "PROXY";
                Log::log_with_endpoint(in_endpoint, "[" + route_type + "] " + target_host + ':' + to_string(target_port), Log::INFO);
                in_async_write(string("\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00", 10));
            }
            
            // Store the trojan request for proxy mode
            if (!is_direct) {
                out_write_buf = temp_buf;
            }
            break;
        }
        case CONNECT: {
            sent_len += data.length();
            first_packet_recv = true;
            if (is_direct) {
                // Buffer data for direct connection
                out_write_buf += data;
            } else {
                out_write_buf += data;
            }
            break;
        }
        case FORWARD: {
            sent_len += data.length();
            out_async_write(data);
            break;
        }
        case DIRECT_FORWARD: {
            sent_len += data.length();
            direct_async_write(data);
            break;
        }
        case UDP_FORWARD: {
            Log::log_with_endpoint(in_endpoint, "unexpected data from TCP port", Log::ERROR);
            destroy();
            break;
        }
        default: break;
    }
}

void ClientSession::in_sent() {
    switch (status) {
        case HANDSHAKE: {
            status = REQUEST;
            in_async_read();
            break;
        }
        case REQUEST: {
            status = CONNECT;
            in_async_read();
            if (is_udp) {
                udp_async_read();
            }
            
            auto self = shared_from_this();
            
            if (is_direct) {
                // Direct connection - connect to target directly
                resolver.async_resolve(target_host, to_string(target_port), [this, self](const boost::system::error_code error, const tcp::resolver::results_type& results) {
                    if (error || results.empty()) {
                        Log::log_with_endpoint(in_endpoint, "cannot resolve " + target_host + ": " + error.message(), Log::ERROR);
                        destroy();
                        return;
                    }
                    auto iterator = results.begin();
                    Log::log_with_endpoint(in_endpoint, "[DIRECT] " + target_host + " resolved to " + iterator->endpoint().address().to_string(), Log::ALL);
                    
                    boost::system::error_code ec;
                    direct_socket.open(iterator->endpoint().protocol(), ec);
                    if (ec) {
                        destroy();
                        return;
                    }
                    if (config.tcp.no_delay) {
                        direct_socket.set_option(tcp::no_delay(true));
                    }
                    if (config.tcp.keep_alive) {
                        direct_socket.set_option(boost::asio::socket_base::keep_alive(true));
                    }
                    
                    direct_socket.async_connect(*iterator, [this, self](const boost::system::error_code error) {
                        if (error) {
                            Log::log_with_endpoint(in_endpoint, "cannot connect to " + target_host + ':' + to_string(target_port) + ": " + error.message(), Log::ERROR);
                            destroy();
                            return;
                        }
                        Log::log_with_endpoint(in_endpoint, "[DIRECT] connected to " + target_host + ':' + to_string(target_port));
                        
                        boost::system::error_code ec;
                        if (!first_packet_recv) {
                            in_socket.cancel(ec);
                        }
                        status = DIRECT_FORWARD;
                        direct_async_read();
                        if (!out_write_buf.empty()) {
                            direct_async_write(out_write_buf);
                            out_write_buf.clear();
                        } else {
                            in_async_read();
                        }
                    });
                });
            } else {
                // Proxy connection - connect to trojan server
                resolver.async_resolve(config.remote_addr, to_string(config.remote_port), [this, self](const boost::system::error_code error, const tcp::resolver::results_type& results) {
                    if (error || results.empty()) {
                        Log::log_with_endpoint(in_endpoint, "cannot resolve remote server hostname " + config.remote_addr + ": " + error.message(), Log::ERROR);
                        destroy();
                        return;
                    }
                    auto iterator = results.begin();
                    Log::log_with_endpoint(in_endpoint, config.remote_addr + " is resolved to " + iterator->endpoint().address().to_string(), Log::ALL);
                    boost::system::error_code ec;
                    out_socket.next_layer().open(iterator->endpoint().protocol(), ec);
                    if (ec) {
                        destroy();
                        return;
                    }
                    if (config.tcp.no_delay) {
                        out_socket.next_layer().set_option(tcp::no_delay(true));
                    }
                    if (config.tcp.keep_alive) {
                        out_socket.next_layer().set_option(boost::asio::socket_base::keep_alive(true));
                    }
#ifdef TCP_FASTOPEN_CONNECT
                    if (config.tcp.fast_open) {
                        using fastopen_connect = boost::asio::detail::socket_option::boolean<IPPROTO_TCP, TCP_FASTOPEN_CONNECT>;
                        boost::system::error_code ec;
                        out_socket.next_layer().set_option(fastopen_connect(true), ec);
                    }
#endif // TCP_FASTOPEN_CONNECT
                    out_socket.next_layer().async_connect(*iterator, [this, self](const boost::system::error_code error) {
                        if (error) {
                            Log::log_with_endpoint(in_endpoint, "cannot establish connection to remote server " + config.remote_addr + ':' + to_string(config.remote_port) + ": " + error.message(), Log::ERROR);
                            destroy();
                            return;
                        }
                        out_socket.async_handshake(stream_base::client, [this, self](const boost::system::error_code error) {
                            if (error) {
                                Log::log_with_endpoint(in_endpoint, "SSL handshake failed with " + config.remote_addr + ':' + to_string(config.remote_port) + ": " + error.message(), Log::ERROR);
                                destroy();
                                return;
                            }
                            Log::log_with_endpoint(in_endpoint, "[PROXY] tunnel established for " + target_host + ':' + to_string(target_port));
                            if (config.ssl.reuse_session) {
                                auto ssl = out_socket.native_handle();
                                if (!SSL_session_reused(ssl)) {
                                    Log::log_with_endpoint(in_endpoint, "SSL session not reused");
                                } else {
                                    Log::log_with_endpoint(in_endpoint, "SSL session reused");
                                }
                            }
                            boost::system::error_code ec;
                            if (is_udp) {
                                if (!first_packet_recv) {
                                    udp_socket.cancel(ec);
                                }
                                status = UDP_FORWARD;
                            } else {
                                if (!first_packet_recv) {
                                    in_socket.cancel(ec);
                                }
                                status = FORWARD;
                            }
                            out_async_read();
                            out_async_write(out_write_buf);
                        });
                    });
                });
            }
            break;
        }
        case FORWARD: {
            out_async_read();
            break;
        }
        case DIRECT_FORWARD: {
            direct_async_read();
            break;
        }
        case INVALID: {
            destroy();
            break;
        }
        default: break;
    }
}

void ClientSession::out_recv(const string &data) {
    if (data.length() > out_read_buf.size() * 0.75) {
        resize_buffer(out_read_buf, data.length() * 2);
    }
    
    if (status == FORWARD) {
        recv_len += data.length();
        in_async_write(data);
    } else if (status == UDP_FORWARD) {
        udp_data_buf += data;
        udp_sent();
    }
}

void ClientSession::out_sent() {
    if (status == FORWARD) {
        in_async_read();
    } else if (status == UDP_FORWARD) {
        udp_async_read();
    }
}

void ClientSession::udp_recv(const string &data, const udp::endpoint&) {
    if (data.length() > udp_read_buf.size() * 0.75) {
        resize_buffer(udp_read_buf, data.length() * 2);
    }
    
    if (data.length() == 0) {
        return;
    }
    if (data.length() < 3 || data[0] || data[1] || data[2]) {
        Log::log_with_endpoint(in_endpoint, "bad UDP packet", Log::ERROR);
        destroy();
        return;
    }
    SOCKS5Address address;
    size_t address_len;
    bool is_addr_valid = address.parse(data.substr(3), address_len);
    if (!is_addr_valid) {
        Log::log_with_endpoint(in_endpoint, "bad UDP packet", Log::ERROR);
        destroy();
        return;
    }
    size_t length = data.length() - 3 - address_len;
    Log::log_with_endpoint(in_endpoint, "sent a UDP packet of length " + to_string(length) + " bytes to " + address.address + ':' + to_string(address.port));
    string packet = data.substr(3, address_len) + char(uint8_t(length >> 8)) + char(uint8_t(length & 0xFF)) + "\r\n" + data.substr(address_len + 3);
    sent_len += length;
    if (status == CONNECT) {
        first_packet_recv = true;
        out_write_buf += packet;
    } else if (status == UDP_FORWARD) {
        out_async_write(packet);
    }
}

void ClientSession::udp_sent() {
    if (status == UDP_FORWARD) {
        UDPPacket packet;
        size_t packet_len;
        bool is_packet_valid = packet.parse(udp_data_buf, packet_len);
        if (!is_packet_valid) {
            if (udp_data_buf.length() > MAX_LENGTH) {
                Log::log_with_endpoint(in_endpoint, "UDP packet too long", Log::ERROR);
                destroy();
                return;
            }
            out_async_read();
            return;
        }
        Log::log_with_endpoint(in_endpoint, "received a UDP packet of length " + to_string(packet.length) + " bytes from " + packet.address.address + ':' + to_string(packet.address.port));
        SOCKS5Address address;
        size_t address_len;
        bool is_addr_valid = address.parse(udp_data_buf, address_len);
        if (!is_addr_valid) {
            Log::log_with_endpoint(in_endpoint, "udp_sent: invalid UDP packet address", Log::ERROR);
            destroy();
            return;
        }
        string reply = string("\x00\x00\x00", 3) + udp_data_buf.substr(0, address_len) + packet.payload;
        udp_data_buf = udp_data_buf.substr(packet_len);
        recv_len += packet.length;
        udp_async_write(reply, udp_recv_endpoint);
    }
}

void ClientSession::destroy() {
    if (status == DESTROY) {
        return;
    }
    status = DESTROY;
    string route_info = is_direct ? "[DIRECT]" : "[PROXY]";
    Log::log_with_endpoint(in_endpoint, route_info + " disconnected from " + target_host + ", " + to_string(recv_len) + " bytes received, " + to_string(sent_len) + " bytes sent, lasted for " + to_string(time(nullptr) - start_time) + " seconds", Log::INFO);
    boost::system::error_code ec;
    resolver.cancel();
    if (in_socket.is_open()) {
        in_socket.cancel(ec);
        in_socket.shutdown(tcp::socket::shutdown_both, ec);
        in_socket.close(ec);
    }
    if (direct_socket.is_open()) {
        direct_socket.cancel(ec);
        direct_socket.shutdown(tcp::socket::shutdown_both, ec);
        direct_socket.close(ec);
    }
    if (udp_socket.is_open()) {
        udp_socket.cancel(ec);
        udp_socket.close(ec);
    }
    if (out_socket.next_layer().is_open()) {
        auto self = shared_from_this();
        auto ssl_shutdown_cb = [this, self](const boost::system::error_code error) {
            if (error == boost::asio::error::operation_aborted) {
                return;
            }
            boost::system::error_code ec;
            ssl_shutdown_timer.cancel();
            out_socket.next_layer().cancel(ec);
            out_socket.next_layer().shutdown(tcp::socket::shutdown_both, ec);
            out_socket.next_layer().close(ec);
        };
        out_socket.next_layer().cancel(ec);
        out_socket.async_shutdown(ssl_shutdown_cb);
        ssl_shutdown_timer.expires_after(chrono::seconds(SSL_SHUTDOWN_TIMEOUT));
        ssl_shutdown_timer.async_wait(ssl_shutdown_cb);
    }
}
