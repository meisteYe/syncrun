import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'activity_detail_page.dart'; // DETAY SAYFASI İÇERİ AKTARILDI

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Antrenmanlar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[900],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('activities')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Bir hata oluştu.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            );
          }

          final activities = snapshot.data!.docs;

          if (activities.isEmpty) {
            return const Center(
              child: Text(
                'Henüz geçmiş bir antrenmanın yok.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final doc = activities[index];
              final data = doc.data() as Map<String, dynamic>;

              final distance = data['totalDistance'] ?? 0.0;
              final createdAt = data['createdAt'] as Timestamp?;
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM yyyy - HH:mm').format(createdAt.toDate())
                  : 'Tarih Yok';

              final startTimeStr = data['startTime'] as String?;
              final endTimeStr = data['endTime'] as String?;
              int durationInSeconds = 0;

              if (startTimeStr != null && endTimeStr != null) {
                try {
                  final start = DateTime.parse(startTimeStr);
                  final end = DateTime.parse(endTimeStr);
                  durationInSeconds = end.difference(start).inSeconds;
                } catch (_) {}
              }

              // KARTA TIKLANABİLİRLİK (GestureDetector) EKLENDİ
              return GestureDetector(
                onTap: () {
                  // Detay sayfasına ID'yi ve verileri yolluyoruz
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityDetailPage(
                        activityId: doc.id,
                        summaryData: data, // Tüm veriyi de aktarıyoruz
                      ),
                    ),
                  );
                },
                child: Card(
                  color: Colors.grey[850],
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatColumn(
                              'Mesafe',
                              '${distance.toStringAsFixed(1)} m',
                            ),
                            _buildStatColumn(
                              'Süre',
                              '${(durationInSeconds / 60).toStringAsFixed(1)} dk',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
