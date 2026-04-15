import 'dart:convert';

import '../../profiles/domain/client_profile.dart';
import '../../routing/application/routing_profile_codec.dart';

class TrojanClientConfigRenderer {
  TrojanClientConfigRenderer({RoutingProfileCodec? routingCodec})
      : _routingCodec = routingCodec ?? const RoutingProfileCodec();

  final RoutingProfileCodec _routingCodec;

  String render({
    required ClientProfile profile,
    required String password,
    String? certPath,
  }) {
    final payload = <String, Object?>{
      'run_type': 'client',
      'local_addr': '127.0.0.1',
      'local_port': profile.localSocksPort,
      'remote_addr': profile.serverHost,
      'remote_port': profile.serverPort,
      'password': <String>[password],
      'log_level': 1,
      'ssl': <String, Object?>{
        'verify': profile.verifyTls,
        'verify_hostname': profile.verifyTls,
        'cert': certPath ?? '',
        'sni': profile.sni.isEmpty ? profile.serverHost : profile.sni,
        'alpn': const <String>['h2', 'http/1.1'],
        'reuse_session': true,
        'session_ticket': false,
        'cipher': 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256',
        'cipher_tls13': 'TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256',
        'curves': '',
      },
      'tcp': <String, Object?>{
        'no_delay': true,
        'keep_alive': true,
        'reuse_port': false,
        'fast_open': false,
        'fast_open_qlen': 20,
      },
      'routing': _routingCodec.encodeToJsonMap(profile.routing),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
