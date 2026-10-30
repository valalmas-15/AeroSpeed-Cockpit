import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_session_model.dart';

/// Service untuk menyimpan dan mengelola riwayat workout / sesi berkendara di disk lokal
class WorkoutHistoryService {
  static final WorkoutHistoryService instance = WorkoutHistoryService._internal();
  static const String _storageKey = 'saved_workout_sessions_v1';

  final List<WorkoutSession> _sessions = [];
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);

  final _historyNotifier = StreamController<List<WorkoutSession>>.broadcast();
  Stream<List<WorkoutSession>> get historyStream => _historyNotifier.stream;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  WorkoutHistoryService._internal() {
    loadSessions();
  }

  /// Memuat riwayat dari SharedPreferences
  Future<List<WorkoutSession>> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey);
      _sessions.clear();

      if (rawList != null) {
        for (var item in rawList) {
          try {
            _sessions.add(WorkoutSession.fromJson(item));
          } catch (_) {}
        }
      }

      // Urutkan dari yang terbaru ke terlama
      _sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      _isLoaded = true;
      _historyNotifier.add(_sessions);
      return _sessions;
    } catch (e) {
      debugPrint('[WorkoutHistory] Gagal memuat riwayat: $e');
      return [];
    }
  }

  /// Menyimpan satu sesi baru ke riwayat
  Future<void> saveSession(WorkoutSession session) async {
    try {
      if (!_isLoaded) {
        await loadSessions();
      }

      // Tambahkan di awal daftar (terbaru)
      _sessions.removeWhere((s) => s.id == session.id);
      _sessions.insert(0, session);

      final prefs = await SharedPreferences.getInstance();
      final rawList = _sessions.map((s) => s.toJson()).toList();
      await prefs.setStringList(_storageKey, rawList);

      _historyNotifier.add(_sessions);
      debugPrint('[WorkoutHistory] Sesi ${session.id} berhasil disimpan (${session.totalDistanceKm.toStringAsFixed(1)} km, ${session.duration.inSeconds}s)');
    } catch (e) {
      debugPrint('[WorkoutHistory] Gagal menyimpan sesi: $e');
    }
  }

  /// Menghapus satu sesi tertentu
  Future<void> deleteSession(String id) async {
    try {
      _sessions.removeWhere((s) => s.id == id);
      final prefs = await SharedPreferences.getInstance();
      final rawList = _sessions.map((s) => s.toJson()).toList();
      await prefs.setStringList(_storageKey, rawList);

      _historyNotifier.add(_sessions);
      debugPrint('[WorkoutHistory] Sesi $id berhasil dihapus.');
    } catch (e) {
      debugPrint('[WorkoutHistory] Gagal menghapus sesi: $e');
    }
  }

  /// Menghapus seluruh riwayat
  Future<void> clearAll() async {
    try {
      _sessions.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);

      _historyNotifier.add(_sessions);
      debugPrint('[WorkoutHistory] Semua riwayat berhasil dibersihkan.');
    } catch (e) {
      debugPrint('[WorkoutHistory] Gagal membersihkan riwayat: $e');
    }
  }
}

