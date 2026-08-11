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

    // 2. Ham GPS noktalarını Hayalet Koşu mantığına uygun (lat, lng, timeOffset) şekilde kaydediyoruz
    final batch = _firestore.batch();
    final pointsRef = activityRef.collection('telemetry');

    int totalSeconds = endTime.difference(startTime).inSeconds;

    for (int i = 0; i < routePoints.length; i++) {
      final point = routePoints[i];
      final docRef = pointsRef.doc();

      // Toplam geçen süreyi kaydedilen noktalara eşit olarak dağıtıp timeOffset (saniye) buluyoruz
      int timeOffset = routePoints.length > 1
          ? (i * (totalSeconds / (routePoints.length - 1))).round()
          : 0;

      batch.set(docRef, {
        'lat': point
            .latitude, // 'latitude' yerine 'lat' oldu (GhostRunner için gerekli)
        'lng': point
            .longitude, // 'longitude' yerine 'lng' oldu (GhostRunner için gerekli)
        'timeOffset': timeOffset, // Hangi saniyede bu koordinattaydı?
        'sequence': i,
      });
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getUserActivities() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    try {
      final snapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Veriler çekilirken bir hata oluştu: $e');
    }
  }

  Future<List<LatLng>> getActivityRoute(String activityId) async {
    try {
      final snapshot = await _firestore
          .collection('activities')
          .doc(activityId)
          .collection('telemetry')
          .orderBy('sequence')
          .get();

      // Veritabanındaki yeni isimlendirmeye (lat, lng) göre okuma yapıyoruz
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return LatLng(data['lat'] as double, data['lng'] as double);
      }).toList();
    } catch (e) {
      throw Exception('Rota verileri çekilirken hata oluştu: $e');
    }
  }
}
