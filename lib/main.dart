import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'screens/menu_screen.dart';
import 'state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  await api.loadTokens();
  runApp(PizzeriaApp(api: api));
}

class PizzeriaApp extends StatelessWidget {
  final ApiClient api;

  const PizzeriaApp({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider(create: (_) => AuthModel(api)),
        ChangeNotifierProvider(create: (_) => CartModel()),
      ],
      child: MaterialApp(
        title: 'Good Pizza',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD84315)),
          useMaterial3: true,
        ),
        home: const MenuScreen(),
      ),
    );
  }
}
