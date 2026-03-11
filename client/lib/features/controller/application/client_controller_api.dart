import 'package:flutter/foundation.dart';

import '../../profiles/domain/client_profile.dart';
import '../domain/client_connection_status.dart';

abstract class ClientControllerApi extends ChangeNotifier {
  ClientConnectionStatus get status;

  Future<void> connect(ClientProfile profile);

  Future<void> disconnect();
}
