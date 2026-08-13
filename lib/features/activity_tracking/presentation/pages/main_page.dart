import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_page.dart';
import 'tracking_page.dart';
import 'history_page.dart';
import '../../../../features/profile/presentation/pages/profile_page.dart';
import '../../../ghost_run/ghost_runner_cubit.dart';

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
    _pages = [
      HomePage(onStartRunTap: () => globalPageIndex.value = 1),
      const TrackingPage(),
      const HistoryPage(),
      const ProfilePage(),
    ];

    globalPageIndex.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // BLOCLISTENER İLE HAYALETİ TAKİP ET
    return BlocListener<GhostRunnerCubit, GhostRunnerState>(
      listenWhen: (previous, current) => !previous.isActive && current.isActive,
      listener: (context, state) {
        // Hayalet yüklendiği an:
        globalPageIndex.value = 1; // Haritaya geç
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
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Geçmiş'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
