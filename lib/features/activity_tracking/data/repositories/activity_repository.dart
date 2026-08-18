import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityRepository {
  static const String _offlineKey = 'offline_activities';

  // 1. MEVCUT KOŞUYU KAYDETME MANTIĞI (GÜVENLİK KALKANI)
  Future<void> saveActivity({
    required List<LatLng> routePoints,
    required double totalDistance,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final activityData = {
      'userId': user.uid,
      'totalDistance': totalDistance,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final telemetryData = routePoints
        .asMap()
        .entries
        .map(
          (e) => {
            'lat': e.value.latitude,
            'lng': e.value.longitude,
            'timeOffset': e.key * 1000,
          },
        )
        .toList();

    try {
      // 5 saniye içinde Firebase'e yazmayı dene. (İnternet var mı testi)
      await _saveToFirebase(
        activityData,
        telemetryData,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      // İNTERNET YOK VEYA SUNUCU ÇÖKTÜ: Veriyi yerel hafızaya hapset!
      await _saveLocally(activityData, telemetryData);
    }
  }

  // 2. FİREBASE'E YAZMA VE LİDERLİK TABLOSUNU GÜNCELLEME
  Future<void> _saveToFirebase(
    Map<String, dynamic> activityData,
    List<Map<String, dynamic>> telemetryData,
  ) async {
    final docRef = await FirebaseFirestore.instance
        .collection('activities')
        .add(activityData);
    final batch = FirebaseFirestore.instance.batch();

    for (var point in telemetryData) {
      final pointRef = docRef.collection('telemetry').doc();
      batch.set(pointRef, point);
    }
    await batch.commit();

    // YENİ: LİDERLİK TABLOSUNU GÜNCELLEME (HATASIZ VE HIZLI YÖNTEM: FieldValue.increment)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      // Sunucuya mesafeyi doğrudan mevcut değerin üzerine eklemesini söylüyoruz
      await userRef.set({
        'leaderboardDistance': FieldValue.increment(
          activityData['totalDistance'],
        ),
      }, SetOptions(merge: true));
    }
  }

  // 3. HATALI KOŞUYU SİLME VE LİDERLİK TABLOSUNDAN EKSİLTME
  Future<void> deleteActivity(
    String activityId,
    double distanceToDeduct,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Önce alt koleksiyondaki 'telemetry' verilerini sil (GPS verileri)
    final telemetrySnap = await FirebaseFirestore.instance
        .collection('activities')
        .doc(activityId)
        .collection('telemetry')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in telemetrySnap.docs) {
      batch.delete(doc.reference);
    }

    // 2. Ana aktivite belgesini sil
    final activityRef = FirebaseFirestore.instance
        .collection('activities')
        .doc(activityId);
    batch.delete(activityRef);

    await batch.commit();

    // 3. Kullanıcının liderlik puanından sildiğimiz bu koşunun mesafesini düş
    // YENİ: Hata veren Transaction yerine FieldValue.increment(-deger) kullandık!
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    await userRef.set({
      'leaderboardDistance': FieldValue.increment(-distanceToDeduct),
    }, SetOptions(merge: true));
  }

  // 4. YEREL HAFIZAYA YAZMA (OFFLINE KASA)
  Future<void> _saveLocally(
    Map<String, dynamic> activityData,
    List<Map<String, dynamic>> telemetryData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> offlineList = prefs.getStringList(_offlineKey) ?? [];

    activityData['createdAt'] = DateTime.now().toIso8601String();

    final localData = {'activity': activityData, 'telemetry': telemetryData};
    offlineList.add(jsonEncode(localData));
    await prefs.setStringList(_offlineKey, offlineList);
  }

  // 5. İNTERNET GELDİĞİNDE VERİLERİ SUNUCUYA İTME (BACKGROUND SYNC)
  Future<void> syncOfflineActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> offlineList = prefs.getStringList(_offlineKey) ?? [];

    if (offlineList.isEmpty) return;

    List<String> remainingList = [];

    for (String item in offlineList) {
      try {
        final data = jsonDecode(item);
        final activityData = data['activity'] as Map<String, dynamic>;
        final telemetryData = List<Map<String, dynamic>>.from(
          data['telemetry'],
        );

        activityData['createdAt'] = FieldValue.serverTimestamp();
        await _saveToFirebase(
          activityData,
          telemetryData,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        remainingList.add(item);
      }
    }
    await prefs.setStringList(_offlineKey, remainingList);
  }

  // 6. GEÇMİŞ ROTA GETİRİCİSİ (Detay sayfası için)
  Future<List<LatLng>> getActivityRoute(String activityId) async {
    final snap = await FirebaseFirestore.instance
        .collection('activities')
        .doc(activityId)
        .collection('telemetry')
        .orderBy('timeOffset')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return LatLng(data['lat'], data['lng']);
    }).toList();
  }
}
