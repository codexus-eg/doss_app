import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:doss_core/doss_core.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/ride/ride_bloc.dart';
import 'config/router.dart';

const String kBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://doss-backend-production.up.railway.app',
);

final _lastError = ValueNotifier<String?>(null);

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      _lastError.value = '${d.exceptionAsString()}\n\n${d.stack}';
    };
    PlatformDispatcher.instance.onError = (e, s) {
      _lastError.value = '$e\n\n$s';
      return true;
    };
    ErrorWidget.builder = (d) =>
        _FatalErrorScreen(message: '${d.exceptionAsString()}\n\n${d.stack}');
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
    ));
    ApiClient.instance.configure(kBackendUrl);
    runApp(const DossRiderApp());
  }, (e, s) => _lastError.value = '$e\n\n$s');
}

class _FatalErrorScreen extends StatelessWidget {
  final String message;
  const _FatalErrorScreen({required this.message});
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: const Color(0xFF08131F),
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DOSS STARTUP ERROR',
                  style: TextStyle(
                      color: Color(0xFF06F6FF),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SelectableText(message,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4)),
            ]),
          ),
        ),
      );
}

class DossRiderApp extends StatelessWidget {
  const DossRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (_, lang, __) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) {
              final bloc = AuthBloc()..add(AuthCheckRequested());
              AppRouter.setAuthBloc(bloc); // register for GoRouter refresh
              return bloc;
            }),
            BlocProvider(create: (_) => RideBloc()),
          ],
          child: MaterialApp.router(
            title: 'DOSS',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            locale: lang.locale,
            routerConfig: AppRouter.router,
            builder: (ctx, child) => Directionality(
              textDirection: lang.textDirection,
              child: child!,
            ),
          ),
        ),
      ),
    );
  }
}
