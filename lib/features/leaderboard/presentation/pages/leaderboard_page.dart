import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Global Liderlik Tablosu',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ÜST REKABET KARTI
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.emoji_events, size: 60, color: Colors.amberAccent),
                SizedBox(height: 16),
                Text(
                  'En Çok Koşanlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tüm zamanların en iyi SyncRun Fit atletleri',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),

          // LİDERLİK LİSTESİ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('leaderboardDistance', descending: true)
                  .limit(50) // En iyi 50 koşucu
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E676)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz veri yok. İlk koşan sen ol!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final distanceMeters =
                        (data['leaderboardDistance'] ?? 0.0) as double;
                    final distanceKm = distanceMeters / 1000.0;
                    final isMe = users[index].id == currentUser?.uid;

                    // Dinamik İsim ve Harf Yakalama
                    final String displayName =
                        data['displayName'] ??
                        data['email']?.toString().split('@').first ??
                        'Anonim Atlet';
                    final String initial = displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'A';

                    // İlk 3'e Madalya Rengi
                    Color medalColor;
                    if (index == 0) {
                      medalColor = Colors.amberAccent;
                    } else if (index == 1) {
                      medalColor = Colors.grey[300]!;
                    } else if (index == 2) {
                      medalColor = Colors.brown[400]!;
                    } else {
                      medalColor = Colors.transparent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF00E676).withOpacity(0.1)
                            : Colors.black,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isMe
                              ? const Color(0xFF00E676)
                              : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: medalColor == Colors.transparent
                                ? Colors.grey[850]
                                : medalColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: medalColor == Colors.transparent
                                  ? Colors.transparent
                                  : medalColor,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: index < 3
                                ? Icon(Icons.star, color: medalColor, size: 20)
                                : Text(
                                    '#${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        // YENİ: İSMİN YANINA MİNİ PROFİL AVATARI EKLENDİ
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isMe
                                  ? const Color(0xFF00E676).withOpacity(0.2)
                                  : Colors.grey[800],
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? const Color(0xFF00E676)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isMe
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: isMe
                            ? const Text(
                                'Sen',
                                style: TextStyle(
                                  color: Color(0xFF00E676),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                        trailing: Text(
                          '${distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
