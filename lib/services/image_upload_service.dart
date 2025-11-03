// services/image_upload_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:html' as html; // For web file upload
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:universal_html/html.dart' as html;

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Pick image - works for both mobile and web
  Future<dynamic> pickImage({bool fromGallery = true}) async {
    try {
      // For web platform
      if (_isWeb()) {
        return await _pickImageWeb();
      }

      // For mobile platforms
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  // Web-specific image picker
  Future<html.File?> _pickImageWeb() async {
    final html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement();
    uploadInput.accept = 'image/*';

    uploadInput.click();

    final completer = Completer<html.File?>();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        completer.complete(files[0]);
      } else {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  // Upload image to Firebase Storage - works for both web and mobile
  Future<String> uploadCategoryImage({
    required dynamic imageFile,
    required String vendorId,
    required String categoryId,
  }) async {
    try {
      final String fileName =
          'category_${DateTime.now().millisecondsSinceEpoch}${_getFileExtension(imageFile)}';
      final String storagePath =
          'vendors/$vendorId/categories/$categoryId/$fileName';

      UploadTask uploadTask;

      if (_isWeb() && imageFile is html.File) {
        // For web - upload from html.File
        final metadata = SettableMetadata(
          contentType: 'image/${_getMimeType(imageFile)}',
        );
        uploadTask = _storage
            .ref()
            .child(storagePath)
            .putBlob(imageFile.slice(), metadata);
      } else if (imageFile is File) {
        // For mobile - upload from File
        uploadTask = _storage.ref().child(storagePath).putFile(imageFile);
      } else {
        throw Exception('Unsupported file type');
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Add this method to ImageUploadService class
  Future<String> uploadProductImage({
    required dynamic imageFile,
    required String vendorId,
    required String productId,
  }) async {
    try {
      final String fileName =
          'product_${DateTime.now().millisecondsSinceEpoch}${_getFileExtension(imageFile)}';
      final String storagePath =
          'vendors/$vendorId/products/$productId/$fileName';

      UploadTask uploadTask;

      if (_isWeb() && imageFile is html.File) {
        // For web - upload from html.File
        final metadata = SettableMetadata(
          contentType: 'image/${_getMimeType(imageFile)}',
        );
        uploadTask = _storage
            .ref()
            .child(storagePath)
            .putBlob(imageFile.slice(), metadata);
      } else if (imageFile is File) {
        // For mobile - upload from File
        uploadTask = _storage.ref().child(storagePath).putFile(imageFile);
      } else {
        throw Exception('Unsupported file type');
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload product image: $e');
    }
  }

  // Get file extension for web and mobile
  String _getFileExtension(dynamic file) {
    if (_isWeb() && file is html.File) {
      final fileName = file.name;
      final dotIndex = fileName.lastIndexOf('.');
      return dotIndex != -1 ? fileName.substring(dotIndex) : '.jpg';
    } else if (file is File) {
      return path.extension(file.path);
    }
    return '.jpg';
  }

  // Get MIME type for web files
  String _getMimeType(html.File file) {
    final type = file.type;
    if (type.isNotEmpty) {
      if (type.contains('jpeg') || type.contains('jpg')) return 'jpeg';
      if (type.contains('png')) return 'png';
      if (type.contains('gif')) return 'gif';
      if (type.contains('bmp')) return 'bmp';
      if (type.contains('webp')) return 'webp';
    }
    return 'jpeg'; // default
  }

  // Check if running on web
  bool _isWeb() {
    return identical(0, 0.0);
  }

  // Delete image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.isNotEmpty) {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }
    } catch (e) {
      // Log error but don't throw - deletion of storage file is secondary
      print('Error deleting image from storage: $e');
    }
  }

  // Get file size in MB
  double getFileSizeInMB(dynamic file) {
    if (_isWeb() && file is html.File) {
      return file.size / (1024 * 1024);
    } else if (file is File) {
      final sizeInBytes = file.lengthSync();
      return sizeInBytes / (1024 * 1024);
    }
    return 0;
  }

  // Validate image file
  String? validateImage(dynamic file) {
    if (file == null) return null;

    final sizeInMB = getFileSizeInMB(file);
    if (sizeInMB > 5) {
      return 'Image size should be less than 5MB';
    }

    // Validate file type for web
    if (_isWeb() && file is html.File) {
      final allowedTypes = [
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/bmp',
      ];
      if (!allowedTypes.contains(file.type.toLowerCase())) {
        return 'Please select a valid image file (JPEG, PNG, GIF, WebP, BMP)';
      }
    }

    return null;
  }

  // Convert web file to bytes for preview (optional)
  Future<Uint8List?> getFileBytes(dynamic file) async {
    if (_isWeb() && file is html.File) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      return reader.result as Uint8List?;
    }
    return null;
  }

  // Add this method to ImageUploadService class
  Future<String> uploadDiscountImage({
    required dynamic imageFile,
    required String vendorId,
    required String discountId,
  }) async {
    try {
      final String fileName =
          'discount_${DateTime.now().millisecondsSinceEpoch}${_getFileExtension(imageFile)}';
      final String storagePath =
          'vendors/$vendorId/discounts/$discountId/$fileName';

      UploadTask uploadTask;

      if (_isWeb() && imageFile is html.File) {
        // For web - upload from html.File
        final metadata = SettableMetadata(
          contentType: 'image/${_getMimeType(imageFile)}',
        );
        uploadTask = _storage
            .ref()
            .child(storagePath)
            .putBlob(imageFile.slice(), metadata);
      } else if (imageFile is File) {
        // For mobile - upload from File
        uploadTask = _storage.ref().child(storagePath).putFile(imageFile);
      } else {
        throw Exception('Unsupported file type');
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload discount image: $e');
    }
  }
}
