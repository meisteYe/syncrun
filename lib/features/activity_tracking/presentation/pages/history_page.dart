import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../ghost_run/ghost_runner_cubit.dart';

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
      // Firebase'den verileri çekerken senin veritabanındaki 'createdAt' alanına göre sıralıyoruz
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

              // 1. Mesafeyi çek (Senin DB'de totalDistance)
              final distance = data['totalDistance'] ?? 0.0;

              // 2. Tarihi çek (Senin DB'de createdAt)
              final createdAt = data['createdAt'] as Timestamp?;
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM yyyy - HH:mm').format(createdAt.toDate())
                  : 'Tarih Yok';

              // 3. Süreyi hesapla (startTime ve endTime arasındaki farkı bularak)
              final startTimeStr = data['startTime'] as String?;
              final endTimeStr = data['endTime'] as String?;
              int durationInSeconds = 0;

              if (startTimeStr != null && endTimeStr != null) {
                try {
                  final start = DateTime.parse(startTimeStr);
                  final end = DateTime.parse(endTimeStr);
                  durationInSeconds = end.difference(start).inSeconds;
                } catch (e) {
                  // Tarih formatı hatalıysa sıfır kalır
                }
              }

              return Card(
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
                            Icons.directions_run,
                            color: Color(0xFF00E676),
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
                      const SizedBox(height: 16),
                      // 👻 HAYALET YARIŞ BUTONU
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.sports_score,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Bu Koşuyla Yarış',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _loadGhostRun(context, doc.id),
                        ),
                      ),
                    ],
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

  // Firebase'den seçilen koşunun telemetri verilerini çekip Cubit'e aktaran metod
  Future<void> _loadGhostRun(BuildContext context, String activityId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
      ),
    );

    try {
      final telemetrySnapshot = await FirebaseFirestore.instance
          .collection('activities')
          .doc(activityId)
          .collection('telemetry')
          .orderBy('timeOffset') // Telemetry içindeki saniye sıralaması
          .get();

      if (context.mounted) Navigator.pop(context);

      if (telemetrySnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu koşunun GPS verisi bulunamadı!')),
          );
        }
        return;
      }

      final ghostPath = telemetrySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'lat': data['lat'],
          'lng': data['lng'],
          'timeOffset': data['timeOffset'],
        };
      }).toList();

      if (context.mounted) {
        context.read<GhostRunnerCubit>().startGhostRun(ghostPath);
        Navigator.pop(context); // Geçmiş sayfasını kapatıp haritaya dönüyoruz

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hayalet rotası yüklendi! Haritada görebilirsin.'),
            backgroundColor: Colors.deepPurpleAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }
}
