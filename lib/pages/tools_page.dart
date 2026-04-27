import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'cinebot_page.dart';
import 'minigame_page.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});
  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // === TAB 1: Waktu Premiere Global ===
  String _timeWIB = "", _timeWITA = "", _timeWIT = "";
  String _timeLondon = "", _timeLA = "", _timeTokyo = "";
  late Timer _timer;
  
  // === TAB 2: Konversi Mata Uang ===
  final TextEditingController _currencyController = TextEditingController();
  String _fromCurrency = 'USD';
  double _inputAmount = 0;
  Map<String, double> _convertedValues = {};
  
  // Kurs terhadap IDR (contoh kurs)
  final Map<String, double> _exchangeRates = {
    'IDR': 1.0,
    'USD': 15800.0,    // 1 USD = 15800 IDR
    'EUR': 17200.0,    // 1 EUR = 17200 IDR
    'GBP': 20000.0,    // 1 GBP = 20000 IDR
    'JPY': 105.0,      // 1 JPY = 105 IDR
    'CNY': 2200.0,     // 1 CNY = 2200 IDR
    'KRW': 11.8,       // 1 KRW = 11.8 IDR
  };
  
  final Map<String, String> _currencyNames = {
    'IDR': '🇮🇩 Rupiah Indonesia',
    'USD': '🇺🇸 US Dollar',
    'EUR': '🇪🇺 Euro',
    'GBP': '🇬🇧 Pound Sterling',
    'JPY': '🇯🇵 Japanese Yen',
    'CNY': '🇨🇳 Chinese Yuan',
    'KRW': '🇰🇷 Korean Won',
  };
  
  // Harga tiket bioskop di berbagai negara (dalam mata uang lokal)
  final List<Map<String, dynamic>> _ticketPrices = [
    {'country': '🇺🇸 USA (AMC)', 'currency': 'USD', 'price': 15.0, 'type': 'Standard'},
    {'country': '🇬🇧 UK (Odeon)', 'currency': 'GBP', 'price': 12.5, 'type': 'Standard'},
    {'country': '🇯🇵 Japan (TOHO)', 'currency': 'JPY', 'price': 1900.0, 'type': 'Standard'},
    {'country': '🇰🇷 Korea (CGV)', 'currency': 'KRW', 'price': 15000.0, 'type': 'Standard'},
    {'country': '🇨🇳 China (Wanda)', 'currency': 'CNY', 'price': 45.0, 'type': 'Standard'},
    {'country': '🇪🇺 Europe (Vue)', 'currency': 'EUR', 'price': 13.0, 'type': 'Standard'},
    {'country': '🇺🇸 USA IMAX', 'currency': 'USD', 'price': 25.0, 'type': 'IMAX'},
    {'country': '🇯🇵 Japan IMAX', 'currency': 'JPY', 'price': 2600.0, 'type': 'IMAX'},
  ];
  
  // === TAB 3: Estimasi Selesai ===
  TimeOfDay _startTime = const TimeOfDay(hour: 19, minute: 0);
  int _duration = 120;
  final int _previewTime = 15;
  String _endTimeResult = "21:15";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
    _calculateEndTime();
    _convertCurrency();
  }

  @override
  void dispose() {
    _timer.cancel();
    _tabController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  // === FUNGSI TAB 1: Update Waktu ===
  void _updateTime() {
    final now = DateTime.now().toUtc();
    final format = DateFormat('HH:mm:ss');
    
    if(mounted) {
      setState(() {
        _timeWIB = format.format(now.add(const Duration(hours: 7)));
        _timeWITA = format.format(now.add(const Duration(hours: 8)));
        _timeWIT = format.format(now.add(const Duration(hours: 9)));
        _timeLondon = format.format(now);
        _timeLA = format.format(now.subtract(const Duration(hours: 8)));
        _timeTokyo = format.format(now.add(const Duration(hours: 9)));
      });
    }
  }

  // === FUNGSI TAB 2: Konversi Mata Uang ===
  void _convertCurrency() {
    double amountInIDR;
    
    // Konversi input ke IDR terlebih dahulu
    if (_fromCurrency == 'IDR') {
      amountInIDR = _inputAmount;
    } else {
      amountInIDR = _inputAmount * _exchangeRates[_fromCurrency]!;
    }
    
    // Konversi dari IDR ke semua mata uang lain
    Map<String, double> results = {};
    _exchangeRates.forEach((currency, rate) {
      if (currency != _fromCurrency) {
        results[currency] = amountInIDR / rate;
      }
    });
    
    setState(() => _convertedValues = results);
  }
  
  // Konversi harga tiket ke IDR
  double _convertToIDR(String currency, double amount) {
    return amount * _exchangeRates[currency]!;
  }

  // === FUNGSI TAB 3: Estimasi Selesai ===
  void _calculateEndTime() {
    int totalMinutes = _startTime.hour * 60 + _startTime.minute;
    totalMinutes += _duration + _previewTime;
    
    int endHour = (totalMinutes ~/ 60) % 24;
    int endMinute = totalMinutes % 60;
    
    setState(() {
      _endTimeResult = "${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      _calculateEndTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎬 Cinema Tools", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF00113A),
        foregroundColor: Colors.white,
        surfaceTintColor: const Color(0xFF00113A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFCD400),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFCD400),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.schedule_rounded), text: "Waktu"),
            Tab(icon: Icon(Icons.currency_exchange), text: "Mata Uang"),
            Tab(icon: Icon(Icons.timer_outlined), text: "Durasi"),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Quick Access: CineBot & MiniGame ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CinebotPage())),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00113A), Color(0xFFFCD400)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFF00113A).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Row(children: [
                          Icon(Icons.smart_toy, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("CineBot AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("Chat asisten film", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ])),
                          Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MinigamePage())),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Row(children: [
                          Icon(Icons.quiz, color: Colors.white, size: 28),
                          SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("CineQuiz", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text("Mini game film", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ])),
                          Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // ── Existing TabBarView ──
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPremiereTimeTab(),
                  _buildCurrencyConverterTab(),
                  _buildEndTimeTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // TAB 1: WAKTU PREMIERE GLOBAL
  // =============================================
  Widget _buildPremiereTimeTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("🌍 Konversi Waktu Global", 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text("Waktu premiere film realtime di berbagai kota", 
          style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),
        
        _buildSectionHeader("🇮🇩 Indonesia"),
        _buildClockCard("Jakarta (WIB)", _timeWIB, Icons.location_city, Colors.blue, "UTC+7"),
        _buildClockCard("Makassar (WITA)", _timeWITA, Icons.location_city, Colors.teal, "UTC+8"),
        _buildClockCard("Jayapura (WIT)", _timeWIT, Icons.location_city, Colors.indigo, "UTC+9"),
        
        const SizedBox(height: 20),
        _buildSectionHeader("🌏 Internasional"),
        _buildClockCard("London (UK)", _timeLondon, Icons.theater_comedy, Colors.redAccent, "UTC+0"),
        _buildClockCard("Hollywood (LA)", _timeLA, Icons.movie_filter, Colors.purple, "UTC-8"),
        _buildClockCard("Tokyo (Japan)", _timeTokyo, Icons.animation, Colors.pink, "UTC+9"),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildClockCard(String city, String time, IconData icon, Color color, String utc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(utc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(time, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  // =============================================
  // TAB 2: KONVERSI MATA UANG + HARGA TIKET GLOBAL
  // =============================================
  Widget _buildCurrencyConverterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("💰 Konversi Mata Uang", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Bandingkan harga tiket bioskop di seluruh dunia", 
            style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 25),
          
          // === SECTION: Harga Tiket Premier di Seluruh Dunia ===
          const Text("🎟️ Harga Tiket Bioskop Global", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text("Tap untuk konversi ke Rupiah", style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 15),
          
          ..._ticketPrices.map((ticket) => _buildTicketPriceCard(ticket)),
          
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 20),
          
          // === SECTION: Input Manual ===
          const Text("✏️ Konversi Manual", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Dari Mata Uang", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Dropdown Pilih Mata Uang
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _fromCurrency,
                      isExpanded: true,
                      items: _currencyNames.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _fromCurrency = val!);
                        _convertCurrency();
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Input Jumlah
                TextField(
                  controller: _currencyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00113A)),
                  decoration: InputDecoration(
                    labelText: "Masukkan Jumlah",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: const Icon(Icons.calculate, color: Color(0xFF00113A)),
                  ),
                  onChanged: (val) {
                    _inputAmount = double.tryParse(val.replaceAll(',', '')) ?? 0;
                    _convertCurrency();
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Hasil Konversi Manual
          if (_inputAmount > 0) ...[
            const Text("📊 Hasil Konversi", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            ..._convertedValues.entries.map((entry) {
              return _buildCurrencyResultCard(entry.key, entry.value);
            }),
          ],
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildTicketPriceCard(Map<String, dynamic> ticket) {
    double priceInIDR = _convertToIDR(ticket['currency'], ticket['price']);
    String originalPrice = ticket['currency'] == 'JPY' || ticket['currency'] == 'KRW'
        ? '${ticket['price'].toStringAsFixed(0)} ${ticket['currency']}'
        : '${ticket['price'].toStringAsFixed(2)} ${ticket['currency']}';
    
    bool isIMAX = ticket['type'] == 'IMAX';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isIMAX ? Border.all(color: Colors.amber, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isIMAX ? Colors.amber.shade100 : const Color(0xFF00113A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isIMAX ? Icons.hd : Icons.local_movies,
            color: isIMAX ? Colors.amber.shade800 : const Color(0xFF00113A),
          ),
        ),
        title: Text(ticket['country'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(originalPrice, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(priceInIDR),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00113A), fontSize: 14),
            ),
            if (isIMAX)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text("IMAX", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        onTap: () {
          // Set nilai ke input manual saat di-tap
          setState(() {
            _fromCurrency = ticket['currency'];
            _inputAmount = ticket['price'];
            _currencyController.text = ticket['price'].toString();
          });
          _convertCurrency();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${ticket['country']} = ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(priceInIDR)}"),
              backgroundColor: const Color(0xFF00113A),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildCurrencyResultCard(String currency, double value) {
    String formattedValue;
    if (currency == 'IDR') {
      formattedValue = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(value);
    } else if (currency == 'JPY' || currency == 'KRW') {
      formattedValue = NumberFormat.currency(symbol: '', decimalDigits: 0).format(value);
    } else {
      formattedValue = NumberFormat.currency(symbol: '', decimalDigits: 2).format(value);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_currencyNames[currency] ?? currency, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(formattedValue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00113A))),
        ],
      ),
    );
  }

  // =============================================
  // TAB 3: ESTIMASI WAKTU SELESAI NONTON
  // =============================================
  Widget _buildEndTimeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("⏱️ Estimasi Selesai Nonton", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Hitung kapan film selesai untuk rencana setelah nonton", 
            style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 25),
          
          // Jam Mulai
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Jam Mulai Film", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickStartTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF00113A)),
                        const SizedBox(width: 10),
                        Text(
                          _startTime.format(context),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Durasi Film
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Durasi Film (menit)", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Slider(
                  value: _duration.toDouble(),
                  min: 60,
                  max: 240,
                  divisions: 36,
                  activeColor: const Color(0xFF00113A),
                  label: "$_duration menit",
                  onChanged: (val) {
                    setState(() => _duration = val.toInt());
                    _calculateEndTime();
                  },
                ),
                Center(
                  child: Text("${_duration ~/ 60} jam ${_duration % 60} menit", 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Preview/Iklan
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Waktu Iklan & Preview", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Ditambahkan otomatis", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("+$_previewTime menit", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Hasil
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00113A), Color(0xFF65C7F7)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text("🎬 Film Selesai Sekitar", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 10),
                Text(
                  _endTimeResult,
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 10),
                Text(
                  "Total durasi: ${_duration + _previewTime} menit",
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}