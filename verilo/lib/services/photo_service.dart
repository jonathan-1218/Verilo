import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/database.dart';
import 'location_service.dart';

class PhotoService {
  PhotoService(this._db, this._location);
  final AppDatabase _db;
  final LocationService _location;

  final _picker = ImagePicker();

  Future<Photo?> capturePhoto(int visitId) async {
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) return null;

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return null;

    final pos = await _location.currentPosition();
    final id = await _db.insertPhoto(PhotosCompanion.insert(
      visitId: visitId,
      filePath: file.path,
      lat: Value(pos?.latitude),
      lng: Value(pos?.longitude),
      accuracyMeters: Value(pos?.accuracy),
    ));
    return (_db.select(_db.photos)..where((p) => p.id.equals(id))).getSingle();
  }
}
