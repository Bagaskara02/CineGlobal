import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import '../services/database_helper.dart';

class MinigamePage extends StatefulWidget {
  const MinigamePage({super.key});
  @override
  State<MinigamePage> createState() => _MinigamePageState();
}

class _MinigamePageState extends State<MinigamePage> with TickerProviderStateMixin {
  // Game state
  bool _gameStarted = false;
  bool _gameOver = false;
  int _score = 0;
  int _currentQ = 0;
  final int _totalQ = 10;
  int _highScore = 0;
  int _skipsLeft = 2;
  String? _earnedReward;

  // Film data — pool film yang sudah dipakai untuk avoid duplikasi
  List<Map<String, dynamic>> _films = [];
  final Set<int> _usedFilmIndices = {};
  Map<String, dynamic>? _currentFilm;
  List<String> _options = [];
  String? _selectedAnswer;
  bool? _isCorrect;
  bool _isLoading = true;

  // Gyroscope shake detection
  StreamSubscription? _gyroSub;
  DateTime _lastShake = DateTime.now();
  static const double _shakeThreshold = 8.0;

  // Animation
  late AnimationController _shakeAnimCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _scoreAnimCtrl;

  // Cek apakah judul film hanya berisi karakter Latin (bisa dibaca)
  static bool _isLatinTitle(String title) {
    for (int i = 0; i < title.length; i++) {
      final code = title.codeUnitAt(i);
      // Izinkan: ASCII printable (32-126)
      if (code > 126) return false;
    }
    return title.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _shakeAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeAnimCtrl);
    _scoreAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _loadHighScore();
    _initGyroscope();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _shakeAnimCtrl.dispose();
    _scoreAnimCtrl.dispose();
    super.dispose();
  }

  void _initGyroscope() {
    try {
      _gyroSub = gyroscopeEventStream().listen((GyroscopeEvent event) {
        if (!_gameStarted || _gameOver || _selectedAnswer != null) return;
        double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        if (magnitude > _shakeThreshold && DateTime.now().difference(_lastShake).inMilliseconds > 1500) {
          _lastShake = DateTime.now();
          _skipQuestion();
        }
      });
    } catch (_) {
      // Gyroscope not available (web/emulator)
    }
  }

  Future<void> _loadHighScore() async {
    try {
      final hs = await DatabaseHelper.instance.getHighScore('cinequiz');
      if (mounted) setState(() => _highScore = hs);
    } catch (_) {}
  }

  /// Fetch film dari beberapa halaman TMDB untuk pool besar & unik
  Future<void> _fetchFilms() async {
    setState(() => _isLoading = true);
    final rng = Random();
    List<Map<String, dynamic>> allFilms = [];

    // Fetch film terkenal dari top_rated (bukan popular yang bisa random)
    // include_adult=false untuk filter konten dewasa
    final endpoints = [
      'movie/top_rated',
      'movie/now_playing',
      'trending/movie/week',
    ];
    for (int i = 0; i < endpoints.length; i++) {
      final page = rng.nextInt(3) + 1;
      try {
        final response = await http.get(
          Uri.parse('https://api.themoviedb.org/3/${endpoints[i]}?api_key=276b3a68ef2888c401b69fc9f9ad9140&language=en-US&page=$page&include_adult=false'),
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = (data['results'] as List).where((m) =>
            m['poster_path'] != null &&
            m['title'] != null &&
            (m['title'] as String).isNotEmpty &&
            _isLatinTitle(m['title'] as String) &&
            (m['vote_average'] as num).toDouble() > 3.0 &&
            (m['vote_count'] as num?)?.toInt() != null &&
            (m['vote_count'] as num).toInt() > 200 // Hanya film terkenal
          ).toList();
          allFilms.addAll(List<Map<String, dynamic>>.from(results));
        }
      } catch (_) {}
    }

    // Deduplikasi berdasarkan judul
    final seen = <String>{};
    allFilms.removeWhere((m) => !seen.add(m['title'] as String));

    // Shuffle untuk randomisasi
    allFilms.shuffle(rng);

    if (allFilms.length >= 4) {
      if (mounted) setState(() { _films = allFilms; _isLoading = false; });
    } else {
      // Fallback data jika API gagal
      if (mounted) {
        setState(() {
        _films = [
          {'title': 'Avengers: Endgame', 'vote_average': 8.3, 'poster_path': '/or06FN3Dka5tukK1e9sl16pB3iy.jpg'},
          {'title': 'The Dark Knight', 'vote_average': 8.5, 'poster_path': '/qJ2tW6WMUDux911OhTTg6aKKd8L.jpg'},
          {'title': 'Inception', 'vote_average': 8.4, 'poster_path': '/9gk7adHYeDvHkCSEhniRtcYUKeN.jpg'},
          {'title': 'Interstellar', 'vote_average': 8.6, 'poster_path': '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg'},
          {'title': 'Parasite', 'vote_average': 8.5, 'poster_path': '/7IiTTgloJzvGI1TAYymCfbfl3vT.jpg'},
          {'title': 'Spider-Man: No Way Home', 'vote_average': 8.2, 'poster_path': '/1g0dhYtq4irTY1GPXvft6k4YLjm.jpg'},
          {'title': 'The Batman', 'vote_average': 7.7, 'poster_path': '/74xTEgt7R36Fpooo50r9T25onhq.jpg'},
          {'title': 'Dune', 'vote_average': 7.8, 'poster_path': '/d5NXSklXo0qyIYkgV94XAgMIckC.jpg'},
          {'title': 'Top Gun: Maverick', 'vote_average': 8.3, 'poster_path': '/62HCnUTziyWcpDaBO2i1DG0Os8l.jpg'},
          {'title': 'John Wick 4', 'vote_average': 7.7, 'poster_path': '/vZloFAK7NmvMGKE7BXKUlAkKMKa.jpg'},
          {'title': 'Oppenheimer', 'vote_average': 8.1, 'poster_path': '/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg'},
          {'title': 'Barbie', 'vote_average': 7.0, 'poster_path': '/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg'},
        ];
        _isLoading = false;
      });
      }
    }
  }

  void _startGame() async {
    _usedFilmIndices.clear();
    await _fetchFilms();
    if (_films.length < 4) return;
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _score = 0;
      _currentQ = 0;
      _skipsLeft = 2;
      _earnedReward = null;
    });
    _nextQuestion();
  }

  void _nextQuestion() {
    // Cek apakah game sudah selesai
    if (_currentQ >= _totalQ) {
      _endGame();
      return;
    }

    final rng = Random();

    // Pilih film yang BELUM dipakai
    int correctIdx;
    int attempts = 0;
    do {
      correctIdx = rng.nextInt(_films.length);
      attempts++;
      if (attempts > 50) {
        // Jika semua film sudah dipakai, reset
        _usedFilmIndices.clear();
        break;
      }
    } while (_usedFilmIndices.contains(correctIdx));

    _usedFilmIndices.add(correctIdx);
    final correct = _films[correctIdx];
    
    // Generate 3 wrong options yang BERBEDA dari correct dan satu sama lain
    Set<String> optionSet = {correct['title']};
    int optAttempts = 0;
    while (optionSet.length < 4 && optAttempts < 100) {
      final candidate = _films[rng.nextInt(_films.length)]['title'] as String;
      optionSet.add(candidate);
      optAttempts++;
    }
    final optionsList = optionSet.toList()..shuffle(rng);

    setState(() {
      _currentFilm = correct;
      _options = optionsList;
      _selectedAnswer = null;
      _isCorrect = null;
    });

    // Precache poster agar image load lebih cepat
    if (correct['poster_path'] != null && mounted) {
      precacheImage(
        NetworkImage('https://image.tmdb.org/t/p/w185${correct['poster_path']}'),
        context,
      );
    }
  }

  void _selectAnswer(String answer) {
    if (_selectedAnswer != null) return;
    final correct = _currentFilm!['title'];
    final isRight = answer == correct;
    setState(() {
      _selectedAnswer = answer;
      _isCorrect = isRight;
      if (isRight) _score++;
    });
    if (isRight) {
      _scoreAnimCtrl.forward(from: 0);
    } else {
      _shakeAnimCtrl.forward(from: 0);
    }
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _currentQ++;
      if (_currentQ >= _totalQ) {
        _endGame();
      } else {
        // Reset state SEBELUM load soal baru agar poster baru dimulai dengan blur
        setState(() {
          _currentFilm = null;
          _selectedAnswer = null;
          _isCorrect = null;
        });
        _nextQuestion();
      }
    });
  }

  void _skipQuestion() {
    if (_skipsLeft <= 0 || _selectedAnswer != null) return;
    _skipsLeft--;
    _currentQ++;
    if (_currentQ >= _totalQ) {
      _endGame();
    } else {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("📱 Shake! Skip digunakan ($_skipsLeft tersisa)"), backgroundColor: Colors.orange, duration: const Duration(seconds: 1)));
      _nextQuestion();
    }
  }

  void _endGame() {
    // Tentukan reward berdasarkan skor
    final pct = _totalQ > 0 ? (_score / _totalQ * 100).round() : 0;
    String reward;
    if (pct == 100) {
      reward = '🎫 Voucher GRATIS 1 Tiket Film!';
    } else if (pct >= 80) {
      reward = '🍿 Diskon 50% Combo Popcorn + Drink';
    } else if (pct >= 60) {
      reward = '🎬 Diskon 25% Tiket Weekend';
    } else if (pct >= 40) {
      reward = '🥤 Gratis Upgrade Minuman L → XL';
    } else {
      reward = '🎟️ Cashback 10% Pembelian Tiket';
    }

    // Save score (try-catch untuk web compatibility)
    try {
      DatabaseHelper.instance.saveGameScore('cinequiz', _score, _totalQ);
    } catch (_) {}

    setState(() {
      if (_score > _highScore) _highScore = _score;
      _earnedReward = reward;
      _gameOver = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text("🎬 CineQuiz", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: _C.appBar, foregroundColor: Colors.white, elevation: 0, surfaceTintColor: _C.appBar, automaticallyImplyLeading: false,
        actions: [
          if (_gameStarted && !_gameOver) Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: _C.buttonBg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: _C.accent, size: 18),
              const SizedBox(width: 4),
              Text("$_score/$_totalQ", style: const TextStyle(fontWeight: FontWeight.bold, color: _C.accent, fontSize: 15)),
            ]),
          ),
        ],
      ),
      body: _isLoading && _gameStarted
          ? const Center(child: CircularProgressIndicator(color: _C.accent))
          : !_gameStarted
              ? _buildStartScreen()
              : _gameOver
                  ? _buildResultScreen()
                  : _buildQuizScreen(),
    );
  }

  Widget _buildStartScreen() {
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.navyPrimary, AppColors.gold]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: _C.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]),
        child: const Icon(Icons.quiz, color: Colors.white, size: 56)),
      const SizedBox(height: 28),
      const Text("CineQuiz", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: _C.accent)),
      const SizedBox(height: 8),
      const Text("Tebak Judul Film dari Poster!", style: TextStyle(fontSize: 16, color: _C.hint)),
      const SizedBox(height: 30),
      // Info cards
      _infoCard(Icons.image, "Poster Film", "Tebak judul film dari posternya"),
      _infoCard(Icons.vibration, "Shake to Skip", "Kocok HP untuk skip pertanyaan (2x)"),
      _infoCard(Icons.card_giftcard, "Hadiah", "Dapatkan voucher berdasarkan skor!"),
      _infoCard(Icons.emoji_events, "High Score", "$_highScore poin"),
      const SizedBox(height: 30),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _startGame,
        icon: const Icon(Icons.play_arrow, color: _C.accent),
        label: const Text("Mulai Main!", style: TextStyle(color: _C.accent, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: _C.buttonBg, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
      )),
    ])));
  }

  Widget _infoCard(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _C.accent, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(desc, style: const TextStyle(fontSize: 12, color: _C.hint)),
        ])),
      ]),
    );
  }

  Widget _buildQuizScreen() {
    if (_currentFilm == null) {
      return const Center(child: CircularProgressIndicator(color: _C.accent));
    }
    final posterUrl = 'https://image.tmdb.org/t/p/w185${_currentFilm!['poster_path']}';
    final displayQ = (_currentQ + 1).clamp(1, _totalQ);
    final bool answered = _selectedAnswer != null;
    return Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20, 10, 20, 10), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Soal $displayQ/$_totalQ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _C.accent)),
          Row(children: [
            const Icon(Icons.vibration, size: 14, color: _C.hint),
            const SizedBox(width: 4),
            Text("Skip: $_skipsLeft", style: TextStyle(fontSize: 12, color: _skipsLeft > 0 ? Colors.orange : Colors.grey)),
          ]),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: displayQ / _totalQ, backgroundColor: _C.bg, color: _C.accent, minHeight: 6)),
      ])),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        AnimatedBuilder(animation: _shakeAnim, builder: (ctx, child) => Transform.translate(offset: Offset(_shakeAnim.value * sin(_shakeAnimCtrl.value * pi * 4), 0), child: child),
          child: Container(
            height: 260, width: 180,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: _C.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 185,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: _C.accent.withValues(alpha: 0.15),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            color: _C.buttonBg,
                            strokeWidth: 3,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: _C.accent.withValues(alpha: 0.2),
                      child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.white70)),
                    ),
                  ),
                  // Blur: selalu aktif penuh, hanya hilang setelah jawab (tanpa animasi fade)
                  if (!answered)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(color: Colors.black.withValues(alpha: 0.1)),
                      ),
                    ),
                  if (answered)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isCorrect! ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isCorrect! ? "✓ Benar!" : "✗ Salah",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text("Film apa ini?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _C.accent)),
        const SizedBox(height: 16),
        ...List.generate(_options.length, (i) {
          final opt = _options[i];
          final isSelected = _selectedAnswer == opt;
          final isCorrectOpt = opt == _currentFilm!['title'];
          Color bgColor = Colors.white;
          Color borderColor = Colors.grey.shade200;
          Color textColor = AppColors.navyPrimary;
          if (_selectedAnswer != null) {
            if (isCorrectOpt) { bgColor = Colors.green.shade50; borderColor = Colors.green; textColor = Colors.green.shade800; }
            else if (isSelected && !_isCorrect!) { bgColor = Colors.red.shade50; borderColor = Colors.red; textColor = Colors.red.shade800; }
          }
          return GestureDetector(
            onTap: () => _selectAnswer(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), width: double.infinity,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor, width: isSelected || (_selectedAnswer != null && isCorrectOpt) ? 2 : 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: _C.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Center(child: Text(String.fromCharCode(65 + i), style: const TextStyle(fontWeight: FontWeight.bold, color: _C.accent)))),
                const SizedBox(width: 14),
                Expanded(child: Text(opt, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (_selectedAnswer != null && isCorrectOpt) const Icon(Icons.check_circle, color: Colors.green, size: 22),
                if (isSelected && _selectedAnswer != null && !_isCorrect!) const Icon(Icons.cancel, color: Colors.red, size: 22),
              ]),
            ),
          );
        }),
      ]))),
    ]);
  }

  Widget _buildResultScreen() {
    final pct = _totalQ > 0 ? (_score / _totalQ * 100).round() : 0;
    String emoji = pct == 100 ? "🏆" : pct >= 80 ? "🎉" : pct >= 60 ? "👏" : pct >= 40 ? "😊" : "😅";
    String msg = pct == 100 ? "PERFECT!" : pct >= 80 ? "Luar Biasa!" : pct >= 60 ? "Bagus!" : pct >= 40 ? "Lumayan!" : "Coba Lagi!";
    Color rewardColor = pct >= 80 ? AppColors.navyPrimary : pct >= 60 ? Colors.green : Colors.orange;

    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // Emoji & message
      Text(emoji, style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _C.accent)),
      const SizedBox(height: 20),

      // Score card
      Container(
        padding: const EdgeInsets.all(24), width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
        ),
        child: Column(children: [
          Text("$_score", style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: _C.accent)),
          Text("dari $_totalQ soal benar", style: const TextStyle(fontSize: 16, color: _C.hint)),
          const SizedBox(height: 12),
          // Progress bar skor
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _score / _totalQ, minHeight: 10,
              backgroundColor: _C.bg,
              color: pct >= 80 ? AppColors.navyPrimary : pct >= 60 ? Colors.green : pct >= 40 ? Colors.orange : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Text("High Score: $_highScore", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 16),

      // ── REWARD / HADIAH ──
      if (_earnedReward != null) Container(
        padding: const EdgeInsets.all(20), width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [rewardColor.withValues(alpha: 0.1), rewardColor.withValues(alpha: 0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: rewardColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rewardColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.card_giftcard, color: rewardColor, size: 32),
          ),
          const SizedBox(height: 12),
          const Text("🎁 Hadiah Kamu!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.accent)),
          const SizedBox(height: 8),
          Text(
            _earnedReward!,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: rewardColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: rewardColor.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.content_copy, size: 14, color: rewardColor),
              const SizedBox(width: 6),
              Text(
                "CINE${pct >= 80 ? 'VIP' : pct >= 60 ? 'GOLD' : pct >= 40 ? 'SILVER' : 'START'}${DateTime.now().millisecondsSinceEpoch % 10000}",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: rewardColor, letterSpacing: 1),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text("Berlaku hingga ${DateTime.now().add(const Duration(days: 7)).day}/${DateTime.now().add(const Duration(days: 7)).month}/${DateTime.now().add(const Duration(days: 7)).year}",
            style: const TextStyle(fontSize: 11, color: _C.hint),
          ),
        ]),
      ),

      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _startGame,
        icon: const Icon(Icons.replay, color: Colors.white),
        label: const Text("Main Lagi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        style: ElevatedButton.styleFrom(backgroundColor: _C.appBar, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      )),
    ])));
  }
}

// =============================================================================
// PENGATURAN WARNA HALAMAN MINIGAME
// Ubah warna di bawah ini untuk mengubah tampilan halaman MiniGame Quiz.
// Referensi warna global: lihat lib/theme/app_colors.dart
// =============================================================================
class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar

  // --- Warna Aksen ---
  static const Color accent = AppColors.navyPrimary;         // warna aksen utama (skor, judul)

  // --- Jawaban Quiz ---
  static const Color correct = Color(0xFF66BB6A);            // jawaban benar (hijau)
  static const Color wrong = Color(0xFFE53935);              // jawaban salah (merah)

  // --- Tombol ---
  static const Color buttonBg = AppColors.gold;              // background tombol aksi

  // --- Teks ---
  static const Color hint = AppColors.fontGreyLight;         // warna hint
  static const Color subtitle = AppColors.fontGrey;          // warna subtitle
}
