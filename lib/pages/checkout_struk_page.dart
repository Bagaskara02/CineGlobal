import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/ticket_models.dart';
import '../services/notification_helper.dart';
import '../services/database_helper.dart';

class CheckoutStrukPage extends StatefulWidget {
  final TicketOrder order;
  const CheckoutStrukPage({super.key, required this.order});

  @override
  State<CheckoutStrukPage> createState() => _CheckoutStrukPageState();
}

class _CheckoutStrukPageState extends State<CheckoutStrukPage> {
  bool _paid = false;
  bool _isSaving = false;
  String _selectedPayment = 'GoPay';
  String _ticketId = '';

  final List<Map<String, dynamic>> _paymentMethods = [
    {'name': 'GoPay', 'icon': Icons.account_balance_wallet, 'color': _C.colorGopay},
    {'name': 'OVO', 'icon': Icons.account_balance_wallet_outlined, 'color': _C.colorOvo},
    {'name': 'DANA', 'icon': Icons.wallet, 'color': _C.accent},
    {'name': 'ShopeePay', 'icon': Icons.shopping_bag_outlined, 'color': _C.colorShopeePay},
    {'name': 'Transfer Bank', 'icon': Icons.account_balance, 'color': _C.accent},
    {'name': 'Kartu Kredit', 'icon': Icons.credit_card, 'color': _C.colorKredit},
  ];

  @override
  Widget build(BuildContext context) {
    return _paid ? _buildStruk(context) : _buildCheckout(context);
  }

  Future<void> _processPayment() async {
    setState(() => _isSaving = true);
    final order = widget.order;
    _ticketId = 'CGX-${DateTime.now().millisecondsSinceEpoch % 1000000}';

    // Simpan tiket ke SQLite (lokal per akun)
    final session = await DatabaseHelper.instance.getSession();
    if (session != null) {
      final userId = session['user_id'] as String;
      try {
        await DatabaseHelper.instance.saveTicket(
          userId: userId,
          ticketId: _ticketId,
          movieTitle: order.movie.title,
          cinemaName: order.schedule.cinemaName,
          showDate: order.showDate,
          showTime: order.showTime,
          seats: order.seatLabel,
          totalPrice: order.totalIDR,
          studioType: order.schedule.studioType,
          paymentMethod: _selectedPayment,
        );
        debugPrint("Tiket berhasil disimpan ke SQLite");
      } catch (e) {
        debugPrint("Gagal simpan tiket: $e");
      }
    }

    if (mounted) {
      setState(() {
        _paid = true;
        _isSaving = false;
      });
    }

    // Kirim notifikasi push (seperti notif WA)
    NotificationHelper.instance.showTicketPurchaseNotification(
      movieTitle: order.movie.title,
      cinemaName: order.schedule.cinemaName,
      showTime: order.showTime,
      showDate: order.showDate,
      ticketId: _ticketId,
      paymentMethod: _selectedPayment,
      totalPrice: order.totalIDR,
    );
  }

  // ===========================================================
  // CHECKOUT
  // ===========================================================
  Widget _buildCheckout(BuildContext context) {
    final order = widget.order;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text('Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _C.appBarCheckoutBg,
        foregroundColor: _C.buttonFg,
        elevation: 0.5,
        surfaceTintColor: _C.appBarCheckoutBg,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Movie summary (Navy card) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.accentPrimary, _C.accentSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: order.movie.posterUrl.isNotEmpty
                              ? Image.network(order.movie.posterUrl,
                                  width: 64, height: 96, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _posterFallback())
                              : _posterFallback(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.movie.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _C.movieTitle)),
                              const SizedBox(height: 4),
                              Text(order.schedule.cinemaName,
                                  style: const TextStyle(color: _C.movieSubtitle, fontSize: 12)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _C.buttonBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${order.showDate.split(',').first} • ${order.showTime}',
                                  style: const TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Rincian harga ──
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _priceRow('💎 Kursi (${order.seatLabel})',
                            'Rp ${_fmt(order.totalIDR)}'),
                        const SizedBox(height: 6),
                        _priceRow('📦 Biaya Layanan', 'Rp ${_fmt(4000)}'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: _C.bg),
                        ),
                        _priceRow('Total Pembayaran', 'Rp ${_fmt(order.totalIDR + 4000)}', bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Metode pembayaran ──
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Pilih Metode Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _C.accent)),
                  ),
                  _card(
                    child: Column(
                      children: _paymentMethods.map((m) {
                        final selected = _selectedPayment == m['name'];
                        final color = m['color'] as Color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPayment = m['name']),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            decoration: BoxDecoration(
                              color: _C.paymentBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _C.paymentBorderSelected : _C.paymentBorder,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: selected ? [
                                BoxShadow(color: _C.accent.withValues(alpha: 0.08), blurRadius: 8),
                              ] : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: selected ? color.withValues(alpha: 0.15) : _C.paymentIconBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(m['icon'] as IconData,
                                      size: 18, color: selected ? color : _C.paymentIconColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(m['name'].toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                        color: selected ? _C.paymentTextSelected : _C.paymentText,
                                      )),
                                ),
                                if (selected)
                                  const Icon(Icons.radio_button_checked, color: _C.accent, size: 22)
                                else
                                  Icon(Icons.radio_button_off, color: _C.paymentRadioOff, size: 22),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: _C.bottomBarBg,
              boxShadow: [BoxShadow(color: _C.bottomBarShadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Harga', style: TextStyle(color: _C.hint, fontSize: 12)),
                    Text('Rp ${_fmt(order.totalIDR + 4000)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20, color: _C.accent)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.buttonBg,
                      foregroundColor: _C.buttonFg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Bayar Sekarang',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(width: 6),
                        Icon(Icons.lock_outline, size: 16),
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

  // ===========================================================
  // STRUK (WHITE THEME)
  // ===========================================================
  Widget _buildStruk(BuildContext context) {
    final order = widget.order;
    final timeMap = order.timeConversions;
    final priceMap = order.priceConversions;
    final brandClr = brandColor(order.schedule.brand);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.appBar,
        foregroundColor: _C.appBarStrukFg,
        elevation: 0,
        surfaceTintColor: _C.appBar,
        title: const Text('E-Tiket', style: TextStyle(fontWeight: FontWeight.bold, color: _C.appBarStrukFg)),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            icon: const Icon(Icons.home_outlined, size: 18, color: _C.buttonBg),
            label: const Text('Beranda',
                style: TextStyle(color: _C.buttonBg, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Tiket digital ──────────────────────────────
            _buildTicketCard(order, brandClr),
            const SizedBox(height: 20),

            // ── Timezone Conversion ────────────────────────
            _buildConversionSection(
              icon: Icons.schedule_outlined,
              title: 'Jadwal Tayang Dunia',
              subtitle: 'Konversi Zona Waktu',
              accentColor: _C.accentPrimary,
              entries: timeMap.entries.toList(),
              isTime: true,
            ),
            const SizedBox(height: 16),

            // ── Currency Conversion ─────────────────────────
            _buildConversionSection(
              icon: Icons.currency_exchange_outlined,
              title: 'Harga Tiket Dunia',
              subtitle: 'Konversi Mata Uang',
              accentColor: _C.accentGold,
              entries: priceMap.entries.toList(),
              isTime: false,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(TicketOrder order, Color brandClr) {
    return Container(
      decoration: BoxDecoration(
        color: _C.ticketCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _C.accent.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          // Header — Navy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.accentPrimary, _C.accentSecondary],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                // VALID badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.buttonBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: _C.accent, size: 14),
                      SizedBox(width: 4),
                      Text('VALID', style: TextStyle(color: _C.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                // Ticket ID
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: _C.ticketIdBorder.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _ticketId.isNotEmpty ? _ticketId : 'CGX-${DateTime.now().millisecondsSinceEpoch % 1000000}',
                    style: const TextStyle(color: _C.buttonBg, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          
          // Movie info on navy background
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            color: _C.accentSecondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CINEGLOBAL PREMIERE ACCESS',
                    style: TextStyle(color: _C.ticketTextMuted, fontSize: 10, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(order.movie.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _C.ticketTextLight)),
                const SizedBox(height: 4),
                Text('${order.schedule.studioType} • Original Audio',
                    style: const TextStyle(color: _C.ticketTextMuted2, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DATE', style: TextStyle(color: _C.ticketTextMuted, fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(order.showDate.split(',').first.isEmpty ? order.showDate : order.showDate.split(',').first,
                            style: const TextStyle(color: _C.buttonBg, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(width: 40),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TIME', style: TextStyle(color: _C.ticketTextMuted, fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text('${order.showTime} Local',
                            style: const TextStyle(color: _C.buttonBg, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Dashed divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              children: [
                _notch(right: false),
                Expanded(
                  child: Row(
                    children: List.generate(
                        30,
                        (_) => Expanded(
                              child: Container(
                                  height: 1.5,
                                  color: _C.ticketDashedLine,
                                  margin: const EdgeInsets.symmetric(horizontal: 2)),
                            )),
                  ),
                ),
                _notch(right: true),
              ],
            ),
          ),

          // Price & Location (white section)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LOCATION', style: TextStyle(color: _C.hint, fontSize: 10, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(order.schedule.cinemaName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _C.accent)),
                      Text('Studio 1, ${order.schedule.studioType}',
                          style: const TextStyle(color: _C.subtitle, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('SEAT', style: TextStyle(color: _C.hint, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(order.seatLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: _C.accent)),
                  ],
                ),
              ],
            ),
          ),

          // Barcode
          Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                // Vertical barcode stripes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    30,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: i % 3 == 0 ? 3 : 2,
                      height: 50,
                      color: i % 5 == 0 ? Colors.transparent : _C.barcodeLine,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CGX${DateTime.now().millisecondsSinceEpoch % 10000000000}',
                  style: const TextStyle(fontSize: 12, color: _C.hint, letterSpacing: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required List<MapEntry<String, String>> entries,
    required bool isTime,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.accentPrimary, _C.accentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _C.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: _C.conversionIcon, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _C.conversionTitle)),
              ],
            ),
          ),

          // Entries
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: entries.asMap().entries.map((mapEntry) {
                final idx = mapEntry.key;
                final e = mapEntry.value;
                final isFirst = idx == 0;
                final flagMap = {
                  'WIB (UTC+7)': '🇮🇩',
                  'WITA (UTC+8)': '🇮🇩',
                  'WIT (UTC+9)': '🇮🇩',
                  'London (UTC+0)': '🇬🇧',
                  'Tokyo (UTC+9)': '🇯🇵',
                  'New York (UTC-5)': '🇺🇸',
                  'IDR': '🇮🇩',
                  'USD': '🇺🇸',
                  'EUR': '🇪🇺',
                  'GBP': '🇬🇧',
                  'SGD': '🇸🇬',
                  'JPY': '🇯🇵',
                  'MYR': '🇲🇾',
                };
                final flag = flagMap[e.key] ?? '🌐';

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? _C.conversionBgFirst
                        : _C.conversionBgNormal,
                    borderRadius: BorderRadius.circular(10),
                    border: isFirst
                        ? Border.all(color: _C.conversionBorderFirst.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                              color: isFirst ? _C.conversionTextFirst : _C.conversionTextNormal,
                            )),
                      ),
                      Text(e.value,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isFirst ? _C.conversionValueFirst : _C.conversionValueNormal,
                          )),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────
  Widget _notch({required bool right}) {
    return Container(
      width: 18, height: 18,
      decoration: BoxDecoration(
        color: _C.paymentIconBg,
        borderRadius: BorderRadius.horizontal(
          left: right ? const Radius.circular(18) : Radius.zero,
          right: right ? Radius.zero : const Radius.circular(18),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _C.cardShadow.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }




  Widget _priceRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? _C.priceRowBold : _C.priceRowNormal)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: bold ? _C.priceRowBold : _C.priceRowBold)),
      ],
    );
  }

  Widget _posterFallback({double height = 108}) {
    return Container(
      width: 72, height: height,
      decoration: BoxDecoration(
        color: _C.posterFallbackBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.movie, color: _C.hint, size: 28),
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


class _C {
  _C._();
  // --- Background ---
  static const Color bg = AppColors.scaffoldBg;              // background halaman
  static const Color appBar = AppColors.navyPrimary;         // background AppBar (Struk)
  static const Color appBarCheckoutBg = Colors.white;        // background AppBar (Checkout)

  // --- Warna Aksen ---
  static const Color accent = AppColors.navyPrimary;         // warna aksen utama
  static const Color accentPrimary = AppColors.navyPrimary;
  static const Color accentSecondary = AppColors.navySecondary; // gradient secondary
  static const Color accentGold = AppColors.gold;

  // --- Tombol Bayar ---
  static const Color buttonBg = AppColors.gold;              // background tombol bayar
  static const Color buttonFg = AppColors.navyPrimary;       // teks tombol bayar

  // --- Harga & Diskon ---
  static const Color discountRed = Color(0xFFE53935);        // badge diskon (merah)
  static const Color priceGreen = Color(0xFF2ECC71);         // warna harga (hijau)

  // --- Metode Pembayaran ---
  static const Color colorGopay = AppColors.info;
  static const Color colorOvo = AppColors.deepPurple;
  static const Color colorShopeePay = AppColors.shopeeOrange;
  static const Color colorKredit = AppColors.fontGreen;
  static const Color paymentBg = Colors.white;
  static Color paymentBorder = _C.bg;
  static const Color paymentBorderSelected = AppColors.navyPrimary;
  static const Color paymentIconBg = AppColors.scaffoldBg;
  static const Color paymentIconColor = AppColors.fontGreyLight;
  static const Color paymentText = AppColors.fontGrey;
  static const Color paymentTextSelected = AppColors.navyPrimary;
  static Color paymentRadioOff = Colors.grey.shade300;

  // --- Summary & Card ---
  static const Color movieTitle = Colors.white;
  static const Color movieSubtitle = Colors.white70;
  static const Color bottomBarBg = Colors.white;
  static const Color bottomBarShadow = Colors.black;
  static const Color cardBg = Colors.white;
  static const Color cardShadow = Colors.black;
  static const Color priceRowBold = AppColors.navyPrimary;
  static const Color priceRowNormal = AppColors.fontGreyLight;
  static const Color posterFallbackBg = AppColors.lightPurpleBg;

  // --- Tiket Struk ---
  static const Color appBarStrukFg = Colors.white;
  static const Color ticketCardBg = Colors.white;
  static const Color ticketIdBorder = AppColors.gold;
  static const Color ticketTextMuted = Colors.white54;
  static const Color ticketTextMuted2 = Colors.white60;
  static const Color ticketTextLight = Colors.white;
  static Color ticketDashedLine = Colors.grey.shade200;
  static const Color barcodeLine = AppColors.navyPrimary;
  static const Color barcodeTransparent = Colors.transparent;

  // --- Konversi (Struk) ---
  static const Color conversionIcon = Colors.white70;
  static const Color conversionTitle = Colors.white;
  static Color conversionBgFirst = Colors.white.withValues(alpha: 0.12);
  static Color conversionBgNormal = Colors.white.withValues(alpha: 0.06);
  static const Color conversionBorderFirst = AppColors.gold;
  static const Color conversionTextFirst = AppColors.gold;
  static const Color conversionTextNormal = Colors.white70;
  static const Color conversionValueFirst = AppColors.gold;
  static const Color conversionValueNormal = Colors.white;

  // --- Teks ---
  static const Color hint = AppColors.fontGreyLight;         // warna hint
  static const Color subtitle = AppColors.fontGrey;          // warna subtitle
}
