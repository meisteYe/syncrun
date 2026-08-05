// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/activity_tracking/presentation/bloc/activity_bloc.dart'; // <-- EKLENDİ
import 'features/auth/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase'i başlat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Dependency Injection konteynerini başlat
  await di.init();

  runApp(const SyncRunApp());
}

class SyncRunApp extends StatelessWidget {
  const SyncRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiBlocProvider ile uygulamanın en üst seviyesinden Bloc'ları sağlıyoruz.
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
        BlocProvider<ActivityBloc>(
          create: (_) => di.sl<ActivityBloc>(),
        ), // <-- EKLENDİ
      ],
      child: MaterialApp(
        title: 'SyncRun',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00E676),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        // Giriş ekranımızı ana sayfa yapıyoruz
        home: const LoginPage(),
      ),
    );
  }
}
