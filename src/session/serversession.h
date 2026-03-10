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

#ifndef _SERVERSESSION_H_
#define _SERVERSESSION_H_

#include "session.h"
#include <boost/asio/ssl.hpp>
#include <functional>
#include "core/authenticator.h"
#include "core/embedded_tls_inbound.h"
#include "core/relay_executor.h"
#include "core/session_gate.h"

class ServerSession : public Session {
private:
    enum Status {
        HANDSHAKE,
        FORWARD,
        UDP_FORWARD,
        DESTROY
    } status;
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket>in_socket;
    boost::asio::ip::tcp::socket out_socket;
    boost::asio::ip::udp::resolver udp_resolver;
    Authenticator *auth;
    EmbeddedTlsInbound embedded_tls_inbound;
    RelayExecutor relay_executor;
    std::function<void(const boost::asio::ip::tcp::endpoint&)> release_connection_slot;
    std::function<void()> release_fallback_slot;
    std::function<void()> record_auth_success;
    std::function<void(const boost::asio::ip::tcp::endpoint&)> record_auth_failure;
    std::function<bool()> record_fallback_connection;
    bool connection_slot_acquired;
    void connect_outbound(const ConnectTarget &target, bool requires_fallback_slot);
    void start_udp_forward(const RelayExecutionPlan &plan);
    void execute_plan(const RelayExecutionPlan &plan);
    
    bool fallback_slot_acquired;
    std::string auth_password;
    const std::string &plain_http_response;
    
    // 零拷贝写缓冲区
    std::vector<uint8_t> in_write_data;
    std::vector<uint8_t> out_write_data;
    std::vector<uint8_t> udp_write_data;
    
    void destroy();
    void in_async_read();
    void in_async_write_buffer(const uint8_t* data, size_t length);
    void in_async_write(const std::string &data);
    void in_recv(size_t length);
    void in_sent();
    void out_async_read();
    void out_async_write_buffer(const uint8_t* data, size_t length);
    void out_async_write(const std::string &data);
    void out_recv(size_t length);
    void out_sent();
    void udp_async_read();
    void udp_async_write(const std::string &data, const boost::asio::ip::udp::endpoint &endpoint);
    void udp_recv(size_t length, const boost::asio::ip::udp::endpoint &endpoint);
    void udp_sent();
public:
    ServerSession(const Config &config,
                  boost::asio::io_context &io_context,
                  boost::asio::ssl::context &ssl_context,
                  Authenticator *auth,
                  const std::string &plain_http_response,
                  std::function<void(const boost::asio::ip::tcp::endpoint&)> release_connection_slot = {},
                  std::function<void()> release_fallback_slot = {},
                  std::function<void()> record_auth_success = {},
                  std::function<void(const boost::asio::ip::tcp::endpoint&)> record_auth_failure = {},
                  std::function<bool()> record_fallback_connection = {});
    boost::asio::ip::tcp::socket& accept_socket() override;
    void start() override;
};

#endif // _SERVERSESSION_H_
