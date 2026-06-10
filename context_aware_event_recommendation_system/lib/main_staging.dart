import 'config/app_env.dart';
import 'main.dart' as base;

Future<void> main() async {
  AppEnv.flavor = 'staging';
  AppEnv.sentryTracesSampleRate = 0.5;
  await base.main();
}
