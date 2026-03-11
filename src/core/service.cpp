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

#include "service.h"
#include <cstring>
#include <cerrno>
#include <stdexcept>
#include <fstream>
#ifdef _WIN32
#include <wincrypt.h>
#include <tchar.h>
#endif // _WIN32
#ifdef __APPLE__
#include <Security/Security.h>
#endif // __APPLE__
#include <openssl/opensslv.h>
#include "session/serversession.h"
#include "session/clientsession.h"
#include "session/forwardsession.h"
#include "session/natsession.h"
#include "ssl/ssldefaults.h"
#include "ssl/sslsession.h"

using namespace std;
using namespace boost::asio::ip;
using namespace boost::asio::ssl;

#ifdef ENABLE_REUSE_PORT
typedef boost::asio::detail::socket_option::boolean<SOL_SOCKET, SO_REUSEPORT> reuse_port;
#endif // ENABLE_REUSE_PORT

Service::Service(Config &config, bool test) :
    config(config),
    thread_num(0),
    use_multi_io_context(false),
    socket_acceptor(io_context),
    abuse_controller(config.abuse_control),
    runtime_metrics(),
    fallback_controller(config.abuse_control, runtime_metrics),
    trusted_internal_handoff_source_stub(config),
    external_front_metadata_provider(config),
    ssl_context(context::sslv23),
    auth(nullptr),
    udp_socket(io_context) {
#ifndef ENABLE_NAT
    if (config.run_type == Config::NAT) {
        throw runtime_error("NAT is not supported");
    }
#endif // ENABLE_NAT

    // 计算线程数
    thread_num = config.threads;
    if (thread_num <= 0) {
        thread_num = std::thread::hardware_concurrency();
        if (thread_num <= 0) {
            thread_num = 1;
        }
    }

    // 判断是否启用多 io_context 模式
#ifdef ENABLE_REUSE_PORT
    use_multi_io_context = (thread_num > 1 && config.tcp.reuse_port);
#else
    use_multi_io_context = false;
#endif

    if (!test) {
        tcp::resolver resolver(io_context);
        tcp::endpoint listen_endpoint = *resolver.resolve(config.local_addr, to_string(config.local_port)).begin();

        if (use_multi_io_context) {
            // 多 io_context 模式：每个 worker 有独立的 acceptor
            Log::log_with_date_time("using multi io_context mode with " + to_string(thread_num) + " workers", Log::WARN);
            for (int i = 0; i < thread_num; ++i) {
                auto worker = make_unique<WorkerContext>();
                worker->acceptor = make_unique<tcp::acceptor>(*worker->io_context);
                setup_acceptor(*worker->acceptor, listen_endpoint);
                workers.push_back(std::move(worker));
            }
        } else {
            // 单 io_context 模式
            setup_acceptor(socket_acceptor, listen_endpoint);
        }

        if (config.run_type == Config::FORWARD) {
            auto udp_bind_endpoint = udp::endpoint(listen_endpoint.address(), listen_endpoint.port());
            udp_socket.open(udp_bind_endpoint.protocol());
            udp_socket.bind(udp_bind_endpoint);
        }
    }

    Log::level = config.log_level;
    auto native_context = ssl_context.native_handle();
    ssl_context.set_options(context::default_workarounds | context::no_sslv2 | context::no_sslv3 | context::single_dh_use);
    if (!config.ssl.curves.empty()) {
        SSL_CTX_set1_curves_list(native_context, config.ssl.curves.c_str());
    }
    if (config.run_type == Config::SERVER) {
        ssl_context.use_certificate_chain_file(config.ssl.cert);
        ssl_context.set_password_callback([this](size_t, context_base::password_purpose) {
            return this->config.ssl.key_password;
        });
        ssl_context.use_private_key_file(config.ssl.key, context::pem);
        if (config.ssl.prefer_server_cipher) {
            SSL_CTX_set_options(native_context, SSL_OP_CIPHER_SERVER_PREFERENCE);
        }
        if (!config.ssl.alpn.empty()) {
            SSL_CTX_set_alpn_select_cb(native_context, [](SSL*, const unsigned char **out, unsigned char *outlen, const unsigned char *in, unsigned int inlen, void *config) -> int {
                if (SSL_select_next_proto((unsigned char**)out, outlen, (unsigned char*)(((Config*)config)->ssl.alpn.c_str()), ((Config*)config)->ssl.alpn.length(), in, inlen) != OPENSSL_NPN_NEGOTIATED) {
                    return SSL_TLSEXT_ERR_NOACK;
                }
                return SSL_TLSEXT_ERR_OK;
            }, &config);
        }
        if (config.ssl.reuse_session) {
            SSL_CTX_set_timeout(native_context, config.ssl.session_timeout);
            if (!config.ssl.session_ticket) {
                SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
            }
        } else {
            SSL_CTX_set_session_cache_mode(native_context, SSL_SESS_CACHE_OFF);
            SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
        }
        if (!config.ssl.plain_http_response.empty()) {
            ifstream ifs(config.ssl.plain_http_response, ios::binary);
            if (!ifs.is_open()) {
                throw runtime_error(config.ssl.plain_http_response + ": " + strerror(errno));
            }
            plain_http_response = string(istreambuf_iterator<char>(ifs), istreambuf_iterator<char>());
        }
        if (config.ssl.dhparam.empty()) {
            ssl_context.use_tmp_dh(boost::asio::const_buffer(SSLDefaults::g_dh2048_sz, SSLDefaults::g_dh2048_sz_size));
        } else {
            ssl_context.use_tmp_dh_file(config.ssl.dhparam);
        }
        if (config.mysql.enabled) {
#ifdef ENABLE_MYSQL
            auth = new Authenticator(config);
#else // ENABLE_MYSQL
            Log::log_with_date_time("MySQL is not supported", Log::WARN);
#endif // ENABLE_MYSQL
        }
    } else {
        if (config.ssl.sni.empty()) {
            config.ssl.sni = config.remote_addr;
        }
        if (config.ssl.verify) {
            ssl_context.set_verify_mode(verify_peer);
            if (config.ssl.cert.empty()) {
                ssl_context.set_default_verify_paths();
#ifdef _WIN32
                HCERTSTORE h_store = CertOpenSystemStore(0, _T("ROOT"));
                if (h_store) {
                    X509_STORE *store = SSL_CTX_get_cert_store(native_context);
                    PCCERT_CONTEXT p_context = NULL;
                    while ((p_context = CertEnumCertificatesInStore(h_store, p_context))) {
                        const unsigned char *encoded_cert = p_context->pbCertEncoded;
                        X509 *x509 = d2i_X509(NULL, &encoded_cert, p_context->cbCertEncoded);
                        if (x509) {
                            X509_STORE_add_cert(store, x509);
                            X509_free(x509);
                        }
                    }
                    CertCloseStore(h_store, 0);
                }
#endif // _WIN32
#ifdef __APPLE__
                SecKeychainSearchRef pSecKeychainSearch = NULL;
                SecKeychainRef pSecKeychain;
                OSStatus status = noErr;
                X509 *cert = NULL;

                // Leopard and above store location
                status = SecKeychainOpen ("/System/Library/Keychains/SystemRootCertificates.keychain", &pSecKeychain);
                if (status == noErr) {
                    X509_STORE *store = SSL_CTX_get_cert_store(native_context);
                    status = SecKeychainSearchCreateFromAttributes (pSecKeychain, kSecCertificateItemClass, NULL, &pSecKeychainSearch);
                     for (;;) {
                        SecKeychainItemRef pSecKeychainItem = nil;

                        status = SecKeychainSearchCopyNext (pSecKeychainSearch, &pSecKeychainItem);
                        if (status == errSecItemNotFound) {
                            break;
                        }

                        if (status == noErr) {
                            void *_pCertData;
                            UInt32 _pCertLength;
                            status = SecKeychainItemCopyAttributesAndData (pSecKeychainItem, NULL, NULL, NULL, &_pCertLength, &_pCertData);

                            if (status == noErr && _pCertData != NULL) {
                                unsigned char *ptr;

                                ptr = (unsigned char *)_pCertData;       /*required because d2i_X509 is modifying pointer */
                                cert = d2i_X509 (NULL, (const unsigned char **) &ptr, _pCertLength);
                                if (cert == NULL) {
                                    continue;
                                }

                                if (!X509_STORE_add_cert (store, cert)) {
                                    X509_free (cert);
                                    continue;
                                }
                                X509_free (cert);

                                status = SecKeychainItemFreeAttributesAndData (NULL, _pCertData);
                            }
                        }
                        if (pSecKeychainItem != NULL) {
                            CFRelease (pSecKeychainItem);
                        }
                    }
                    CFRelease (pSecKeychainSearch);
                    CFRelease (pSecKeychain);
                }
#endif // __APPLE__
            } else {
                ssl_context.load_verify_file(config.ssl.cert);
            }
            if (config.ssl.verify_hostname) {
#if BOOST_VERSION >= 107300
                ssl_context.set_verify_callback(host_name_verification(config.ssl.sni));
#else
                ssl_context.set_verify_callback(rfc2818_verification(config.ssl.sni));
#endif
            }
            X509_VERIFY_PARAM *param = X509_VERIFY_PARAM_new();
            X509_VERIFY_PARAM_set_flags(param, X509_V_FLAG_PARTIAL_CHAIN);
            SSL_CTX_set1_param(native_context, param);
            X509_VERIFY_PARAM_free(param);
        } else {
            ssl_context.set_verify_mode(verify_none);
        }
        if (!config.ssl.alpn.empty()) {
            SSL_CTX_set_alpn_protos(native_context, (unsigned char*)(config.ssl.alpn.c_str()), config.ssl.alpn.length());
        }
        if (config.ssl.reuse_session) {
            SSL_CTX_set_session_cache_mode(native_context, SSL_SESS_CACHE_CLIENT);
            SSLSession::set_callback(native_context);
            if (!config.ssl.session_ticket) {
                SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
            }
        } else {
            SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
        }
    }
    if (!config.ssl.cipher.empty()) {
        SSL_CTX_set_cipher_list(native_context, config.ssl.cipher.c_str());
    }
    if (!config.ssl.cipher_tls13.empty()) {
#ifdef ENABLE_TLS13_CIPHERSUITES
        SSL_CTX_set_ciphersuites(native_context, config.ssl.cipher_tls13.c_str());
#else  // ENABLE_TLS13_CIPHERSUITES
        Log::log_with_date_time("TLS1.3 ciphersuites are not supported", Log::WARN);
#endif // ENABLE_TLS13_CIPHERSUITES
    }

    if (Log::keylog) {
#ifdef ENABLE_SSL_KEYLOG
        SSL_CTX_set_keylog_callback(native_context, [](const SSL*, const char *line) {
            fprintf(Log::keylog, "%s\n", line);
            fflush(Log::keylog);
        });
#else // ENABLE_SSL_KEYLOG
        Log::log_with_date_time("SSL KeyLog is not supported", Log::WARN);
#endif // ENABLE_SSL_KEYLOG
    }
}

void Service::setup_acceptor(tcp::acceptor& acceptor, const tcp::endpoint& endpoint) {
    acceptor.open(endpoint.protocol());
    acceptor.set_option(tcp::acceptor::reuse_address(true));

#ifdef ENABLE_REUSE_PORT
    if (config.tcp.reuse_port) {
        acceptor.set_option(reuse_port(true));
    }
#endif

    acceptor.bind(endpoint);
    acceptor.listen();

    if (config.tcp.no_delay) {
        acceptor.set_option(tcp::no_delay(true));
    }
    if (config.tcp.keep_alive) {
        acceptor.set_option(boost::asio::socket_base::keep_alive(true));
    }
    if (config.tcp.fast_open) {
#ifdef TCP_FASTOPEN
        using fastopen = boost::asio::detail::socket_option::integer<IPPROTO_TCP, TCP_FASTOPEN>;
        boost::system::error_code ec;
        acceptor.set_option(fastopen(config.tcp.fast_open_qlen), ec);
#else
        Log::log_with_date_time("TCP_FASTOPEN is not supported", Log::WARN);
#endif
    }
}

boost::asio::io_context& Service::get_worker_io_context() {
    if (use_multi_io_context && !workers.empty()) {
        auto index = next_worker.fetch_add(1, std::memory_order_relaxed) % workers.size();
        return *workers[index]->io_context;
    }
    return io_context;
}

void Service::release_connection_slot(const tcp::endpoint& endpoint) {
    auto active = runtime_metrics.active_sessions.load(std::memory_order_relaxed);
    while (active > 0 && !runtime_metrics.active_sessions.compare_exchange_weak(active, active - 1, std::memory_order_relaxed)) {
    }
    abuse_controller.release_connection_slot(endpoint);
}

void Service::record_auth_success() {
    ++runtime_metrics.auth_success_total;
}

void Service::record_auth_failure(const tcp::endpoint& endpoint) {
    ++runtime_metrics.auth_failure_total;
    abuse_controller.record_auth_failure(endpoint);
}

void Service::release_fallback_slot() {
    fallback_controller.release_slot();
}

bool Service::record_fallback_connection() {
    return fallback_controller.try_acquire_slot();
}

Service::AcceptDecision Service::evaluate_incoming_connection(const tcp::endpoint &endpoint) {
    if (config.run_type != Config::SERVER) {
        return AcceptDecision::StartSession;
    }
    if (abuse_controller.is_ip_in_cooldown(endpoint)) {
        return AcceptDecision::RejectCooldown;
    }
    if (!abuse_controller.try_acquire_connection_slot(endpoint)) {
        return AcceptDecision::RejectConnectionLimit;
    }
    return AcceptDecision::StartSession;
}

std::optional<ExternalFrontHandoff> Service::maybe_build_external_front_handoff() {
    auto trusted_internal_evaluation = trusted_internal_handoff_source_stub.evaluate();
    if (trusted_internal_evaluation.decision != ConfigTrustedInternalHandoffSourceStub::Decision::Inactive) {
        if (trusted_internal_evaluation.decision == ConfigTrustedInternalHandoffSourceStub::Decision::ActiveWithoutInput) {
            Log::log_with_date_time(
                "external-front trusted-internal source active without input: source_name=" + trusted_internal_evaluation.source_name + " reason=" + trusted_internal_evaluation.reason,
                Log::WARN);
            return std::nullopt;
        }

        auto build_result = external_front_handoff_builder.build_trusted_internal_handoff(*trusted_internal_evaluation.input);
        if (!build_result.built()) {
            Log::log_with_date_time(
                "external-front trusted-internal source rejected before handoff apply: source_name=" + trusted_internal_evaluation.source_name + " reason=" + build_result.reason,
                Log::WARN);
            return std::nullopt;
        }
        return std::move(build_result.handoff);
    }

    auto injection = external_front_metadata_provider.evaluate_injection();

    if (injection.decision == ExternalFrontMetadataProvider::Decision::Inactive) {
        return std::nullopt;
    }

    if (injection.decision == ExternalFrontMetadataProvider::Decision::ActiveNoMetadata) {
        Log::log_with_date_time(
            "external-front metadata provider active without context: " + injection.mode,
            Log::WARN);
        return std::nullopt;
    }

    auto build_result = external_front_handoff_builder.build_test_injected_handoff(injection);
    if (!build_result.built()) {
        Log::log_with_date_time(
            "external-front test-injected handoff build rejected: mode=" + injection.mode + " reason=" + build_result.reason,
            Log::WARN);
        return std::nullopt;
    }
    return std::move(build_result.handoff);
}

void Service::maybe_apply_external_front_handoff(ServerSession &session, std::optional<ExternalFrontHandoff> handoff) {
    if (!handoff.has_value()) {
        return;
    }

    auto source_kind = external_front_handoff_source_kind_name(handoff->source_kind);
    auto decision = external_front_handoff_contract.evaluate(*handoff);
    if (!decision.accepted()) {
        Log::log_with_date_time(
            "external-front handoff rejected: source_kind=" + source_kind + " source_name=" + handoff->source_name + " reason=" + decision.reason,
            Log::WARN);
        return;
    }

    Log::log_with_date_time(
        "external-front handoff applied: source_kind=" + source_kind + " source_name=" + handoff->source_name + " reason=" + decision.reason,
        Log::INFO);
    session.set_external_front_handoff(std::move(*handoff));
}

shared_ptr<Session> Service::create_server_session(boost::asio::io_context &target_io_context) {
    auto session = make_shared<ServerSession>(config, target_io_context, ssl_context, auth, plain_http_response,
        [this](const tcp::endpoint& endpoint) { release_connection_slot(endpoint); },
        [this]() { release_fallback_slot(); },
        [this]() { record_auth_success(); },
        [this](const tcp::endpoint& endpoint) { record_auth_failure(endpoint); },
        [this]() { return record_fallback_connection(); });
    auto external_front_handoff = maybe_build_external_front_handoff();
    maybe_apply_external_front_handoff(*session, std::move(external_front_handoff));
    return session;
}

shared_ptr<Session> Service::create_session(boost::asio::io_context &target_io_context) {
    if (config.run_type == Config::SERVER) {
        return create_server_session(target_io_context);
    }
    if (config.run_type == Config::FORWARD) {
        return make_shared<ForwardSession>(config, target_io_context, ssl_context);
    }
    if (config.run_type == Config::NAT) {
        return make_shared<NATSession>(config, target_io_context, ssl_context);
    }
    return make_shared<ClientSession>(config, target_io_context, ssl_context);
}

bool Service::handle_accept_completion(const shared_ptr<Session> &session,
                                       const boost::system::error_code &error,
                                       const string &success_log_message) {
    if (error == boost::asio::error::operation_aborted) {
        return false;
    }
    if (!error) {
        boost::system::error_code ec;
        auto endpoint = session->accept_socket().remote_endpoint(ec);
        if (!ec) {
            auto decision = evaluate_incoming_connection(endpoint);
            if (decision == AcceptDecision::RejectCooldown) {
                ++runtime_metrics.rejected_connections_total;
                Log::log_with_endpoint(endpoint, "connection rejected: IP is in authentication cooldown", Log::WARN);
                boost::system::error_code close_ec;
                session->accept_socket().shutdown(tcp::socket::shutdown_both, close_ec);
                session->accept_socket().close(close_ec);
            } else if (decision == AcceptDecision::RejectConnectionLimit) {
                ++runtime_metrics.rejected_connections_total;
                Log::log_with_endpoint(endpoint, "connection rejected: per-IP concurrent connection limit reached", Log::WARN);
                boost::system::error_code close_ec;
                session->accept_socket().shutdown(tcp::socket::shutdown_both, close_ec);
                session->accept_socket().close(close_ec);
            } else {
                ++runtime_metrics.accepted_connections_total;
                if (config.run_type == Config::SERVER) {
                    ++runtime_metrics.active_sessions;
                }
                Log::log_with_endpoint(endpoint, success_log_message);
                session->start();
            }
        }
    }
    return true;
}

void Service::run() {
    tcp::endpoint local_endpoint;
    
    if (use_multi_io_context) {
        local_endpoint = workers[0]->acceptor->local_endpoint();
    } else {
        local_endpoint = socket_acceptor.local_endpoint();
    }

    string rt;
    if (config.run_type == Config::SERVER) {
        rt = "server";
    } else if (config.run_type == Config::FORWARD) {
        rt = "forward";
    } else if (config.run_type == Config::NAT) {
        rt = "nat";
    } else {
        rt = "client";
    }
    Log::log_with_date_time(string("trojan service (") + rt + ") started at " + local_endpoint.address().to_string() + ':' + to_string(local_endpoint.port()), Log::WARN);

    if (use_multi_io_context) {
        // 多 io_context 模式
        Log::log_with_date_time("starting " + to_string(thread_num) + " worker threads (multi io_context)", Log::WARN);
        
        if (config.run_type == Config::FORWARD) {
            udp_async_read();
        }

        // 启动每个 worker 的 accept 循环和线程
        for (size_t i = 0; i < workers.size(); ++i) {
            async_accept_worker(i);
            workers[i]->thread = std::thread([this, i]() {
                workers[i]->io_context->run();
            });
        }

        // 主线程运行 UDP（如果需要）
        if (config.run_type == Config::FORWARD) {
            io_context.run();
        }

        // 等待所有 worker 线程结束
        for (auto& worker : workers) {
            if (worker->thread.joinable()) {
                worker->thread.join();
            }
        }
    } else {
        // 单 io_context 模式
        async_accept();
        if (config.run_type == Config::FORWARD) {
            udp_async_read();
        }

        if (thread_num > 1) {
            Log::log_with_date_time("starting " + to_string(thread_num) + " worker threads (shared io_context)", Log::WARN);
            for (int i = 0; i < thread_num; ++i) {
                thread_pool.emplace_back([this]() {
                    io_context.run();
                });
            }
            for (auto &t : thread_pool) {
                if (t.joinable()) {
                    t.join();
                }
            }
        } else {
            io_context.run();
        }
    }

    Log::log_with_date_time(runtime_metrics.summary(), Log::WARN);
    Log::log_with_date_time("trojan service stopped", Log::WARN);
}

void Service::stop() {
    boost::system::error_code ec;
    
    if (use_multi_io_context) {
        for (auto& worker : workers) {
            if (worker->acceptor) {
                worker->acceptor->cancel(ec);
            }
            worker->io_context->stop();
        }
    } else {
        socket_acceptor.cancel(ec);
    }
    
    if (udp_socket.is_open()) {
        udp_socket.cancel(ec);
        udp_socket.close(ec);
    }
    io_context.stop();
}

// 单 io_context 模式的 accept
void Service::async_accept() {
    auto session = create_session(io_context);
    socket_acceptor.async_accept(session->accept_socket(), [this, session](const boost::system::error_code error) {
        if (handle_accept_completion(session, error, "incoming connection")) {
            async_accept();
        }
    });
}

// 多 io_context 模式的 accept
void Service::async_accept_worker(size_t worker_index) {
    auto& worker = workers[worker_index];
    auto& worker_io_context = *worker->io_context;
    
    auto session = create_session(worker_io_context);
    
    worker->acceptor->async_accept(session->accept_socket(), [this, session, worker_index](const boost::system::error_code error) {
        if (handle_accept_completion(session, error, "incoming connection (worker " + to_string(worker_index) + ")")) {
            async_accept_worker(worker_index);
        }
    });
}

void Service::udp_async_read() {
    udp_socket.async_receive_from(boost::asio::buffer(udp_read_buf, MAX_LENGTH), udp_recv_endpoint, [this](const boost::system::error_code error, size_t length) {
        if (error == boost::asio::error::operation_aborted) {
            return;
        }
        if (error) {
            Log::log_with_date_time("udp receive failed: " + error.message(), Log::ERROR);
            stop();
            return;
        }
        string data((const char *)udp_read_buf, length);
        {
            std::lock_guard<std::mutex> lock(udp_sessions_mutex);
            auto it = udp_sessions.find(udp_recv_endpoint);
            if (it != udp_sessions.end()) {
                if (it->second.expired()) {
                    udp_sessions.erase(it);
                } else {
                    if (it->second.lock()->process(udp_recv_endpoint, data)) {
                        udp_async_read();
                        return;
                    }
                }
            }
        }
        Log::log_with_endpoint(tcp::endpoint(udp_recv_endpoint.address(), udp_recv_endpoint.port()), "new UDP session");
        
        // UDP session 使用 round-robin 分配到各个 worker
        auto& target_io_context = get_worker_io_context();
        auto session = make_shared<UDPForwardSession>(config, target_io_context, ssl_context, udp_recv_endpoint, [this](const udp::endpoint &endpoint, const string &data) {
            boost::system::error_code ec;
            {
                std::lock_guard<std::mutex> lock(udp_socket_mutex);
                udp_socket.send_to(boost::asio::buffer(data), endpoint, 0, ec);
            }
            if (ec == boost::asio::error::no_permission) {
                Log::log_with_endpoint(tcp::endpoint(endpoint.address(), endpoint.port()), "dropped a UDP packet due to firewall policy or rate limit");
            } else if (ec) {
                Log::log_with_endpoint(tcp::endpoint(endpoint.address(), endpoint.port()), "udp send failed: " + ec.message(), Log::ERROR);
            }
        });
        {
             std::lock_guard<std::mutex> lock(udp_sessions_mutex);
             udp_sessions[udp_recv_endpoint] = session;
        }
        session->start();
        session->process(udp_recv_endpoint, data);
        udp_async_read();
    });
}

boost::asio::io_context &Service::service() {
    if (use_multi_io_context && !workers.empty()) {
        return *workers[0]->io_context;
    }
    return io_context;
}

void Service::reload_cert() {
    if (config.run_type == Config::SERVER) {
        Log::log_with_date_time("reloading certificate and private key. . . ", Log::WARN);
        ssl_context.use_certificate_chain_file(config.ssl.cert);
        ssl_context.use_private_key_file(config.ssl.key, context::pem);
        
        if (use_multi_io_context) {
            boost::system::error_code ec;
            for (size_t i = 0; i < workers.size(); ++i) {
                workers[i]->acceptor->cancel(ec);
                async_accept_worker(i);
            }
        } else {
            boost::system::error_code ec;
            socket_acceptor.cancel(ec);
            async_accept();
        }
        Log::log_with_date_time("certificate and private key reloaded", Log::WARN);
    } else {
        Log::log_with_date_time("cannot reload certificate and private key: wrong run_type", Log::ERROR);
    }
}

Service::~Service() {
    if (auth) {
        delete auth;
        auth = nullptr;
    }
}
