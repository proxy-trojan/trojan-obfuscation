import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await ClientBootstrap.createServices();
  runApp(TrojanClientApp(services: services));
}
