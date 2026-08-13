import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  final VoidCallback onStartRunTap;

  const HomePage({super.key, required this.onStartRunTap});

  // Haftalık toplam mesafeyi kilometre bazında hesaplar
  double _calculateWeeklyDistance(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    double total = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        if (timestamp.toDate().isAfter(startOfWeek) ||
            timestamp.toDate().isAtSameMomentAs(startOfWeek)) {
          total += (data['totalDistance'] ?? 0.0);
        }
      }
    }
    return total / 1000.0;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String displayName = user?.displayName?.split(' ').first ?? 'Emir';

    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('activities')
              .where('userId', isEqualTo: user?.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            double weeklyKm = 0.0;
            Map<String, dynamic>? lastRun;

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              weeklyKm = _calculateWeeklyDistance(snapshot.data!.docs);
              lastRun =
                  snapshot.data!.docs.first.data() as Map<String, dynamic>;
            }

            double progress = weeklyKm / 5.0; // 5 KM hedefine göre oran
            if (progress > 1.0) progress = 1.0;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // KİŞİSELLEŞTİRİLMİŞ KARŞILAMA
                  Text(
                    'Hoş Geldin,\n$displayName!',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bugün yeni bir rekor kırmaya ne dersin?',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // MERKEZİ DAİRESEL HEDEF (PREMIUM GÖRÜNÜM)
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey[850],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E676),
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_run,
                              color: Color(0xFF00E676),
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              weeklyKm.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              '/ 5.0 KM',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // SON KOŞU KARTI
                  const Text(
                    'Son Antrenmanın',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLastRunCard(lastRun),

                  const Spacer(),

                  // DEVASA KOŞU BAŞLAT BUTONU
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: const Color(0xFF00E676).withOpacity(0.5),
                      ),
                      onPressed: onStartRunTap, // Harita sekmesine uçurur
                      child: const Text(
                        'YENİ KOŞU BAŞLAT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLastRunCard(Map<String, dynamic>? lastRun) {
    if (lastRun == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'Henüz bir koşu kaydın yok.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final distance = (lastRun['totalDistance'] ?? 0.0) / 1000.0;
    final createdAt = lastRun['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toDate())
        : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${distance.toStringAsFixed(2)} KM',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF00E676),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
