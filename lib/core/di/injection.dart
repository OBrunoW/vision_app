import 'package:get_it/get_it.dart';

import '../../features/streaming/streaming_view_model.dart';
import '../../services/rtmp_service.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  getIt.registerFactory<RtmpService>(() => RtmpService());
  getIt.registerFactory<StreamingViewModel>(
    () => StreamingViewModel(getIt<RtmpService>()),
  );
}
