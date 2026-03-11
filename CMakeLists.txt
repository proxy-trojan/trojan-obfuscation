cmake_minimum_required(VERSION 3.7.2)
project(trojan CXX)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake/")
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(MSVC)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
else()
    add_definitions(-Wall -Wextra)
endif()

file(GLOB_RECURSE CPP_LIST src/*.cpp)

add_executable(trojan ${CPP_LIST})
target_include_directories(trojan PRIVATE src)

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
target_link_libraries(trojan ${CMAKE_THREAD_LIBS_INIT})

# Use static Boost libraries for portable binaries (especially on Linux)
option(BOOST_USE_STATIC_LIBS "Use static Boost libraries" ON)
if(BOOST_USE_STATIC_LIBS)
    set(Boost_USE_STATIC_LIBS ON)
    set(Boost_USE_STATIC_RUNTIME OFF)
endif()

find_package(Boost 1.66.0 REQUIRED COMPONENTS system program_options)
target_include_directories(trojan PRIVATE ${Boost_INCLUDE_DIR})
target_link_libraries(trojan ${Boost_LIBRARIES})
if(MSVC)
    add_definitions(-DBOOST_DATE_TIME_NO_LIB)
endif()

find_package(OpenSSL 1.1.0 REQUIRED)
target_include_directories(trojan PRIVATE ${OPENSSL_INCLUDE_DIR})
target_link_libraries(trojan ${OPENSSL_LIBRARIES})
if(OPENSSL_VERSION VERSION_GREATER_EQUAL 1.1.1)
    option(ENABLE_SSL_KEYLOG "Build with SSL KeyLog support" OFF)
    if(ENABLE_SSL_KEYLOG)
        add_definitions(-DENABLE_SSL_KEYLOG)
    endif()

    option(ENABLE_TLS13_CIPHERSUITES "Build with TLS1.3 ciphersuites support" ON)
    if(ENABLE_TLS13_CIPHERSUITES)
        add_definitions(-DENABLE_TLS13_CIPHERSUITES)
    endif()
endif()

option(ENABLE_MYSQL "Build with MySQL support" OFF)
if(ENABLE_MYSQL)
    find_package(MySQL REQUIRED)
    target_include_directories(trojan PRIVATE ${MYSQL_INCLUDE_DIR})
    target_link_libraries(trojan ${MYSQL_LIBRARIES})
    add_definitions(-DENABLE_MYSQL)
endif()

option(FORCE_TCP_FASTOPEN "Force build with TCP Fast Open support" ON)
if(FORCE_TCP_FASTOPEN)
    add_definitions(-DTCP_FASTOPEN=23 -DTCP_FASTOPEN_CONNECT=30)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL Linux)
    option(ENABLE_NAT "Build with NAT support" ON)
    if(ENABLE_NAT)
        add_definitions(-DENABLE_NAT)
    endif()

    option(ENABLE_REUSE_PORT "Build with SO_REUSEPORT support" ON)
    if(ENABLE_REUSE_PORT)
        add_definitions(-DENABLE_REUSE_PORT)
    endif()
endif()

if(APPLE)
    find_library(CoreFoundation CoreFoundation)
    find_library(Security Security)
    target_link_libraries(trojan ${CoreFoundation} ${Security})
endif()

if(WIN32)
    target_link_libraries(trojan wsock32 ws2_32 crypt32)
else()
    set(SYSTEMD_SERVICE AUTO CACHE STRING "Install systemd service")
    set_property(CACHE SYSTEMD_SERVICE PROPERTY STRINGS AUTO ON OFF)
    set(SYSTEMD_SERVICE_PATH /lib/systemd/system CACHE PATH "Systemd service path")
    if(SYSTEMD_SERVICE STREQUAL AUTO)
        if(EXISTS /usr/lib/systemd/system)
            set(SYSTEMD_SERVICE ON)
            set(SYSTEMD_SERVICE_PATH /usr/lib/systemd/system CACHE PATH "Systemd service path" FORCE)
        elseif(EXISTS /lib/systemd/system)
            set(SYSTEMD_SERVICE ON)
            set(SYSTEMD_SERVICE_PATH /lib/systemd/system CACHE PATH "Systemd service path" FORCE)
        endif()
    endif()

    include(GNUInstallDirs)
    install(TARGETS trojan DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES examples/server.json-example DESTINATION ${CMAKE_INSTALL_FULL_SYSCONFDIR}/trojan RENAME config.json)
    set(DEFAULT_CONFIG ${CMAKE_INSTALL_FULL_SYSCONFDIR}/trojan/config.json CACHE STRING "Default config path")
    add_definitions(-DDEFAULT_CONFIG="${DEFAULT_CONFIG}")
    install(FILES docs/trojan.1 DESTINATION ${CMAKE_INSTALL_MANDIR}/man1)
    install(DIRECTORY docs/ DESTINATION ${CMAKE_INSTALL_DOCDIR} FILES_MATCHING PATTERN "*.md")
    install(DIRECTORY examples DESTINATION ${CMAKE_INSTALL_DOCDIR} FILES_MATCHING PATTERN "*.json-example")
    if(SYSTEMD_SERVICE STREQUAL ON)
        set(CONFIG_NAME config)
        configure_file(examples/trojan.service-example trojan.service)
        set(CONFIG_NAME %i)
        configure_file(examples/trojan.service-example trojan@.service)
        install(FILES ${CMAKE_BINARY_DIR}/trojan.service ${CMAKE_BINARY_DIR}/trojan@.service DESTINATION ${SYSTEMD_SERVICE_PATH})
    endif()

    enable_testing()
    add_test(NAME LinuxSmokeTest-basic
             COMMAND bash ${CMAKE_SOURCE_DIR}/tests/LinuxSmokeTest/basic.sh ${CMAKE_BINARY_DIR}/trojan)
    add_test(NAME LinuxSmokeTest-server-config-fails
             COMMAND bash ${CMAKE_SOURCE_DIR}/tests/LinuxSmokeTest/server-config-fails.sh ${CMAKE_BINARY_DIR}/trojan)
    add_test(NAME LinuxSmokeTest-auth-fail-cooldown
             COMMAND bash ${CMAKE_SOURCE_DIR}/tests/LinuxSmokeTest/auth-fail-cooldown.sh ${CMAKE_BINARY_DIR}/trojan)
    add_test(NAME LinuxSmokeTest-fallback-budget
             COMMAND bash ${CMAKE_SOURCE_DIR}/tests/LinuxSmokeTest/fallback-budget.sh ${CMAKE_BINARY_DIR}/trojan)

    add_executable(runtime_seam_tests
                   tests/RuntimeSeamTest/runtime_seam_tests.cpp
                   src/core/session_admission_runtime.cpp
                   src/core/session_lifecycle_runtime.cpp
                   src/core/session_gate.cpp
                   src/core/embedded_tls_edge.cpp
                   src/core/embedded_tls_inbound.cpp
                   src/proto/trojanrequest.cpp
                   src/proto/socks5address.cpp
                   src/core/relay_executor.cpp
                   src/core/outbound_dialer.cpp
                   src/core/config_trusted_internal_handoff_source_stub.cpp
                   src/core/external_front_handoff_builder.cpp
                   src/core/external_front_handoff_contract.cpp
                   src/core/trusted_front_envelope.cpp
                   src/core/trusted_internal_handoff_input.cpp
                   src/core/external_front_metadata_provider.cpp
                   src/core/external_front_trust_policy.cpp
                   src/core/external_front_inbound.cpp
                   src/core/server_ingress_selector.cpp
                   src/core/authenticator.cpp
                   src/core/config.cpp
                   src/core/log.cpp)
    target_include_directories(runtime_seam_tests PRIVATE src)
    target_link_libraries(runtime_seam_tests ${CMAKE_THREAD_LIBS_INIT} ${Boost_LIBRARIES} ${OPENSSL_LIBRARIES})

    add_test(NAME RuntimeSeamTests COMMAND runtime_seam_tests)

    set_tests_properties(LinuxSmokeTest-server-config-fails PROPERTIES DEPENDS "LinuxSmokeTest-basic")
    set_tests_properties(LinuxSmokeTest-auth-fail-cooldown PROPERTIES DEPENDS "LinuxSmokeTest-basic")
    set_tests_properties(LinuxSmokeTest-fallback-budget PROPERTIES DEPENDS "LinuxSmokeTest-basic")
endif()
