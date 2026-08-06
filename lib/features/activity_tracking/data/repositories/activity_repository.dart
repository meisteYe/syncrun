import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

class ActivityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveActivity({
    required List<LatLng> routePoints,
    required double totalDistance,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    // 1. Özet veriyi 'activities' koleksiyonuna kaydet
    final activityRef = await _firestore.collection('activities').add({
      'userId': user.uid,
      'totalDistance': totalDistance,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Ham GPS noktalarını (Telemetry) ML modelleri için optimize edilmiş alt koleksiyona kaydet
    // Batch (Toplu işlem) kullanarak veritabanını yormadan tek seferde yazıyoruz.
    final batch = _firestore.batch();
    final pointsRef = activityRef.collection('telemetry');

    for (int i = 0; i < routePoints.length; i++) {
      final point = routePoints[i];
      final docRef = pointsRef.doc(); // Otomatik ID

      batch.set(docRef, {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'sequence': i, // Sıralama garantisi için
      });
    }

    await batch.commit();
  }

  /// Mevcut kullanıcının geçmiş antrenmanlarını tarihe göre azalan (en yeni en üstte) sırayla getirir.
  Future<List<Map<String, dynamic>>> getUserActivities() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    try {
      final snapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .orderBy(
            'createdAt',
            descending: true,
          ) // En yeniler ilk sırada gelsin
          .get();

      // Firestore'dan gelen verileri List<Map> formatına dönüştürüyoruz
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc
            .id; // Belge ID'sini de ekleyelim, ileride detaya gitmek için lazım olacak
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Veriler çekilirken bir hata oluştu: $e');
    }
  }

  /// Belirli bir antrenmanın ham GPS (telemetry) verilerini sırasıyla çeker.
  Future<List<LatLng>> getActivityRoute(String activityId) async {
    try {
      final snapshot = await _firestore
          .collection('activities')
          .doc(activityId)
          .collection('telemetry')
          .orderBy('sequence') // Kaydettiğimiz sıraya göre (0, 1, 2...) getir
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return LatLng(data['latitude'] as double, data['longitude'] as double);
      }).toList();
    } catch (e) {
      throw Exception('Rota verileri çekilirken hata oluştu: $e');
    }
  }
}
