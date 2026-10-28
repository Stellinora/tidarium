import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/adapter_repository.dart';

final adapterRepositoryProvider = Provider<AdapterRepository>(
  (ref) => AdapterRepository(),
);
