import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hardware_ui/calculator_chassis_shell.dart';
import 'state/calculator_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0C0E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const Cal_1100_DB_App());
}

/// Root Flutter application for the Cal_ 1100_DB_ ClassWiz emulator.
class Cal_1100_DB_App extends StatefulWidget {
  const Cal_1100_DB_App({super.key});

  @override
  State<Cal_1100_DB_App> createState() => _Cal_1100_DB_AppState();
}

class _Cal_1100_DB_AppState extends State<Cal_1100_DB_App>
    with WidgetsBindingObserver {
  late final CalculatorController _controller = CalculatorController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.restoreFromPersistentStorage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _controller.saveToPersistentStorage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.saveToPersistentStorage();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CalculatorScope(
      controller: _controller,
      child: MaterialApp(
        title: 'Scientific Calculator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF101215),
        ),
        home: const Cal_ChassisShell(),
      ),
    );
  }
}
