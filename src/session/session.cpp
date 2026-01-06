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

#include "session.h"
#include <algorithm>
#include <cstring>

Session::Session(const Config &config, boost::asio::io_context &io_context) : config(config),
                                                                              recv_len(0),
                                                                              sent_len(0),
                                                                              resolver(io_context),
                                                                              udp_socket(io_context),
                                                                              ssl_shutdown_timer(io_context) {
    initialize_buffers();
}

Session::~Session() = default;

void Session::initialize_buffers() {
    // 初始化为默认大小 (16KB)
    in_read_buf.resize(DEFAULT_BUFFER_SIZE);
    out_read_buf.resize(DEFAULT_BUFFER_SIZE);
    udp_read_buf.resize(DEFAULT_BUFFER_SIZE);
    // 写缓冲区初始化
    in_write_buf.reserve(DEFAULT_BUFFER_SIZE);
    out_write_buf_data.reserve(DEFAULT_BUFFER_SIZE);
}

void Session::resize_buffer(std::vector<uint8_t>& buffer, size_t required_size) {
    // 只在需要更大的缓冲区时调整大小，且不超过最大限制
    if (required_size > buffer.size() && required_size <= MAX_BUFFER_SIZE) {
        // 扩大缓冲区，但有一个上限
        size_t new_size = std::min(MAX_BUFFER_SIZE, std::max(buffer.size() * 2, required_size));
        buffer.resize(new_size);
    }
}

void Session::prepare_write_buffer(std::vector<uint8_t>& write_buf, const uint8_t* data, size_t length) {
    // 确保写缓冲区足够大
    if (write_buf.capacity() < length) {
        write_buf.reserve(std::max(length, write_buf.capacity() * 2));
    }
    write_buf.assign(data, data + length);
}

void Session::prepare_write_buffer(std::vector<uint8_t>& write_buf, const std::string& data) {
    prepare_write_buffer(write_buf, reinterpret_cast<const uint8_t*>(data.data()), data.size());
}
