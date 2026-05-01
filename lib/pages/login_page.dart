import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_page.dart';
import '../main.dart';
import '../services/database_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _biometricAvailable = false;
  bool _hasSavedCredentials = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  // Cek apakah biometrik tersedia dan ada kredensial tersimpan
  Future<void> _checkBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('bio_username');

      // Cek apakah user sudah enable biometric di profile
      bool bioEnabled = false;
      if (savedUser != null && savedUser.isNotEmpty) {
        bioEnabled = await DatabaseHelper.instance.isBiometricEnabled(savedUser);
      }

      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck && isDeviceSupported;
          _hasSavedCredentials = savedUser != null && savedUser.isNotEmpty && bioEnabled;
        });
      }
    } catch (e) {
      debugPrint("Biometric check error: $e");
    }
  }

  // ═══════════════════════════════════════════════════
  // LOGIN MANUAL — username + password → SQLite
  // ═══════════════════════════════════════════════════
  void _login() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi Username dan Password!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verifikasi username + SHA-256(password) di SQLite
      final user = await DatabaseHelper.instance.loginUser(
        _userCtrl.text.trim(),
        _passCtrl.text,
      );

      if (user == null) throw 'Username atau Password salah';

      // 2. Print hash untuk debugging/presentasi
      final passwordHash = DatabaseHelper.hashPassword(_passCtrl.text);
      debugPrint("══════════════════════════════════════════");
      debugPrint("LOGIN BERHASIL");
      debugPrint("Username    : ${_userCtrl.text.trim()}");
      debugPrint("Password    : ${'*' * _passCtrl.text.length}");
      debugPrint("SHA-256 Hash: $passwordHash");
      debugPrint("══════════════════════════════════════════");

      // 3. Simpan session ke SQLite
      await DatabaseHelper.instance.saveSession(
        user['id'].toString(),
        user['email'] as String,
        user['username'] as String,
        '', // no token needed for SQLite auth
      );

      // 4. Simpan kredensial untuk biometric (jika nanti diaktifkan)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bio_username', _userCtrl.text.trim());
      await prefs.setString('bio_password', _passCtrl.text); // untuk auto-login biometric

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════
  // LOGIN BIOMETRIC — sidik jari → auto-login dari SQLite
  // ═══════════════════════════════════════════════════
  void _loginBiometric() async {
    setState(() => _isLoading = true);

    try {
      // 1. Cek apakah biometric tersedia
      bool canAuth = false;
      try {
        canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      } catch (e) {
        throw 'Biometrik tidak tersedia di perangkat ini.';
      }
      if (!canAuth) {
        throw 'Perangkat tidak mendukung biometrik';
      }

      // 2. Cek apakah ada kredensial tersimpan & biometric diaktifkan
      if (!_hasSavedCredentials) {
        throw 'Sidik jari belum diaktifkan.\nAktifkan di Profil → "Login Sidik Jari" setelah login manual.';
      }

      // 3. Tampilkan dialog sidik jari
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Tempelkan sidik jari Anda untuk login CineGlobal',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!authenticated) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 4. Biometric berhasil — ambil kredensial tersimpan
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('bio_username');
      final savedPass = prefs.getString('bio_password');

      if (savedUser == null || savedPass == null) {
        throw 'Kredensial tersimpan tidak ditemukan.\nSilakan login manual terlebih dahulu.';
      }

      // 5. Verifikasi di SQLite
      final user = await DatabaseHelper.instance.loginUser(savedUser, savedPass);
      if (user == null) {
        throw 'Kredensial tersimpan tidak valid.\nSilakan login manual.';
      }

      // 6. Simpan session
      await DatabaseHelper.instance.saveSession(
        user['id'].toString(),
        user['email'] as String,
        user['username'] as String,
        '',
      );

      debugPrint("══════════════════════════════════════════");
      debugPrint("LOGIN BIOMETRIC BERHASIL");
      debugPrint("Username: $savedUser");
      debugPrint("══════════════════════════════════════════");

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.gradientStart, _C.gradientEnd],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.movie_filter_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "CineGlobal",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Welcome Back!",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      // Enkripsi badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Text(
                          "Login Untuk Melanjutkan",
                          style: TextStyle(color: Color.fromARGB(255, 6, 13, 90), fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Input Username
                      TextField(
                        controller: _userCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Tombol Login
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.buttonBg,
                            foregroundColor: _C.buttonFg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: _C.gradientStart)
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(color: _C.buttonFg, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Biometric Login Button (FIX OVERFLOW) ──
                      Column(children: [
                        Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("atau", style: TextStyle(color: Colors.grey, fontSize: 12))),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _loginBiometric,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _C.biometricBorder, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _C.fingerprintBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.fingerprint, size: 24, color: _C.iconFingerprint),
                                ),
                                const SizedBox(width: 10),
                                // FIX: Flexible agar tidak overflow
                                const Flexible(
                                  child: Text(
                                    "Login dengan Sidik Jari",
                                    style: TextStyle(
                                      color: AppColors.navyPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => const RegisterPage()),
                        ),
                        child: const Text(
                          "Don't have an account? Register",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PENGATURAN WARNA HALAMAN LOGIN
// Ubah warna di bawah ini untuk mengubah tampilan halaman Login.
// Referensi warna global: lihat lib/theme/app_colors.dart
// =============================================================================
class _C {
  _C._();
  // --- Gradient Background ---
  static const Color gradientStart = AppColors.navyPrimary;   // gradient atas
  static const Color gradientEnd = AppColors.navySecondary;   // gradient bawah

  // --- Tombol Login ---
  static const Color buttonBg = AppColors.gold;               // background tombol Login
  static const Color buttonFg = AppColors.navyPrimary;        // teks tombol Login
  static const Color loadingIndicator = AppColors.navyPrimary;// loading saat proses login

  // --- Tombol Biometric ---
  static const Color biometricBorder = AppColors.gold;        // border tombol sidik jari
  static const Color iconFingerprint = AppColors.navyPrimary; // icon sidik jari
  static Color fingerprintBg = AppColors.navyPrimary.withValues(alpha: 0.1); // bg icon sidik jari
  static const Color fontBiometric = AppColors.navyPrimary;   // teks login biometric

  // --- Teks ---
  static const Color fontTitle = Colors.white;                // judul "CineGlobal"
  static const Color fontSubtitle = Colors.white70;           // subtitle "Masuk ke akun"
}
