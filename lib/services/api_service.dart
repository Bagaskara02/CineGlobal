import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String apiKey = "276b3a68ef2888c401b69fc9f9ad9140"; 
  final String baseUrl = "https://api.themoviedb.org/3";

  // LOGIKA DETAIL: Paling stabil dengan Fallback Bahasa
  Future<Map<String, dynamic>> getDetail(int id, String type) async {
    try {
      // 1. Coba ambil data dalam Bahasa Indonesia dahulu
      final resIndo = await http.get(Uri.parse(
          "$baseUrl/$type/$id?api_key=$apiKey&language=id-ID&append_to_response=videos,credits"));
      
      if (resIndo.statusCode == 200) {
        final dataIndo = json.decode(resIndo.body);
        
        // 2. Jika sinopsis atau video kosong, ambil dari Inggris
        bool overviewEmpty = dataIndo['overview'] == null || dataIndo['overview'].toString().isEmpty;
        bool videosEmpty = dataIndo['videos'] == null || (dataIndo['videos']['results'] as List).isEmpty;

        if (overviewEmpty || videosEmpty) {
          final resEng = await http.get(Uri.parse("$baseUrl/$type/$id?api_key=$apiKey&append_to_response=videos,credits"));
          if (resEng.statusCode == 200) {
            final dataEng = json.decode(resEng.body);
            if (overviewEmpty) dataIndo['overview'] = dataEng['overview'];
            if (videosEmpty) dataIndo['videos'] = dataEng['videos'];
          }
        }
        return dataIndo;
      } else {
        // 3. Fallback total ke Global jika rute Indo error
        final resGlobal = await http.get(Uri.parse("$baseUrl/$type/$id?api_key=$apiKey&append_to_response=videos,credits"));
        return json.decode(resGlobal.body);
      }
    } catch (e) {
      throw Exception('Gagal memuat detail: $e');
    }
  }

  Future<dynamic> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse("$baseUrl$path").replace(queryParameters: {
      'api_key': apiKey, 'language': 'id-ID', if (params != null) ...params,
    });
    final response = await http.get(uri);
    return json.decode(response.body);
  }

  Future<List<dynamic>> getMovies2026() async => (await _get("/discover/movie", params: {'primary_release_year': '2026'}))['results'];
  Future<List<dynamic>> getSeries2026() async => (await _get("/discover/tv", params: {'first_air_date_year': '2026'}))['results'];
  Future<List<dynamic>> getTrending(String period) async => (await _get("/trending/all/$period"))['results'];
}