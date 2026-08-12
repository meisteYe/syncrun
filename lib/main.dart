// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // OTO GİRİŞ İÇİN EKLENDİ
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/activity_tracking/presentation/bloc/activity_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/ghost_run/ghost_runner_cubit.dart';
// ARTIK TRACKING PAGE DEĞİL, MAIN PAGE'İ İÇERİ AKTARIYORUZ
import 'features/activity_tracking/presentation/pages/main_page.dart';

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
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
        BlocProvider<ActivityBloc>(create: (_) => di.sl<ActivityBloc>()),
        BlocProvider<GhostRunnerCubit>(create: (_) => GhostRunnerCubit()),
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
        // OTO GİRİŞ: Oturum durumunu dinleyip ilgili sayfaya yönlendiriyoruz
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                ),
              );
            }
            if (snapshot.hasData) {
              return const MainPage(); // ARTIK ALT MENÜLÜ ANA SAYFAYA GİDİYOR
            }
            return const LoginPage(); // Giriş yapmamışsa login ekranı
          },
        ),
      ),
    );
  }
}
