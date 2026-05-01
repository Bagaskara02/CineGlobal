import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/ticket_models.dart';
import 'checkout_struk_page.dart';

class SeatSelectionPage extends StatefulWidget {
  final NowPlayingMovie movie;
  final CinemaSchedule schedule;
  final String showDate;
  final String showTime;

  const SeatSelectionPage({
    super.key,
    required this.movie,
    required this.schedule,
    required this.showDate,
    required this.showTime,
  });

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  static const int _rows = 13;
  // 11 kolom (kiri 5 + aisle + kanan 6) lebih mudah masuk layar
  static const int _leftCols = 5;
  static const int _rightCols = 6;
  static const int _totalCols = _leftCols + _rightCols; // 11
  static const String _rowLabels = 'ABCDEFGHIJKLM';

  late final List<List<int>> _seatStatus;
  final Set<String> _selectedSeats = {};

  @override
  void initState() {
    super.initState();
    _seatStatus = _generateSeats();
  }

  List<List<int>> _generateSeats() {
    final rng = Random(widget.movie.id + widget.showTime.hashCode);
    return List.generate(_rows, (_) {
      return List.generate(_totalCols, (_) {
        final r = rng.nextDouble();
        if (r < 0.28) return 1; // terisi
        if (r < 0.36) return 2; // dibooking
        return 0; // tersedia
      });
    });
  }

  String _seatLabel(int row, int col) => '${_rowLabels[row]}${col + 1}';

  void _toggleSeat(int row, int col) {
    if (_seatStatus[row][col] == 1 || _seatStatus[row][col] == 2) return;
    final id = _seatLabel(row, col);
    setState(() {
      if (_seatStatus[row][col] == 3) {
        _seatStatus[row][col] = 0;
        _selectedSeats.remove(id);
      } else {
        _seatStatus[row][col] = 3;
        _selectedSeats.add(id);
      }
    });
  }


  void _proceed() {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal 1 kursi terlebih dahulu.')),
      );
      return;
    }
    final order = TicketOrder(
      movie: widget.movie,
      schedule: widget.schedule,
      showDate: widget.showDate,
      showTime: widget.showTime,
      selectedSeats: _selectedSeats.toList()..sort(),
      studioType: widget.schedule.studioType,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutStrukPage(order: order)),
    );
  }

  Color _seatColor(int status) {
    switch (status) {
      case 0: return _C.available; // Tersedia - abu terang
      case 1: return _C.available.withValues(alpha: 0.4); // Terisi - transparan
      case 2: return _C.available.withValues(alpha: 0.4); // Dibooking
      case 3: return _C.selected; // Dipilih - GOLD
      default: return _C.available;
    }
  }

  Color _seatBorderColor(int status) {
    switch (status) {
      case 0: return _C.availableBorder;
      case 1: return Colors.transparent;
      case 2: return Colors.transparent;
      case 3: return _C.selectedBorder;
      default: return _C.availableBorder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSeats = _selectedSeats.toList()..sort();
    final totalPrice = widget.schedule.priceIDR * _selectedSeats.length;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.movie.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            Text('STUDIO 1 • ${widget.showTime} • HARI INI',
                style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 1.2)),
          ],
        ),
        centerTitle: true,
        backgroundColor: _C.appBar,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: _C.appBar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline, color: Colors.white70), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // (Info panel removed — now in AppBar)

          // ── LEGEND ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem(_C.available, _C.availableBorder, 'Tersedia'),
                _legendItem(_C.selected, _C.selectedBorder, 'Dipilih'),
                _legendItem(_C.available.withValues(alpha: 0.4), Colors.transparent, 'Terisi'),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // ── GRID ──
          Expanded(
            child: LayoutBuilder(builder: (ctx, bc) {
              // Rumus tepat:
              // totalRow = leftLabel(20) + gap(4) + leftCols*(s+m*2) + aisle(14) + rightCols*(s+m*2) + gap(4) + rightLabel(20)
              // = 62 + 11*(s+m*2)  → m = 2 (tiap sisi)
              // availW = bc.maxWidth - 16(lr padding) - 62 = bc.maxWidth - 78
              // slot = availW / 11
              final availW = bc.maxWidth - 16 - 62; // 16 = 8+8 padding
              final slot = (availW / _totalCols).clamp(22.0, 36.0);
              const double m = 2.0;
              final sz = slot - m * 2;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  children: [
                    // Screen
                    Container(
                      margin: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_C.appBar, _C.bottomBar, _C.appBar]),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40),
                        ),
                        boxShadow: [BoxShadow(color: _C.bottomBar.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: const Center(
                        child: Text('LAYAR',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 3)),
                      ),
                    ),

                    // Rows dari M ke A
                    ...List.generate(_rows, (i) {
                      final row = _rows - 1 - i;
                      final label = _rowLabels[row];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: m),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, child: Text(label,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center)),
                            const SizedBox(width: 4),
                            // Kiri
                            ...List.generate(_leftCols, (c) => _buildSeat(row, c, sz, m)),
                            // Lorong
                            const SizedBox(width: 14),
                            // Kanan
                            ...List.generate(_rightCols, (c) => _buildSeat(row, c + _leftCols, sz, m)),
                            const SizedBox(width: 4),
                            SizedBox(width: 20, child: Text(label,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 9, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center)),
                          ],
                        ),
                      );
                    }),

                    // Angka kolom
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 24),
                        ...List.generate(_leftCols, (i) => SizedBox(
                          width: slot,
                          child: Text('${i + 1}',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 8), textAlign: TextAlign.center),
                        )),
                        const SizedBox(width: 14),
                        ...List.generate(_rightCols, (i) => SizedBox(
                          width: slot,
                          child: Text('${i + 1}',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 8), textAlign: TextAlign.center),
                        )),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),

          // ── BOTTOM BAR ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: _C.bottomBar,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedSeats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('KURSI (${_selectedSeats.length})',
                                style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(sortedSeats.join(', '),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('TOTAL HARGA',
                                style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text('Rp ${_fmt(totalPrice)}',
                                style: TextStyle(color: _C.priceText, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedSeats.isEmpty ? null : _proceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.buttonBg,
                      foregroundColor: _C.buttonFg,
                      disabledBackgroundColor: Colors.grey.shade700,
                      disabledForegroundColor: Colors.grey.shade500,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedSeats.isEmpty ? 'PILIH KURSI TERLEBIH DAHULU' : 'LANJUTKAN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5),
                        ),
                        if (_selectedSeats.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeat(int row, int col, double sz, double m) {
    final status = _seatStatus[row][col];
    final label = _seatLabel(row, col);
    final canTap = (status == 0 || status == 3);

    return GestureDetector(
      onTap: canTap ? () => _toggleSeat(row, col) : null,
      child: Container(
        width: sz,
        height: sz,
        margin: EdgeInsets.all(m),
        decoration: BoxDecoration(
          color: _seatColor(status),
          borderRadius: BorderRadius.circular(sz * 0.18),
          border: Border.all(color: _seatBorderColor(status), width: 1),
          boxShadow: status == 3 ? [BoxShadow(color: _C.selected.withValues(alpha: 0.5), blurRadius: 6)] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: sz * 0.26,
            color: (status == 3) ? _C.bottomBar : (status == 0) ? Colors.grey.shade600 : Colors.transparent,
            fontWeight: status == 3 ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color fill, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13, height: 13,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(3), border: Border.all(color: border)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: _C.labelText)),
      ],
    );
  }

  String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// =============================================================================
// PENGATURAN WARNA HALAMAN PILIH KURSI
// Ubah warna di bawah ini untuk mengubah tampilan halaman Pilih Kursi.
// Referensi warna global: lihat lib/theme/app_colors.dart
// =============================================================================
class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar

  // --- Kursi Tersedia ---
  static const Color available = Color(0xFFE5E7EB);          // warna kursi tersedia
  static const Color availableBorder = Color(0xFFD1D5DB);    // border kursi tersedia

  // --- Kursi Dipilih ---
  static const Color selected = AppColors.gold;              // warna kursi dipilih (GOLD)
  static const Color selectedBorder = AppColors.goldDark;    // border kursi dipilih

  // --- Bar Bawah ---
  static const Color bottomBar = AppColors.navyPrimary;      // background bar bawah
  static const Color priceText = AppColors.gold;             // harga di bar bawah

  // --- Tombol Lanjut ---
  static const Color buttonBg = AppColors.gold;              // background tombol lanjut
  static const Color buttonFg = AppColors.navyPrimary;       // teks tombol lanjut

  // --- Teks ---
  static const Color labelText = AppColors.fontGreyLight;    // label kursi (A1, B2)
}
