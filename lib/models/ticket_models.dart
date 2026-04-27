// ============================================================
// TICKET MODELS — CineGlobal
// ============================================================

import 'package:flutter/material.dart';

// Film dari TMDB
class NowPlayingMovie {
  final int id;
  final String title;
  final String posterPath;
  final String backdropPath;
  final double rating;
  final String overview;
  final String releaseDate;
  final List<String> genres;
  final int runtime; // menit

  NowPlayingMovie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.overview,
    required this.releaseDate,
    required this.genres,
    required this.runtime,
  });

  factory NowPlayingMovie.fromJson(Map<String, dynamic> json) {
    return NowPlayingMovie(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? 'Unknown',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      overview: json['overview'] ?? '',
      releaseDate: json['release_date'] ?? '',
      genres: [],
      runtime: json['runtime'] ?? 120,
    );
  }

  String get posterUrl => posterPath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w185$posterPath'
      : '';

  String get backdropUrl => backdropPath.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w780$backdropPath'
      : '';

  String get ratingLabel => rating.toStringAsFixed(1);

  String get runtimeLabel {
    int h = runtime ~/ 60;
    int m = runtime % 60;
    return h > 0 ? '${h}j ${m}m' : '${m}m';
  }

  String get ageRating {
    // Sederhana: derive from rating
    if (rating >= 7.5) return 'SU';
    if (rating >= 6.0) return '13+';
    return '17+';
  }
}

// Jadwal per bioskop
class CinemaSchedule {
  final String cinemaName;
  final String brand; // XXI, CGV, Cinépolis
  final String studioType; // Regular 2D, 4DX, IMAX
  final int priceIDR;
  final List<String> showTimes; // ["12:15", "14:25", ...]

  CinemaSchedule({
    required this.cinemaName,
    required this.brand,
    required this.studioType,
    required this.priceIDR,
    required this.showTimes,
  });
}

// Pesanan tiket
class TicketOrder {
  final NowPlayingMovie movie;
  final CinemaSchedule schedule;
  final String showDate; // "Jumat, 20 Februari 2026"
  final String showTime; // "12:15"
  final List<String> selectedSeats; // ["A3", "A4"]
  final String studioType;

  TicketOrder({
    required this.movie,
    required this.schedule,
    required this.showDate,
    required this.showTime,
    required this.selectedSeats,
    required this.studioType,
  });

  int get quantity => selectedSeats.length;
  int get totalIDR => schedule.priceIDR * quantity;
  String get seatLabel => selectedSeats.join(', ');

  // Konversi waktu dari WIB (UTC+7)
  Map<String, String> get timeConversions {
    final parts = showTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    String fmt(int h, int m) {
      final hh = h % 24;
      return '${hh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    // WIB = UTC+7
    int utcH = hour - 7;
    return {
      'WIB (UTC+7)': fmt(hour, minute),
      'WITA (UTC+8)': fmt(hour + 1, minute),
      'WIT (UTC+9)': fmt(hour + 2, minute),
      'London (UTC+0)': fmt(utcH, minute),
      'Tokyo (UTC+9)': fmt(utcH + 9, minute),
      'New York (UTC-5)': fmt(utcH - 5, minute),
    };
  }

  // Exchange rates per IDR (statis, cukup untuk demo)
  static const Map<String, double> _ratesFromIDR = {
    'IDR': 1.0,
    'USD': 0.0000624,
    'EUR': 0.0000571,
    'GBP': 0.0000488,
    'SGD': 0.0000836,
    'JPY': 0.0092,
    'MYR': 0.000294,
  };

  static const Map<String, String> _currencySymbols = {
    'IDR': 'Rp',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'SGD': 'S\$',
    'JPY': '¥',
    'MYR': 'RM',
  };

  Map<String, String> get priceConversions {
    final result = <String, String>{};
    _ratesFromIDR.forEach((currency, rate) {
      final converted = totalIDR * rate;
      final symbol = _currencySymbols[currency]!;
      if (currency == 'IDR') {
        result[currency] = '$symbol ${_formatIDR(totalIDR)}';
      } else if (currency == 'JPY') {
        result[currency] = '$symbol ${converted.round()}';
      } else {
        result[currency] = '$symbol ${converted.toStringAsFixed(2)}';
      }
    });
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

// ============================================================
// DUMMY DATA: Bioskop Jogja + jadwal
// ============================================================
List<CinemaSchedule> generateSchedules() {
  return [
    CinemaSchedule(
      cinemaName: 'Empire XXI',
      brand: 'Cinema XXI',
      studioType: 'Regular 2D',
      priceIDR: 40000,
      showTimes: ['12:15', '14:25', '16:35', '18:45', '20:55'],
    ),
    CinemaSchedule(
      cinemaName: 'Sleman City Hall XXI',
      brand: 'Cinema XXI',
      studioType: 'Regular 2D',
      priceIDR: 45000,
      showTimes: ['11:30', '13:45', '16:00', '18:15', '20:30'],
    ),
    CinemaSchedule(
      cinemaName: 'Ambarrukmo XXI',
      brand: 'Cinema XXI',
      studioType: 'Regular 2D',
      priceIDR: 45000,
      showTimes: ['12:00', '14:15', '16:30', '18:45', '21:00'],
    ),
    CinemaSchedule(
      cinemaName: 'Jogja City Mall XXI',
      brand: 'Cinema XXI',
      studioType: '4DX',
      priceIDR: 75000,
      showTimes: ['13:00', '15:30', '18:00', '20:30'],
    ),
    CinemaSchedule(
      cinemaName: 'CGV Cinemas J-Walk Mall',
      brand: 'CGV Cinemas',
      studioType: 'Regular 2D',
      priceIDR: 45000,
      showTimes: ['12:30', '14:45', '17:00', '19:15', '21:30'],
    ),
    CinemaSchedule(
      cinemaName: 'CGV Pakuwon Mall Jogja',
      brand: 'CGV Cinemas',
      studioType: 'SphereX',
      priceIDR: 60000,
      showTimes: ['11:00', '13:30', '16:00', '18:30', '21:00'],
    ),
    CinemaSchedule(
      cinemaName: 'Cinépolis Lippo Plaza Jogja',
      brand: 'Cinépolis',
      studioType: 'Regular 2D',
      priceIDR: 50000,
      showTimes: ['12:00', '14:30', '17:00', '19:30', '22:00'],
    ),
  ];
}

// ============================================================
// WARNA PER BRAND
// ============================================================
Color brandColor(String brand) {
  if (brand.contains('XXI')) return const Color(0xFFFFA000);
  if (brand.contains('CGV')) return const Color(0xFFD32F2F);
  if (brand.contains('Cinépolis') || brand.contains('Cinepolis')) return const Color(0xFF1976D2);
  return const Color(0xFF00113A);
}

IconData brandIcon(String brand) {
  if (brand.contains('XXI')) return Icons.movie_filter;
  if (brand.contains('CGV')) return Icons.theaters;
  return Icons.movie;
}
