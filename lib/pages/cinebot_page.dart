import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:http/http.dart' as http;
import '../services/database_helper.dart';

class CinebotPage extends StatefulWidget {
  const CinebotPage({super.key});
  @override
  State<CinebotPage> createState() => _CinebotPageState();
}

class _CinebotPageState extends State<CinebotPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isConnected = false;
  // Auto-detect: web=localhost, mobile=PC WiFi IP
  String _ollamaUrl = kIsWeb ? 'http://localhost:11434'  : 'http://10.218.250.75:11434';
  String _selectedModel = 'gemma3:1b';
  final List<String> _availableModels = [];
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _loadChatHistory();
    _checkConnection();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await DatabaseHelper.instance.getChatHistory();
      if (mounted) {
        setState(() {
          _messages.clear();
          for (var msg in history) {
            _messages.add({'role': msg['role'] as String, 'content': msg['content'] as String});
          }
        });
      }
    } catch (_) {
      // Database tidak tersedia (web), abaikan
    }
    if (_messages.isEmpty) {
      setState(() => _messages.add({
        'role': 'assistant',
        'content': "Halo! 👋 Saya CineBot, asisten film AI Anda.\n\n"
            "Saya bisa membantu:\n"
            "🎬 Rekomendasi film berdasarkan genre/mood\n"
            "📖 Info & sinopsis film\n"
            "🌍 Perbandingan harga tiket\n"
            "⭐ Rating & review film\n\n"
            "Tanya apa saja tentang film!",
      }));
    }
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http.get(Uri.parse('$_ollamaUrl/api/tags')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final models = (data['models'] as List?)?.map((m) => m['name'] as String).toList() ?? [];
        setState(() {
          _isConnected = true;
          _availableModels.clear();
          _availableModels.addAll(models);
          if (models.isNotEmpty && !models.contains(_selectedModel)) _selectedModel = models.first;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isConnected = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  static const String _tmdbKey = '276b3a68ef2888c401b69fc9f9ad9140';
  static const String _tmdbBase = 'https://api.themoviedb.org/3';

  /// Fetch data TMDB berdasarkan query user untuk konteks CineBot
  Future<String> _fetchTmdbContext(String query) async {
    final q = query.toLowerCase();
    try {
      String url;
      String label;

      // Deteksi intent dari pesan user
      if (q.contains('trending') || q.contains('tren') || q.contains('populer') || q.contains('terbaru')) {
        url = '$_tmdbBase/trending/movie/week?api_key=$_tmdbKey&language=id-ID';
        label = 'Film Trending Minggu Ini';
      } else if (q.contains('superhero') || q.contains('super hero') || q.contains('marvel') || q.contains('dc') || q.contains('avenger') || q.contains('batman') || q.contains('spider') || q.contains('superman') || q.contains('iron man') || q.contains('thor')) {
        // TMDB search 'superhero' returns garbage. Provide real superhero film data.
        return '\n[DATA FILM SUPERHERO POPULER]\n'
            '1. Avengers: Endgame (2019) ⭐ 8.4/10 - Pertarungan terakhir Avengers melawan Thanos\n'
            '2. The Dark Knight (2008) ⭐ 9.0/10 - Batman vs Joker, film DC terbaik sepanjang masa\n'
            '3. Spider-Man: No Way Home (2021) ⭐ 8.2/10 - Tiga Spider-Man bertemu dalam satu film\n'
            '4. Avengers: Infinity War (2018) ⭐ 8.3/10 - Thanos mengumpulkan Infinity Stones\n'
            '5. The Batman (2022) ⭐ 7.7/10 - Robert Pattinson sebagai Batman, dark detective story\n'
            '6. Guardians of the Galaxy Vol. 3 (2023) ⭐ 7.9/10 - Petualangan terakhir Guardians\n'
            '7. Black Panther (2018) ⭐ 7.3/10 - Raja Wakanda, film Marvel pertama nominasi Oscar\n'
            '8. Deadpool & Wolverine (2024) ⭐ 7.7/10 - Ryan Reynolds & Hugh Jackman kembali\n'
            '9. Iron Man (2008) ⭐ 7.9/10 - Film pertama MCU, Tony Stark jadi Iron Man\n'
            '10. Wonder Woman (2017) ⭐ 7.4/10 - Diana Prince dalam Perang Dunia I\n'
            '11. Thor: Ragnarok (2017) ⭐ 7.9/10 - Thor melawan Hela, penuh humor\n'
            '12. Doctor Strange in the Multiverse of Madness (2022) ⭐ 6.9/10 - Multiverse MCU\n'
            '13. The Suicide Squad (2021) ⭐ 7.2/10 - Tim villain DC yang kocak\n'
            '14. Shazam! (2019) ⭐ 7.0/10 - Anak remaja berubah jadi superhero DC\n'
            '15. Avengers: Doomsday (2026) - Film terbaru MCU yang akan datang\n';
      } else if (q.contains('action') || q.contains('aksi')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=28&sort_by=popularity.desc';
        label = 'Film Action Populer';
      } else if (q.contains('horror') || q.contains('horor') || q.contains('seram')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=27&sort_by=popularity.desc';
        label = 'Film Horror Populer';
      } else if (q.contains('komedi') || q.contains('comedy') || q.contains('lucu')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=35&sort_by=popularity.desc';
        label = 'Film Komedi Populer';
      } else if (q.contains('romantis') || q.contains('romance') || q.contains('cinta')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=10749&sort_by=popularity.desc';
        label = 'Film Romantis Populer';
      } else if (q.contains('animasi') || q.contains('animation') || q.contains('anime') || q.contains('kartun')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=16&sort_by=popularity.desc';
        label = 'Film Animasi Populer';
      } else if (q.contains('keluarga') || q.contains('family') || q.contains('anak')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=10751&sort_by=popularity.desc';
        label = 'Film Keluarga Populer';
      } else if (q.contains('sci-fi') || q.contains('fiksi ilmiah') || q.contains('science')) {
        url = '$_tmdbBase/discover/movie?api_key=$_tmdbKey&language=id-ID&with_genres=878&sort_by=popularity.desc';
        label = 'Film Sci-Fi Populer';
      } else if (q.contains('tayang') || q.contains('bioskop') || q.contains('now playing') || q.contains('sedang')) {
        url = '$_tmdbBase/movie/now_playing?api_key=$_tmdbKey&language=id-ID&region=ID';
        label = 'Sedang Tayang di Bioskop';
      } else if (q.contains('upcoming') || q.contains('segera') || q.contains('akan datang')) {
        url = '$_tmdbBase/movie/upcoming?api_key=$_tmdbKey&language=id-ID&region=ID';
        label = 'Film yang Akan Datang';
      } else if (q.contains('rating') || q.contains('top') || q.contains('terbaik')) {
        url = '$_tmdbBase/movie/top_rated?api_key=$_tmdbKey&language=id-ID';
        label = 'Film Rating Tertinggi';
      } else if (q.contains('harga') || q.contains('tiket') || q.contains('price')) {
        // Untuk pertanyaan harga, beri data harga tiket
        return '\n[DATA HARGA TIKET BIOSKOP INDONESIA 2026]\n'
            '• CGV Regular: Rp 40.000 - Rp 50.000 (weekday), Rp 50.000 - Rp 60.000 (weekend)\n'
            '• CGV IMAX: Rp 80.000 - Rp 100.000\n'
            '• XXI Regular: Rp 35.000 - Rp 50.000\n'
            '• XXI Premiere: Rp 75.000 - Rp 100.000\n'
            '• Cinepolis: Rp 35.000 - Rp 55.000\n'
            '• Harga bervariasi berdasarkan kota dan jam tayang.\n';
      } else {
        // Coba search film spesifik dari TMDB
        final searchUrl = '$_tmdbBase/search/movie?api_key=$_tmdbKey&language=id-ID&query=${Uri.encodeComponent(query)}';
        final res = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final results = (data['results'] as List).take(3);
          if (results.isEmpty) return '';
          final buf = StringBuffer('\n[DATA FILM DARI TMDB]\n');
          for (final m in results) {
            buf.writeln('• ${m['title']} (${(m['release_date'] ?? '').toString().split('-').firstOrNull ?? 'N/A'})');
            buf.writeln('  Rating: ${m['vote_average']}/10 | Vote: ${m['vote_count']}');
            final overview = (m['overview'] ?? '').toString();
            if (overview.isNotEmpty) buf.writeln('  Sinopsis: ${overview.length > 150 ? '${overview.substring(0, 150)}...' : overview}');
            buf.writeln('');
          }
          return buf.toString();
        }
        return '';
      }

      // Fetch data dari TMDB
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = (data['results'] as List).take(8);
        final buf = StringBuffer('\n[DATA $label DARI TMDB]\n');
        for (int i = 0; i < results.length; i++) {
          final m = results.elementAt(i);
          final title = m['title'] ?? m['name'] ?? 'N/A';
          final rating = m['vote_average'] ?? 0;
          final date = (m['release_date'] ?? m['first_air_date'] ?? '').toString();
          final year = date.length >= 4 ? date.substring(0, 4) : 'N/A';
          final overview = (m['overview'] ?? '').toString();
          buf.writeln('${i + 1}. $title ($year) ⭐ $rating/10');
          if (overview.isNotEmpty) buf.writeln('   ${overview.length > 100 ? '${overview.substring(0, 100)}...' : overview}');
        }
        return buf.toString();
      }
    } catch (_) {}
    return '';
  }

  /// Kirim pesan ke Ollama dengan konteks TMDB
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;
    _messageController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isTyping = true;
    });
    _saveChatMsg('user', text);
    _scrollToBottom();

    if (!_isConnected) {
      await Future.delayed(const Duration(milliseconds: 500));
      _finishBotMessage("⚠️ Ollama belum terhubung.\n\nPastikan:\n1. Ollama sudah berjalan (ollama serve)\n2. Model sudah di-pull (ollama pull gemma3:1b)\n3. Konfigurasi IP yang benar di ⚙️");
      return;
    }

    try {
      // 1) Fetch data TMDB sebagai konteks
      final tmdbContext = await _fetchTmdbContext(text);

      // 2) Bangun prompt dengan data TMDB
      final recent = _messages.length > 4 ? _messages.sublist(_messages.length - 4) : List<Map<String, String>>.from(_messages);
      final promptBuffer = StringBuffer();
      promptBuffer.writeln('Kamu adalah CineBot, asisten film profesional dari aplikasi CineGlobal.');
      promptBuffer.writeln('Kamu adalah pakar film dengan pengetahuan mendalam tentang:');
      promptBuffer.writeln('- Film superhero: Marvel Cinematic Universe (MCU), DC Extended Universe (DCEU), X-Men, Spider-Man, Batman, Superman, dll.');
      promptBuffer.writeln('- Semua genre: action, horror, komedi, drama, animasi, sci-fi, thriller, romantis.');
      promptBuffer.writeln('- Sutradara terkenal: Christopher Nolan, Martin Scorsese, Quentin Tarantino, James Gunn, dll.');
      promptBuffer.writeln('- Aktor/aktris: Robert Downey Jr, Scarlett Johansson, Tom Holland, Gal Gadot, dll.');
      promptBuffer.writeln('');
      promptBuffer.writeln('ATURAN FORMAT JAWABAN:');
      promptBuffer.writeln('1. Jawab dalam Bahasa Indonesia yang baik dan informatif.');
      promptBuffer.writeln('2. DILARANG KERAS menggunakan tanda ** atau * untuk formatting. Gunakan teks biasa.');
      promptBuffer.writeln('3. Gunakan emoji yang relevan (bintang, film, api, dll).');
      promptBuffer.writeln('4. Jika menyebutkan film, tulis: nomor. Judul Film (Tahun) - Rating/10 lalu deskripsi singkat.');
      promptBuffer.writeln('5. Gunakan data referensi yang diberikan. Jika tidak ada data, gunakan pengetahuanmu.');
      promptBuffer.writeln('');
      
      if (tmdbContext.isNotEmpty) {
        promptBuffer.writeln('--- DATA REFERENSI ---');
        promptBuffer.writeln(tmdbContext);
        promptBuffer.writeln('--- AKHIR DATA ---');
        promptBuffer.writeln('');
        promptBuffer.writeln('Gunakan data di atas untuk menjawab pertanyaan user. Format jawaban rapi dan mudah dibaca.');
        promptBuffer.writeln('');
      }

      for (final msg in recent) {
        if (msg['role'] == 'user') {
          promptBuffer.writeln('User: ${msg['content']}');
        } else if (msg['role'] == 'assistant' && msg['content']!.length < 200) {
          promptBuffer.writeln('CineBot: ${msg['content']}');
        }
      }
      promptBuffer.writeln('CineBot:');

      // 3) Kirim ke Ollama /api/generate
      final response = await http.post(
        Uri.parse('$_ollamaUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': _selectedModel,
          'prompt': promptBuffer.toString(),
          'stream': false,
          'options': {'num_predict': 400, 'temperature': 0.7},
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final rawReply = (data['response'] ?? 'Maaf, tidak bisa memproses.').toString().trim();
        // Hapus format markdown ** ** dari respons agar teks bersih
        final reply = rawReply.replaceAll('**', '').replaceAll('*', '');
        _finishBotMessage(reply.isNotEmpty ? reply : '🤔 Tidak ada respons. Coba lagi.');
      } else {
        _finishBotMessage("⚠️ Error: Status ${response.statusCode}");
      }

    } on TimeoutException {
      _finishBotMessage("⏱️ Koneksi timeout.\n\nCoba:\n• Pastikan Ollama berjalan\n• Konfigurasi IP di ⚙️\n• Coba pertanyaan lebih singkat");
    } catch (e) {
      _finishBotMessage("⚠️ Gagal menghubungi Ollama.\n\n${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}");
      _checkConnection();
    }
  }

  void _finishBotMessage(String content) {
    setState(() {
      _messages.add({'role': 'assistant', 'content': content});
      _isTyping = false;
    });
    _saveChatMsg('assistant', content);
    _scrollToBottom();
  }

  void _saveChatMsg(String role, String content) {
    try {
      DatabaseHelper.instance.addChatMessage(role, content);
    } catch (_) {}
  }

  void _showSettingsDialog() {
    final urlCtrl = TextEditingController(text: _ollamaUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.settings, color: _C.header), SizedBox(width: 8), Text("Pengaturan Ollama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Server URL", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: urlCtrl, decoration: InputDecoration(hintText: "http://localhost:11434", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)), style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          if (_availableModels.isNotEmpty) ...[
            const Text("Model", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: _C.inputBorder), borderRadius: BorderRadius.circular(10)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedModel, isExpanded: true, items: _availableModels.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (val) { if (val != null) setState(() => _selectedModel = val); Navigator.pop(ctx); _showSettingsDialog(); }))),
          ],
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _isConnected ? _C.onlineBg : _C.offlineBg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [Icon(_isConnected ? Icons.check_circle : Icons.error, color: _isConnected ? _C.online : _C.offline, size: 20), const SizedBox(width: 8), Expanded(child: Text(_isConnected ? "Terhubung ke Ollama Server" : "Tidak Terhubung (Pastikan server berjalan)", style: TextStyle(color: _isConnected ? _C.onlineText : _C.offlineText, fontSize: 12, fontWeight: FontWeight.bold)))])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Batal", style: TextStyle(color: _C.cancelText))),
          ElevatedButton(onPressed: () { setState(() => _ollamaUrl = urlCtrl.text.trim()); Navigator.pop(ctx); _checkConnection(); }, style: ElevatedButton.styleFrom(backgroundColor: _C.header, foregroundColor: _C.titleText, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: const Text("Simpan & Cek")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_C.gradientIcon1, _C.gradientIcon2]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.smart_toy, color: _C.iconBot, size: 20)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("CineBot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _C.titleText)),
            Text(_isConnected ? "Online • $_selectedModel" : "Offline", style: TextStyle(fontSize: 11, color: _isConnected ? _C.onlineTextLight : _C.offlineTextLight)),
          ]),
        ]),
        backgroundColor: _C.header, foregroundColor: _C.titleText, elevation: 0, surfaceTintColor: _C.header, automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep_outlined, size: 22), onPressed: () {
            try { DatabaseHelper.instance.clearChatHistory(); } catch (_) {}
            setState(() => _messages.clear());
            _loadChatHistory();
          }),
          IconButton(icon: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _isConnected ? _C.online.withValues(alpha: 0.2) : _C.offline.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.settings, size: 20, color: _C.titleText)), onPressed: _showSettingsDialog),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController, padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping && (_messages.isEmpty || _messages.last['role'] != 'assistant' || _messages.last['content']!.isEmpty) ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= _messages.length) return _buildTypingIndicator();
              return _buildBubble(_messages[i]);
            },
          ),
        ),
        if (_messages.length <= 1) Container(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Wrap(spacing: 8, runSpacing: 8, children: ["🎬 Rekomendasi film action", "🇮🇩 Harga tiket bioskop", "⭐ Film terbaik 2026", "🎭 Film keluarga"].map((t) => GestureDetector(
              onTap: () { _messageController.text = t.replaceAll(RegExp(r'[^\w\s]'), '').trim(); _sendMessage(); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: _C.warningBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.header.withValues(alpha: 0.3))), child: Text(t, style: const TextStyle(fontSize: 12, color: _C.header, fontWeight: FontWeight.w500))),
            )).toList())),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 20),
          decoration: BoxDecoration(color: _C.inputContainerBg, boxShadow: [BoxShadow(color: _C.inputShadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
          child: Row(children: [
            Expanded(child: Container(decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(24)),
              child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: "Tanya tentang film...", hintStyle: TextStyle(color: _C.hint, fontSize: 14), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)), maxLines: 3, minLines: 1, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage()))),
            const SizedBox(width: 8),
            GestureDetector(onTap: _isTyping ? null : _sendMessage, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: _isTyping ? [_C.btnDisabled, _C.btnDisabled] : [_C.gradientSend1, _C.gradientSend2]), shape: BoxShape.circle, boxShadow: [if (!_isTyping) BoxShadow(color: _C.gradientSend1.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]), child: const Icon(Icons.send_rounded, color: _C.sendIcon, size: 20))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isUser ? 60 : 0, right: isUser ? 0 : 60),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? _C.userBubble : _C.botBubble,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18)),
          boxShadow: [BoxShadow(color: isUser ? _C.userBubbleShadow.withValues(alpha: 0.25) : _C.botBubbleShadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (!isUser) ...[Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _C.iconBot.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.smart_toy, size: 14, color: _C.iconBot)), const SizedBox(width: 8)],
          Flexible(child: Text(msg['content'] ?? '', style: TextStyle(color: isUser ? _C.userText : _C.botText, fontSize: 14, height: 1.4))),
        ]),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(alignment: Alignment.centerLeft, child: Container(
      margin: const EdgeInsets.only(bottom: 12, right: 60), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _C.botBubble, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)), boxShadow: [BoxShadow(color: _C.botBubbleShadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: _C.iconBot.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.smart_toy, size: 14, color: _C.iconBot)),
        const SizedBox(width: 10),
        AnimatedBuilder(animation: _dotController, builder: (ctx, _) => Row(children: List.generate(3, (i) {
          final v = ((_dotController.value + i * 0.2) % 1.0);
          final op = (v < 0.5) ? v * 2 : (1 - v) * 2;
          return Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 8, height: 8, decoration: BoxDecoration(color: _C.header.withValues(alpha: op.clamp(0.3, 1.0)), shape: BoxShape.circle));
        }))),
      ]),
    ));
  }
}

//CINEBOT

class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background chat
  static const Color header = AppColors.navyPrimary;         // background AppBar header

  // --- Teks ---
  static const Color titleText = Colors.white;               // tulisan "CineBot" di header
  static const Color hint = AppColors.fontGreyLight;         // warna hint input
  static const Color subtitle = AppColors.fontGrey;          // warna subtitle

  // --- Icon ---
  static const Color iconBot = Colors.white;               // icon smart_toy (robot)
  static const Color sendIcon = Colors.white;                // icon send di tombol kirim

  // --- Input ---
  static Color inputBorder = Colors.grey.shade300;           // border input di modal settings
  static const Color inputContainerBg = Colors.white;        // background container text field
  static Color inputShadow = Colors.black;                   // shadow text field container

  // --- Buttons & Status ---
  static Color cancelText = Colors.grey.shade700;            // teks Batal
  static const Color btnDisabled = Colors.grey;              // tombol mati
  static Color warningBg = Colors.red.shade50;               // background box peringatan

  // --- Connection Status ---
  static Color onlineBg = Colors.green.shade50;              // bg status online panel
  static Color onlineText = Colors.green.shade700;           // teks status online panel
  static Color offlineBg = Colors.red.shade50;               // bg status offline panel
  static Color offlineText = Colors.red.shade700;            // teks status offline panel
  static Color onlineTextLight = Colors.green.shade100;      // teks status online (appbar)
  static Color offlineTextLight = Colors.red.shade100;       // teks status offline (appbar)

  // --- Gradient icon robot di header ---
  static const Color gradientIcon1 = AppColors.navyPrimary;  // gradient kiri icon robot
  static const Color gradientIcon2 = AppColors.navyPrimary;         // gradient kanan icon robot

  // --- Gradient tombol send ---
  static const Color gradientSend1 = AppColors.navyPrimary;  // gradient kiri tombol send
  static const Color gradientSend2 = AppColors.navyPrimary;         // gradient kanan tombol send

  // --- Bubble chat ---
  static const Color userBubble = AppColors.navyPrimary;     // bubble pesan user
  static Color userBubbleShadow = AppColors.navyPrimary;     // shadow bubble user
  static const Color userText = Colors.white;                // teks bubble user
  static const Color botBubble = Colors.white;               // bubble pesan bot
  static Color botBubbleShadow = Colors.black;               // shadow bubble bot
  static const Color botText = Colors.black87;               // teks bubble bot

  // --- Status ---
  static const Color online = Color(0xFF2ECC71);             // status online (hijau)
  static const Color offline = Color(0xFFFF5252);            // status offline (merah)
  static const Color sendButton = AppColors.navyPrimary;     // (legacy, gunakan gradientSend)
}
