import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'detail_page.dart';
import '../services/database_helper.dart';

// ─────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────
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
          _showMsg("Foto profil berhasil diperbarui!", Colors.green);
        }
      } catch (e) {
        _showMsg("Gagal mengunggah foto: $e", Colors.red);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateUsername(String newName) async {
    if (!_isLoggedIn) return;
    try {
      final userId = _session!['user_id'] as String;
      // Update session di SQLite
      await DatabaseHelper.instance.saveSession(userId, _email ?? '', newName, '');
      await _loadUserData();
      _showMsg("Username berhasil diganti!", Colors.green);
    } catch (e) {
      _showMsg("Gagal ganti username", Colors.red);
    }
  }

  Future<void> _updatePassword(String newPass) async {
    if (!_isLoggedIn || username == null) return;
    try {
      // Update password hash di SQLite
      final db = await DatabaseHelper.instance.database;
      final newHash = DatabaseHelper.hashPassword(newPass);
      await db.update(
        'users',
        {'password_hash': newHash},
        where: 'username = ?',
        whereArgs: [username],
      );
      // Update juga di SharedPreferences jika biometric aktif
      final prefs = await SharedPreferences.getInstance();
      if (_biometricEnabled) {
        await prefs.setString('bio_password', newPass);
      }
      _showMsg("Password berhasil diperbarui!", Colors.green);
    } catch (e) {
      _showMsg("Gagal ganti password: $e", Colors.red);
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
        _showMsg("Login manual terlebih dahulu sebelum mengaktifkan sidik jari.", Colors.orange);
        return;
      }

      if (enable) {
        // Verifikasi sidik jari sebelum mengaktifkan
        final canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (!canAuth) {
          _showMsg("Perangkat tidak mendukung biometrik", Colors.red);
          return;
        }

        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Verifikasi sidik jari untuk mengaktifkan login biometrik',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );

        if (!authenticated) {
          _showMsg("Verifikasi sidik jari gagal", Colors.red);
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
          enable ? Colors.green : Colors.grey,
        );
      }
    } catch (e) {
      _showMsg("Gagal mengubah pengaturan sidik jari: $e", Colors.red);
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF00113A),
        surfaceTintColor: const Color(0xFF00113A),
        elevation: 0,
        foregroundColor: Colors.white,
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
                  color: const Color(0xFF00113A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded, size: 64, color: Color(0xFF00113A)),
              ),
              const SizedBox(height: 28),
              const Text(
                "Selamat Datang!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00113A)),
              ),
              const SizedBox(height: 10),
              const Text(
                "Login atau daftar untuk menikmati fitur lengkap seperti pemesanan tiket, watchlist, dan profil.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), height: 1.5),
              ),
              const SizedBox(height: 36),

              // Tombol LOGIN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _promptLogin,
                  icon: const Icon(Icons.login, color: Color(0xFF00113A), size: 20),
                  label: const Text("Login", style: TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFCD400),
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
                  icon: const Icon(Icons.person_add_outlined, color: Color(0xFF00113A), size: 20),
                  label: const Text("Buat Akun Baru", style: TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFF00113A), width: 1.5),
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Profil Saya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF00113A),
        surfaceTintColor: const Color(0xFF00113A),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
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
                        backgroundColor: const Color(0xFF00113A),
                        backgroundImage: avatarUrl != null ? FileImage(File(avatarUrl!)) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, size: 56, color: Colors.white) : null,
                      ),
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Color(0xFF00113A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    username ?? "User",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00113A)),
                  ),
                  Text(
                    _email ?? "-",
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00113A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fingerprint, color: Color(0xFF00113A), size: 18),
                      ),
                      title: const Text("Login Sidik Jari", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      subtitle: Text(
                        _biometricEnabled ? "Aktif" : "Nonaktif",
                        style: TextStyle(fontSize: 11, color: _biometricEnabled ? Colors.green : Colors.grey),
                      ),
                      trailing: Switch(
                        value: _biometricEnabled,
                        activeThumbColor: const Color(0xFF00113A),
                        onChanged: (val) => _toggleBiometric(val),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── WATCHLIST ────────────────────────────────────
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF00113A), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      const Text("Watchlist Saya",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (watchlist.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                      ),
                      child: const Column(children: [
                        Icon(Icons.bookmark_border, size: 36, color: Color(0xFFD0D0E0)),
                        SizedBox(height: 8),
                        Text(
                          "Belum ada film yang disimpan",
                          style: TextStyle(color: Color(0xFF9CA3AF)),
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
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
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
                        colors: [const Color(0xFF00113A).withValues(alpha: 0.08), const Color(0xFF65C7F7).withValues(alpha: 0.08)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00113A).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFF00113A).withValues(alpha: 0.18), shape: BoxShape.circle),
                            child: const Icon(Icons.school, color: Color(0xFF00113A), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("Mata Kuliah", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text("Teknologi & Pemrograman Mobile",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ])),
                        ]),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 10),
                        const Text("💡 Kesan:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
                        const SizedBox(height: 6),
                        const Text(
                          "Mata kuliah TPM sangat seru dan aplikatif. "
                          "Belajar Flutter dari nol hingga bisa membuat aplikasi lengkap dengan sensor, database, dan AI chatbot.",
                          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                        ),
                        const SizedBox(height: 14),
                        const Text("✨ Saran:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
                        const SizedBox(height: 6),
                        const Text(
                          "Semoga bisa ditambahkan materi state management dan deployment ke Play Store.",
                          style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
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
          color: const Color(0xFF00113A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF00113A), size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
