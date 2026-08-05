import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Firebase'deki anlık kullanıcı durumunu (giriş yaptı/çıktı) dinleyen akış.
  Stream<UserEntity?> get userStream;

  Future<UserEntity> signUpWithEmail(String email, String password);
  Future<UserEntity> signInWithEmail(String email, String password);
  Future<void> signOut();
}
