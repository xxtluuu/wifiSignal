import 'package:get_it/get_it.dart';
import 'arp_service.dart';

final GetIt getIt = GetIt.instance;

void setupServiceLocator() {
  getIt.registerLazySingleton<ARPService>(() => ARPService());
}
