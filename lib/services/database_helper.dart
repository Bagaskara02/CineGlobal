import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cineglobal.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── TABEL USERS (Auth SQLite — email & password SHA-256) ──
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        biometric_enabled INTEGER DEFAULT 0,
        avatar_path TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel session user (untuk auto-login)
    await db.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        username TEXT,
        token TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel riwayat pencarian
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        searched_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel cache film (untuk offline)
    await db.execute('''
      CREATE TABLE cached_movies (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        poster_path TEXT,
        backdrop_path TEXT,
        overview TEXT,
        release_date TEXT,
        vote_average REAL,
        media_type TEXT DEFAULT 'movie',
        cached_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel riwayat chat CineBot
    await db.execute('''
      CREATE TABLE chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel highscore mini game
    await db.execute('''
      CREATE TABLE game_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_mode TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        played_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel riwayat tiket (per akun user, disimpan lokal)
    await db.execute('''
      CREATE TABLE ticket_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        ticket_id TEXT NOT NULL,
        movie_title TEXT NOT NULL,
        cinema_name TEXT,
        show_date TEXT,
        show_time TEXT,
        seats TEXT,
        total_price INTEGER DEFAULT 0,
        studio_type TEXT,
        payment_method TEXT,
        is_claimed INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel watchlist (per user, lokal)
    await db.execute('''
      CREATE TABLE watchlist (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        movie_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        poster_path TEXT,
        release_date TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabel komentar/diskusi (per film, lokal)
    await db.execute('''
      CREATE TABLE comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movie_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Upgrade dari versi lama
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          email TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          biometric_enabled INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ticket_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          ticket_id TEXT NOT NULL,
          movie_title TEXT NOT NULL,
          cinema_name TEXT,
          show_date TEXT,
          show_time TEXT,
          seats TEXT,
          total_price INTEGER DEFAULT 0,
          studio_type TEXT,
          payment_method TEXT,
          is_claimed INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS watchlist (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          movie_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          poster_path TEXT,
          release_date TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS comments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          movie_id INTEGER NOT NULL,
          user_id TEXT NOT NULL,
          username TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN avatar_path TEXT');
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────
  // ENKRIPSI SHA-256
  // ─────────────────────────────────────────────────
  /// Mengenkripsi password dengan SHA-256
  /// Input: password plain text → Output: hex string 64 karakter
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);   // 1. String → bytes UTF-8
    final digest = sha256.convert(bytes);  // 2. Hitung SHA-256 hash
    return digest.toString();              // 3. Hash → hex string
  }

  // ─────────────────────────────────────────────────
  // AUTH — REGISTER & LOGIN (SQLite)
  // ─────────────────────────────────────────────────

  /// Registrasi user baru ke SQLite
  /// Password di-hash SHA-256 sebelum disimpan
  Future<Map<String, dynamic>> registerUser(String username, String email, String password) async {
    final db = await database;
    
    // Cek apakah username sudah ada
    final existingUser = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (existingUser.isNotEmpty) {
      throw 'Username "$username" sudah digunakan';
    }

    // Cek apakah email sudah ada
    final existingEmail = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (existingEmail.isNotEmpty) {
      throw 'Email "$email" sudah terdaftar';
    }

    // Hash password dengan SHA-256
    final passwordHash = hashPassword(password);

    // Simpan ke tabel users
    final id = await db.insert('users', {
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'biometric_enabled': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
    };
  }

  /// Login user — verifikasi username + SHA-256(password) di SQLite
  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    final db = await database;
    final passwordHash = hashPassword(password);

    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, passwordHash],
    );

    if (result.isNotEmpty) return result.first;
    return null;
  }

  /// Ambil data user berdasarkan username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  /// Ambil password hash (terenkripsi) untuk presentasi
  Future<String?> getEncryptedPassword(String username) async {
    final db = await database;
    final result = await db.query('users', columns: ['password_hash'], where: 'username = ?', whereArgs: [username]);
    if (result.isNotEmpty) return result.first['password_hash'] as String?;
    return null;
  }

  /// Toggle biometric on/off
  Future<void> toggleBiometric(String username, bool enabled) async {
    final db = await database;
    await db.update(
      'users',
      {'biometric_enabled': enabled ? 1 : 0},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  /// Cek apakah biometric diaktifkan untuk user tertentu
  Future<bool> isBiometricEnabled(String username) async {
    final db = await database;
    final result = await db.query('users', columns: ['biometric_enabled'], where: 'username = ?', whereArgs: [username]);
    if (result.isNotEmpty) return (result.first['biometric_enabled'] as int) == 1;
    return false;
  }

  // ─────────────────────────────────────────────────
  // SESSION
  // ─────────────────────────────────────────────────
  Future<void> saveSession(String userId, String email, String? username, String? token) async {
    final db = await database;
    await db.delete('user_session'); // Hanya 1 session aktif
    await db.insert('user_session', {
      'user_id': userId,
      'email': email,
      'username': username ?? '',
      'token': token ?? '',
    });
  }

  Future<Map<String, dynamic>?> getSession() async {
    final db = await database;
    final result = await db.query('user_session', limit: 1);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  Future<void> clearSession() async {
    final db = await database;
    await db.delete('user_session');
  }

  // ─────────────────────────────────────────────────
  // SEARCH HISTORY
  // ─────────────────────────────────────────────────
  Future<void> addSearchHistory(String query) async {
    final db = await database;
    // Hapus duplicate
    await db.delete('search_history', where: 'query = ?', whereArgs: [query]);
    await db.insert('search_history', {
      'query': query,
      'searched_at': DateTime.now().toIso8601String(),
    });
    // Simpan max 20
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM search_history'));
    if (count != null && count > 20) {
      await db.rawDelete('DELETE FROM search_history WHERE id IN (SELECT id FROM search_history ORDER BY searched_at ASC LIMIT ${count - 20})');
    }
  }

  Future<List<String>> getSearchHistory() async {
    final db = await database;
    final result = await db.query('search_history', orderBy: 'searched_at DESC', limit: 10);
    return result.map((e) => e['query'] as String).toList();
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  // ─────────────────────────────────────────────────
  // CACHED MOVIES
  // ─────────────────────────────────────────────────
  Future<void> cacheMovies(List<Map<String, dynamic>> movies) async {
    final db = await database;
    final batch = db.batch();
    for (var movie in movies) {
      batch.insert('cached_movies', {
        'id': movie['id'],
        'title': movie['title'] ?? movie['name'] ?? '',
        'poster_path': movie['poster_path'] ?? '',
        'backdrop_path': movie['backdrop_path'] ?? '',
        'overview': movie['overview'] ?? '',
        'release_date': movie['release_date'] ?? movie['first_air_date'] ?? '',
        'vote_average': (movie['vote_average'] as num?)?.toDouble() ?? 0.0,
        'media_type': movie['media_type'] ?? 'movie',
        'cached_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedMovies() async {
    final db = await database;
    return await db.query('cached_movies', orderBy: 'cached_at DESC');
  }

  // ─────────────────────────────────────────────────
  // CHAT HISTORY
  // ─────────────────────────────────────────────────
  Future<void> addChatMessage(String role, String content) async {
    final db = await database;
    await db.insert('chat_history', {
      'role': role,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    final db = await database;
    return await db.query('chat_history', orderBy: 'created_at ASC');
  }

  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete('chat_history');
  }

  // ─────────────────────────────────────────────────
  // GAME SCORES
  // ─────────────────────────────────────────────────
  Future<void> saveGameScore(String mode, int score, int total) async {
    final db = await database;
    await db.insert('game_scores', {
      'game_mode': mode,
      'score': score,
      'total_questions': total,
      'played_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> getHighScore(String mode) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(score) as high_score FROM game_scores WHERE game_mode = ?',
      [mode],
    );
    return result.first['high_score'] as int? ?? 0;
  }

  Future<List<Map<String, dynamic>>> getGameHistory(String mode) async {
    final db = await database;
    return await db.query(
      'game_scores',
      where: 'game_mode = ?',
      whereArgs: [mode],
      orderBy: 'score DESC',
      limit: 10,
    );
  }

  // ─────────────────────────────────────────────────
  // TICKET HISTORY (SQLite lokal per user)
  // ─────────────────────────────────────────────────

  /// Simpan tiket ke SQLite (per user_id)
  Future<void> saveTicket({
    required String userId,
    required String ticketId,
    required String movieTitle,
    String? cinemaName,
    String? showDate,
    String? showTime,
    String? seats,
    int totalPrice = 0,
    String? studioType,
    String? paymentMethod,
  }) async {
    final db = await database;
    await db.insert('ticket_history', {
      'user_id': userId,
      'ticket_id': ticketId,
      'movie_title': movieTitle,
      'cinema_name': cinemaName ?? '',
      'show_date': showDate ?? '',
      'show_time': showTime ?? '',
      'seats': seats ?? '',
      'total_price': totalPrice,
      'studio_type': studioType ?? '',
      'payment_method': paymentMethod ?? '',
      'is_claimed': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Ambil semua tiket milik user tertentu
  Future<List<Map<String, dynamic>>> getTickets(String userId) async {
    final db = await database;
    return await db.query(
      'ticket_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  /// Tandai tiket sebagai claimed
  Future<void> claimTicket(int ticketRowId) async {
    final db = await database;
    await db.update(
      'ticket_history',
      {'is_claimed': 1},
      where: 'id = ?',
      whereArgs: [ticketRowId],
    );
  }

  // ─────────────────────────────────────────────────
  // WATCHLIST (SQLite lokal per user)
  // ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWatchlist(String userId) async {
    final db = await database;
    return await db.query('watchlist', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  Future<bool> isInWatchlist(String userId, int movieId) async {
    final db = await database;
    final res = await db.query('watchlist', where: 'user_id = ? AND movie_id = ?', whereArgs: [userId, movieId]);
    return res.isNotEmpty;
  }

  Future<void> addToWatchlist(String userId, int movieId, String title, String? posterPath, String? releaseDate) async {
    final db = await database;
    await db.insert('watchlist', {
      'user_id': userId,
      'movie_id': movieId,
      'title': title,
      'poster_path': posterPath ?? '',
      'release_date': releaseDate ?? '',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeFromWatchlist(String userId, int movieId) async {
    final db = await database;
    await db.delete('watchlist', where: 'user_id = ? AND movie_id = ?', whereArgs: [userId, movieId]);
  }

  // ─────────────────────────────────────────────────
  // COMMENTS / DISKUSI (SQLite lokal per film)
  // ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getComments(int movieId) async {
    final db = await database;
    return await db.query('comments', where: 'movie_id = ?', whereArgs: [movieId], orderBy: 'created_at DESC');
  }

  Future<void> addComment(int movieId, String userId, String username, String content) async {
    final db = await database;
    await db.insert('comments', {
      'movie_id': movieId,
      'user_id': userId,
      'username': username,
      'content': content,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ─────────────────────────────────────────────────
  // AVATAR (simpan file lokal + path di SQLite)
  // ─────────────────────────────────────────────────
  Future<String> saveAvatar(String userId, String sourceImagePath) async {
    final dbPath = await getDatabasesPath();
    final avatarDir = Directory(join(dbPath, 'avatars'));
    if (!await avatarDir.exists()) {
      await avatarDir.create(recursive: true);
    }
    final ext = sourceImagePath.split('.').last;
    final destPath = join(avatarDir.path, 'avatar_$userId.$ext');
    await File(sourceImagePath).copy(destPath);

    final db = await database;
    await db.update('users', {'avatar_path': destPath},
        where: 'id = ?', whereArgs: [int.tryParse(userId) ?? userId]);
    return destPath;
  }

  Future<String?> getAvatarPath(String userId) async {
    final db = await database;
    final res = await db.query('users',
        columns: ['avatar_path'],
        where: 'id = ?',
        whereArgs: [int.tryParse(userId) ?? userId]);
    if (res.isNotEmpty && res.first['avatar_path'] != null) {
      final path = res.first['avatar_path'] as String;
      if (path.isNotEmpty && File(path).existsSync()) return path;
    }
    return null;
  }
}
