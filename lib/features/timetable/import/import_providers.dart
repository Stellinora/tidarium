import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/adapter_repository.dart';
import 'data/wakeup_school_repository.dart';

final adapterRepositoryProvider = Provider<AdapterRepository>(
  (ref) => AdapterRepository(),
);

final wakeUpSchoolRepositoryProvider = Provider<WakeUpSchoolRepository>(
  (ref) => WakeUpSchoolRepository(),
);
