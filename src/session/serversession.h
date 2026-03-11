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
#include "core/relay_executor.h"
#include "core/server_ingress_selector.h"
#include "core/session_admission_runtime.h"
#include "core/session_gate.h"
#include "core/session_lifecycle_runtime.h"
#include "core/trusted_front_ingress.h"

class ServerSession : public Session {
private:
    enum Status {
        HANDSHAKE,
        FORWARD,
        UDP_FORWARD,
        DESTROY
    } status;

    enum class BootstrapMode {
        StandardTls,
        TrustedFrontIngress,
        TrustedFrontIngressMtls
    } bootstrap_mode;
    boost::asio::ssl::stream<boost::asio::ip::tcp::socket>in_socket;
    boost::asio::ip::tcp::socket out_socket;
    boost::asio::ip::udp::resolver udp_resolver;
    Authenticator *auth;
    ServerIngressSelector ingress_selector;
    std::optional<ExternalFrontHandoff> external_front_handoff;
    std::string trusted_front_bootstrap_buffer;
    RelayExecutor relay_executor;
    SessionAdmissionRuntime admission_runtime;
    SessionLifecycleRuntime lifecycle_runtime;
    bool connection_slot_acquired;
    void connect_outbound(const ConnectTarget &target, bool requires_fallback_slot);
    void start_udp_forward(const RelayExecutionPlan &plan);
    void execute_plan(const RelayExecutionPlan &plan);
    ServerIngressSelector::Selection select_ingress() const;
    void handle_handshake_payload(std::string_view data);
    void trusted_front_ingress_async_read();
    void cancel_runtime_io();
    void close_outbound_sockets();
    void shutdown_inbound_tls();
    
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
    void out_async_write_buffer(const uint8_t* data, size_t length, bool account_sent_bytes = false);
    void out_async_write(const std::string &data, bool account_sent_bytes = false);
    void out_recv(size_t length);
    void out_sent();
    enum class UdpDispatchDecision {
        Proceed,
        WaitForMoreData,
        DestroySession
    };

    struct UdpDispatchRequest {
        std::string payload;
        size_t packet_length{0};
        std::string query_addr;
        uint16_t query_port{0};
    };

    enum class UdpResolveDecision {
        DispatchPayload,
        DestroySession
    };

    void udp_async_read();
    void udp_async_write(const std::string &data, const boost::asio::ip::udp::endpoint &endpoint, size_t accounted_length = 0);
    void udp_recv(size_t length, const boost::asio::ip::udp::endpoint &endpoint);
    UdpDispatchDecision try_parse_udp_packet(UdpDispatchRequest &request);
    void resolve_udp_target(const std::string &payload,
                            size_t packet_length,
                            const std::string &query_addr,
                            uint16_t query_port);
    UdpResolveDecision evaluate_udp_resolve_result(const std::string &query_addr,
                                                   const boost::system::error_code &error,
                                                   const boost::asio::ip::udp::resolver::results_type &results) const;
    boost::asio::ip::udp::resolver::results_type::const_iterator choose_udp_target_endpoint(
        const boost::asio::ip::udp::resolver::results_type &results) const;
    void ensure_udp_socket_open(const boost::asio::ip::udp::endpoint::protocol_type &protocol);
    void dispatch_udp_payload(const std::string &payload,
                              size_t packet_length,
                              const boost::asio::ip::udp::endpoint &endpoint);
    void handle_udp_resolved_packet(const std::string &payload,
                                    size_t packet_length,
                                    const std::string &query_addr,
                                    const boost::asio::ip::udp::resolver::results_type &results);
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
    void enable_trusted_front_ingress_mode(bool use_mtls = false);
    void set_external_front_handoff(ExternalFrontHandoff handoff);
    void clear_external_front_handoff();
};

#endif // _SERVERSESSION_H_
