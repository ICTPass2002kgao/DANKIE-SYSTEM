import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:ttact/Components/API.dart';

class OverseerService {
  // 1. Create User WITHOUT logging out the Admin
  Future<String> createOverseerAuth({
    required String email,
    required String password,
  }) async {
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'tempOverseerCreator',
        options: Firebase.app().options,
      );

      UserCredential cred = await FirebaseAuth.instanceFor(
        app: tempApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      return cred.user!.uid;
    } catch (e) {
      // If user exists, we might want to proceed if just adding profile data,
      // but usually this is an error.
      rethrow;
    } finally {
      await tempApp?.delete();
    }
  }

  // 2. Main Submit Function
  Future<void> addOverseer({
    required String initialsSurname,
    required String region,
    required String code,
    required String province,
    required String secretaryName,
    required XFile? secretaryImage,
    required String chairpersonName,
    required XFile? chairpersonImage,
    required Map<String, List<Map<String, String>>> districtsData,
    required String adminUid,
  }) async {
    // Generate Email
    String cleanName = initialsSurname.replaceAll(" ", "").toLowerCase().trim();
    String overseerEmail = '$cleanName$code@gmail.com';
    String defaultPassword = "password123";

    try {
      // Step A: Create Auth
      String uid = await createOverseerAuth(
        email: overseerEmail,
        password: defaultPassword,
      );

      // Step B: Prepare District JSON
      List<Map<String, dynamic>> formattedDistricts = [];
      districtsData.forEach((elderName, communities) {
        List<Map<String, dynamic>> comms = [];
        for (var c in communities) {
          comms.add({
            'community_name': c['communityName'],
            'district_elder_name': elderName,
          });
        }
        formattedDistricts.add({
          'district_elder_name': elderName,
          'communities': comms,
        });
      });

      // Step C: Send to Django
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/overseers/');
      var request = http.MultipartRequest('POST', url);
      String? token = await FirebaseAuth.instanceFor(
        app: Firebase.app(),
      ).currentUser!.getIdToken();
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['overseer_initials_surname'] = initialsSurname;
      request.fields['email'] = overseerEmail;
      request.fields['province'] = province;
      request.fields['region'] = region;
      request.fields['code'] = code;
      request.fields['uid'] = uid; // The new UID we just created
      request.fields['districts'] = jsonEncode(formattedDistricts);

      // ⭐️ MISSING FIELDS ADDED HERE ⭐️
      request.fields['secretary_name'] = secretaryName;
      request.fields['chairperson_name'] = chairpersonName;

      // Attach Images
      if (secretaryImage != null) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'secretary_face_image',
              await secretaryImage.readAsBytes(),
              filename: 'sec.jpg',
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'secretary_face_image',
              secretaryImage.path,
            ),
          );
        }
      }

      if (chairpersonImage != null) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'chairperson_face_image',
              await chairpersonImage.readAsBytes(),
              filename: 'chair.jpg',
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'chairperson_face_image',
              chairpersonImage.path,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw "Server Error: ${response.body}";
      }
    } catch (e) {
      rethrow;
    }
  }
}
