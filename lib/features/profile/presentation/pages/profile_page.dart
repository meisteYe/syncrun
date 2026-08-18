import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Firebase'deki kullanıcı belgesini güncellemek için metod
  Future<void> _updateUserStat(String field, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        field: value,
      }, SetOptions(merge: true));
    }
  }

  // İsim (Kullanıcı Adı) güncellemek için açılan pencere
  void _showNameEditDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Kullanıcı Adını Güncelle',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Yeni adınızı girin',
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00E676)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  // Hem Firestore'u hem de Firebase Auth profilini güncelle
                  await _updateUserStat('displayName', newName);
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(
                    newName,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                'Kaydet',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Kilo veya Yağ Oranını güncellemek için açılan pencere
  void _showEditDialog(
    BuildContext context,
    String title,
    String fieldKey,
    String currentValue,
  ) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            '$title Güncelle',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Yeni değer girin',
              hintStyle: const TextStyle(color: Colors.grey),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00E676)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
              ),
              onPressed: () {
                final newValue = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (newValue != null) {
                  _updateUserStat(fieldKey, newValue);
                }
                Navigator.pop(context);
              },
              child: const Text(
                'Kaydet',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  // Bu haftanın (Pzt-Pzr) toplam mesafesini hesaplayan yardımcı metod
  double _calculateWeeklyDistance(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    double totalDistanceMeters = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        if (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek)) {
          totalDistanceMeters += (data['totalDistance'] ?? 0.0);
        }
      }
    }
    return totalDistanceMeters / 1000.0;
  }

  // Geçmiş verileri tarayıp kazanılan rozetleri hesaplayan fonksiyon
  List<Map<String, dynamic>> _calculateBadges(
    List<QueryDocumentSnapshot> docs,
  ) {
    int totalRuns = docs.length;
    double totalDistance = 0;
    bool has5K = false;
    bool has10K = false;
    bool hasNightRun = false;
    bool hasEarlyRun = false;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dist = (data['totalDistance'] ?? 0) as double;
      totalDistance += dist;

      if (dist >= 5000) has5K = true;
      if (dist >= 10000) has10K = true;

      DateTime? runTime;
      if (data['startTime'] is String) {
        runTime = DateTime.tryParse(data['startTime'])?.toLocal();
      } else if (data['createdAt'] is Timestamp) {
        runTime = (data['createdAt'] as Timestamp).toDate().toLocal();
      }

      if (runTime != null) {
        final startHour = runTime.hour;
        if (startHour >= 22 || startHour <= 3) hasNightRun = true;
        if (startHour >= 5 && startHour <= 7) hasEarlyRun = true;
      }
    }

    return [
      {
        'id': 'first_step',
        'title': 'İlk Adım',
        'desc': 'İlk antrenmanını tamamladın.',
        'icon': '👟',
        'color': Colors.blueAccent,
        'earned': totalRuns > 0,
      },
      {
        'id': '5k_conqueror',
        'title': '5K Fatihi',
        'desc': 'Tek seferde 5 km devirdin.',
        'icon': '🔥',
        'color': Colors.orangeAccent,
        'earned': has5K,
      },
      {
        'id': '10k_beast',
        'title': '10K Canavarı',
        'desc': 'Durmadan 10 km koştun.',
        'icon': '🦍',
        'color': Colors.redAccent,
        'earned': has10K,
      },
      {
        'id': 'night_owl',
        'title': 'Gece Kuşu',
        'desc': '22:00 sonrasında antrenman yaptın.',
        'icon': '🦉',
        'color': Colors.deepPurpleAccent,
        'earned': hasNightRun,
      },
      {
        'id': 'early_bird',
        'title': 'Erkenci Kuş',
        'desc': 'Sabah 07:00 öncesi uyanıp koştun.',
        'icon': '🌅',
        'color': Colors.amberAccent,
        'earned': hasEarlyRun,
      },
      {
        'id': 'marathon_prep',
        'title': 'Maratoncu',
        'desc': 'Toplamda 42 km mesafeye ulaştın.',
        'icon': '🏆',
        'color': const Color(0xFF00E676),
        'earned': totalDistance >= 42000,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Profil & Kondisyon'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(
              child: Text(
                'Bir hata oluştu',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};

          // Veritabanından gelen kullanıcı değerleri
          final String displayName =
              userData['displayName'] ??
              user.displayName ??
              user.email?.split('@').first ??
              'Kullanıcı';
          final String initial = displayName.isNotEmpty
              ? displayName[0].toUpperCase()
              : 'S';

          final double weight = userData['weight']?.toDouble() ?? 67.5;
          final double bodyFat = userData['bodyFat']?.toDouble() ?? 18.5;
          final bool creatineTaken = userData['creatineTaken'] ?? false;
          final bool zmaTaken = userData['zmaTaken'] ?? false;
          final bool d3k2Taken = userData['d3k2Taken'] ?? false;
          final String ghostColor = userData['ghostColor'] ?? 'grey';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('activities')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, actSnapshot) {
              double weeklyKm = 0.0;
              List<Map<String, dynamic>> badges = [];

              if (actSnapshot.hasData) {
                final docs = actSnapshot.data!.docs;
                weeklyKm = _calculateWeeklyDistance(docs);
                badges = _calculateBadges(docs);
              }

              double progress = weeklyKm / 5.0;
              if (progress > 1.0) progress = 1.0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- KULLANICI BİLGİSİ VE İSİM DÜZENLEME ---
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.grey,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showNameEditDialog(context, displayName),
                          tooltip: 'İsmi Düzenle',
                        ),
                      ],
                    ),
                    Text(
                      user.email ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // Dinamik Haftalık Hedef Barı
                    _buildSectionTitle('Haftalık Koşu Hedefi (5 km)'),
                    Card(
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Bu Hafta İlerlemen',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  '${weeklyKm.toStringAsFixed(1)} / 5.0 km',
                                  style: const TextStyle(
                                    color: Color(0xFF00E676),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[700],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF00E676),
                              ),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Fiziksel Durum
                    _buildSectionTitle('Fiziksel Durum'),
                    Card(
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () => _showEditDialog(
                                context,
                                'Kilo',
                                'weight',
                                weight.toString(),
                              ),
                              child: _StatColumn(
                                label: 'Kilo',
                                value: '${weight.toStringAsFixed(1)} kg',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[700],
                            ),
                            GestureDetector(
                              onTap: () => _showEditDialog(
                                context,
                                'Yağ Oranı',
                                'bodyFat',
                                bodyFat.toString(),
                              ),
                              child: _StatColumn(
                                label: 'Yağ Oranı',
                                value: '%${bodyFat.toStringAsFixed(1)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hayalet Rengi Seçimi
                    _buildSectionTitle('Hayalet Koşucu Rengi'),
                    Card(
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ColorOption(
                              colorValue: 'grey',
                              displayColor: Colors.grey,
                              selected: ghostColor == 'grey',
                              onTap: () =>
                                  _updateUserStat('ghostColor', 'grey'),
                            ),
                            _ColorOption(
                              colorValue: 'purple',
                              displayColor: Colors.deepPurpleAccent,
                              selected: ghostColor == 'purple',
                              onTap: () =>
                                  _updateUserStat('ghostColor', 'purple'),
                            ),
                            _ColorOption(
                              colorValue: 'red',
                              displayColor: Colors.redAccent,
                              selected: ghostColor == 'red',
                              onTap: () => _updateUserStat('ghostColor', 'red'),
                            ),
                            _ColorOption(
                              colorValue: 'yellow',
                              displayColor: Colors.amberAccent,
                              selected: ghostColor == 'yellow',
                              onTap: () =>
                                  _updateUserStat('ghostColor', 'yellow'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Günlük Takviyeler
                    _buildSectionTitle('Günlük Takviyeler'),
                    Card(
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Kreatin (3-4g)',
                              style: TextStyle(color: Colors.white),
                            ),
                            value: creatineTaken,
                            activeColor: const Color(0xFF00E676),
                            onChanged: (val) =>
                                _updateUserStat('creatineTaken', val),
                          ),
                          const Divider(color: Colors.grey, height: 1),
                          SwitchListTile(
                            title: const Text(
                              'ZMA',
                              style: TextStyle(color: Colors.white),
                            ),
                            value: zmaTaken,
                            activeColor: const Color(0xFF00E676),
                            onChanged: (val) =>
                                _updateUserStat('zmaTaken', val),
                          ),
                          const Divider(color: Colors.grey, height: 1),
                          SwitchListTile(
                            title: const Text(
                              'D3K2',
                              style: TextStyle(color: Colors.white),
                            ),
                            value: d3k2Taken,
                            activeColor: const Color(0xFF00E676),
                            onChanged: (val) =>
                                _updateUserStat('d3k2Taken', val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // KUPA ODASI (ROZETLER)
                    _buildSectionTitle('Kupa Odası (Başarımlar)'),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.9,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: badges.length,
                      itemBuilder: (context, index) {
                        final badge = badges[index];
                        final bool isEarned = badge['earned'];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          decoration: BoxDecoration(
                            color: isEarned
                                ? (badge['color'] as Color).withOpacity(0.1)
                                : Colors.grey[850],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isEarned
                                  ? (badge['color'] as Color).withOpacity(0.5)
                                  : Colors.transparent,
                              width: isEarned ? 2 : 1,
                            ),
                            boxShadow: isEarned
                                ? [
                                    BoxShadow(
                                      color: (badge['color'] as Color)
                                          .withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isEarned ? badge['icon'] : '🔒',
                                style: TextStyle(
                                  fontSize: 40,
                                  color: isEarned ? null : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                badge['title'],
                                style: TextStyle(
                                  color: isEarned
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: Text(
                                  badge['desc'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isEarned
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Çıkış Yap Butonu
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Çıkış Yap',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Fiziksel Durum Sütunları
class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit, color: Colors.grey, size: 14),
          ],
        ),
      ],
    );
  }
}

// Hayalet Rengi Seçenek Butonu
class _ColorOption extends StatelessWidget {
  final String colorValue;
  final Color displayColor;
  final bool selected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.colorValue,
    required this.displayColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: displayColor.withOpacity(selected ? 1.0 : 0.5),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: displayColor.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}
