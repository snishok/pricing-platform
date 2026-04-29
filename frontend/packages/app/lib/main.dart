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

class PricingPlatformApp extends StatelessWidget {
  const PricingPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pricing Platform',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (!auth.isLoggedIn) return const LoginPage();
          return const HomeTabs();
        },
      ),
    );
  }
}

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pricing Platform'),
          bottom: const TabBar(tabs: [Tab(text: 'Search'), Tab(text: 'Upload')]),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: () => context.read<AuthState>().logout(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            SearchPage(),
            UploadPage(),
          ],
        ),
      ),
    );
  }
}

