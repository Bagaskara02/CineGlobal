import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:sensors_plus/sensors_plus.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';

class DetailPage extends StatefulWidget {
  final int id;
  final String type; 
  const DetailPage({super.key, required this.id, required this.type});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? detail;
  YoutubePlayerController? _youtubeController;
  bool isWatchlisted = false;
  bool isDataLoading = true; 
  // Session dari SQLite (bukan Supabase auth)
  Map<String, dynamic>? _session;
  String? _userId;
  String? _username;
  List<Map<String, dynamic>> comments = [];
  final TextEditingController _commentController = TextEditingController();

  double _x = 0, _y = 0;
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _fetchDetail();
    _loadComments();
    _streamSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      if (mounted) setState(() { _x = event.x; _y = event.y; });
    });
  }

  Future<void> _loadSession() async {
    final session = await DatabaseHelper.instance.getSession();
    if (session != null && mounted) {
      setState(() {
        _session = session;
        _userId = session['user_id'] as String?;
        _username = session['username'] as String?;
      });
      _checkWatchlistStatus();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _youtubeController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    try {
      final data = await ApiService().getDetail(widget.id, widget.type);
      if (!mounted) return;

      String? videoKey;
      if (data['videos'] != null && data['videos']['results'] != null) {
        final List videos = data['videos']['results'];
        if (videos.isNotEmpty) {
          for (var v in videos) {
            if (v['site'] == 'YouTube' && v['type'] == 'Trailer') {
              videoKey = v['key'];
              break;
            }
          }
          if (videoKey == null) {
            for (var v in videos) {
              if (v['site'] == 'YouTube' && v['type'] == 'Teaser') {
                videoKey = v['key'];
                break;
              }
            }
          }
          videoKey ??= videos.firstWhere((v) => v['site'] == 'YouTube', orElse: () => null)?['key'];
        }
      }

      setState(() {
        detail = data;
        isDataLoading = false; 
        if (videoKey != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoKey,
            flags: const YoutubePlayerFlags(autoPlay: false, mute: false, forceHD: true),
          );
        }
      });
    } catch (e) {
      debugPrint("Error detail: $e");
      if (mounted) setState(() => isDataLoading = false);
    }
  }

  void _loadComments() async {
    try {
      final res = await DatabaseHelper.instance.getComments(widget.id);
      if (mounted) setState(() => comments = List<Map<String, dynamic>>.from(res));
    } catch (e) { debugPrint("Error load comments: $e"); }
  }

  // --- PERBAIKAN LOGIKA: AMBIL USERNAME DARI SESSION SQLite ---
  void _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _userId == null) return;
    
    try {
      final displayName = _username ?? 'Anonim';
      
      await DatabaseHelper.instance.addComment(
        widget.id, _userId!, displayName, content,
      );
      _commentController.clear();
      _loadComments();
    } catch (e) { debugPrint("Error add comment: $e"); }
  }

  void _checkWatchlistStatus() async {
    if (_userId == null) return;
    try {
      final inList = await DatabaseHelper.instance.isInWatchlist(_userId!, widget.id);
      if (mounted) setState(() => isWatchlisted = inList);
    } catch (e) { debugPrint("Watchlist error: $e"); }
  }

  void _toggleWatchlist() async {
    if (_userId == null || detail == null) return;
    try {
      if (isWatchlisted) {
        await DatabaseHelper.instance.removeFromWatchlist(_userId!, widget.id);
      } else {
        await DatabaseHelper.instance.addToWatchlist(
          _userId!,
          widget.id,
          detail!['title'] ?? detail!['name'] ?? 'Untitled',
          detail!['poster_path'],
          detail!['release_date'] ?? detail!['first_air_date'] ?? '-',
        );
      }
      setState(() => isWatchlisted = !isWatchlisted);
    } catch (e) { debugPrint("Toggle error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    if (isDataLoading) return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Color(0xFF00113A))));
    if (detail == null) return const Scaffold(backgroundColor: Colors.white, body: Center(child: Text("Gagal memuat detail.")));

    final String title = detail!['title'] ?? detail!['name'] ?? 'Unknown';
    final String? poster = detail!['poster_path'];
    final String? backdrop = detail!['backdrop_path'];
    final String overview = (detail!['overview'] != null && detail!['overview'].toString().trim().isNotEmpty) 
        ? detail!['overview'] 
        : 'Sinopsis tidak tersedia.';
    final double voteAvg = (detail!['vote_average'] ?? 0.0).toDouble();
    final int votePercent = (voteAvg * 10).round();
    final String releaseYear = (detail!['release_date'] ?? detail!['first_air_date'] ?? '').toString().length >= 4
        ? (detail!['release_date'] ?? detail!['first_air_date'] ?? '').toString().substring(0, 4)
        : '';
    
    // Genres
    final List genres = detail!['genres'] ?? [];
    
    // Credits
    final Map<String, dynamic>? credits = detail!['credits'];
    final List cast = credits?['cast'] ?? [];
    final List crew = credits?['crew'] ?? [];
    final String? director = crew.isNotEmpty 
        ? (crew.cast<Map<String, dynamic>>().where((c) => c['job'] == 'Director').isNotEmpty
            ? crew.cast<Map<String, dynamic>>().firstWhere((c) => c['job'] == 'Director')['name'] as String?
            : null)
        : null;
    final String? creator = crew.isNotEmpty 
        ? (crew.cast<Map<String, dynamic>>().where((c) => c['job'] == 'Director' || c['job'] == 'Creator' || c['department'] == 'Writing').isNotEmpty
            ? crew.cast<Map<String, dynamic>>().firstWhere((c) => c['job'] == 'Director' || c['job'] == 'Creator' || c['department'] == 'Writing')['name'] as String?
            : null)
        : null;

    return YoutubePlayerBuilder(
      player: YoutubePlayer(controller: _youtubeController ?? YoutubePlayerController(initialVideoId: "")),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis),
            backgroundColor: const Color(0xFF00113A), elevation: 0,
            surfaceTintColor: const Color(0xFF00113A),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Trailer / Backdrop ──
                _youtubeController != null ? player : (backdrop != null 
                  ? Image.network(
                      "https://image.tmdb.org/t/p/w500$backdrop", 
                      height: 220, width: double.infinity, fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 220, color: Colors.grey.shade100,
                          child: const Center(child: CircularProgressIndicator(color: Color(0xFF00113A), strokeWidth: 3)),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(height: 220, color: Colors.grey.shade100, child: const Icon(Icons.movie, size: 50, color: Colors.grey)),
                    )
                  : Container(height: 220, color: Colors.grey.shade100, child: const Icon(Icons.movie, size: 50, color: Colors.grey))),
                
                // ── Score Row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Score badge
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: votePercent >= 70 ? const Color(0xFF21D07A) : votePercent >= 40 ? Colors.amber : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12, width: 3),
                        ),
                        child: Center(
                          child: RichText(
                            text: TextSpan(children: [
                              TextSpan(text: '$votePercent', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                              const TextSpan(text: '%', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Skor", style: TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Pengguna", style: TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Title + Year ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text('$title ($releaseYear)',
                    style: const TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 22)),
                ),

                // ── Genres ──
                if (genres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Wrap(
                      spacing: 8, runSpacing: 6,
                      children: genres.map<Widget>((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF00113A).withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(g['name'] ?? '', style: const TextStyle(color: Color(0xFF00113A), fontSize: 12)),
                      )).toList(),
                    ),
                  ),

                // ── Poster 3D + Watchlist ──
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Center(
                        child: Transform(
                          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(_y * 0.05)..rotateY(_x * -0.05),
                          alignment: FractionalOffset.center,
                          child: Container(
                            height: 300, width: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(_x * 5, _y * 5))],
                              color: Colors.grey[200],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: poster != null 
                                ? Image.network(
                                    "https://image.tmdb.org/t/p/w342$poster",
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(child: CircularProgressIndicator(color: Color(0xFF00113A), strokeWidth: 3)),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.grey)),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.grey)),
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _toggleWatchlist,
                          icon: Icon(isWatchlisted ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFF00113A)),
                          label: Text(isWatchlisted ? "Tersimpan" : "Tambah ke Watchlist", style: const TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFCD400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Sinopsis ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Kilasan Singkat", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
                      const SizedBox(height: 10),
                      Text(overview, style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87)),
                    ],
                  ),
                ),

                // ── Kreator ──
                if (creator != null || director != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(director ?? creator ?? '', style: const TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text("Kreator", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),

                // ── Aktor ──
                if (cast.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Aktor", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: cast.length > 10 ? 10 : cast.length,
                            itemBuilder: (ctx, i) {
                              final actor = cast[i];
                              final String? profilePath = actor['profile_path'];
                              return Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 35,
                                      backgroundColor: const Color(0xFF00113A),
                                      backgroundImage: profilePath != null ? NetworkImage('https://image.tmdb.org/t/p/w185$profilePath') : null,
                                      child: profilePath == null ? const Icon(Icons.person, color: Colors.white54) : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(actor['name'] ?? '', style: const TextStyle(color: Color(0xFF00113A), fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    Text(actor['character'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Diskusi ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Diskusi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
                      const SizedBox(height: 10),
                      
                      comments.isEmpty 
                        ? Text("Belum ada diskusi.", style: TextStyle(color: Colors.grey.shade500))
                        : ListView.builder(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00113A).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comments[index]['username'] ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00113A), fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(comments[index]['content'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 10),
                      if (_userId != null)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: TextField(
                            controller: _commentController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: "Tulis diskusi...",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixIcon: IconButton(icon: const Icon(Icons.send, color: Color(0xFFFCD400)), onPressed: _addComment),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
