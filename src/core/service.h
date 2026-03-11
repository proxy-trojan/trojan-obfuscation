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

#ifndef _SERVICE_H_
#define _SERVICE_H_

#include <list>
#include <map>
#include <atomic>
#include <unordered_map>
#include <boost/version.hpp>
#include <boost/asio/io_context.hpp>
#include <boost/asio/ssl.hpp>
#include <boost/asio/ip/udp.hpp>
#include "abuse_controller.h"
#include "authenticator.h"
#include "fallback_controller.h"
#include "runtime_metrics.h"
#include "config_trusted_internal_handoff_source_stub.h"
#include "external_front_handoff_builder.h"
#include "external_front_handoff_contract.h"
#include "external_front_metadata_provider.h"
#include "trusted_front_admission_policy.h"
#include "session/udpforwardsession.h"

#include <thread>
#include <vector>
#include <mutex>
#include <memory>
#include <chrono>

class ServerSession;

// 每个 worker 的独立上下文
struct WorkerContext {
    std::unique_ptr<boost::asio::io_context> io_context;
    std::unique_ptr<boost::asio::ip::tcp::acceptor> acceptor;
    std::thread thread;
    
    WorkerContext() : io_context(std::make_unique<boost::asio::io_context>()) {}
};

class Service {
private:
    enum {
        MAX_LENGTH = 8192
    };

    enum class AcceptDecision {
        RejectCooldown,
        RejectConnectionLimit,
        StartSession
    };
    const Config &config;
    
    // 多 io_context 架构
    std::vector<std::unique_ptr<WorkerContext>> workers;
    int thread_num;
    bool use_multi_io_context;  // 是否启用多 io_context 模式
    
    // 单 io_context 模式的后备（用于不支持 SO_REUSEPORT 的平台）
    boost::asio::io_context io_context;
    boost::asio::ip::tcp::acceptor socket_acceptor;
    std::unique_ptr<boost::asio::ip::tcp::acceptor> trusted_front_acceptor;
    std::vector<std::thread> thread_pool;
    
    AbuseController abuse_controller;
    RuntimeMetrics runtime_metrics;
    FallbackController fallback_controller;
    ExternalFrontHandoffBuilder external_front_handoff_builder;
    ExternalFrontHandoffContract external_front_handoff_contract;
    TrustedFrontAdmissionPolicy trusted_front_admission_policy;
    ConfigTrustedInternalHandoffSourceStub trusted_internal_handoff_source_stub;
    ConfigExternalFrontMetadataProvider external_front_metadata_provider;

    // 共享资源
    boost::asio::ssl::context ssl_context;
    boost::asio::ssl::context trusted_front_ssl_context;
    Authenticator *auth;
    std::string plain_http_response;
    
    // UDP 相关（保持单 io_context，UDP 流量通常较小）
    boost::asio::ip::udp::socket udp_socket;
    std::map<boost::asio::ip::udp::endpoint, std::weak_ptr<UDPForwardSession> > udp_sessions;
    std::mutex udp_sessions_mutex;
    std::mutex udp_socket_mutex;
    uint8_t udp_read_buf[MAX_LENGTH]{};
    boost::asio::ip::udp::endpoint udp_recv_endpoint;
    
    // Round-robin 分配（用于 UDP session）
    std::atomic<size_t> next_worker{0};
    boost::asio::io_context& get_worker_io_context();
    void release_connection_slot(const boost::asio::ip::tcp::endpoint& endpoint);
    void record_auth_success();
    void record_auth_failure(const boost::asio::ip::tcp::endpoint& endpoint);
    void release_fallback_slot();
    bool record_fallback_connection();
    AcceptDecision evaluate_incoming_connection(const boost::asio::ip::tcp::endpoint &endpoint);
    std::optional<ExternalFrontHandoff> maybe_build_external_front_handoff();
    void maybe_apply_external_front_handoff(ServerSession &session, std::optional<ExternalFrontHandoff> handoff);
    std::shared_ptr<Session> create_server_session(boost::asio::io_context &target_io_context, bool apply_default_handoff = true);
    std::shared_ptr<Session> create_session(boost::asio::io_context &target_io_context);
    std::shared_ptr<ServerSession> create_trusted_front_server_session(boost::asio::io_context &target_io_context);
    bool handle_accept_completion(const std::shared_ptr<Session> &session,
                                  const boost::system::error_code &error,
                                  const std::string &success_log_message,
                                  bool bypass_public_admission = false);
    
    void async_accept();  // 单 io_context 模式
    void async_accept_worker(size_t worker_index);  // 多 io_context 模式
    void async_accept_trusted_front();
    void udp_async_read();
    void setup_acceptor(boost::asio::ip::tcp::acceptor& acceptor, const boost::asio::ip::tcp::endpoint& endpoint);
    
public:
    explicit Service(Config &config, bool test = false);
    void run();
    void stop();
    boost::asio::io_context &service();
    void reload_cert();

    ~Service();
};

#endif // _SERVICE_H_
