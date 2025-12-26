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

#include "authenticator.h"
#include <cstdlib>
#include <stdexcept>
using namespace std;

#ifdef ENABLE_MYSQL

Authenticator::Authenticator(const Config &config) {
    mysql_init(&con);
    Log::log_with_date_time("connecting to MySQL server " + config.mysql.server_addr + ':' + to_string(config.mysql.server_port), Log::INFO);
    if (!config.mysql.ca.empty()) {
        if (!config.mysql.key.empty() && !config.mysql.cert.empty()) {
            mysql_ssl_set(&con, config.mysql.key.c_str(), config.mysql.cert.c_str(), config.mysql.ca.c_str(), nullptr, nullptr);
        } else {
            mysql_ssl_set(&con, nullptr, nullptr, config.mysql.ca.c_str(), nullptr, nullptr);
        }
    }
    if (mysql_real_connect(&con, config.mysql.server_addr.c_str(),
                                 config.mysql.username.c_str(),
                                 config.mysql.password.c_str(),
                                 config.mysql.database.c_str(),
                                 config.mysql.server_port, nullptr, 0) == nullptr) {
        throw runtime_error(mysql_error(&con));
    }
    bool reconnect = true;
    mysql_options(&con, MYSQL_OPT_RECONNECT, &reconnect);
    Log::log_with_date_time("connected to MySQL server", Log::INFO);
}

bool Authenticator::auth(const string &password) {
    if (!is_valid_password(password)) {
        return false;
    }
    
    // 使用参数化查询防止SQL注入
    MYSQL_STMT *stmt = mysql_stmt_init(&con);
    if (!stmt) {
        Log::log_with_date_time("Failed to initialize statement: " + string(mysql_error(&con)), Log::ERROR);
        return false;
    }
    
    const char *sql = "SELECT quota, download + upload FROM users WHERE password = ?";
    if (mysql_stmt_prepare(stmt, sql, strlen(sql))) {
        Log::log_with_date_time("Failed to prepare statement: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return false;
    }
    
    // 绑定参数
    MYSQL_BIND param;
    memset(&param, 0, sizeof(param));
    param.buffer_type = MYSQL_TYPE_STRING;
    param.buffer = const_cast<char*>(password.c_str());
    param.buffer_length = password.length();
    
    if (mysql_stmt_bind_param(stmt, &param)) {
        Log::log_with_date_time("Failed to bind parameters: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return false;
    }
    
    // 执行查询
    if (mysql_stmt_execute(stmt)) {
        Log::log_with_date_time("Failed to execute statement: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return false;
    }
    
    // 存储结果
    if (mysql_stmt_store_result(stmt)) {
        Log::log_with_date_time("Failed to store result: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return false;
    }
    
    // 绑定结果
    long long quota = 0, used = 0;
    MYSQL_BIND result[2];
    memset(result, 0, sizeof(result));
    
    result[0].buffer_type = MYSQL_TYPE_LONGLONG;
    result[0].buffer = &quota;
    
    result[1].buffer_type = MYSQL_TYPE_LONGLONG;
    result[1].buffer = &used;
    
    if (mysql_stmt_bind_result(stmt, result)) {
        Log::log_with_date_time("Failed to bind result: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return false;
    }
    
    // 获取结果
    bool has_row = (mysql_stmt_fetch(stmt) == 0);
    mysql_stmt_close(stmt);
    
    if (!has_row) {
        return false;
    }
    
    if (quota < 0) {
        return true;
    }
    
    if (used >= quota) {
        Log::log_with_date_time(password + " ran out of quota", Log::WARN);
        return false;
    }
    
    return true;
}

void Authenticator::record(const string &password, uint64_t download, uint64_t upload) {
    if (!is_valid_password(password)) {
        return;
    }
    
    // 使用参数化查询防止SQL注入
    MYSQL_STMT *stmt = mysql_stmt_init(&con);
    if (!stmt) {
        Log::log_with_date_time("Failed to initialize statement: " + string(mysql_error(&con)), Log::ERROR);
        return;
    }
    
    const char *sql = "UPDATE users SET download = download + ?, upload = upload + ? WHERE password = ?";
    if (mysql_stmt_prepare(stmt, sql, strlen(sql))) {
        Log::log_with_date_time("Failed to prepare statement: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return;
    }
    
    // 绑定参数
    MYSQL_BIND params[3];
    memset(params, 0, sizeof(params));
    
    params[0].buffer_type = MYSQL_TYPE_LONGLONG;
    params[0].buffer = const_cast<uint64_t*>(&download);
    
    params[1].buffer_type = MYSQL_TYPE_LONGLONG;
    params[1].buffer = const_cast<uint64_t*>(&upload);
    
    params[2].buffer_type = MYSQL_TYPE_STRING;
    params[2].buffer = const_cast<char*>(password.c_str());
    params[2].buffer_length = password.length();
    
    if (mysql_stmt_bind_param(stmt, params)) {
        Log::log_with_date_time("Failed to bind parameters: " + string(mysql_error(&con)), Log::ERROR);
        mysql_stmt_close(stmt);
        return;
    }
    
    // 执行更新
    if (mysql_stmt_execute(stmt)) {
        Log::log_with_date_time("Failed to execute update: " + string(mysql_error(&con)), Log::ERROR);
    }
    
    mysql_stmt_close(stmt);
}

bool Authenticator::is_valid_password(const string &password) {
    if (password.size() != PASSWORD_LENGTH) {
        return false;
    }
    for (size_t i = 0; i < PASSWORD_LENGTH; ++i) {
        if (!((password[i] >= '0' && password[i] <= '9') || (password[i] >= 'a' && password[i] <= 'f'))) {
            return false;
        }
    }
    return true;
}

Authenticator::~Authenticator() {
    mysql_close(&con);
}

#else // ENABLE_MYSQL

Authenticator::Authenticator(const Config&) {}
bool Authenticator::auth(const string&) { return true; }
void Authenticator::record(const string&, uint64_t, uint64_t) {}
bool Authenticator::is_valid_password(const string&) { return true; }
Authenticator::~Authenticator() {}

#endif // ENABLE_MYSQL
