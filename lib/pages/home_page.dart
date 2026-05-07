import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import 'detail_page.dart';
import 'login_page.dart';
import 'lbs_page.dart';
import 'search_page.dart';
import '../services/notification_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List list2026 = [];
  List listSeries = [];
  List listTrending = [];
  
  String trendingFilter = 'day'; 
  bool isTrendingLoading = true;
  bool isLoading = true;
  static const String _bannerVideoId = '4GLOr5C7uBo';

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    _tabController = TabController(length: 3, vsync: this);
    
    _fetchInitialData();
    _fetchTrendingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final movies = await ApiService().getMovies2026();
      final series = await ApiService().getSeries2026();
      if (mounted) {
        setState(() {
          list2026 = movies;
          listSeries = series;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchTrendingData() async {
    if (!mounted) return;
    setState(() => isTrendingLoading = true);
    try {
      final trending = await ApiService().getTrending(trendingFilter);
      if (mounted) {
        setState(() {
          listTrending = trending;
          isTrendingLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isTrendingLoading = false);
    }
  }

  void _changeTrendingFilter(String filter) {
    if (trendingFilter == filter) return;
    setState(() => trendingFilter = filter);
    _fetchTrendingData();
  }

  void _checkLoginAndNavigate(int id, String type) async {
    final session = await DatabaseHelper.instance.getSession();
    if (session != null) {
      Navigator.push(context, MaterialPageRoute(builder: (c) => DetailPage(id: id, type: type)));
    } else {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginPage()));
      if (result == true && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => DetailPage(id: id, type: type)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: const Text('CineGlobal', style: TextStyle(fontWeight: FontWeight.w800, color: _C.appBarTitle, fontSize: 20)),
            backgroundColor: const Color(0xFF00113A),
            surfaceTintColor: const Color(0xFF00113A),
            elevation: innerBoxIsScrolled ? 2 : 0,
            floating: true, pinned: true, snap: true,
            iconTheme: const IconThemeData(color: _C.appBarIcon),
            actions: [
              IconButton(icon: const Icon(Icons.search, color: _C.appBarIcon), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()))),
              IconButton(icon: const Icon(Icons.notifications_outlined, color: _C.appBarIcon), onPressed: _showNotificationPanel),
              IconButton(icon: const Icon(Icons.map_rounded, color: _C.appBarIcon), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LbsPage()))),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFFCD400),
              indicatorWeight: 3,
              labelColor: const Color(0xFFFCD400),
              unselectedLabelColor: _C.tabUnselectedLabel,
              tabs: const [ Tab(text: "FILM"), Tab(text: "SERIAL"), Tab(text: "TREN")],
            ),
          ),
        ],
        body: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMovieTab(), 
                _buildGenericList(listSeries, 'tv'), 
                _buildTrendingTab(),
              ],
            ),
      ),
    );
  }

  Widget _buildMovieTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroBanner(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
            child: Text("Tayang di 2026", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))
          ),
          _buildGenericList(list2026, 'movie'),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return GestureDetector(
      onTap: () => _checkLoginAndNavigate(1003596, 'movie'),
      child: Container(
        margin: const EdgeInsets.all(20),
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28), 
          boxShadow: [BoxShadow(color: const Color(0xFF00113A).withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 12))]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://img.youtube.com/vi/$_bannerVideoId/maxresdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF00113A)),
              ),
              Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
              const Positioned(
                bottom: 40, left: 20,
                child: Text("AVENGERS: DOOMSDAY", style: TextStyle(color: _C.bannerTitle, fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              Positioned(
                bottom: 10, left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.trailerBtnBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow, color: _C.trailerBtnIcon, size: 16),
                    SizedBox(width: 4),
                    Text("Trailer", style: TextStyle(color: _C.trailerBtnText, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendingTab() {
    return Column(
      children: [
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTrendingFilterChip("Hari Ini", 'day'),
            const SizedBox(width: 10),
            _buildTrendingFilterChip("Minggu Ini", 'week'),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: isTrendingLoading 
            ? const Center(child: CircularProgressIndicator())
            // PERBAIKAN: Gunakan 'auto' untuk mendeteksi media_type dari API
            : _buildGenericList(listTrending, 'auto'), 
        ),
      ],
    );
  }

  Widget _buildTrendingFilterChip(String label, String value) {
    bool isSelected = trendingFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _changeTrendingFilter(value),
      selectedColor: const Color(0xFFFCD400),
      backgroundColor: const Color(0xFFE5E7EB),
      labelStyle: TextStyle(color: isSelected ? _C.chipTextSelected : _C.chipTextDefault, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildGenericList(List data, String defaultType) {
    if (data.isEmpty) return const Center(child: Text("Data tidak tersedia."));
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        String actualType = defaultType == 'auto' 
            ? (item['media_type'] ?? 'movie') 
            : defaultType;
            
        return _buildCard(item, actualType);
      }
    );
  }

  Widget _buildCard(var item, String type) {
    final String title = item['title'] ?? item['name'] ?? 'Tanpa Judul';
    final String date = item['release_date'] ?? item['first_air_date'] ?? 'TBA';
    final double rating = (item['vote_average'] ?? 0.0).toDouble();
    final String? poster = item['poster_path'];

    return GestureDetector(
      onTap: () => _checkLoginAndNavigate(item['id'], type),
      child: Container(
        decoration: BoxDecoration(
          color: _C.movieCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _C.movieCardShadow.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  'https://image.tmdb.org/t/p/w300${poster ?? ""}',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: const Color(0xFF00113A),
                    child: const Center(child: Icon(Icons.movie, color: _C.moviePosterError, size: 40)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00113A)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(date, style: TextStyle(fontSize: 11, color: _C.movieDateText)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: _C.movieStarIcon, size: 14),
                      const SizedBox(width: 3),
                      Text(rating.toStringAsFixed(1),
                          style: TextStyle(color: _C.movieRatingText, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: _C.notifSheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _C.notifHandle, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.notifications, color: Color(0xFF00113A), size: 24),
              SizedBox(width: 10),
              Text("Notifikasi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _notifItem(Icons.movie, "Film Baru!", "Avengers: Doomsday segera tayang di bioskop terdekat Anda.", "2 jam lalu", Colors.red),
                  _notifItem(Icons.local_offer, "Promo Akhir Pekan", "Diskon 30% untuk semua tiket hari Sabtu & Minggu!", "5 jam lalu", Colors.green),
                  _notifItem(Icons.event_seat, "Tiket Tersedia", "Kursi premium IMAX untuk film 'Mickey 17' tersedia!", "Kemarin", Colors.blue),
                  _notifItem(Icons.star, "Rating Update", "Film favoritmu 'Paddington' naik ke 8.2!", "2 hari lalu", Colors.amber),
                  _notifItem(Icons.campaign, "Reminder", "Jangan lupa tonton film pilihanmu hari ini!", "3 hari lalu", Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifItem(IconData icon, String title, String body, String time, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4)),
              const SizedBox(height: 4),
              Text(time, style: TextStyle(fontSize: 11, color: _C.notifTimeText)),
            ],
          )),
        ],
      ),
    );
  }
}

class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.cardBg;                  // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar

  // --- AppBar ---
  static const Color appBarTitle = Colors.white;             // teks "CineGlobal"
  static const Color appBarIcon = Colors.white;              // icon search/notif/map
  static const Color tabUnselectedLabel = Colors.white60;    // tab label tidak aktif

  // --- Tab Bar ---
  static const Color tabIndicator = AppColors.gold;          // garis bawah tab aktif
  static const Color tabLabel = AppColors.gold;              // label tab aktif

  // --- Banner/Hero ---
  static Color bannerGradientStart = Colors.transparent;     // gradient banner atas
  static Color bannerGradientEnd = Colors.black;             // gradient banner bawah
  static const Color bannerTitle = Colors.white;             // judul banner
  static const Color trailerBtnBg = Colors.red;              // background tombol trailer
  static const Color trailerBtnIcon = Colors.white;          // icon play trailer
  static const Color trailerBtnText = Colors.white;          // teks "Trailer"

  // --- Chip Kategori ---
  static const Color chipSelected = AppColors.gold;          // chip trending dipilih
  static const Color chipBg = Color(0xFFE5E7EB);            // chip trending default
  static Color chipTextSelected = const Color(0xFF00113A);   // teks chip dipilih
  static Color chipTextDefault = Colors.grey.shade600;       // teks chip default

  // --- Movie Card ---
  static const Color movieCardBg = Colors.white;             // background card film
  static Color movieCardShadow = Colors.black;               // shadow card film
  static const Color moviePosterError = Colors.white54;      // icon error poster
  static Color movieDateText = Colors.grey.shade500;         // teks tanggal rilis
  static Color movieStarIcon = Colors.amber.shade600;        // icon bintang rating
  static Color movieRatingText = Colors.amber.shade700;      // teks rating angka

  // --- Notifikasi Bottom Sheet ---
  static const Color notifSheetBg = Colors.white;            // background sheet notif
  static Color notifHandle = Colors.grey.shade300;           // handle bar atas sheet
  static Color notifTimeText = Colors.grey.shade400;         // teks waktu notifikasi

  // --- Warna Aksen ---
  static const Color accent = AppColors.navyPrimary;         // warna aksen umum (heading, border)

  // --- Teks ---
  static const Color subtitle = AppColors.fontGrey;          // subtitle/body text

  // --- Icon ---
  static const Color notifIcon = AppColors.navyPrimary;      // icon notifikasi
}

