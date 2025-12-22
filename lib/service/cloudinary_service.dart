import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // Tu configuración real
  static const String cloudName = "dizj9rwfx";
  static const String uploadPreset = "safezone_unsigned";

  /// ---- SUBIR IMAGEN ----
  static Future<String?> uploadImage(File image) async {
    return _uploadFile(
      file: image,
      resourceType: "image",
    );
  }

  /// ---- SUBIR VIDEO ----
  static Future<String?> uploadVideo(File video) async {
    return _uploadFile(
      file: video,
      resourceType: "video",
    );
  }

  /// ---- SUBIR AUDIO ----
  /// Cloudinary maneja AUDIO como "video"
  static Future<String?> uploadAudio(File audio) async {
    return _uploadFile(
      file: audio,
      resourceType: "video",
    );
  }

  /// --------------------------------------
  /// MÉTODO CENTRAL (para cualquier archivo)
  /// --------------------------------------
  static Future<String?> _uploadFile({
    required File file,
    required String resourceType, // image | video | raw
  }) async {
    try {
      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload",
      );

      final request = http.MultipartRequest("POST", url)
        ..fields["upload_preset"] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath("file", file.path));

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(body);
        return data["secure_url"];
      } else {
        print("Cloudinary ERROR: ${response.statusCode} → $body");
        return null;
      }
    } catch (e) {
      print("Exception Cloudinary: $e");
      return null;
    }
  }
}
