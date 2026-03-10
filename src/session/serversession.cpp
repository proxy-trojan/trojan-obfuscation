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

#include "serversession.h"
#include "proto/trojanrequest.h"
#include "proto/udppacket.h"
using namespace std;
using namespace boost::asio::ip;
using namespace boost::asio::ssl;

ServerSession::ServerSession(const Config &config,
                             boost::asio::io_context &io_context,
                             context &ssl_context,
                             Authenticator *auth,
                             const string &plain_http_response,
                             function<void(const tcp::endpoint&)> release_connection_slot,
                             function<void()> release_fallback_slot,
                             function<void()> record_auth_success,
                             function<void(const tcp::endpoint&)> record_auth_failure,
                             function<bool()> record_fallback_connection) :
    Session(config, io_context),
    status(HANDSHAKE),
    in_socket(io_context, ssl_context),
    out_socket(io_context),
    udp_resolver(io_context),
    auth(auth),
    embedded_tls_inbound(config, auth),
    relay_executor(config),
    release_connection_slot(std::move(release_connection_slot)),
    release_fallback_slot(std::move(release_fallback_slot)),
    record_auth_success(std::move(record_auth_success)),
    record_auth_failure(std::move(record_auth_failure)),
    record_fallback_connection(std::move(record_fallback_connection)),
    connection_slot_acquired(false),
    fallback_slot_acquired(false),
    plain_http_response(plain_http_response) {
    // 预分配写缓冲区
    in_write_data.reserve(DEFAULT_BUFFER_SIZE);
    out_write_data.reserve(DEFAULT_BUFFER_SIZE);
    udp_write_data.reserve(DEFAULT_BUFFER_SIZE);
}

tcp::socket& ServerSession::accept_socket() {
    return (tcp::socket&)in_socket.next_layer();
}

void ServerSession::start() {
    boost::system::error_code ec;
    start_time = time(nullptr);
    in_endpoint = in_socket.next_layer().remote_endpoint(ec);
    if (ec) {
        destroy();
        return;
    }
    connection_slot_acquired = true;
    auto self = shared_from_this();
    in_socket.async_handshake(stream_base::server, [this, self](const boost::system::error_code error) {
        if (error) {
            Log::log_with_endpoint(in_endpoint, "SSL handshake failed: " + error.message(), Log::ERROR);
            if (error.message() == "http request" && !plain_http_response.empty()) {
                recv_len += plain_http_response.length();
                boost::asio::async_write(accept_socket(), boost::asio::buffer(plain_http_response), [this, self](const boost::system::error_code, size_t) {
                    destroy();
                });
                return;
            }
            destroy();
            return;
        }
        in_async_read();
    });
}

void ServerSession::in_async_read() {
    auto self = shared_from_this();
    in_socket.async_read_some(boost::asio::buffer(in_read_buf.data(), in_read_buf.size()), [this, self](const boost::system::error_code error, size_t length) {
        if (error) {
            destroy();
            return;
        }
        in_recv(length);
    });
}

// 零拷贝写入 - 直接从缓冲区写入
void ServerSession::in_async_write_buffer(const uint8_t* data, size_t length) {
    auto self = shared_from_this();
    // 复制到成员缓冲区，避免每次分配
    if (in_write_data.capacity() < length) {
        in_write_data.reserve(std::max(length, in_write_data.capacity() * 2));
    }
    in_write_data.assign(data, data + length);
    boost::asio::async_write(in_socket, boost::asio::buffer(in_write_data.data(), in_write_data.size()), [this, self](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        in_sent();
    });
}

void ServerSession::in_async_write(const string &data) {
    in_async_write_buffer(reinterpret_cast<const uint8_t*>(data.data()), data.size());
}

void ServerSession::out_async_read() {
    auto self = shared_from_this();
    out_socket.async_read_some(boost::asio::buffer(out_read_buf.data(), out_read_buf.size()), [this, self](const boost::system::error_code error, size_t length) {
        if (error) {
            destroy();
            return;
        }
        out_recv(length);
    });
}

// 零拷贝写入 - 直接从缓冲区写入
void ServerSession::out_async_write_buffer(const uint8_t* data, size_t length) {
    auto self = shared_from_this();
    // 复制到成员缓冲区，避免每次分配
    if (out_write_data.capacity() < length) {
        out_write_data.reserve(std::max(length, out_write_data.capacity() * 2));
    }
    out_write_data.assign(data, data + length);
    boost::asio::async_write(out_socket, boost::asio::buffer(out_write_data.data(), out_write_data.size()), [this, self](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        out_sent();
    });
}

void ServerSession::out_async_write(const string &data) {
    out_async_write_buffer(reinterpret_cast<const uint8_t*>(data.data()), data.size());
}

void ServerSession::udp_async_read() {
    auto self = shared_from_this();
    udp_socket.async_receive_from(boost::asio::buffer(udp_read_buf.data(), udp_read_buf.size()), udp_recv_endpoint, [this, self](const boost::system::error_code error, size_t length) {
        if (error) {
            destroy();
            return;
        }
        udp_recv(length, udp_recv_endpoint);
    });
}

void ServerSession::udp_async_write(const string &data, const udp::endpoint &endpoint) {
    auto self = shared_from_this();
    // 复制到成员缓冲区
    if (udp_write_data.capacity() < data.size()) {
        udp_write_data.reserve(std::max(data.size(), udp_write_data.capacity() * 2));
    }
    udp_write_data.assign(data.begin(), data.end());
    udp_socket.async_send_to(boost::asio::buffer(udp_write_data.data(), udp_write_data.size()), endpoint, [this, self](const boost::system::error_code error, size_t) {
        if (error) {
            destroy();
            return;
        }
        udp_sent();
    });
}

void ServerSession::connect_outbound(const ConnectTarget &target, bool requires_fallback_slot) {
    sent_len += out_write_buf.length();
    auto self = shared_from_this();
    auto started = relay_executor.begin_tcp_relay(
        resolver,
        out_socket,
        in_endpoint,
        target,
        requires_fallback_slot,
        [this]() {
            if (!record_fallback_connection) {
                return true;
            }
            fallback_slot_acquired = record_fallback_connection();
            return fallback_slot_acquired;
        },
        [this, self]() {
            status = FORWARD;
            out_async_read();
            if (!out_write_buf.empty()) {
                out_async_write(out_write_buf);
            } else {
                in_async_read();
            }
        },
        [this, self](const string &message) {
            Log::log_with_endpoint(in_endpoint, message, message.rfind("fallback rejected:", 0) == 0 ? Log::WARN : Log::ERROR);
            destroy();
        });

    if (!started) {
        return;
    }
}

void ServerSession::execute_plan(const RelayExecutionPlan &plan) {
    if (!plan.log_message.empty()) {
        Log::log_with_endpoint(in_endpoint, plan.log_message, plan.log_as_warning ? Log::WARN : Log::INFO);
    }

    out_write_buf = plan.initial_outbound_payload;

    if (plan.mode == RelayMode::StartUdpForward) {
        status = UDP_FORWARD;
        udp_data_buf = out_write_buf;
        udp_sent();
        return;
    }

    if (plan.mode == RelayMode::StartTcpForward) {
        connect_outbound(plan.target, plan.requires_fallback_slot);
        return;
    }

    destroy();
}

void ServerSession::in_recv(size_t length) {
    if (length > in_read_buf.size() * 0.75) {
        resize_buffer(in_read_buf, length * 2);
    }
    
    if (status == HANDSHAKE) {
        string_view data(reinterpret_cast<const char*>(in_read_buf.data()), length);
        auto gate_result = embedded_tls_inbound.evaluate_initial_data(in_endpoint, in_socket, data);
        if (gate_result.valid_trojan_request && gate_result.authenticated) {
            if (gate_result.used_external_authenticator) {
                auth_password = gate_result.auth_record_password;
                if (record_auth_success) {
                    record_auth_success();
                }
                Log::log_with_endpoint(in_endpoint, "authenticated by external authenticator", Log::INFO);
            } else {
                if (record_auth_success) {
                    record_auth_success();
                }
                Log::log_with_endpoint(in_endpoint, "authenticated by configured credential", Log::INFO);
            }
        } else if (gate_result.valid_trojan_request) {
            if (record_auth_failure) {
                record_auth_failure(in_endpoint);
            }
            Log::log_with_endpoint(in_endpoint, "valid trojan request structure but authentication failed", Log::WARN);
        }

        auto execution_plan = relay_executor.build_execution_plan(gate_result);
        execute_plan(execution_plan);
    } else if (status == FORWARD) {
        sent_len += length;
        // 零拷贝：直接从读缓冲区写入
        out_async_write_buffer(in_read_buf.data(), length);
    } else if (status == UDP_FORWARD) {
        udp_data_buf += string(reinterpret_cast<const char*>(in_read_buf.data()), length);
        udp_sent();
    }
}

void ServerSession::in_sent() {
    if (status == FORWARD) {
        out_async_read();
    } else if (status == UDP_FORWARD) {
        udp_async_read();
    }
}

void ServerSession::out_recv(size_t length) {
    if (length > out_read_buf.size() * 0.75) {
        resize_buffer(out_read_buf, length * 2);
    }
    
    if (status == FORWARD) {
        recv_len += length;
        // 零拷贝：直接从读缓冲区写入
        in_async_write_buffer(out_read_buf.data(), length);
    }
}

void ServerSession::out_sent() {
    if (status == FORWARD) {
        in_async_read();
    }
}

void ServerSession::udp_recv(size_t length, const udp::endpoint &endpoint) {
    if (length > udp_read_buf.size() * 0.75) {
        resize_buffer(udp_read_buf, length * 2);
    }
    
    if (status == UDP_FORWARD) {
        Log::log_with_endpoint(in_endpoint, "received a UDP packet of length " + to_string(length) + " bytes from " + endpoint.address().to_string() + ':' + to_string(endpoint.port()));
        recv_len += length;
        string data(reinterpret_cast<const char*>(udp_read_buf.data()), length);
        in_async_write(UDPPacket::generate(endpoint, data));
    }
}

void ServerSession::udp_sent() {
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
            in_async_read();
            return;
        }
        Log::log_with_endpoint(in_endpoint, "sent a UDP packet of length " + to_string(packet.length) + " bytes to " + packet.address.address + ':' + to_string(packet.address.port));
        udp_data_buf = udp_data_buf.substr(packet_len);
        string query_addr = packet.address.address;
        auto self = shared_from_this();
        udp_resolver.async_resolve(query_addr, to_string(packet.address.port), [this, self, packet, query_addr](const boost::system::error_code error, const udp::resolver::results_type& results) {
            if (error || results.empty()) {
                Log::log_with_endpoint(in_endpoint, "cannot resolve remote server hostname " + query_addr + ": " + error.message(), Log::ERROR);
                destroy();
                return;
            }
            auto iterator = results.begin();
            if (config.tcp.prefer_ipv4) {
                for (auto it = results.begin(); it != results.end(); ++it) {
                    const auto &addr = it->endpoint().address();
                    if (addr.is_v4()) {
                        iterator = it;
                        break;
                    }
                }
            }
            Log::log_with_endpoint(in_endpoint, query_addr + " is resolved to " + iterator->endpoint().address().to_string(), Log::ALL);
            if (!udp_socket.is_open()) {
                auto protocol = iterator->endpoint().protocol();
                boost::system::error_code ec;
                udp_socket.open(protocol, ec);
                if (ec) {
                    destroy();
                    return;
                }
                udp_socket.bind(udp::endpoint(protocol, 0));
                udp_async_read();
            }
            sent_len += packet.length;
            udp_async_write(packet.payload, *iterator);
        });
    }
}

void ServerSession::destroy() {
    if (status == DESTROY) {
        return;
    }
    status = DESTROY;
    Log::log_with_endpoint(in_endpoint, "disconnected, " + to_string(recv_len) + " bytes received, " + to_string(sent_len) + " bytes sent, lasted for " + to_string(time(nullptr) - start_time) + " seconds", Log::INFO);
    if (connection_slot_acquired && release_connection_slot) {
        release_connection_slot(in_endpoint);
        connection_slot_acquired = false;
    }
    if (fallback_slot_acquired && release_fallback_slot) {
        release_fallback_slot();
        fallback_slot_acquired = false;
    }
    if (auth && !auth_password.empty()) {
        auth->record(auth_password, recv_len, sent_len);
    }
    boost::system::error_code ec;
    resolver.cancel();
    udp_resolver.cancel();
    if (out_socket.is_open()) {
        out_socket.cancel(ec);
        out_socket.shutdown(tcp::socket::shutdown_both, ec);
        out_socket.close(ec);
    }
    if (udp_socket.is_open()) {
        udp_socket.cancel(ec);
        udp_socket.close(ec);
    }
    if (in_socket.next_layer().is_open()) {
        auto self = shared_from_this();
        auto ssl_shutdown_cb = [this, self](const boost::system::error_code error) {
            if (error == boost::asio::error::operation_aborted) {
                return;
            }
            boost::system::error_code ec;
            ssl_shutdown_timer.cancel();
            in_socket.next_layer().cancel(ec);
            in_socket.next_layer().shutdown(tcp::socket::shutdown_both, ec);
            in_socket.next_layer().close(ec);
        };
        in_socket.next_layer().cancel(ec);
        in_socket.async_shutdown(ssl_shutdown_cb);
        ssl_shutdown_timer.expires_after(chrono::seconds(SSL_SHUTDOWN_TIMEOUT));
        ssl_shutdown_timer.async_wait(ssl_shutdown_cb);
    }
}
