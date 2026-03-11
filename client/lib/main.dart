import 'package:flutter/widgets.dart';

import 'bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final services = ClientBootstrap.createServices();
  runApp(TrojanClientApp(services: services));
}
