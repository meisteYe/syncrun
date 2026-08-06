// lib/injection_container.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

// Activity Tracking importları
import 'features/activity_tracking/data/repositories/activity_repository.dart';
import 'features/activity_tracking/presentation/bloc/activity_bloc.dart';

// Auth importları
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';

// Core importları
import 'core/services/location_service.dart';

final sl = GetIt.instance; // sl: Service Locator

Future<void> init() async {
  // BLoC (Factory: Her çağrıldığında yeni bir instance oluşturur)
  sl.registerFactory(() => AuthBloc(authRepository: sl()));

  // ActivityBloc artık hem LocationService hem de ActivityRepository istiyor
  sl.registerFactory(() => ActivityBloc(sl(), sl()));

  // Repository (LazySingleton: Sadece ihtiyaç duyulduğunda 1 kez oluşturulur ve bellekte tutulur)
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton(() => ActivityRepository());

  // Data Sources
  sl.registerLazySingleton(() => AuthRemoteDataSource(firebaseAuth: sl()));

  // Core Services
  sl.registerLazySingleton(() => LocationService());

  // External Packages
  sl.registerLazySingleton(() => FirebaseAuth.instance);
}
