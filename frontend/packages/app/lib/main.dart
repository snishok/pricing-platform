import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/state/auth_state.dart';
import 'src/state/pricing_state.dart';
import 'src/ui/login_page.dart';
import 'src/ui/search_page.dart';
import 'src/ui/upload_page.dart';

void main() {
  const apiBaseRaw = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8080/api/');
  final apiBase = apiBaseRaw.endsWith('/') ? apiBaseRaw : '$apiBaseRaw/';
  final client = ApiClient(baseUri: Uri.parse(apiBase));

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider(create: (_) => AuthState(client)),
        ChangeNotifierProvider(create: (_) => PricingState(client)),
      ],
      child: const PricingPlatformApp(),
    ),
  );
}

class PricingPlatformApp extends StatefulWidget {
  const PricingPlatformApp({super.key});

  @override
  State<PricingPlatformApp> createState() => _PricingPlatformAppState();
}

class _PricingPlatformAppState extends State<PricingPlatformApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleThemeMode() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.light => ThemeMode.dark,
        _ => ThemeMode.light,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1F6FEB);
    return MaterialApp(
      title: 'Pricing Platform',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (!auth.isLoggedIn) return const LoginPage();
          return HomeTabs(onToggleTheme: _toggleThemeMode, themeMode: _themeMode);
        },
      ),
    );
  }
}

class HomeTabs extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  const HomeTabs({super.key, required this.onToggleTheme, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final tabs = <Widget>[const Tab(text: 'Search')];
    final views = <Widget>[const SearchPage()];
    if (auth.canUpload) {
      tabs.add(const Tab(text: 'Upload'));
      views.add(const UploadPage());
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pricing Platform'),
          bottom: TabBar(tabs: tabs),
          actions: [
            IconButton(
              tooltip: themeMode == ThemeMode.dark ? 'Switch to light theme' : 'Switch to dark theme',
              onPressed: onToggleTheme,
              icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            ),
            IconButton(
              tooltip: 'Logout',
              onPressed: () => context.read<AuthState>().logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: TabBarView(children: views),
      ),
    );
  }
}

