import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isWifi() async {
  final res = await Connectivity().checkConnectivity();
  return res.contains(ConnectivityResult.wifi);
}
