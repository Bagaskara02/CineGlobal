import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'detail_page.dart';
import '../services/database_helper.dart';


class ProfilePage extends StatefulWidget {
  final ValueNotifier<int>? reloadNotifier;
  const ProfilePage({super.key, this.reloadNotifier});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Session dari SQLite
  Map<String, dynamic>? _session;
  bool get _isLoggedIn => _session != null;
  String? username;
  String? _email;
  String? avatarUrl;
  List<Map<String, dynamic>> watchlist = [];
  bool isLoading = true;
  bool _biometricEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBiometricStatus();
    // Listen notifier dari MainPage untuk reload saat pindah tab
    widget.reloadNotifier?.addListener(_onReloadRequested);
  }

  @override
  void dispose() {
    widget.reloadNotifier?.removeListener(_onReloadRequested);
    super.dispose();
  }

  void _onReloadRequested() => _loadUserData();

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    
    // Cek session dari SQLite (bukan Supabase auth)
    // Wrapped in try-catch + timeout karena sqflite TIDAK support Web/Chrome
    Map<String, dynamic>? session;
    try {
      session = await DatabaseHelper.instance.getSession()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("SQLite getSession error (mungkin web): $e");
      session = null;
    }
    
    if (session != null) {
      try {
        final sessionUserId = session['user_id'] as String;
        final sessionEmail = session['email'] as String;
        final sessionUsername = session['username'] as String?;

        // Ambil avatar dari SQLite (path lokal)
        String? avatar;
        try {
          avatar = await DatabaseHelper.instance.getAvatarPath(sessionUserId);
        } catch (e) {
          debugPrint("Load avatar error: $e");
        }

        // Ambil watchlist dari SQLite
        List<Map<String, dynamic>> wl = [];
        try {
          wl = await DatabaseHelper.instance.getWatchlist(sessionUserId);
        } catch (e) {
          debugPrint("Load watchlist error: $e");
        }

        if (mounted) {
          setState(() {
            _session = session;
            username = sessionUsername ?? sessionEmail.split('@')[0];
            _email = sessionEmail;
            avatarUrl = avatar;
            watchlist = wl;
          });
        }
      } catch (e) {
        debugPrint("Error load profile: $e");
      }
    } else {
      // Guest: reset semua data
      if (mounted) {
        setState(() {
          _session = null;
          username = null;
          _email = null;
          avatarUrl = null;
          watchlist = [];
        });
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    if (!_isLoggedIn) {
      _promptLogin();
      return;
    }
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null && _isLoggedIn) {
      setState(() => isLoading = true);
      try {
        final userId = _session!['user_id'] as String;
        final savedPath = await DatabaseHelper.instance.saveAvatar(userId, image.path);
        if (mounted) {
          setState(() => avatarUrl = savedPath);
          _showMsg("Foto profil berhasil diperbarui!", _C.snackSuccess);
        }
      } catch (e) {
        _showMsg("Gagal mengunggah foto: $e", _C.snackError);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateUsername(String newName) async {
    if (!_isLoggedIn) return;
    try {
      final userId = _session!['user_id'] as String;
      final oldUsername = username;

      // 1. Update username di tabel users (data utama login)
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'users',
        {'username': newName},
        where: 'id = ?',
        whereArgs: [int.tryParse(userId) ?? userId],
      );

      // 2. Update session di SQLite (display)
      await DatabaseHelper.instance.saveSession(userId, _email ?? '', newName, '');

      // 3. Update bio_username di SharedPreferences (untuk biometric login)
      final prefs = await SharedPreferences.getInstance();
      final savedBioUser = prefs.getString('bio_username');
      if (savedBioUser == oldUsername) {
        await prefs.setString('bio_username', newName);
      }

      // 4. Update username di tabel comments (agar nama di komentar ikut berubah)
      await db.update(
        'comments',
        {'username': newName},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // 5. Update biometric_enabled reference (toggle berdasarkan username)
      if (oldUsername != null && oldUsername != newName) {
        await db.update(
          'users',
          {}, // no-op, username already updated above
          where: 'username = ?',
          whereArgs: [newName],
        );
      }

      await _loadUserData();
      _showMsg("Username berhasil diganti!", _C.snackSuccess);
    } catch (e) {
      _showMsg("Gagal ganti username: $e", _C.snackError);
    }
  }

  Future<void> _updatePassword(String newPass) async {
    if (!_isLoggedIn || username == null) return;
    try {
      // 1. Update password hash di tabel users (data utama login)
      final db = await DatabaseHelper.instance.database;
      final newHash = DatabaseHelper.hashPassword(newPass);
      await db.update(
        'users',
        {'password_hash': newHash},
        where: 'username = ?',
        whereArgs: [username],
      );

      // 2. SELALU update bio_password di SharedPreferences
      //    agar biometric login selalu pakai password terbaru
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bio_password', newPass);

      _showMsg("Password berhasil diperbarui!", _C.snackSuccess);
    } catch (e) {
      _showMsg("Gagal ganti password: $e", _C.snackError);
    }
  }

  void _showMsg(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _promptLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    // Setelah kembali dari LoginPage, cek ulang apakah sudah login
    if (mounted) {
      _loadUserData();
      _loadBiometricStatus();
    }
  }

  // ── BIOMETRIC STATUS ─────────────────────────────────
  Future<void> _loadBiometricStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('bio_username');
      if (savedUser != null && savedUser.isNotEmpty) {
        final enabled = await DatabaseHelper.instance.isBiometricEnabled(savedUser);
        if (mounted) setState(() => _biometricEnabled = enabled);
      }
    } catch (e) {
      debugPrint("Load biometric status error: $e");
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('bio_username');

      if (savedUser == null || savedUser.isEmpty) {
        _showMsg("Login manual terlebih dahulu sebelum mengaktifkan sidik jari.", _C.snackWarning);
        return;
      }

      if (enable) {
        // Verifikasi sidik jari sebelum mengaktifkan
        final canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (!canAuth) {
          _showMsg("Perangkat tidak mendukung biometrik", _C.snackError);
          return;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verifikasi sidik jari untuk mengaktifkan login biometrik',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );

        if (!authenticated) {
          _showMsg("Verifikasi sidik jari gagal", _C.snackError);
          return;
        }
      }

      // Toggle di SQLite
      await DatabaseHelper.instance.toggleBiometric(savedUser, enable);
      
      if (!enable) {
        // Nonaktifkan tapi JANGAN hapus bio_password
        // agar user bisa re-enable tanpa login ulang
      }

      if (mounted) {
        setState(() => _biometricEnabled = enable);
        _showMsg(
          enable ? "Login sidik jari diaktifkan ✓" : "Login sidik jari dinonaktifkan",
          enable ? _C.snackSuccess : _C.biometricInactive,
        );
      }
    } catch (e) {
      _showMsg("Gagal mengubah pengaturan sidik jari: $e", _C.snackError);
    }
  }

  void _promptRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (mounted) _loadUserData();
  }

  void _showEditDialog({required String title, required Function(String) onSave, bool isPassword = false}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Ganti $title"),
        content: TextField(controller: ctrl, obscureText: isPassword, decoration: InputDecoration(hintText: "Masukkan $title baru")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.isNotEmpty) { onSave(ctrl.text); Navigator.pop(context); }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Jika belum login (session SQLite kosong), tampilkan halaman guest
    if (!_isLoggedIn && !isLoading) {
      return _buildGuestPage();
    }

    return _buildProfileScaffold();
  }

  // ── HALAMAN GUEST (belum login) ──────────────────────────
  Widget _buildGuestPage() {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold, color: _C.appBarText)),
        backgroundColor: _C.appBar,
        surfaceTintColor: _C.appBar,
        elevation: 0,
        foregroundColor: _C.appBarFg,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _C.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded, size: 64, color: _C.accent),
              ),
              const SizedBox(height: 28),
              const Text(
                "Selamat Datang!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _C.accent),
              ),
              const SizedBox(height: 10),
              const Text(
                "Login atau daftar untuk menikmati fitur lengkap seperti pemesanan tiket, watchlist, dan profil.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _C.hint, height: 1.5),
              ),
              const SizedBox(height: 36),

              // Tombol LOGIN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _promptLogin,
                  icon: const Icon(Icons.login, color: _C.accent, size: 20),
                  label: const Text("Login", style: TextStyle(color: _C.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.buttonBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Tombol REGISTER
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _promptRegister,
                  icon: const Icon(Icons.person_add_outlined, color: _C.accent, size: 20),
                  label: const Text("Buat Akun Baru", style: TextStyle(color: _C.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: _C.accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HALAMAN PROFIL (sudah login) ────────────────────────
  Widget _buildProfileScaffold() {

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold, color: _C.appBarText)),
        backgroundColor: _C.appBar,
        surfaceTintColor: _C.appBar,
        elevation: 0,
        foregroundColor: _C.appBarFg,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: _C.logoutIcon),
            onPressed: () async {
              // Hapus session dari SQLite (tapi JANGAN hapus bio credentials)
              // bio_username & bio_password tetap tersimpan agar
              // user bisa login kembali dengan sidik jari tanpa login manual
              await DatabaseHelper.instance.clearSession();
              if (mounted) {
                setState(() {
                  _session = null;
                  username = null;
                  _email = null;
                  avatarUrl = null;
                  watchlist = [];
                  _biometricEnabled = false;
                });
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // ── AVATAR ──────────────────────────────────────
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: _C.avatarBg,
                        backgroundImage: avatarUrl != null ? FileImage(File(avatarUrl!)) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, size: 56, color: _C.avatarIcon) : null,
                      ),
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _C.cameraBg,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _C.cameraShadow.withValues(alpha: 0.15), blurRadius: 6)],
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: _C.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    username ?? "User",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _C.accent),
                  ),
                  Text(
                    _email ?? "-",
                    style: const TextStyle(color: _C.hint, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // ── EDIT TILES ───────────────────────────────────
                  _editTile(Icons.edit, "Ganti Username",
                      () => _showEditDialog(title: "Username", onSave: _updateUsername)),
                  const SizedBox(height: 8),
                  _editTile(Icons.lock_outline, "Ganti Password",
                      () => _showEditDialog(title: "Password", onSave: _updatePassword, isPassword: true)),
                  const SizedBox(height: 8),

                  // ── TOGGLE SIDIK JARI ──────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: _C.cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _C.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fingerprint, color: _C.accent, size: 18),
                      ),
                      title: const Text("Login Sidik Jari", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(
                        _biometricEnabled ? "Aktif" : "Nonaktif",
                        style: TextStyle(fontSize: 11, color: _biometricEnabled ? _C.biometricActive : _C.biometricInactive),
                      ),
                      trailing: Switch(
                        value: _biometricEnabled,
                        activeThumbColor: _C.thumbActive,
                        onChanged: (val) => _toggleBiometric(val),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── WATCHLIST ────────────────────────────────────
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: _C.accent, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      const Text("Watchlist Saya",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _C.accent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (watchlist.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _C.cardBg, borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: _C.cardShadow.withValues(alpha: 0.04), blurRadius: 8)],
                      ),
                      child: const Column(children: [
                        Icon(Icons.bookmark_border, size: 36, color: _C.hintLighter),
                        SizedBox(height: 8),
                        Text(
                          "Belum ada film yang disimpan",
                          style: TextStyle(color: _C.hint),
                        ),
                      ]),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: watchlist.length,
                      itemBuilder: (_, idx) {
                        final item = watchlist[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                "https://image.tmdb.org/t/p/w200${item['poster_path']}",
                                width: 46, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.movie),
                              ),
                            ),
                            title: Text(item['title'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(item['release_date'] ?? '-', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: _C.hint),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(id: item['movie_id'], type: 'movie'))),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 28),

                  // ── KESAN & SARAN ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_C.accent.withValues(alpha: 0.08), _C.gradientEnd.withValues(alpha: 0.08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.accent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.18), shape: BoxShape.circle),
                            child: const Icon(Icons.school, color: _C.accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Mata Kuliah", style: TextStyle(fontSize: 11, color: _C.mataKuliahLabel)),
                            Text("Teknologi & Pemrograman Mobile",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ])),
                        ]),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Text("💡 Kesan:", style: TextStyle(fontWeight: FontWeight.bold, color: _C.accent)),
                        const SizedBox(height: 6),
                        const Text(
                          "Mata kuliah TPM sangat seru dan aplikatif. "
                          "Belajar Flutter dari nol hingga bisa membuat aplikasi lengkap dengan sensor, database, dan AI chatbot.",
                          style: TextStyle(fontSize: 13, height: 1.5, color: _C.kesanBodyText),
                        ),
                        const SizedBox(height: 14),
                        const Text("✨ Saran:", style: TextStyle(fontWeight: FontWeight.bold, color: _C.accent)),
                        const SizedBox(height: 6),
                        const Text(
                          "Semoga bisa ditambahkan materi state management dan deployment ke Play Store.",
                          style: TextStyle(fontSize: 13, height: 1.5, color: _C.kesanBodyText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ── FLEXIBLE TAB CONTENT (tidak lagi pakai fixed SizedBox height) ──
  Widget _editTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _C.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _C.accent, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: _C.hint),
      tileColor: _C.tileBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar
  static const Color appBarText = Colors.white;              // teks AppBar "Profil Saya"
  static const Color appBarFg = Colors.white;                // foreground AppBar

  // --- Warna Aksen ---
  static const Color accent = AppColors.navyPrimary;         // warna aksen utama (heading, icon)

  // --- List Tile ---
  static const Color tileBg = Colors.white;                  // background list tile

  // --- Tombol ---
  static const Color buttonBg = AppColors.gold;              // background tombol Login/action
  static const Color logoutIcon = Colors.red;                // icon logout

  // --- Avatar ---
  static const Color avatarBg = AppColors.navyPrimary;       // background avatar circle
  static const Color avatarIcon = Colors.white;              // icon person default
  static const Color cameraBg = Colors.white;                // background tombol kamera
  static Color cameraShadow = Colors.black;                  // shadow tombol kamera

  // --- Toggle Biometric ---
  static const Color thumbActive = AppColors.navyPrimary;    // switch biometric aktif
  static const Color biometricActive = Colors.green;         // teks "Aktif"
  static const Color biometricInactive = Colors.grey;        // teks "Nonaktif"

  // --- Card & Surface ---
  static const Color cardBg = Colors.white;                  // background card/tile
  static Color cardShadow = Colors.black;                    // shadow card



  // --- Kesan & Pesan ---
  static const Color gradientEnd = Color(0xFF65C7F7);        // gradient kesan pesan

  static const Color mataKuliahLabel = Colors.grey;          // label "Mata Kuliah"
  static const Color kesanBodyText = Color(0xDD000000);      // teks isi kesan (Colors.black87)

  // --- Snackbar ---
  static const Color snackSuccess = Colors.green;            // snackbar berhasil
  static const Color snackError = Colors.red;                // snackbar gagal
  static const Color snackWarning = Colors.orange;           // snackbar peringatan

  static const Color hint = AppColors.fontGreyLight;         // warna hint/placeholder
  static const Color hintLighter = AppColors.fontGreyLighter;// warna disabled text
}

