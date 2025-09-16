import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/order_service.dart';

final orderServiceProvider = Provider<OrderService>((ref) => OrderService());

