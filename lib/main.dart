import 'dart:async';

import 'package:flutter/material.dart';
import 'theme/app_colors.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'pages/home_page.dart';
import 'pages/now_playing_page.dart';
import 'pages/profile_page.dart';
import 'pages/minigame_page.dart';
import 'pages/cinebot_page.dart';
import 'services/database_helper.dart';
import 'services/notification_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tangkap semua error Flutter dan tampilkan UI error (Red Screen) agar tidak blank hitam
  FlutterError.onError = (details) {
    debugPrint("══ FLUTTER ERROR ══\n${details.exceptionAsString()}");
    debugPrint(details.stack.toString());
    FlutterError.presentError(details); // Ini penting agar Red Screen of Death muncul!
  };

  debugPrint("▶ main() START");

  try {
    await initializeDateFormatting('id_ID', null);
    debugPrint("▶ Date formatting OK");
  } catch (e) {
    debugPrint("▶ Date formatting GAGAL: $e");
  }

  try {
    await DatabaseHelper.instance.database.timeout(const Duration(seconds: 3));
    debugPrint("▶ SQLite OK");
  } catch (e) {
    debugPrint("▶ SQLite GAGAL: $e");
  }

  // Notification init DENGAN timeout 3 detik (agar tidak hang selamanya)
  try {
    await NotificationHelper.instance.init()
        .timeout(const Duration(seconds: 3));
    debugPrint("▶ Notification OK");
  } catch (e) {
    debugPrint("▶ Notification SKIP: $e");
  }

  debugPrint("▶ runApp()");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CineGlobal',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navyPrimary,
          primary: AppColors.navyPrimary,
          secondary: AppColors.gold,
        ),
      ),
      home: const SplashCheckPage(),
    );
  }
}

class SplashCheckPage extends StatefulWidget {
  const SplashCheckPage({super.key});
  @override
  State<SplashCheckPage> createState() => _SplashCheckPageState();
}

class _SplashCheckPageState extends State<SplashCheckPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyPrimary, AppColors.navySecondary],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie_filter_rounded, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text("CineGlobal", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MAIN PAGE — 4 Tab Bottom Navigation + Floating CineBot
// ─────────────────────────────────────────────────────────
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _cinebotOpen = false;
  // Notifier untuk trigger reload profil
  final ValueNotifier<int> _profileReloadNotifier = ValueNotifier<int>(0);

  late final List<Widget> _pages = [
    const HomePage(),
    const NowPlayingPage(),
    const MinigamePage(),
    ProfilePage(reloadNotifier: _profileReloadNotifier),
  ];

  void _toggleCinebot() {
    setState(() => _cinebotOpen = !_cinebotOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          IndexedStack(index: _currentIndex, children: _pages),
          
          // ── CineBot Popup Overlay ──
          if (_cinebotOpen) ...[
            // Background dim
            GestureDetector(
              onTap: _toggleCinebot,
              child: Container(color: Colors.black54),
            ),
            // Chat popup
            Positioned(
              left: 12,
              right: 12,
              bottom: 90,
              top: MediaQuery.of(context).size.height * 0.12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyPrimary.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: const CinebotPage(),
              ),
            ),
          ],
        ],
      ),
      // ── Floating CineBot Button ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: _toggleCinebot,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: _cinebotOpen
                  ? const LinearGradient(colors: [_C.fabClose1, _C.fabClose2])
                  : const LinearGradient(colors: [_C.fabOpen1, _C.fabOpen2]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (_cinebotOpen ? _C.fabClose1 : _C.fabOpen1).withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _cinebotOpen ? Icons.close : Icons.chat_bubble,
                  color: _cinebotOpen ? _C.fabCloseIcon : _C.fabOpenIcon,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _cinebotOpen ? "Tutup" : "CineBot",
                  style: TextStyle(
                    color: _cinebotOpen ? _C.fabCloseText : _C.fabOpenText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _C.bottomNavBg,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(color: _C.bottomNavActive, fontSize: 12, fontWeight: FontWeight.bold);
                }
                return const TextStyle(color: _C.bottomNavInactive, fontSize: 12);
              }),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: _C.bottomNavBg,
            indicatorColor: Colors.transparent,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (i) {
              setState(() => _currentIndex = i);
              // Reload profil saat pindah ke tab Profil (index 3)
              if (i == 3) {
                _profileReloadNotifier.value++;
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: _C.bottomNavInactive),
                selectedIcon: Icon(Icons.home, color: _C.bottomNavActive),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_movies_outlined, color: _C.bottomNavInactive),
                selectedIcon: Icon(Icons.local_movies, color: _C.bottomNavActive),
                label: 'Tiket',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined, color: _C.bottomNavInactive),
                selectedIcon: Icon(Icons.sports_esports, color: _C.bottomNavActive),
                label: 'MiniGame',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: _C.bottomNavInactive),
                selectedIcon: Icon(Icons.person, color: _C.bottomNavActive),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _C {
  _C._();
  // --- Bottom Navigation ---
  static const Color bottomNavBg = AppColors.navyPrimary;    // background bottom nav
  static const Color bottomNavActive = AppColors.gold;       // icon + label aktif
  static const Color bottomNavInactive = Colors.white54;     // icon + label non-aktif

  // --- FAB Gradient (saat tertutup = "CineBot") ---
  static const Color fabOpen1 = AppColors.navyPrimary;       // gradient kiri (tertutup)
  static const Color fabOpen2 = AppColors.navyPrimary;       // gradient kanan (tertutup)
  static const Color fabOpenIcon = AppColors.gold;           // icon chat_bubble
  static const Color fabOpenText = AppColors.gold;           // teks "CineBot"

  // --- FAB Gradient (saat terbuka = "Tutup") ---
  static const Color fabClose1 = Colors.red;
  static const Color fabClose2 = Colors.red;
  static const Color fabCloseIcon = Colors.white;
  static const Color fabCloseText = Colors.white;

  // --- Legacy (backward compat) ---
  static const Color fabIcon = AppColors.gold;
  static const Color fabText = AppColors.gold;
}
