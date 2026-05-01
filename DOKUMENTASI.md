# CineGlobal - Dokumentasi Teknis & Alur Fitur

## Gambaran Umum

CineGlobal adalah aplikasi mobile bioskop berbasis Flutter dengan arsitektur **offline-first**. Data user tersimpan di **SQLite lokal**, data film dari **TMDB API**, chat AI via **Ollama lokal**.

---

## Struktur Project

| Path | Fungsi |
|---|---|
| `lib/main.dart` | Entry point, navigasi 4 tab, floating CineBot |
| `lib/theme/app_colors.dart` | Pusat warna seluruh UI (1 file) |
| `lib/models/ticket_models.dart` | Model: NowPlayingMovie, CinemaSchedule, TicketOrder |
| `lib/services/api_service.dart` | HTTP client ke TMDB API |
| `lib/services/database_helper.dart` | SQLite CRUD (users, tickets, watchlist, dll) |
| `lib/pages/login_page.dart` | Login + biometrik |
| `lib/pages/register_page.dart` | Registrasi akun |
| `lib/pages/home_page.dart` | Tab Film / Serial / Trending |
| `lib/pages/detail_page.dart` | Detail film + trailer + sensor accelerometer |
| `lib/pages/search_page.dart` | Pencarian film |
| `lib/pages/now_playing_page.dart` | Film now playing + booking |
| `lib/pages/film_detail_page.dart` | Pilih bioskop, jadwal, harga |
| `lib/pages/seat_selection_page.dart` | Pilih kursi (grid interaktif) |
| `lib/pages/checkout_struk_page.dart` | Pembayaran + struk digital |
| `lib/pages/profile_page.dart` | Profil, watchlist, riwayat |
| `lib/pages/cinebot_page.dart` | Chat AI (Ollama lokal) |
| `lib/pages/minigame_page.dart` | Quiz tebak film + shake sensor |
| `lib/pages/lbs_page.dart` | Peta bioskop + kompas AR |

---

## Database SQLite

File: [database_helper.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/services/database_helper.dart)

| Tabel | Kolom Utama | Fungsi |
|---|---|---|
| `users` | username, email, password_hash, biometric_enabled | Akun user |
| `user_session` | user_id, email, username, token | Auto-login session |
| `search_history` | query, searched_at | Riwayat pencarian |
| `cached_movies` | id, title, poster_path, vote_average | Cache offline |
| `chat_history` | role, content, created_at | Riwayat CineBot |
| `game_scores` | game_mode, score, total_questions | Highscore quiz |
| `ticket_history` | ticket_id, movie_title, cinema_name, seats, total_price | Tiket |
| `watchlist` | movie_id, title, poster_path | Film favorit |
| `comments` | movie_id, user_id, username, content | Review film |

---

## Alur Fitur Detail

### 1. Login Manual (SHA-256)

**File:** [login_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/login_page.dart) **line 57-116**

Proses login di method `_login()`:

```dart
// login_page.dart — line 57-96
void _login() async {
    setState(() => _isLoading = true);
    try {
      // 1. Verifikasi username + SHA-256(password) di SQLite
      final user = await DatabaseHelper.instance.loginUser(
        _userCtrl.text.trim(),
        _passCtrl.text,
      );
      if (user == null) throw 'Username atau Password salah';

      // 2. Print hash untuk debugging
      final passwordHash = DatabaseHelper.hashPassword(_passCtrl.text);
      debugPrint("SHA-256 Hash: $passwordHash");

      // 3. Simpan session ke SQLite
      await DatabaseHelper.instance.saveSession(
        user['id'].toString(),
        user['email'] as String,
        user['username'] as String,
        '',
      );

      // 4. Simpan kredensial untuk biometric
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bio_username', _userCtrl.text.trim());
      await prefs.setString('bio_password', _passCtrl.text);
    }
}
```

**Alur:**
1. User ketik username + password
2. `DatabaseHelper.loginUser()` → hash password dengan SHA-256 → cocokkan dengan tabel `users`
3. Jika cocok → simpan session ke tabel `user_session` dan `SharedPreferences`
4. Credential juga disimpan untuk biometric login nanti
5. Navigasi ke `MainPage`

---

### 2. Login Biometrik (Sidik Jari)

**File:** [login_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/login_page.dart) **line 30-52** (cek) + **line 122-153** (proses)

Cek ketersediaan biometrik saat halaman dibuka:

```dart
// login_page.dart — line 30-46
Future<void> _checkBiometric() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('bio_username');

    // Cek apakah user sudah enable biometric di profile
    bool bioEnabled = false;
    if (savedUser != null && savedUser.isNotEmpty) {
      bioEnabled = await DatabaseHelper.instance.isBiometricEnabled(savedUser);
    }
    setState(() {
      _biometricAvailable = canCheck && isDeviceSupported;
      _hasSavedCredentials = savedUser != null && bioEnabled;
    });
}
```

Proses autentikasi sidik jari:

```dart
// login_page.dart — line 142-159
// Tampilkan dialog sidik jari
final authenticated = await _localAuth.authenticate(
    localizedReason: 'Tempelkan sidik jari Anda untuk login CineGlobal',
    options: const AuthenticationOptions(
      biometricOnly: false,
      stickyAuth: true,
    ),
);
if (!authenticated) return;

// Biometric berhasil — ambil kredensial tersimpan
final prefs = await SharedPreferences.getInstance();
final savedUser = prefs.getString('bio_username');
final savedPass = prefs.getString('bio_password');
```

**Alur:**
1. `_checkBiometric()` → cek device support + cek apakah ada credential tersimpan + cek biometric enabled di DB
2. Jika semua OK → tampilkan tombol sidik jari di halaman login
3. Tap tombol → `_localAuth.authenticate()` → dialog sidik jari muncul
4. Berhasil → ambil credential dari `SharedPreferences` → login otomatis ke SQLite

---

### 3. Sensor Accelerometer (Parallax Poster)

**File:** [detail_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/detail_page.dart) **line 31-42**

```dart
// detail_page.dart — line 31-42
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
```

**Alur:**
1. `initState()` subscribe ke `accelerometerEvents` dari package `sensors_plus`
2. Setiap event → simpan nilai `_x` (kiri-kanan) dan `_y` (depan-belakang)
3. Nilai ini digunakan untuk menggeser posisi poster film → efek parallax 3D
4. Miringkan HP ke kiri → poster bergeser ke kiri, dst
5. `dispose()` di line 58 membatalkan subscription agar tidak memory leak

---

### 4. Detail Film + Trailer YouTube

**File:** [detail_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/detail_page.dart) **line 65-100** + [api_service.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/services/api_service.dart) **line 9-38**

```dart
// api_service.dart — line 9-30
Future<Map<String, dynamic>> getDetail(int id, String type) async {
    // 1. Coba bahasa Indonesia dulu
    final resIndo = await http.get(Uri.parse(
        "$baseUrl/$type/$id?api_key=$apiKey&language=id-ID&append_to_response=videos,credits"));
    if (resIndo.statusCode == 200) {
      final dataIndo = json.decode(resIndo.body);

      // 2. Jika sinopsis atau video kosong → fallback ke Inggris
      bool overviewEmpty = dataIndo['overview']?.toString().isEmpty ?? true;
      bool videosEmpty = (dataIndo['videos']['results'] as List).isEmpty;

      if (overviewEmpty || videosEmpty) {
        final resEng = await http.get(Uri.parse("$baseUrl/$type/$id?api_key=$apiKey&append_to_response=videos,credits"));
        if (resEng.statusCode == 200) {
          final dataEng = json.decode(resEng.body);
          if (overviewEmpty) dataIndo['overview'] = dataEng['overview'];
          if (videosEmpty) dataIndo['videos'] = dataEng['videos'];
        }
      }
      return dataIndo;
    }
}
```

Pencarian trailer YouTube:

```dart
// detail_page.dart — line 70-89
String? videoKey;
final List videos = data['videos']['results'];
// Cari Trailer dulu
for (var v in videos) {
    if (v['site'] == 'YouTube' && v['type'] == 'Trailer') {
      videoKey = v['key'];
      break;
    }
}
// Fallback ke Teaser jika Trailer tidak ada
if (videoKey == null) {
    for (var v in videos) {
      if (v['site'] == 'YouTube' && v['type'] == 'Teaser') {
        videoKey = v['key'];
        break;
      }
    }
}
```

**Alur:**
1. Request TMDB dengan `append_to_response=videos,credits` (1 request dapat semuanya)
2. Prioritas bahasa Indonesia → fallback Inggris jika sinopsis kosong
3. Dari `videos.results` → cari yang `site=="YouTube"` dan `type=="Trailer"`
4. Jika tidak ada trailer → cari `type=="Teaser"` sebagai fallback
5. Key YouTube → load ke `YoutubePlayerController`

---

### 5. Watchlist (Simpan Film Favorit)

**File:** [detail_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/detail_page.dart) **line 131-136**

```dart
// detail_page.dart — line 131-136
void _checkWatchlistStatus() async {
    if (_userId == null) return;
    final inList = await DatabaseHelper.instance.isInWatchlist(_userId!, widget.id);
    if (mounted) setState(() => isWatchlisted = inList);
}
```

**Alur:**
1. Saat detail page dibuka → cek tabel `watchlist` apakah film sudah ada
2. Tap icon bookmark → `addToWatchlist()` atau `removeFromWatchlist()`
3. Data tersimpan di SQLite lokal per user

---

### 6. CineBot AI (Ollama + TMDB Context)

**File:** [cinebot_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/cinebot_page.dart)

Cek koneksi ke Ollama (line 71-87):

```dart
// cinebot_page.dart — line 71-86
Future<void> _checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_ollamaUrl/api/tags')
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final models = (data['models'] as List?)
            ?.map((m) => m['name'] as String).toList() ?? [];
        setState(() {
          _isConnected = true;
          _availableModels.clear();
          _availableModels.addAll(models);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isConnected = false);
    }
}
```

Konteks TMDB otomatis (line 100-200) — CineBot otomatis cari data film dari TMDB berdasarkan keyword user:

```dart
// cinebot_page.dart — line 126-167
// Deteksi genre dari pertanyaan user
if (q.contains('action')) {
    url = '$_tmdbBase/discover/movie?with_genres=28&sort_by=popularity.desc';
    label = 'Film Action Populer';
} else if (q.contains('horror') || q.contains('horor')) {
    url = '$_tmdbBase/discover/movie?with_genres=27';
    label = 'Film Horror Populer';
} else if (q.contains('harga') || q.contains('tiket')) {
    // Untuk pertanyaan harga → data hardcoded
    return '\n[DATA HARGA TIKET BIOSKOP INDONESIA 2026]\n'
        '• CGV Regular: Rp 40.000 - Rp 50.000\n'
        '• XXI Regular: Rp 35.000 - Rp 50.000\n';
} else {
    // Cari film spesifik dari TMDB
    final searchUrl = '$_tmdbBase/search/movie?query=${Uri.encodeComponent(query)}';
    // ... fetch + parse
}
```

**Alur lengkap:**
1. App start → `_checkConnection()` ping `GET /api/tags` ke Ollama
2. User ketik pesan → `_sendMessage()`
3. Sistem analisa keyword → otomatis fetch data TMDB yang relevan
4. Data TMDB dijadikan context tambahan untuk Ollama
5. Build payload: `{ model: "gemma3:1b", messages: [system, context, ...history, user] }`
6. POST ke `http://{PC_IP}:11434/api/chat` → terima response
7. Simpan ke tabel `chat_history` → tampilkan bubble

---

### 7. MiniGame - Shake to Skip (Gyroscope)

**File:** [minigame_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/minigame_page.dart) **line 37-88**

Variabel dan threshold:

```dart
// minigame_page.dart — line 37-40
StreamSubscription? _gyroSub;
DateTime _lastShake = DateTime.now();
static const double _shakeThreshold = 8.0;
```

Inisialisasi sensor gyroscope:

```dart
// minigame_page.dart — line 75-88
void _initGyroscope() {
    try {
      _gyroSub = gyroscopeEventStream().listen((GyroscopeEvent event) {
        if (!_gameStarted || _gameOver || _selectedAnswer != null) return;

        // Hitung magnitude goyangan
        double magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z
        );

        // Jika goyangan > threshold dan cooldown 1.5 detik
        if (magnitude > _shakeThreshold &&
            DateTime.now().difference(_lastShake).inMilliseconds > 1500) {
          _lastShake = DateTime.now();
          _skipQuestion();  // Skip soal!
        }
      });
    } catch (_) {
      // Gyroscope not available (web/emulator)
    }
}
```

**Alur:**
1. `_initGyroscope()` subscribe ke `gyroscopeEventStream()` dari `sensors_plus`
2. Setiap event → hitung magnitude: `sqrt(x² + y² + z²)`
3. Jika magnitude > 8.0 (threshold) DAN sudah lewat 1.5 detik dari shake terakhir
4. → trigger `_skipQuestion()` → loncat ke soal berikutnya
5. User punya 2 skip gratis (`_skipsLeft = 2`)
6. Goyangkan HP → soal terlewati tanpa sentuh layar

---

### 8. LBS - GPS Lokasi User

**File:** [lbs_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/lbs_page.dart) **line 160-192**

```dart
// lbs_page.dart — line 160-191
Future<void> _getCurrentLocation() async {
    // 1. Cek GPS nyala
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = "GPS Mati. Nyalakan GPS Anda.");
      return;
    }

    // 2. Cek & minta izin lokasi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 3. Ambil posisi GPS
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    LatLng latLng = LatLng(pos.latitude, pos.longitude);

    setState(() => _userLocation = latLng);
    _mapController.move(latLng, 13);  // Pindahkan peta ke lokasi user
    _loadCinemas(latLng);  // Hitung jarak ke semua bioskop
}
```

### 9. LBS - Hitung Jarak ke Bioskop

**File:** [lbs_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/lbs_page.dart) **line 197-245**

```dart
// lbs_page.dart — line 222-226
// Hitung jarak user ke bioskop (meter → km)
double dist = Geolocator.distanceBetween(
    center.latitude, center.longitude, lat, lon
) / 1000;

// Filter: hanya tampilkan bioskop dalam radius
if (dist > _radiusKm) continue;
```

Deteksi brand bioskop berdasarkan nama:

```dart
// lbs_page.dart — line 233-245
if (upperName.contains("XXI") || upperName.contains("EMPIRE")) {
    pinColor = AppColors.ratingGold;  // Kuning
    brand = "Cinema XXI";
} else if (upperName.contains("CGV")) {
    pinColor = AppColors.error;  // Merah
    brand = "CGV Cinemas";
} else if (upperName.contains("CINEPOLIS")) {
    pinColor = AppColors.info;  // Biru
    brand = "Cinépolis";
}
```

**Alur:**
1. GPS ambil posisi user → `Geolocator.getCurrentPosition()`
2. Loop 8 bioskop Jogja (hardcoded line 46-113) → hitung jarak masing-masing
3. Filter berdasarkan radius slider (default 5km)
4. Buat marker warna berbeda per brand → tampilkan di peta

---

### 10. LBS - Routing OSRM

**File:** [lbs_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/lbs_page.dart) **line 433-470**

```dart
// lbs_page.dart — line 433-458
Future<void> _fetchRoute(CinemaInfo cinema) async {
    String url =
        "https://router.project-osrm.org/route/v1/driving/"
        "${_userLocation!.longitude},${_userLocation!.latitude};"
        "${cinema.lon},${cinema.lat}"
        "?overview=full&geometries=geojson";

    var response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      var route = data['routes'][0];
      var geometry = route['geometry']['coordinates'] as List;
      double distance = route['distance'];  // meter
      double duration = route['duration'];  // detik

      // Konversi koordinat GeoJSON [lon,lat] → LatLng(lat,lon)
      List<LatLng> points = geometry
          .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();

      // Gambar polyline di peta
      _routePolylines = [
        Polyline(points: points, strokeWidth: 5, color: AppColors.navyPrimary),
      ];
    }
}
```

**Alur:**
1. User tap "Rute" pada bottom sheet bioskop
2. Request ke OSRM: `GET /route/v1/driving/{lon1},{lat1};{lon2},{lat2}?geometries=geojson`
3. Response berisi array koordinat polyline + jarak (meter) + durasi (detik)
4. Koordinat GeoJSON `[lon,lat]` dikonversi ke `LatLng(lat,lon)`
5. Gambar polyline biru di peta + tampilkan info jarak & waktu tempuh

---

### 11. LBS - Kompas AR Direction

**File:** [lbs_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/lbs_page.dart) **line 1224-1246**

Hitung bearing (arah) dari user ke bioskop:

```dart
// lbs_page.dart — line 1224-1232
double _bearingTo(double lat, double lon) {
    double lat1 = widget.userLocation.latitude * pi / 180;
    double lat2 = lat * pi / 180;
    double dLon = (lon - widget.userLocation.longitude) * pi / 180;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;  // Normalisasi ke 0-360 derajat
}
```

Sensor kompas:

```dart
// lbs_page.dart — line 1245-1247
body: StreamBuilder<CompassEvent>(
    stream: FlutterCompass.events,
    builder: (context, snapshot) {
      // snapshot.data.heading = arah utara dalam derajat
```

**Alur:**
1. `FlutterCompass.events` → stream data kompas real-time
2. `heading` = derajat HP menghadap relatif ke utara (0-360)
3. `_bearingTo()` → hitung arah bioskop dari user menggunakan rumus Haversine
4. Selisih `bearing - heading` = arah panah yang harus ditampilkan
5. Putar HP → panah selalu menunjuk ke arah bioskop

---

### 12. Booking Tiket (4 Step)

**Step 1** — [now_playing_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/now_playing_page.dart):
- Fetch `GET /movie/now_playing` dari TMDB → daftar film → tap untuk booking

**Step 2** — [film_detail_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/film_detail_page.dart):
- 8 bioskop Jogja (hardcoded di `ticket_models.dart`)
- Pilih: bioskop → studio type (Regular/IMAX/4DX) → jam tayang → tanggal
- Klik "Pilih Kursi" → buat `TicketOrder`

**Step 3** — [seat_selection_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/seat_selection_page.dart):
- Grid kursi 8×10 (A1-H10)
- Status: `0`=tersedia, `1`=terisi, `3`=dipilih user
- 30-50% kursi terisi random (simulasi)
- Total = jumlah kursi × harga

**Step 4** — [checkout_struk_page.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/pages/checkout_struk_page.dart):
- Ringkasan + diskon random 10-30%
- Pilih pembayaran (GoPay/OVO/DANA/ShopeePay/Bank/CC)
- Bayar → `DatabaseHelper.saveTicket()` → struk + notification

---

## Sensor yang Digunakan

| Sensor | Package | File (Line) | Fungsi |
|---|---|---|---|
| Accelerometer | `sensors_plus` | `detail_page.dart` (L40-41) | Parallax poster 3D |
| Gyroscope | `sensors_plus` | `minigame_page.dart` (L75-88) | Shake to Skip soal |
| GPS | `geolocator` | `lbs_page.dart` (L180-182) | Lokasi user di peta |
| Kompas | `flutter_compass` | `lbs_page.dart` (L1245-1246) | AR Direction bioskop |
| Fingerprint | `local_auth` | `login_page.dart` (L143-149) | Login sidik jari |

---

## API yang Digunakan

| API | Endpoint | File (Line) | Kegunaan |
|---|---|---|---|
| TMDB | `GET /discover/movie` | `api_service.dart` (L49) | Film 2026 |
| TMDB | `GET /{type}/{id}?append_to_response=videos,credits` | `api_service.dart` (L12-13) | Detail + trailer |
| TMDB | `GET /search/multi` | `search_page.dart` | Pencarian film |
| TMDB | `GET /movie/now_playing` | `now_playing_page.dart` | Film sedang tayang |
| Ollama | `POST /api/chat` | `cinebot_page.dart` | Chat AI |
| Ollama | `GET /api/tags` | `cinebot_page.dart` (L73) | Cek koneksi + list model |
| OSRM | `GET /route/v1/driving/...` | `lbs_page.dart` (L441-444) | Rute peta |

---

## Centralized Theme

File: [app_colors.dart](file:///d:/Code/Project1/Project%20Mobile/cineglobal/lib/theme/app_colors.dart)

Ubah warna 1 baris → seluruh app berubah:

```dart
static const Color navyPrimary = Color(0xFF1565C0);  // ganti navy ke biru
static const Color cinebotFabIcon = Colors.red;       // ganti icon CineBot
static const Color fontCinebotTitle = Colors.amber;   // ganti teks "CineBot"
```

---

## Cara Menjalankan

```bash
flutter pub get
flutter run
```

CineBot AI → `ollama serve` di PC, pastikan IP di `cinebot_page.dart` line 22 sesuai.

## Extract Database

```bash
cmd /c "C:\Android\sdk\platform-tools\adb.exe exec-out run-as com.example.cineglobal cat databases/cineglobal.db > D:\cineglobal.db"
```

> [!WARNING]
> Gunakan `cmd /c`, bukan PowerShell langsung — menghindari BOM encoding yang merusak file SQLite.
