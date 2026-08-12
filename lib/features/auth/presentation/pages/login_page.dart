import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = false; // Beni Hatırla seçeneği

  List<Map<String, dynamic>> _savedProfiles = [];

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
  }

  // Telefona kaydedilmiş profilleri çeker
  // Telefona kaydedilmiş profilleri çeker
  Future<void> _loadSavedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesString = prefs.getStringList('saved_profiles') ?? [];

    // EKRAN HALA AÇIKSA GÜNCELLE (HATA BURADA ÇÖZÜLÜYOR)
    if (mounted) {
      setState(() {
        _savedProfiles = profilesString
            .map((str) => jsonDecode(str) as Map<String, dynamic>)
            .toList();
      });
    }
  }

  // Başarılı girişte profili telefona kaydeder
  Future<void> _saveProfileLocally(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // Zaten varsa güncelle, yoksa ekle
    final existingIndex = _savedProfiles.indexWhere((p) => p['email'] == email);
    if (existingIndex >= 0) {
      _savedProfiles[existingIndex] = {'email': email, 'password': password};
    } else {
      _savedProfiles.add({'email': email, 'password': password});
    }

    final profilesString = _savedProfiles.map((p) => jsonEncode(p)).toList();
    await prefs.setStringList('saved_profiles', profilesString);
    await _loadSavedProfiles(); // Listeyi güncelle
  }

  // Tıklanan kayıtlı profilin bilgilerini siler (Uzun basıldığında çalışır)
  Future<void> _removeProfile(String email) async {
    final prefs = await SharedPreferences.getInstance();
    _savedProfiles.removeWhere((p) => p['email'] == email);

    final profilesString = _savedProfiles.map((p) => jsonEncode(p)).toList();
    await prefs.setStringList('saved_profiles', profilesString);
    await _loadSavedProfiles();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        // Giriş Yap
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Beni hatırla seçiliyse kaydet
        if (_rememberMe) {
          await _saveProfileLocally(email, password);
        }
      } else {
        // Kayıt Ol
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Yeni kayıt olanı otomatik hatırla
        if (_rememberMe) {
          await _saveProfileLocally(email, password);
        }
      }
      // İşlem başarılı olursa main.dart bizi otomatik olarak MainPage'e atacak!
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Bir hata oluştu.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Kayıtlı profillere tıklandığında otomatik giriş yapar
  void _loginWithSavedProfile(Map<String, dynamic> profile) {
    _emailController.text = profile['email'];
    _passwordController.text = profile['password'];
    _submitForm();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Icon(
                    Icons.directions_run,
                    size: 80,
                    color: Color(0xFF00E676),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SyncRun Fit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Tekrar Hoş Geldin' : 'Yeni Bir Başlangıç Yap',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),

                  // KAYITLI PROFİLLER (Sadece Giriş ekranında ve kayıtlı hesap varsa gösterilir)
                  if (_isLogin && _savedProfiles.isNotEmpty) ...[
                    const Text(
                      'Kayıtlı Hesaplar',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _savedProfiles.length,
                        itemBuilder: (context, index) {
                          final profile = _savedProfiles[index];
                          final email = profile['email'] as String;
                          final initial = email.isNotEmpty
                              ? email[0].toUpperCase()
                              : '?';

                          return GestureDetector(
                            onTap: () => _loginWithSavedProfile(profile),
                            onLongPress: () {
                              // Uzun basınca profili silme onayı
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: Colors.grey[850],
                                  title: const Text(
                                    'Profili Sil',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Text(
                                    '$email cihazdan silinsin mi?',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        'İptal',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _removeProfile(email);
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'Sil',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              width: 70,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(
                                      0xFF00E676,
                                    ).withOpacity(0.2),
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Color(0xFF00E676),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    email
                                        .split('@')
                                        .first, // Sadece ismini göster
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 24),
                  ],

                  // Email Alanı
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00E676)),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty || !value.contains('@'))
                        ? 'Geçerli bir e-posta girin.'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Şifre Alanı
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.grey[850],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00E676)),
                      ),
                    ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Şifre en az 6 karakter olmalıdır.'
                        : null,
                  ),
                  const SizedBox(height: 8),

                  // Beni Hatırla Checkbox
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(unselectedWidgetColor: Colors.grey),
                    child: CheckboxListTile(
                      title: const Text(
                        'Beni Hatırla',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      value: _rememberMe,
                      activeColor: const Color(0xFF00E676),
                      checkColor: Colors.black,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? value) {
                        setState(() => _rememberMe = value ?? false);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ana Buton
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Form Geçiş Butonu
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _formKey.currentState?.reset();
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Hesabın yok mu? Hemen Kayıt Ol'
                          : 'Zaten bir hesabın var mı? Giriş Yap',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
