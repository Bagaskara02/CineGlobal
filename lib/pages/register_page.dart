import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import '../services/database_helper.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    final String username = _userCtrl.text.trim();
    final String email = _emailCtrl.text.trim();
    final String password = _passCtrl.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar("Harap isi semua data!", _C.snackWarning);
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password minimal 6 karakter!", _C.snackWarning);
      return;
    }

    setState(() => _isLoading = true);

    try {

      // MENYIMPAN KE SQLite (email + password SHA-256)

      final userData = await DatabaseHelper.instance.registerUser(username, email, password);
      
      debugPrint("REGISTER BERHASIL — DATA DI SQLITE:");
      debugPrint("Username      : $username");
      debugPrint("Email         : $email");
      debugPrint("Password Asli : ${'*' * password.length}");
      debugPrint("SHA-256 Hash  : ${userData['password_hash']}");



      if (mounted) {
        _showSnackBar("Registrasi Berhasil! Silakan Login.", _C.snackSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar(e.toString(), _C.snackError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: _C.appBarIcon)
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.gradientStart, _C.gradientEnd], 
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Join CineGlobal", 
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _C.fontTitle)
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: _C.cardBg, 
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: _C.cardShadow, blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      const Text("Create Account", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Badge SQLite
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _C.badgeBorder),
                        ),
                        child: const Text("Buat Akun Anda", style: TextStyle(fontSize: 12, color: _C.badgeText)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _userCtrl, 
                        decoration: InputDecoration(
                          labelText: 'Username', 
                          prefixIcon: const Icon(Icons.person), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _emailCtrl, 
                        decoration: InputDecoration(
                          labelText: 'Email', 
                          prefixIcon: const Icon(Icons.email), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: _passCtrl, 
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password', 
                          prefixIcon: const Icon(Icons.lock), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, 
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.buttonBg, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: _C.loadingIndicator) 
                            : const Text("REGISTER NOW", style: TextStyle(color: _C.buttonFg, fontWeight: FontWeight.bold)),
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

class _C {
  _C._();
  // --- Gradient Background ---
  static const Color gradientStart = AppColors.navyPrimary;      // gradient kiri atas
  static const Color gradientEnd = Color(0xFF65C7F7);            // gradient kanan bawah

  // --- AppBar ---
  static const Color appBarIcon = Colors.white;                  // icon back

  // --- Card ---
  static const Color cardBg = Colors.white;                      // background card
  static const Color cardShadow = Colors.black12;                // shadow card

  // --- Badge ---
  static Color badgeBg = Colors.blue.shade50;                    // background badge
  static Color badgeBorder = Colors.blue.shade200;               // border badge
  static const Color badgeText = Colors.blue;                    // teks badge

  // --- Tombol Register ---
  static const Color buttonBg = AppColors.navyPrimary;           // background tombol
  static const Color buttonFg = Colors.white;                    // teks tombol
  static const Color loadingIndicator = Colors.white;            // loading indicator

  // --- Snackbar ---
  static const Color snackSuccess = Colors.green;                // snackbar berhasil
  static const Color snackError = Colors.red;                    // snackbar error
  static const Color snackWarning = Colors.orange;               // snackbar peringatan

  // --- Teks ---
  static const Color fontTitle = Colors.white;                   // judul "Join CineGlobal"
  static const Color fontCardTitle = Colors.black;               // judul "Create Account"
}
