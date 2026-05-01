import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:http/http.dart' as http;
import '../models/ticket_models.dart';
import 'film_detail_page.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  static const String _apiKey = '276b3a68ef2888c401b69fc9f9ad9140';
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  List<NowPlayingMovie> _movies = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNowPlaying();
  }

  Future<void> _fetchNowPlaying() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/now_playing?api_key=$_apiKey&language=id-ID&region=ID&page=1'),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List results = data['results'] as List;
        if (mounted) {
          setState(() {
            _movies = results.map((e) => NowPlayingMovie.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat film. Menggunakan data lokal.';
          _movies = _dummyMovies();
          _isLoading = false;
        });
      }
    }
  }

  List<NowPlayingMovie> _dummyMovies() {
    final rng = Random();
    final dummies = [
      {'title': 'Avengers: Doomsday', 'rating': 8.4, 'runtime': 148},
      {'title': 'Captain America: Brave New World', 'rating': 7.2, 'runtime': 118},
      {'title': 'Mickey 17', 'rating': 7.0, 'runtime': 137},
      {'title': 'Paddington in Peru', 'rating': 7.5, 'runtime': 106},
      {'title': 'Dog Man', 'rating': 7.3, 'runtime': 96},
      {'title': 'Snow White', 'rating': 6.8, 'runtime': 109},
      {'title': 'Novocaine', 'rating': 7.1, 'runtime': 100},
      {'title': 'Once We Were Us', 'rating': 7.8, 'runtime': 115},
    ];
    return dummies
        .map((d) => NowPlayingMovie(
              id: rng.nextInt(9999) + 1000,
              title: d['title'] as String,
              posterPath: '',
              backdropPath: '',
              rating: d['rating'] as double,
              overview: 'Film yang sedang tayang di bioskop Yogyakarta.',
              releaseDate: '2026-02-${rng.nextInt(20) + 1}',
              genres: ['Drama', 'Action'],
              runtime: d['runtime'] as int,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: _C.appBar,
            elevation: 0,
            surfaceTintColor: _C.appBar,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_movies, color: _C.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sedang Tayang',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20)),
                          Text('Bioskop Yogyakarta',
                              style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.gold),
                        onPressed: _fetchNowPlaying,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _C.accent),
                    SizedBox(height: 16),
                    Text('Memuat film...', style: TextStyle(color: _C.hint, fontSize: 14)),
                  ],
                ),
              ),
            )
          else ...[
            // Label
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    Container(
                        width: 4, height: 20,
                        decoration: BoxDecoration(
                          color: _C.accent,
                          borderRadius: BorderRadius.circular(2),
                        )),
                    const SizedBox(width: 10),
                    Text('${_movies.length} Film Tersedia',
                        style: const TextStyle(
                            color: _C.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (_error != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: const Text('Offline',
                            style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Movie grid
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildMovieCard(_movies[i]),
                  childCount: _movies.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMovieCard(NowPlayingMovie movie) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FilmDetailPage(movie: movie)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: movie.posterUrl.isNotEmpty
                    ? Image.network(
                        movie.posterUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _posterPlaceholder(movie.title),
                      )
                    : _posterPlaceholder(movie.title),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title,
                      style: const TextStyle(
                          color: _C.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 13),
                      const SizedBox(width: 3),
                      Text(movie.ratingLabel,
                          style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _C.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(movie.ageRating,
                            style: const TextStyle(
                                color: _C.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(movie.runtimeLabel,
                      style: TextStyle(color: _C.hint, fontSize: 11)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FilmDetailPage(movie: movie)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: _C.accent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Beli Tiket',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterPlaceholder(String title) {
    final colors = [
      [AppColors.navyPrimary, AppColors.gold],
      [AppColors.error, _C.accent],
      [AppColors.info, _C.accent],
      [AppColors.success, _C.priceGreen],
    ];
    final idx = title.length % colors.length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors[idx],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PENGATURAN WARNA HALAMAN NOW PLAYING
// Ubah warna di bawah ini untuk mengubah tampilan halaman Now Playing.
// Referensi warna global: lihat lib/theme/app_colors.dart
// =============================================================================
class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar

  // --- Warna Aksen ---
  static const Color accent = AppColors.navyPrimary;         // warna aksen utama (judul, border)

  // --- Harga & Jadwal ---
  static const Color priceGreen = Color(0xFF2ECC71);         // warna harga tiket (hijau)
  static const Color showtimeSelected = AppColors.navyPrimary; // jadwal tayang dipilih
  static const Color showtimeDefault = Color(0xFFE5E7EB);    // jadwal tayang default

  // --- Teks ---
  static const Color hint = AppColors.fontGreyLight;         // warna hint/placeholder
  static const Color subtitle = AppColors.fontGrey;          // warna subtitle
}
