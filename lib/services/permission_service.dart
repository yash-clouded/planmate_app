import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService extends ChangeNotifier {
  Future<Map<Permission, PermissionStatus>> requestAll() async {
    final result = await [
      Permission.notification,
      Permission.storage,
      Permission.contacts,
      Permission.locationWhenInUse,
    ].request();
    notifyListeners();
    return result;
  }

  Future<bool> get notificationGranted =>
      Permission.notification.status.then((s) => s.isGranted);

  Future<bool> get storageGranted =>
      Permission.storage.status.then((s) => s.isGranted);

  Future<bool> get contactsGranted =>
      Permission.contacts.status.then((s) => s.isGranted);
}
