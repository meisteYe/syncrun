import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_page.dart';
import 'tracking_page.dart';
import 'history_page.dart';
import '../../../../features/profile/presentation/pages/profile_page.dart';
import '../../../../features/leaderboard/presentation/pages/leaderboard_page.dart'; // YENİ
import '../../../ghost_run/ghost_runner_cubit.dart';
import '../../data/repositories/activity_repository.dart';
import '../../../../injection_container.dart';

final ValueNotifier<int> globalPageIndex = ValueNotifier<int>(0);

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // YENİ: UYGULAMA AÇILDIĞINDA EĞER İNTERNETSİZ KOŞULAR VARSA SUNUCUYA GÖNDER!
    sl<ActivityRepository>().syncOfflineActivities();

    _pages = [
      HomePage(onStartRunTap: () => globalPageIndex.value = 1),
      const TrackingPage(),
      const LeaderboardPage(), // YENİ: Liderlik Tablosu sekmesi
      const HistoryPage(),
      const ProfilePage(),
    ];

    globalPageIndex.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GhostRunnerCubit, GhostRunnerState>(
      listenWhen: (previous, current) => !previous.isActive && current.isActive,
      listener: (context, state) {
        globalPageIndex.value = 1;
      },
      child: Scaffold(
        body: IndexedStack(index: globalPageIndex.value, children: _pages),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: globalPageIndex.value,
          onTap: (index) => globalPageIndex.value = index,
          backgroundColor: Colors.black,
          selectedItemColor: const Color(0xFF00E676),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Harita'),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              label: 'Lig',
            ), // YENİ
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
