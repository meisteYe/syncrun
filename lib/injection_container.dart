// lib/injection_container.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

final sl = GetIt.instance; // sl: Service Locator

Future<void> init() async {
  // BLoC (Factory: Her çağrıldığında yeni bir instance oluşturur)
  sl.registerFactory(() => AuthBloc(authRepository: sl()));

  // Repository (LazySingleton: Sadece ihtiyaç duyulduğunda 1 kez oluşturulur ve bellekte tutulur)
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));

  // Data Sources
  sl.registerLazySingleton(() => AuthRemoteDataSource(firebaseAuth: sl()));

  // External Packages (Firebase vb. dış paketleri de buradan enjekte ediyoruz)
  sl.registerLazySingleton(() => FirebaseAuth.instance);
}
