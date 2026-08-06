import 'package:flutter/material.dart';
import '../../../../injection_container.dart';
import '../../data/repositories/activity_repository.dart';
import 'activity_detail_page.dart'; // En üste ekle

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
      backgroundColor: Colors.black, // Dark tema arka planı
      // FutureBuilder ile BLoC kurmadan doğrudan Repository'den veriyi dinleyebiliyoruz
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: sl<ActivityRepository>().getUserActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Hata oluştu:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz kaydedilmiş antrenman bulunmuyor.\nHadi koşmaya başla!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final activities = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              final distance = activity['totalDistance'] as double;
              final startTimeStr = activity['startTime'] as String;

              // Veritabanındaki UTC zamanını kullanıcının yerel saatine çevir
              final startTime = DateTime.parse(startTimeStr).toLocal();

              // Tarih ve saati okunabilir formata getir
              final dateStr =
                  "${startTime.day.toString().padLeft(2, '0')}.${startTime.month.toString().padLeft(2, '0')}.${startTime.year}";
              final timeStr =
                  "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";

              return Card(
                color: Colors.grey[900], // Kartların koyu gri arka planı
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF00E676,
                      ).withOpacity(0.2), // Neon yeşil saydam arka plan
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_run,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  title: Text(
                    '$dateStr - $timeStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Toplam Mesafe: ${distance.toStringAsFixed(1)} m',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    // Detay sayfasına ID'yi ve özet verileri gönderiyoruz
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActivityDetailPage(
                          activityId: activity['id'] as String,
                          summaryData: activity,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
