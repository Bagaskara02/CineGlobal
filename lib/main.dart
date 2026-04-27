import 'package:flutter/material.dart';

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
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi SQLite Database (wrapped in try-catch agar tidak crash)
  try {
    await DatabaseHelper.instance.database;
    debugPrint("SQLite Berhasil Terhubung");
  } catch (e) {
    debugPrint("SQLite Gagal Inisialisasi: $e");
  }

  // Inisialisasi Notification
  try {
    await NotificationHelper.instance.init();
  } catch (e) {
    debugPrint("Notification Init Gagal: $e");
  }



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
          seedColor: const Color(0xFF00113A),
          primary: const Color(0xFF00113A),
          secondary: const Color(0xFFFCD400),
        ),
      ),
      home: const SplashCheckPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SPLASH / SESSION CHECK (Auto-login jika session ada)
// ─────────────────────────────────────────────────────────
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
    
    // Langsung ke MainPage tanpa perlu login
    // Login hanya diminta saat user mau akses detail/pesan tiket
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
            colors: [Color(0xFF00113A), Color(0xFF001F5C)],
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
                      color: const Color(0xFF00113A).withValues(alpha: 0.3),
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
                  ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                  : const LinearGradient(colors: [Color(0xFF2AC4A0), Color(0xFF3DDAB4)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: (_cinebotOpen ? const Color(0xFFFF6B6B) : const Color(0xFF2AC4A0)).withValues(alpha: 0.4),
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
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _cinebotOpen ? "Tutup" : "Livechat",
                  style: const TextStyle(
                    color: Colors.white,
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
          color: Color(0xFF00113A),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(color: Color(0xFFFCD400), fontSize: 12, fontWeight: FontWeight.bold);
                }
                return const TextStyle(color: Colors.white54, fontSize: 12);
              }),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: const Color(0xFF00113A),
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
                icon: Icon(Icons.home_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.home, color: Color(0xFFFCD400)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_movies_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.local_movies, color: Color(0xFFFCD400)),
                label: 'Tiket',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined, color: Colors.white54),
                selectedIcon: Icon(Icons.sports_esports, color: Color(0xFFFCD400)),
                label: 'MiniGame',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: Colors.white54),
                selectedIcon: Icon(Icons.person, color: Color(0xFFFCD400)),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}