import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ticket_models.dart';
import '../services/database_helper.dart';
import 'seat_selection_page.dart';
import 'login_page.dart';

class FilmDetailPage extends StatefulWidget {
  final NowPlayingMovie movie;
  const FilmDetailPage({super.key, required this.movie});

  @override
  State<FilmDetailPage> createState() => _FilmDetailPageState();
}

class _FilmDetailPageState extends State<FilmDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<CinemaSchedule> _schedules = generateSchedules();

  late DateTime _selectedDate;
  late List<DateTime> _dateTabs;
  String _brandFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime.now();
    _dateTabs = List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<CinemaSchedule> get _filteredSchedules {
    if (_brandFilter == 'Semua') return _schedules;
    return _schedules.where((s) {
      final b = s.brand.toUpperCase();
      final f = _brandFilter.toUpperCase();
      return b.contains(f);
    }).toList();
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Hari ini';
    }
    return DateFormat('EEE', 'id_ID').format(dt);
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      return DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _formatPrice(int price) {
    if (price < 1000) return '$price';
    return '${(price / 1000).round()}.000';
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          // ── Backdrop + Back ──────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                ),
                child: const Icon(Icons.arrow_back, color: Color(0xFF00113A)),
              ),
            ),
            title: Text(movie.title,
                style: const TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  movie.backdropUrl.isNotEmpty
                      ? Image.network(movie.backdropUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF00113A).withValues(alpha: 0.2)))
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF00113A).withValues(alpha: 0.3), const Color(0xFFFCD400).withValues(alpha: 0.2)],
                            ),
                          ),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFFF8F9FA)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Poster + Info Header ──────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: movie.posterUrl.isNotEmpty
                        ? Image.network(movie.posterUrl,
                            width: 90, height: 135, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _smallPoster())
                        : _smallPoster(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(movie.title,
                            style: const TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 6),
                        Text('Tayang: ${_formatDate(movie.releaseDate)}',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: [
                            _chip(Icons.star, movie.ratingLabel, Colors.amber.shade700),
                            _chip(Icons.access_time, movie.runtimeLabel, Colors.grey.shade600),
                            _chip(Icons.shield_outlined, movie.ageRating, const Color(0xFF00113A)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab Bar ──────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: const Color(0xFF00113A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF00113A),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF9CA3AF),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 17),
                            SizedBox(width: 6),
                            Text('Jadwal'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 17),
                            SizedBox(width: 6),
                            Text('Detail'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildScheduleTab(),
            _buildDetailTab(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // JADWAL TAB
  // ─────────────────────────────────────────────────────────
  Widget _buildScheduleTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 12),

        // Date picker row
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dateTabs.length,
            itemBuilder: (ctx, i) {
              final dt = _dateTabs[i];
              final isSelected = dt.day == _selectedDate.day &&
                  dt.month == _selectedDate.month;
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = dt),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 54,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00113A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.grey.shade200),
                    boxShadow: isSelected
                        ? [BoxShadow(color: const Color(0xFF00113A).withValues(alpha: 0.3), blurRadius: 8)]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_dayLabel(dt),
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : const Color(0xFF9CA3AF),
                            fontSize: 10,
                          )),
                      const SizedBox(height: 2),
                      Text('${dt.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF00113A),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Brand filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['Semua', 'XXI', 'CGV', 'Cinépolis'].map((b) {
              final active = _brandFilter == b;
              return GestureDetector(
                onTap: () => setState(() => _brandFilter = b),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF00113A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: active ? null : Border.all(color: Colors.grey.shade200),
                    boxShadow: active
                        ? [BoxShadow(color: const Color(0xFF00113A).withValues(alpha: 0.25), blurRadius: 6)]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                  ),
                  child: Text(b,
                      style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Cinema schedule cards
        ..._filteredSchedules.map((s) => _buildCinemaCard(s)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCinemaCard(CinemaSchedule schedule) {
    final color = brandColor(schedule.brand);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cinema header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(brandIcon(schedule.brand), color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(schedule.cinemaName,
                          style: const TextStyle(
                              color: Color(0xFF00113A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(schedule.studioType,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rp ${_formatPrice(schedule.priceIDR)}',
                        style: const TextStyle(
                            color: Color(0xFF00113A),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const Text('/ kursi',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Colors.grey.shade100),

          // Show time buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: schedule.showTimes.map((time) {
                return InkWell(
                  onTap: () => _onShowTimeSelected(schedule, time),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00113A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00113A).withValues(alpha: 0.3)),
                    ),
                    child: Text(time,
                        style: const TextStyle(
                            color: Color(0xFF00113A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _onShowTimeSelected(CinemaSchedule schedule, String time) async {
    // Cek login dari SQLite session
    final session = await DatabaseHelper.instance.getSession();
    if (session == null) {
      _showLoginRequired();
      return;
    }

    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeatSelectionPage(
          movie: widget.movie,
          schedule: schedule,
          showDate: dateLabel,
          showTime: time,
        ),
      ),
    );
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFF00113A), size: 28),
            SizedBox(width: 10),
            Text('Login Diperlukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Anda harus login terlebih dahulu untuk membeli tiket.',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00113A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Login Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // DETAIL TAB
  // ─────────────────────────────────────────────────────────
  Widget _buildDetailTab() {
    final movie = widget.movie;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sinopsis',
                  style: TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text(
                movie.overview.isNotEmpty ? movie.overview : 'Sinopsis tidak tersedia.',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: Column(
            children: [
              _detailRow('Tanggal Rilis', _formatDate(movie.releaseDate)),
              _detailRow('Durasi', movie.runtimeLabel),
              _detailRow('Rating', '${movie.ratingLabel}/10'),
              _detailRow('Batasan Usia', movie.ageRating, isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        color: Color(0xFF00113A), fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _smallPoster() {
    return Container(
      width: 90, height: 135,
      color: const Color(0xFFEEEEF5),
      child: const Icon(Icons.movie, color: Color(0xFF9CA3AF), size: 40),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Pinned TabBar delegate
// ─────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _TabBarDelegate({required this.child});

  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
