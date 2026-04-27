import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';

// ============================================================
// DATA MODEL
// ============================================================
class CinemaInfo {
  final String name;
  final String brand;
  final String address;
  final double lat;
  final double lon;
  final double distKm;
  final double rating;
  final String? phone;
  final String? website;
  final Color color;
  final IconData icon;

  CinemaInfo({
    required this.name,
    required this.brand,
    required this.address,
    required this.lat,
    required this.lon,
    required this.distKm,
    required this.rating,
    this.phone,
    this.website,
    required this.color,
    required this.icon,
  });
}

// ============================================================
// DATABASE BIOSKOP JOGJA (Koordinat real dari Google Maps)
// Sumber: dataset_bioskop_jogja.xlsx
// ============================================================
final List<Map<String, dynamic>> _localCinemaDatabase = [
  {
    "name": "Sleman City Hall XXI",
    "lat": -7.7204818,
    "lon": 110.3628316,
    "addr": "Jl. Gito Gati, Denggung, Tridadi, Kec. Sleman",
    "rating": 4.6,
    "phone": "+62 21 1500210",
    "website": "http://www.21cineplex.com/",
  },
  {
    "name": "Jogja City Mall XXI",
    "lat": -7.7532573,
    "lon": 110.3610412,
    "addr": "Jl. Magelang No.KM. 6 No. 18, Lt. 2",
    "rating": 4.6,
    "phone": "+62 21 1500210",
    "website": "http://www.21cineplex.com/",
  },
  {
    "name": "Ambarrukmo XXI",
    "lat": -7.7830900,
    "lon": 110.4012330,
    "addr": "Plaza Ambarrukmo, Jl. Laksda Adisucipto KM 6.5, Lt. 3",
    "rating": 4.6,
    "phone": "+62 21 1500210",
    "website": "http://www.21cineplex.com/",
  },
  {
    "name": "Empire XXI",
    "lat": -7.7834061,
    "lon": 110.3868511,
    "addr": "Jl. Urip Sumoharjo No.104, Klitren, Gondokusuman",
    "rating": 4.7,
    "phone": "+62 21 1500210",
    "website": "http://www.21cineplex.com/",
  },
  {
    "name": "CGV Cinemas Transmart Maguwo",
    "lat": -7.7830154,
    "lon": 110.4198628,
    "addr": "Transmart Maguwo, Jl. Raya Solo KM.8 No.234",
    "rating": 4.6,
    "phone": "+62 21 29200100",
    "website": "https://www.cgv.id/",
  },
  {
    "name": "Cinépolis Lippo Plaza Jogja",
    "lat": -7.7841382,
    "lon": 110.3907692,
    "addr": "Lippo Plaza, Jl. Laksda Adisucipto No.32-34, Lt. 1 & 4",
    "rating": 4.5,
    "phone": "+62 274 2922833",
    "website": "http://cinepolis.co.id/",
  },
  {
    "name": "CGV Cinemas J-Walk Mall",
    "lat": -7.7725000,
    "lon": 110.4105000,
    "addr": "J-Walk Mall, Jl. Babarsari No.2, Lt. 3, Sleman",
    "rating": 4.4,
    "phone": "+62 21 29200100",
    "website": "https://www.cgv.id/",
  },
  {
    "name": "CGV Pakuwon Mall Jogja",
    "lat": -7.7588094,
    "lon": 110.3992739,
    "addr": "Pakuwon Mall, Jl. Ring Road Utara, Sleman",
    "rating": 4.7,
    "phone": "+62 21 29200100",
    "website": "https://www.cgv.id/",
  },
];

// ============================================================
// LBS PAGE
// ============================================================
class LbsPage extends StatefulWidget {
  const LbsPage({super.key});
  @override
  State<LbsPage> createState() => _LbsPageState();
}

class _LbsPageState extends State<LbsPage> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  List<Marker> _markers = [];
  List<Polyline> _routePolylines = [];
  bool _isLoading = true;
  bool _isRouteLoading = false;
  String _statusMessage = "Mencari Satelit...";
  List<CinemaInfo> _cinemas = [];
  List<CinemaInfo> _filteredCinemas = [];
  String _activeFilter = "Semua";
  CinemaInfo? _selectedCinema;
  String? _routeDistance;
  String? _routeDuration;

  // Radius setting (default 30km)
  double _radiusKm = 5;

  // Collapsible cinema list
  bool _listExpanded = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ============================================================
  // LOCATION
  // ============================================================
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _statusMessage = "GPS Mati. Nyalakan GPS Anda.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _statusMessage = "Izin lokasi ditolak.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _statusMessage = "Izin lokasi ditolak permanen.");
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    LatLng latLng = LatLng(pos.latitude, pos.longitude);

    if (mounted) {
      setState(() {
        _userLocation = latLng;
      });
      _mapController.move(latLng, 13);
      _loadCinemas(latLng);
    }
  }

  // ============================================================
  // LOAD CINEMAS (INSTANT dari database lokal)
  // ============================================================
  void _loadCinemas(LatLng center) {
    List<Marker> markers = [];
    List<CinemaInfo> tempList = [];

    // Marker lokasi user
    markers.add(Marker(
      point: center,
      width: 60,
      height: 60,
      child: const Icon(
        Icons.person_pin_circle,
        color: Color(0xFF00113A),
        size: 50,
      ),
    ));

    for (var item in _localCinemaDatabase) {
      double lat = item['lat'];
      double lon = item['lon'];
      String name = item['name'];
      String address = item['addr'];
      double rating = (item['rating'] as num).toDouble();
      String? phone = item['phone'];
      String? website = item['website'];

      double dist = Geolocator.distanceBetween(
          center.latitude, center.longitude, lat, lon) / 1000;

      // Filter berdasarkan radius
      if (dist > _radiusKm) continue;

      String upperName = name.toUpperCase();
      String brand = "Bioskop";
      Color pinColor = const Color(0xFFE53935);
      IconData pinIcon = Icons.local_movies;

      if (upperName.contains("XXI") || upperName.contains("EMPIRE")) {
        pinColor = const Color(0xFFFFA000);
        brand = "Cinema XXI";
        pinIcon = Icons.movie_filter;
      } else if (upperName.contains("CGV")) {
        pinColor = const Color(0xFFD32F2F);
        brand = "CGV Cinemas";
        pinIcon = Icons.theaters;
      } else if (upperName.contains("CINEPOLIS") || upperName.contains("CINÉPOLIS")) {
        pinColor = const Color(0xFF1976D2);
        brand = "Cinépolis";
        pinIcon = Icons.movie;
      }

      CinemaInfo cinema = CinemaInfo(
        name: name,
        brand: brand,
        address: address,
        lat: lat,
        lon: lon,
        distKm: dist,
        rating: rating,
        phone: phone,
        website: website,
        color: pinColor,
        icon: pinIcon,
      );
      tempList.add(cinema);
      markers.add(_buildCinemaMarker(cinema));
    }

    tempList.sort((a, b) => a.distKm.compareTo(b.distKm));

    if (mounted) {
      setState(() {
        _markers = markers;
        _cinemas = tempList;
        _filteredCinemas = tempList;
        _isLoading = false;
        _statusMessage = "${tempList.length} bioskop ditemukan";
      });
    }
  }

  // ============================================================
  // MARKER BUILDER
  // ============================================================
  Marker _buildCinemaMarker(CinemaInfo cinema) {
    return Marker(
      point: LatLng(cinema.lat, cinema.lon),
      width: 50,
      height: 65,
      child: GestureDetector(
        onTap: () => _showCinemaSheet(cinema),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cinema.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cinema.color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Icon(cinema.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
              ),
              child: Text(
                cinema.name.length > 15 ? '${cinema.name.substring(0, 15)}...' : cinema.name,
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: cinema.color),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RADIUS CIRCLE (untuk ditampilkan di map)
  // ============================================================
  List<LatLng> _buildRadiusCirclePoints(LatLng center, double radiusKm) {
    List<LatLng> points = [];
    const int segments = 72;
    double radiusMeters = radiusKm * 1000;

    for (int i = 0; i <= segments; i++) {
      double angle = (i * 360 / segments) * pi / 180;
      double latOffset = radiusMeters * cos(angle) / 111320;
      double lonOffset = radiusMeters * sin(angle) / (111320 * cos(center.latitude * pi / 180));
      points.add(LatLng(center.latitude + latOffset, center.longitude + lonOffset));
    }
    return points;
  }

  // ============================================================
  // FILTER
  // ============================================================
  void _applyFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      if (filter == "Semua") {
        _filteredCinemas = _cinemas;
      } else {
        _filteredCinemas =
            _cinemas.where((c) => c.brand.toUpperCase().contains(filter.toUpperCase())).toList();
      }
    });
  }

  // ============================================================
  // RADIUS SETTING DIALOG
  // ============================================================
  void _showRadiusDialog() {
    double tempRadius = _radiusKm;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.radar, color: Color(0xFF00113A)),
              SizedBox(width: 8),
              Text("Radius Pencarian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${tempRadius.round()} km",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00113A)),
              ),
              const SizedBox(height: 8),
              Slider(
                value: tempRadius,
                min: 5,
                max: 30,
                divisions: 25,
                activeColor: const Color(0xFF00113A),
                label: "${tempRadius.round()} km",
                onChanged: (val) {
                  setDialogState(() => tempRadius = val);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("5 km", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  Text("30 km", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Batal", style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _radiusKm = tempRadius;
                });
                if (_userLocation != null) {
                  _loadCinemas(_userLocation!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00113A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Terapkan"),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROUTE (OSRM)
  // ============================================================
  Future<void> _fetchRoute(CinemaInfo cinema) async {
    if (_userLocation == null) return;
    setState(() {
      _isRouteLoading = true;
      _selectedCinema = cinema;
    });

    String url =
        "https://router.project-osrm.org/route/v1/driving/"
        "${_userLocation!.longitude},${_userLocation!.latitude};"
        "${cinema.lon},${cinema.lat}"
        "?overview=full&geometries=geojson";

    try {
      var response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var route = data['routes'][0];
        var geometry = route['geometry']['coordinates'] as List;
        double distance = (route['distance'] as num).toDouble();
        double duration = (route['duration'] as num).toDouble();

        List<LatLng> points =
            geometry.map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();

        if (mounted) {
          setState(() {
            _routePolylines = [
              Polyline(
                points: points,
                strokeWidth: 5,
                color: const Color(0xFF00113A),
                borderStrokeWidth: 2,
                borderColor: const Color(0xFF00113A).withValues(alpha: 0.3),
              ),
            ];
            _routeDistance = (distance / 1000).toStringAsFixed(1);
            _routeDuration = _formatDuration(duration);
            _isRouteLoading = false;
          });

          var bounds = LatLngBounds.fromPoints([_userLocation!, LatLng(cinema.lat, cinema.lon)]);
          _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
        }
      } else {
        if (mounted) setState(() => _isRouteLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRouteLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memuat rute. Coba lagi.")),
        );
      }
    }
  }

  String _formatDuration(double seconds) {
    int mins = (seconds / 60).round();
    if (mins < 60) return "$mins mnt";
    int hours = mins ~/ 60;
    int remMins = mins % 60;
    return "$hours jam $remMins mnt";
  }

  void _clearRoute() {
    setState(() {
      _routePolylines = [];
      _selectedCinema = null;
      _routeDistance = null;
      _routeDuration = null;
    });
    if (_userLocation != null) _mapController.move(_userLocation!, 13);
  }

  // ============================================================
  // CINEMA BOTTOM SHEET
  // ============================================================
  void _showCinemaSheet(CinemaInfo cinema) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CinemaDetailSheet(
        cinema: cinema,
        onRoute: () {
          Navigator.pop(ctx);
          _fetchRoute(cinema);
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Bioskop Terdekat",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF00113A),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: const Color(0xFF00113A),
        actions: [
          // Radius setting
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.radar, color: Colors.white, size: 22),
            ),
            tooltip: "Atur Radius",
            onPressed: _showRadiusDialog,
          ),
          // AR View Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.explore, color: Colors.white, size: 22),
            ),
            tooltip: "AR Direction View",
            onPressed: (_cinemas.isEmpty || _userLocation == null)
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArDirectionPage(
                          userLocation: _userLocation!,
                          cinemas: _cinemas.take(10).toList(),
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Route info bar
          if (_selectedCinema != null && _routeDistance != null)
            _buildRouteInfoBar(),

          // Filter chips
          if (!_isLoading && _cinemas.isNotEmpty) _buildFilterBar(),

          // Map
          Expanded(
            flex: _listExpanded ? 3 : 6,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _userLocation ?? const LatLng(-7.77, 110.36),
                    initialZoom: 13,
                    onTap: (_, __) {
                      if (_selectedCinema != null) _clearRoute();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    ),
                    // Radius circle
                    if (_userLocation != null)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _buildRadiusCirclePoints(_userLocation!, _radiusKm),
                            color: const Color(0xFF00113A).withValues(alpha: 0.06),
                            borderColor: const Color(0xFF00113A).withValues(alpha: 0.35),
                            borderStrokeWidth: 2,
                            isFilled: true,
                          ),
                        ],
                      ),
                    if (_routePolylines.isNotEmpty)
                      PolylineLayer(polylines: _routePolylines),
                    MarkerLayer(markers: _markers),
                  ],
                ),

                // Zoom buttons (kiri atas)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _zoomButton(Icons.add, () {
                          final cam = _mapController.camera;
                          _mapController.move(cam.center, cam.zoom + 1);
                        }),
                        Container(height: 1, width: 32, color: Colors.grey.shade200),
                        _zoomButton(Icons.remove, () {
                          final cam = _mapController.camera;
                          _mapController.move(cam.center, cam.zoom - 1);
                        }),
                      ],
                    ),
                  ),
                ),

                // Radius badge (kiri bawah)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: GestureDetector(
                    onTap: _showRadiusDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar, size: 14, color: Color(0xFF00113A)),
                          const SizedBox(width: 4),
                          Text(
                            "${_radiusKm.round()} km",
                            style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00113A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // FABs (kanan bawah)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: "recenter",
                        backgroundColor: Colors.white,
                        onPressed: () {
                          if (_userLocation != null) {
                            _mapController.move(_userLocation!, 13);
                          }
                        },
                        child: const Icon(Icons.my_location, color: Color(0xFF00113A)),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "refresh",
                        backgroundColor: Colors.white,
                        onPressed: () {
                          if (_userLocation != null) {
                            _loadCinemas(_userLocation!);
                          }
                        },
                        child: const Icon(Icons.refresh, color: Color(0xFF00113A)),
                      ),
                    ],
                  ),
                ),

                // Loading overlay for route
                if (_isRouteLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(strokeWidth: 2),
                                SizedBox(width: 12),
                                Text("Menghitung rute..."),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Collapsible handle + Cinema list
          _buildCollapsibleList(),
        ],
      ),
    );
  }

  // ============================================================
  // ZOOM BUTTON WIDGET
  // ============================================================
  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: Colors.grey.shade700, size: 22),
      ),
    );
  }

  // ============================================================
  // COLLAPSIBLE LIST
  // ============================================================
  Widget _buildCollapsibleList() {
    return Expanded(
      flex: _listExpanded ? 2 : 0,
      child: Column(
        children: [
          // Handle bar untuk hide/unhide
          GestureDetector(
            onTap: () {
              setState(() => _listExpanded = !_listExpanded);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _listExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _listExpanded
                        ? "Sembunyikan (${_filteredCinemas.length})"
                        : "Tampilkan Bioskop (${_filteredCinemas.length})",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List content
          if (_listExpanded)
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFF00113A)),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _filteredCinemas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.movie_filter, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                "Tidak ada bioskop dalam radius ${_radiusKm.round()} km",
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _showRadiusDialog,
                                icon: const Icon(Icons.radar, size: 16),
                                label: const Text("Perbesar Radius"),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredCinemas.length,
                          itemBuilder: (ctx, i) {
                            var c = _filteredCinemas[i];
                            bool isSelected = _selectedCinema?.name == c.name;
                            return _buildCinemaCard(c, isSelected);
                          },
                        ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // UI COMPONENTS
  // ============================================================
  Widget _buildRouteInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF00113A),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCinema!.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "$_routeDistance km • $_routeDuration",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _clearRoute,
            child: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ["Semua", "XXI", "CGV", "Cinépolis"];
    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          bool active = _activeFilter == filters[i];
          return FilterChip(
            label: Text(filters[i], style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.grey.shade700,
            )),
            selected: active,
            onSelected: (_) => _applyFilter(filters[i]),
            selectedColor: const Color(0xFF00113A),
            backgroundColor: Colors.grey.shade100,
            side: BorderSide.none,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          );
        },
      ),
    );
  }

  Widget _buildCinemaCard(CinemaInfo c, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Color(0xFF00113A), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCinemaSheet(c),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: c.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(c.icon, color: c.color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(c.brand,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.color)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.star, size: 12, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text("${c.rating}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade700)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(c.address,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("${c.distKm.toStringAsFixed(1)} km",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00113A),
                    )),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _fetchRoute(c),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00113A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions, size: 14, color: Color(0xFF00113A)),
                          SizedBox(width: 2),
                          Text("Rute", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00113A))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CINEMA DETAIL BOTTOM SHEET
// ============================================================
class _CinemaDetailSheet extends StatelessWidget {
  final CinemaInfo cinema;
  final VoidCallback onRoute;

  const _CinemaDetailSheet({
    required this.cinema,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),

          // Header: icon, name, brand, rating, distance
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: cinema.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(cinema.icon, color: cinema.color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cinema.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cinema.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(cinema.brand, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cinema.color)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text("${cinema.rating}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text("${cinema.distKm.toStringAsFixed(1)} km",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00113A))),
                  Text("dari lokasi", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Alamat
          _infoRow(Icons.location_on, cinema.address),
          const SizedBox(height: 8),

          // Telp (jika ada)
          if (cinema.phone != null && cinema.phone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _infoRow(Icons.phone, cinema.phone!),
            ),

          // Website (jika ada)
          if (cinema.website != null && cinema.website!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _infoRow(Icons.language, cinema.website!),
            ),

          const SizedBox(height: 10),

          // Tombol rute
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRoute,
              icon: const Icon(Icons.route, size: 18),
              label: const Text("Lihat Rute di Peta"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00113A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AR DIRECTION PAGE (Compass-based)
// ============================================================
class ArDirectionPage extends StatefulWidget {
  final LatLng userLocation;
  final List<CinemaInfo> cinemas;

  const ArDirectionPage({
    super.key,
    required this.userLocation,
    required this.cinemas,
  });

  @override
  State<ArDirectionPage> createState() => _ArDirectionPageState();
}

class _ArDirectionPageState extends State<ArDirectionPage> {
  double _heading = 0;

  double _bearingTo(double lat, double lon) {
    double lat1 = widget.userLocation.latitude * pi / 180;
    double lat2 = lat * pi / 180;
    double dLon = (lon - widget.userLocation.longitude) * pi / 180;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("AR Direction", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00113A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Sensor kompas tidak tersedia\ndi perangkat ini.",
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 16), textAlign: TextAlign.center),
            );
          }

          if (!snapshot.hasData || snapshot.data?.heading == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00113A)),
                  SizedBox(height: 16),
                  Text("Mengkalibrasi kompas...\nGerakkan HP dalam pola angka 8",
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          _heading = snapshot.data!.heading!;

          return Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                flex: 3,
                child: Center(
                  child: SizedBox(
                    width: 320, height: 320,
                    child: CustomPaint(
                      painter: _CompassPainter(heading: _heading, cinemas: widget.cinemas, bearingFn: _bearingTo),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("Arahkan HP ke depan untuk melihat posisi bioskop",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 2,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.cinemas.length,
                  itemBuilder: (ctx, i) {
                    var c = widget.cinemas[i];
                    double bearing = _bearingTo(c.lat, c.lon);
                    double relative = (bearing - _heading + 360) % 360;
                    String direction = _getDirectionText(relative);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Transform.rotate(
                            angle: (bearing - _heading) * pi / 180,
                            child: Icon(Icons.navigation, color: c.color, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: const TextStyle(color: Color(0xFF00113A), fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text("${c.distKm.toStringAsFixed(1)} km • $direction",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: c.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("${bearing.toStringAsFixed(0)}°",
                                style: TextStyle(color: c.color, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
            ],
          );
        },
      ),
    );
  }

  String _getDirectionText(double relative) {
    if (relative < 22.5 || relative >= 337.5) return "Di Depan";
    if (relative < 67.5) return "Kanan Depan";
    if (relative < 112.5) return "Di Kanan";
    if (relative < 157.5) return "Kanan Belakang";
    if (relative < 202.5) return "Di Belakang";
    if (relative < 247.5) return "Kiri Belakang";
    if (relative < 292.5) return "Di Kiri";
    return "Kiri Depan";
  }
}

// ============================================================
// COMPASS RADAR PAINTER
// ============================================================
class _CompassPainter extends CustomPainter {
  final double heading;
  final List<CinemaInfo> cinemas;
  final double Function(double, double) bearingFn;

  _CompassPainter({required this.heading, required this.cinemas, required this.bearingFn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Circle rings - hitam agar terlihat di bg putih
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color.fromRGBO(0, 0, 0, 0.15)
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawCircle(center, radius * 0.7, circlePaint);
    canvas.drawCircle(center, radius * 0.4, circlePaint);

    // Cross lines - hitam
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color.fromRGBO(0, 0, 0, 0.08)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), linePaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), linePaint);

    // Cardinal directions - hitam, N tetap merah
    const directions = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      double angle = (i * 90 - heading) * pi / 180;
      double x = center.dx + (radius + 2) * sin(angle);
      double y = center.dy - (radius + 2) * cos(angle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: directions[i],
          style: TextStyle(
            color: directions[i] == 'N' ? const Color(0xFFFF5252) : const Color.fromRGBO(0, 0, 0, 0.6),
            fontSize: 14, fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }

    // Center dot
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF00113A));
    canvas.drawCircle(center, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

    // Cinema dots
    double maxDist = 0;
    for (var c in cinemas) {
      if (c.distKm > maxDist) maxDist = c.distKm;
    }
    if (maxDist == 0) maxDist = 1;

    for (var c in cinemas) {
      double bearing = bearingFn(c.lat, c.lon);
      double relAngle = (bearing - heading) * pi / 180;
      double distRatio = (c.distKm / maxDist).clamp(0.1, 0.9);
      double r = radius * distRatio;

      double x = center.dx + r * sin(relAngle);
      double y = center.dy - r * cos(relAngle);

      canvas.drawCircle(Offset(x, y), 7, Paint()..color = c.color);
      canvas.drawCircle(Offset(x, y), 10, Paint()..color = c.color.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      final textPainter = TextPainter(
        text: TextSpan(
          text: c.name.length > 12 ? '${c.name.substring(0, 12)}…' : c.name,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - textPainter.width / 2 - 3, y + 10, textPainter.width + 6, textPainter.height + 2), const Radius.circular(3)),
        Paint()..color = const Color.fromRGBO(0, 17, 58, 0.8),
      );
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + 11));
    }
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) => oldDelegate.heading != heading;
}