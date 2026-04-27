import 'package:flutter/material.dart';

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
      _showSnackBar("Harap isi semua data!", Colors.orange);
      return;
    }

    if (password.length < 6) {
      _showSnackBar("Password minimal 6 karakter!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ═══════════════════════════════════════════════════
      // 1. SIMPAN KE SQLite (email + password SHA-256)
      // ═══════════════════════════════════════════════════
      final userData = await DatabaseHelper.instance.registerUser(username, email, password);
      
      // Debug: Print hash untuk presentasi
      debugPrint("══════════════════════════════════════════");
      debugPrint("REGISTER BERHASIL — DATA DI SQLITE:");
      debugPrint("Username      : $username");
      debugPrint("Email         : $email");
      debugPrint("Password Asli : ${'*' * password.length}");
      debugPrint("SHA-256 Hash  : ${userData['password_hash']}");
      debugPrint("══════════════════════════════════════════");



      if (mounted) {
        _showSnackBar("Registrasi Berhasil! Silakan Login.", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.red);
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
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00113A), Color(0xFF65C7F7)], 
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
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      const Text("Create Account", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Badge SQLite
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.storage, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text("SQLite + SHA-256", style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                        ]),
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
                            backgroundColor: const Color(0xFF00113A), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text("REGISTER NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
