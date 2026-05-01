import 'package:flutter/material.dart';
class AppColors {
  AppColors._();

  // --- WARNA UTAMA ---

  static const Color navyPrimary = Color(0xFF00113A);   // warna brand utama
  static const Color navySecondary = Color(0xFF001F5C);  // gradient navy terang
  static const Color gold = Color(0xFFFCD400);           // aksen utama (tombol, badge)
  static const Color goldDark = Color(0xFFE5B800);       // border kursi dipilih

  // --- BACKGROUND ---

  static const Color scaffoldBg = Color(0xFFF8F9FA);    // background halaman
  static const Color cardBg = Color(0xFFF5F7FA);        // background card
  static const Color lightPurpleBg = Color(0xFFEEEEF5); // placeholder poster

  // --- WARNA FONT ---

  static const Color fontPrimary = Color(0xFF1A1A2E);   // judul, heading
  static const Color fontBody = Colors.black87;          // body text, sinopsis
  static const Color fontWhite = Colors.white;           // teks di background gelap
  static const Color fontWhiteSub = Colors.white70;      // subtitle di background gelap
  static const Color fontGrey = Color(0xFF6B7280);       // subtitle, info sekunder
  static const Color fontGreyLight = Color(0xFF9CA3AF);  // hint, placeholder
  static const Color fontGreyLighter = Color(0xFFD0D0E0);// disabled text
  static const Color fontNavy = navyPrimary;             // heading di background terang
  static const Color fontGold = gold;                    // harga, badge aktif
  static const Color fontGreen = Color(0xFF2ECC71);      // harga tiket, status aktif
  static const Color fontRed = Color(0xFFE53935);        // error, validasi
  static const Color fontBlue = Color(0xFF1976D2);       // link, info

  // --- WARNA ICON UMUM ---

  static const Color iconWhite = Colors.white;           // icon di AppBar
  static const Color iconNavy = navyPrimary;             // icon di background terang
  static const Color iconGold = gold;                    // icon aktif (bottom nav, rating)
  static const Color iconGrey = Color(0xFF6B7280);       // icon non-aktif
  static const Color iconGreyLight = Color(0xFF9CA3AF);  // icon trailing, hint

  // --- WARNA UMUM ---

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color info = Color(0xFF1976D2);
  static const Color deepPurple = Color(0xFF4C3494);
  static const Color shopeeOrange = Color(0xFFEE4D2D);

  // --- WARNA GLOBAL KOMPONEN ---
  // Warna di bawah ini dipakai bersama oleh banyak halaman.
  // Untuk warna per-halaman, lihat class _C di bagian bawah masing-masing file page.

  static const Color appBarBg = navyPrimary;
  static const Color appBarFg = Colors.white;
}

