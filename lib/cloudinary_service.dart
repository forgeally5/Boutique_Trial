import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String cloudName = "df9pn9xey";
  static const String uploadPreset = "trilok_showroom_upload";

  // Backward compatible wrapper (mostly for mobile/desktop if still used)
  Future<String?> uploadImage(File imageFile) async {
    return uploadFile(imageFile, resourceType: "image");
  }

  Future<String?> uploadFile(File file, {String resourceType = "auto"}) async {
    try {
      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload",
      );

      final request = http.MultipartRequest("POST", uri);
      request.fields["upload_preset"] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath("file", file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return data["secure_url"];
      } else {
        final errorResponse = await response.stream.bytesToString();
        debugPrint("Cloudinary Upload failed: $errorResponse");
      }
      return null;
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
      return null;
    }
  }

  // New method for Web compatibility using XFile
  Future<String?> uploadXFile(XFile file, {String resourceType = "auto"}) async {
    try {
      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload",
      );

      final request = http.MultipartRequest("POST", uri);
      request.fields["upload_preset"] = uploadPreset;
      
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: file.name,
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return data["secure_url"];
      } else {
        final errorResponse = await response.stream.bytesToString();
        debugPrint("Cloudinary Upload failed: $errorResponse");
      }
      return null;
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
      return null;
    }
  }
}