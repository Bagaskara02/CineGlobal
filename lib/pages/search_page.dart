import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:http/http.dart' as http;
import '../services/database_helper.dart';
import 'detail_page.dart';
import 'login_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  List<String> _history = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  static const String _apiKey = '276b3a68ef2888c401b69fc9f9ad9140';
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final h = await DatabaseHelper.instance.getSearchHistory();
    if (mounted) setState(() => _history = h);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      await DatabaseHelper.instance.addSearchHistory(query);
    } catch (_) {}
    _loadHistory();
    try {
      final uri = Uri.parse('$_baseUrl/search/multi').replace(queryParameters: {
        'api_key': _apiKey, 'language': 'id-ID', 'query': query, 'page': '1',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final results = (data['results'] as List).where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv').toList();
        setState(() { _results = List<Map<String, dynamic>>.from(results); _hasSearched = true; _isSearching = false; });
        // Cache results to SQLite
        try { DatabaseHelper.instance.cacheMovies(results.cast<Map<String, dynamic>>()); } catch (_) {}
      } else {
        if (mounted) setState(() { _hasSearched = true; _isSearching = false; });
      }
    } catch (_) {
      // Fallback: load from SQLite cache
      try {
        final cached = await DatabaseHelper.instance.getCachedMovies();
        final filtered = cached.where((m) => (m['title'] as String? ?? '').toLowerCase().contains(query.toLowerCase())).toList();
        if (mounted) setState(() { _results = filtered; _hasSearched = true; _isSearching = false; });
      } catch (_) {
        if (mounted) setState(() { _results = []; _hasSearched = true; _isSearching = false; });
      }
    }
  }

  void _navigateToDetail(int id, String type) async {
    final session = await DatabaseHelper.instance.getSession();
    if (session != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(id: id, type: type)));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(id: id, type: type)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.appBar, elevation: 0, surfaceTintColor: _C.appBar, foregroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: _C.searchBoxBg, borderRadius: BorderRadius.circular(14)),
          child: TextField(
            controller: _searchCtrl, focusNode: _focusNode,
            onChanged: _onSearchChanged,
            onSubmitted: (q) => _search(q.trim()),
            decoration: InputDecoration(
              hintText: "Cari film, serial...",
              hintStyle: TextStyle(color: _C.hintText, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: _C.hintText, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: Icon(Icons.close, size: 18, color: _C.iconClear), onPressed: () { _searchCtrl.clear(); setState(() { _results = []; _hasSearched = false; }); }) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: _C.loading))
          : _hasSearched
              ? _buildResults()
              : _buildHistoryView(),
    );
  }

  Widget _buildHistoryView() {
    if (_history.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _C.accentSearch.withValues(alpha: 0.1), shape: BoxShape.circle), child: const Icon(Icons.search, size: 48, color: _C.accentSearch)),
        const SizedBox(height: 16),
        const Text("Cari Film Favorit Anda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 6),
        Text("Ketik judul film atau serial TV", style: TextStyle(color: Colors.grey.shade500)),
      ]));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text("Riwayat Pencarian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _C.accentSearch)),
        TextButton(onPressed: () async { await DatabaseHelper.instance.clearSearchHistory(); _loadHistory(); }, child: const Text("Hapus Semua", style: TextStyle(color: _C.accentSearch, fontSize: 12))),
      ]),
      const SizedBox(height: 8),
      ..._history.map((q) => ListTile(
        leading: Icon(Icons.history, color: _C.hintText, size: 20),
        title: Text(q, style: const TextStyle(fontSize: 14)),
        trailing: Icon(Icons.north_west, color: _C.hintText, size: 16),
        contentPadding: EdgeInsets.zero,
        dense: true,
        onTap: () { _searchCtrl.text = q; _search(q); },
      )),
    ]);
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text("Tidak ditemukan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text("Coba kata kunci lain", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final item = _results[i];
        final title = item['title'] ?? item['name'] ?? 'Tanpa Judul';
        final type = item['media_type'] ?? 'movie';
        final poster = item['poster_path'];
        final rating = (item['vote_average'] as num?)?.toDouble() ?? 0;
        final date = item['release_date'] ?? item['first_air_date'] ?? '';
        final overview = item['overview'] ?? '';

        return GestureDetector(
          onTap: () => _navigateToDetail(item['id'], type),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: poster != null
                    ? Image.network('https://image.tmdb.org/t/p/w200$poster', width: 70, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _posterPlaceholder())
                    : _posterPlaceholder()),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _C.accentSearch), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: type == 'tv' ? Colors.blue.shade50 : Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                    child: Text(type == 'tv' ? 'SERIAL' : 'FILM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: type == 'tv' ? Colors.blue : Colors.purple))),
                  const SizedBox(width: 8),
                  if (rating > 0) ...[Icon(Icons.star, size: 13, color: Colors.amber.shade700), const SizedBox(width: 2), Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 12, color: Colors.amber.shade700, fontWeight: FontWeight.w600))],
                  if (date.isNotEmpty) ...[const SizedBox(width: 8), Text(date.length >= 4 ? date.substring(0, 4) : date, style: const TextStyle(fontSize: 12, color: _C.dateText))],
                ]),
                if (overview.isNotEmpty) ...[const SizedBox(height: 6), Text(overview, style: const TextStyle(fontSize: 12, color: _C.subtitle, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)],
              ])),
            ]),
          ),
        );
      },
    );
  }

  Widget _posterPlaceholder() {
    return Container(width: 70, height: 100, decoration: BoxDecoration(color: _C.posterBg, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.movie, color: _C.hintText, size: 28));
  }
}

// =============================================================================
// PENGATURAN WARNA HALAMAN SEARCH
// Ubah warna di bawah ini untuk mengubah tampilan halaman Search.
// Referensi warna global: lihat lib/theme/app_colors.dart
// =============================================================================
class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar
  static const Color searchBoxBg = Color(0xFFE5E7EB);       // background kotak search

  // --- Warna Aksen ---
  static const Color accentSearch = AppColors.navyPrimary;   // warna aksen (judul, icon search)

  // --- Loading ---
  static const Color loading = AppColors.navyPrimary;        // warna loading indicator

  // --- Teks ---
  static const Color hintText = AppColors.fontGreyLight;     // warna hint & placeholder
  static const Color subtitle = AppColors.fontGrey;          // warna subtitle/overview
  static const Color dateText = AppColors.fontGreyLight;     // warna tahun rilis

  // --- Icon ---
  static const Color iconClear = AppColors.fontGreyLight;    // icon X clear search

  // --- Poster ---
  static const Color posterBg = AppColors.lightPurpleBg;     // background placeholder poster
}
