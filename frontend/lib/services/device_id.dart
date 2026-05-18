import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Anonymous per-device identity. Generated on first launch, persisted in
/// SharedPreferences. v0.7 plan: Google Sign-In will be able to bind this
/// anonymous id to a Google account (so the writing history follows the user
/// across devices).
class DeviceId {
  DeviceId._(this._id);
  final String _id;
  String get value => _id;

  static Future<DeviceId> load() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('device_id');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await p.setString('device_id', id);
    }
    return DeviceId._(id);
  }
}
