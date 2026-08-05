import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  // Firebase User'ı kendi UserEntity'mize dönüştüren yardımcı fonksiyon
  UserEntity _mapFirebaseUser(User user) {
    return UserEntity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  @override
  Stream<UserEntity?> get userStream {
    return remoteDataSource.authStateChanges.map((firebaseUser) {
      if (firebaseUser == null) return null;
      return _mapFirebaseUser(firebaseUser);
    });
  }

  @override
  Future<UserEntity> signInWithEmail(String email, String password) async {
    final user = await remoteDataSource.signIn(email, password);
    return _mapFirebaseUser(user);
  }

  @override
  Future<UserEntity> signUpWithEmail(String email, String password) async {
    final user = await remoteDataSource.signUp(email, password);
    return _mapFirebaseUser(user);
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }
}
