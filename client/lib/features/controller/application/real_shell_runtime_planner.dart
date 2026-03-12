import '../../profiles/domain/client_profile.dart';
import '../domain/controller_launch_plan.dart';
import 'trojan_binary_locator.dart';

class RealShellRuntimePlanner {
  RealShellRuntimePlanner({TrojanBinaryLocator? binaryLocator})
      : _binaryLocator = binaryLocator ?? const TrojanBinaryLocator();

  final TrojanBinaryLocator _binaryLocator;

  ControllerLaunchPlan buildConnectPlan({
    required ClientProfile profile,
    required String configPath,
  }) {
    final binaryPath = _binaryLocator.preferredBinaryPath();
    return ControllerLaunchPlan(
      binaryPath: binaryPath,
      configPath: configPath,
      arguments: <String>['-c', configPath],
      summary: 'Launch trojan client for ${profile.name} via $binaryPath using config $configPath',
    );
  }

  ControllerLaunchPlan buildHealthPlan() {
    final binaryPath = _binaryLocator.preferredBinaryPath();
    return ControllerLaunchPlan(
      binaryPath: binaryPath,
      configPath: '',
      arguments: const <String>['-v'],
      summary: 'Probe trojan binary version/build info via $binaryPath',
    );
  }
}
