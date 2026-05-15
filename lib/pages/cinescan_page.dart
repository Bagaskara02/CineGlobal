import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';
import 'detail_page.dart';
import '../services/database_helper.dart';
import 'login_page.dart';

class CineScanPage extends StatefulWidget {
  const CineScanPage({super.key});
  @override
  State<CineScanPage> createState() => _CineScanPageState();
}

class _CineScanPageState extends State<CineScanPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _isAnalyzing = false;
  String? _errorMessage;

  // Hasil klasifikasi
  List<MapEntry<String, double>> _results = [];
  String? _topEmotion;
  String? _recommendedGenre;

  // Film rekomendasi dari TMDB
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoadingRecs = false;

  late AnimationController _pulseCtrl;

  // ── Mapping Emosi → Genre TMDB ──
  // Setiap emosi dipetakan ke genre film yang sesuai
  static const Map<String, Map<String, dynamic>> _emotionToGenre = {
    'Angry': {
      'genre': 'Action',
      'genreId': 28,
      'emoji': '😠',
      'suggestion': 'Salurkan energimu lewat film action seru!',
    },
    'Happy': {
      'genre': 'Adventure',
      'genreId': 12,
      'emoji': '😊',
      'suggestion': 'Mood bagus! Petualangan seru menanti!',
    },
    'Neutral': {
      'genre': 'Trending',
      'genreId': 0,
      'emoji': '😐',
      'suggestion': 'Santai? Lihat film populer saat ini!',
    },
  };

  // Warna per emosi
  static const Map<String, Color> _emotionColors = {
    'Angry': Color(0xFFEF4444),
    'Happy': Color(0xFFF59E0B),
    'Neutral': Color(0xFF6B7280),
  };

  // Icon per emosi
  static const Map<String, IconData> _emotionIcons = {
    'Angry': Icons.whatshot,
    'Happy': Icons.sentiment_very_satisfied,
    'Neutral': Icons.sentiment_neutral,
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front, // Kamera depan untuk selfie
        imageQuality: 85,
        maxWidth: 512,
      );
      if (file == null) return;

      setState(() {
        _selectedImage = File(file.path);
        _results = [];
        _topEmotion = null;
        _recommendedGenre = null;
        _recommendations = [];
        _errorMessage = null;
      });

      _analyzeImage();
    } catch (e) {
      setState(() => _errorMessage = 'Gagal mengambil gambar: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // 1. Face Detection + Classification menggunakan Google ML Kit
      final inputImageFile = InputImage.fromFile(_selectedImage!);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true, // Aktifkan smilingProbability & eyeOpenProbability
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await faceDetector.processImage(inputImageFile);
      await faceDetector.close();

      if (faces.isEmpty) {
        throw Exception('Wajah tidak terdeteksi. Pastikan wajah terlihat jelas.');
      }

      // 2. Ambil wajah terbesar
      final face = faces.reduce((a, b) =>
          (a.boundingBox.width * a.boundingBox.height) >
          (b.boundingBox.width * b.boundingBox.height) ? a : b);

      // 3. Ambil probabilitas dari ML Kit
      final smileProb = face.smilingProbability ?? 0.5;
      final leftEyeOpen = face.leftEyeOpenProbability ?? 0.5;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 0.5;
      final avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2;
      final headX = face.headEulerAngleX ?? 0.0;

      // 4. Klasifikasi emosi berdasarkan ML Kit features
      double happyScore = 0.0;
      double angryScore = 0.0;
      double neutralScore = 0.0;

      if (smileProb > 0.5) {
        // Senyum terdeteksi → Happy
        happyScore = smileProb;
        neutralScore = 1.0 - smileProb;
        angryScore = 0.0;
      } else if (smileProb < 0.3) {
        // Tidak senyum / senyum sangat tipis
        // Indikator marah: mata SEDIKIT menyipit (< 0.9) ATAU kepala menunduk
        if (avgEyeOpen < 0.9 || headX < -8.0) {
          // Mata menyipit / menunduk + tidak senyum → Angry
          final eyeFactor = (1.0 - avgEyeOpen).clamp(0.0, 1.0);
          final headFactor = headX < -8.0 ? 0.3 : 0.0;
          angryScore = ((eyeFactor * 2.0) + headFactor + (1.0 - smileProb) * 0.3).clamp(0.0, 1.0);
          neutralScore = (1.0 - angryScore).clamp(0.0, 1.0);
          happyScore = 0.0;
        } else {
          // Mata fully open + tidak senyum → Neutral
          neutralScore = 0.85;
          angryScore = 0.10;
          happyScore = 0.05;
        }
      } else {
        // Senyum ringan → mostly Neutral
        neutralScore = 0.70;
        happyScore = smileProb;
        angryScore = 0.0;
        // Normalize
        final total = neutralScore + happyScore + angryScore;
        neutralScore /= total;
        happyScore /= total;
      }

      // Pastikan total = 1.0
      final total = happyScore + angryScore + neutralScore;
      if (total > 0) {
        happyScore /= total;
        angryScore /= total;
        neutralScore /= total;
      }


      final results = <MapEntry<String, double>>[
        MapEntry('Happy', happyScore),
        MapEntry('Angry', angryScore),
        MapEntry('Neutral', neutralScore),
      ];
      results.sort((a, b) => b.value.compareTo(a.value));

      final topEmotion = results.first.key;
      final genreInfo = _emotionToGenre[topEmotion];

      if (mounted) {
        setState(() {
          _results = results;
          _topEmotion = topEmotion;
          _recommendedGenre = genreInfo?['genre'] ?? 'Trending';
          _isAnalyzing = false;
        });
      }

      // 5. Fetch rekomendasi film berdasarkan genre
      _fetchRecommendations(topEmotion);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Gagal menganalisis: $e';
        });
      }
    }
  }

  Future<void> _fetchRecommendations(String emotion) async {
    setState(() => _isLoadingRecs = true);
    try {
      final genreInfo = _emotionToGenre[emotion];
      final genreId = genreInfo?['genreId'] as int? ?? 0;
      const apiKey = '276b3a68ef2888c401b69fc9f9ad9140';

      String url;
      if (genreId == 0) {
        // Neutral → trending
        url =
            'https://api.themoviedb.org/3/trending/movie/week?api_key=$apiKey&language=id-ID';
      } else {
        url = 'https://api.themoviedb.org/3/discover/movie'
            '?api_key=$apiKey&language=id-ID&with_genres=$genreId'
            '&sort_by=popularity.desc&vote_count.gte=100&page=1';
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = (data['results'] as List).take(6).toList();
        if (mounted) {
          setState(() {
            _recommendations = results.cast<Map<String, dynamic>>();
            _isLoadingRecs = false;
          });
        }
      }
    } catch (e) {
      debugPrint('MoodScan: Fetch recommendations error — $e');
      if (mounted) setState(() => _isLoadingRecs = false);
    }
  }

  void _checkLoginAndNavigate(int id, String type) async {
    final session = await DatabaseHelper.instance.getSession();
    if (session != null) {
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (c) => DetailPage(id: id, type: type)));
    } else {
      final result = await Navigator.push(
          context, MaterialPageRoute(builder: (c) => const LoginPage()));
      if (result == true && mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (c) => DetailPage(id: id, type: type)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: _C.gold, size: 22),
            SizedBox(width: 10),
            Text('CineScan',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18)),
            SizedBox(width: 8),
            Text('AI',
                style: TextStyle(
                    color: _C.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ],
        ),
        backgroundColor: _C.appBar,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: _C.appBar,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ──
            _buildHeaderCard(),

            // ── Error ──
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],

            // ── Preview + Results ──
            if (_selectedImage != null) ...[
              const SizedBox(height: 20),
              _buildImagePreview(),
            ],

            // ── Classification Results ──
            if (_results.isNotEmpty && !_isAnalyzing) ...[
              const SizedBox(height: 20),
              _buildTopResultBadge(),
              const SizedBox(height: 16),
              _buildEmotionBars(),
              const SizedBox(height: 20),
              _buildRecommendations(),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── UI Components ──

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.appBar, Color(0xFF001E5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _C.appBar.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.face_retouching_natural, color: _C.gold, size: 40),
          const SizedBox(height: 12),
          const Text('Mood Detector',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Ambil selfie dan AI akan mendeteksi mood-mu,\nlalu rekomendasikan film yang cocok!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.4),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '🧠 Model: FER2013 Pre-trained CNN (692KB)',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Selfie',
                  color: _C.gold,
                  textColor: _C.appBar,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galeri',
                  color: Colors.white.withValues(alpha: 0.15),
                  textColor: Colors.white,
                  borderColor: Colors.white.withValues(alpha: 0.3),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Image.file(_selectedImage!,
              width: double.infinity, height: 280, fit: BoxFit.cover),
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) => Transform.scale(
                          scale: 1.0 + _pulseCtrl.value * 0.2,
                          child: child,
                        ),
                        child: const Icon(Icons.face_retouching_natural,
                            color: _C.gold, size: 48),
                      ),
                      const SizedBox(height: 12),
                      const Text('Mendeteksi ekspresi wajah...',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopResultBadge() {
    final emoji = _emotionToGenre[_topEmotion]?['emoji'] ?? '🎬';
    final suggestion =
        _emotionToGenre[_topEmotion]?['suggestion'] ?? 'Nikmati filmnya!';
    final color = _emotionColors[_topEmotion] ?? _C.appBar;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Mood: $_topEmotion',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_results.first.value * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.appBar,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Genre: $_recommendedGenre',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(suggestion,
              style: TextStyle(color: color, fontSize: 13, height: 1.3),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmotionBars() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analisis Ekspresi',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _C.appBar)),
          const SizedBox(height: 12),
          ..._results.map((entry) {
            final pct = (entry.value * 100).clamp(0, 100);
            final color = _emotionColors[entry.key] ?? Colors.grey;
            final emoji = _emotionToGenre[entry.key]?['emoji'] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('$emoji ',
                          style: const TextStyle(fontSize: 14)),
                      Icon(_emotionIcons[entry.key] ?? Icons.face,
                          size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(entry.key,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: color)),
                      const Spacer(),
                      Text('${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 8,
                      backgroundColor: color.withValues(alpha: 0.1),
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.movie_filter,
                color: _emotionColors[_topEmotion] ?? _C.appBar, size: 22),
            const SizedBox(width: 8),
            Text('Rekomendasi Film $_recommendedGenre',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _C.appBar)),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingRecs)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator()))
        else if (_recommendations.isNotEmpty)
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendations.length,
              itemBuilder: (ctx, i) {
                final movie = _recommendations[i];
                final poster = movie['poster_path'];
                final title = movie['title'] ?? movie['name'] ?? 'Unknown';
                final rating =
                    (movie['vote_average'] as num?)?.toDouble() ?? 0;
                return GestureDetector(
                  onTap: () => _checkLoginAndNavigate(movie['id'], 'movie'),
                  child: Container(
                    width: 130,
                    margin: EdgeInsets.only(
                        right: i < _recommendations.length - 1 ? 12 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: poster != null
                                ? Image.network(
                                    'https://image.tmdb.org/t/p/w185$poster',
                                    fit: BoxFit.cover,
                                    width: 130,
                                    errorBuilder: (_, __, ___) => Container(
                                        color: _C.appBar,
                                        child: const Center(
                                            child: Icon(Icons.movie,
                                                color: Colors.white54,
                                                size: 40))))
                                : Container(
                                    color: _C.appBar,
                                    child: const Center(
                                        child: Icon(Icons.movie,
                                            color: Colors.white54, size: 40))),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: _C.appBar),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: _C.gold),
                            const SizedBox(width: 3),
                            Text(rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    final enabled = !_isAnalyzing;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? color : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: enabled ? textColor : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: enabled ? textColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─── Design Tokens ───────────────────────────────────────────
class _C {
  _C._();
  static const Color bg = AppColors.scaffoldBg;
  static const Color appBar = AppColors.navyPrimary;
  static const Color gold = AppColors.gold;
}
