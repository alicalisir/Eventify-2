import 'config/app_env.dart';
import 'main.dart' as base;

Future<void> main() async {
  AppEnv.flavor = 'development';
  AppEnv.backendUrlOverride = 'http://10.0.2.2:8000';
  AppEnv.sentryTracesSampleRate = 1.0;
  await base.main();
}
