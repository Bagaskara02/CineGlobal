import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CurrencyService {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  // Cache in-memory
  Map<String, double>? _cachedRates;
  String? _cachedDate;
  DateTime? _lastFetch;

  // Mata uang yang ditampilkan di struk
  static const List<String> targetCurrencies = [
    'usd', 'eur', 'gbp', 'sgd', 'jpy', 'myr', 'krw',
  ];

  // Rate statis sebagai fallback terakhir
  static const Map<String, double> _fallbackRates = {
    'usd': 0.0000576,
    'eur': 0.0000491,
    'gbp': 0.0000425,
    'sgd': 0.0000731,
    'jpy': 0.00904,
    'myr': 0.000226,
    'krw': 0.0841,
  };

  static const Map<String, String> currencySymbols = {
    'IDR': 'Rp',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'SGD': 'S\$',
    'JPY': '¥',
    'MYR': 'RM',
    'KRW': '₩',
  };

  static const Map<String, String> currencyNames = {
    'IDR': 'Rupiah Indonesia',
    'USD': 'Dollar Amerika',
    'EUR': 'Euro',
    'GBP': 'Pound Inggris',
    'SGD': 'Dollar Singapura',
    'JPY': 'Yen Jepang',
    'MYR': 'Ringgit Malaysia',
    'KRW': 'Won Korea',
  };

  /// Apakah rate berasal dari API (live) atau fallback (statis)
  bool get isLive => _cachedDate != null;
  String get rateDate => _cachedDate ?? 'Offline (statis)';

  /// Fetch exchange rates dari API
  /// Menggunakan CDN jsdelivr sebagai primary, Cloudflare Pages sebagai fallback
  Future<Map<String, double>> fetchRates({bool forceRefresh = false}) async {
    // Gunakan cache jika masih segar (< 30 menit)
    if (!forceRefresh &&
        _cachedRates != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 30) {
      return _cachedRates!;
    }

    // Primary URL (jsdelivr CDN)
    const primaryUrl =
        'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/idr.min.json';
    // Fallback URL (Cloudflare Pages)
    const fallbackUrl =
        'https://latest.currency-api.pages.dev/v1/currencies/idr.min.json';

    Map<String, double>? rates;

    // Coba primary
    rates = await _tryFetch(primaryUrl);

    // Jika gagal, coba fallback
    rates ??= await _tryFetch(fallbackUrl);

    // Jika kedua API gagal, gunakan rate statis
    if (rates == null) {
      debugPrint('CurrencyService: Semua API gagal, gunakan fallback statis');
      _cachedRates = Map.from(_fallbackRates);
      _cachedDate = null; // Tandai sebagai offline
      return _cachedRates!;
    }

    _cachedRates = rates;
    _lastFetch = DateTime.now();
    return _cachedRates!;
  }

  Future<Map<String, double>?> _tryFetch(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final date = data['date'] as String?;
        final idrRates = data['idr'] as Map<String, dynamic>?;

        if (idrRates == null) return null;

        final result = <String, double>{};
        for (final currency in targetCurrencies) {
          final rate = idrRates[currency];
          if (rate != null) {
            result[currency] = (rate as num).toDouble();
          }
        }

        if (result.isNotEmpty) {
          _cachedDate = date;
          debugPrint('CurrencyService: Rate berhasil di-fetch ($date) dari $url');
          return result;
        }
      }
    } catch (e) {
      debugPrint('CurrencyService: Gagal fetch dari $url — $e');
    }
    return null;
  }

  /// Konversi harga IDR ke semua mata uang target
  Map<String, String> convertPrice(int amountIDR, Map<String, double> rates) {
    final result = <String, String>{};

    // IDR selalu pertama
    result['IDR'] = 'Rp ${_formatIDR(amountIDR)}';

    for (final entry in rates.entries) {
      final code = entry.key.toUpperCase();
      final rate = entry.value;
      final converted = amountIDR * rate;
      final symbol = currencySymbols[code] ?? code;

      if (code == 'JPY' || code == 'KRW') {
        result[code] = '$symbol ${converted.round()}';
      } else {
        result[code] = '$symbol ${converted.toStringAsFixed(2)}';
      }
    }

    return result;
  }

  String _formatIDR(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
