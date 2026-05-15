import 'dart:io' as io;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:ttact/Components/API.dart'; 

class BranchService {
  
  // ⭐️ THE FIX: Create User WITHOUT logging out the Admin
  Future<String> createBranchAuth({required String email, required String password}) async {
    FirebaseApp? tempApp;
    try {
      // 1. Initialize a secondary Firebase App
      tempApp = await Firebase.initializeApp(
        name: 'tempBranchCreator',
        options: Firebase.app().options,
      );

      // 2. Create the user on the secondary app instance
      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      return cred.user!.uid;
    } catch (e) {
      rethrow;
    } finally {
      // 3. Delete the secondary app so it doesn't leak memory
      await tempApp?.delete();
    }
  }

  // Helper: Upload Image
  Future<String> uploadImage(XFile file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    if (kIsWeb) {
      await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(io.File(file.path));
    }
    return await ref.getDownloadURL();
  }

  // Helper: Delete Image (Rollback)
  Future<void> deleteImage(String path) async {
    try {
      await FirebaseStorage.instance.ref(path).delete();
    } catch (e) {
      print("Warning: Failed to rollback image: $e");
    }
  }

  // Main Action
  Future<void> createBranch({
    required String overseerUid,   // 👈 Added Overseer parameter
    required String districtId,    // 👈 Added District parameter
    required String universityName,
    required String campusName,
    required String appLink,
    required String address,
    required String email,
    required String password,
    required bool isOpen,
    required XFile uniImage,
    required String officerName,
    required XFile officerImage,
    required String chairName,
    required XFile chairImage,
  }) async {
    
    String? uploadedUniImagePath;
    
    try {
      // Step 1: Create Auth (Safe Mode)
      String uid = await createBranchAuth(email: email, password: password);

      // Step 2: Upload Uni Image (Frontend)
      String uniImgPath = "Tactso_Branches/$universityName/University_Images/${DateTime.now().millisecondsSinceEpoch}.jpg";
      String uniImageUrl = await uploadImage(uniImage, uniImgPath);
      uploadedUniImagePath = uniImgPath; // Mark for rollback if needed

      // Step 3: Send to Django
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tactso_branches/'),
      );

      // ⭐️ FIX: Attach Firebase Token so Django doesn't block with 403 Forbidden
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        String token = await currentUser.getIdToken() ?? '';
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Append standard fields
      request.fields['uid'] = uid;
      request.fields['email'] = email;
      request.fields['university_name'] = universityName;
      request.fields['campus_name'] = campusName;
      request.fields['application_link'] = appLink;
      request.fields['address'] = address;
      request.fields['is_application_open'] = isOpen.toString();
      request.fields['image_url'] = uniImageUrl; 
      request.fields['education_officer_name'] = officerName;
      request.fields['chairperson_name'] = chairName;

      // 👈 Append New Assignment Fields
      request.fields['overseer'] = overseerUid;
      request.fields['assigned_district'] = districtId;

      // Attach Files for Encryption (Officer/Chair)
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('education_officer_face_image', await officerImage.readAsBytes(), filename: 'officer.jpg'));
        request.files.add(http.MultipartFile.fromBytes('chairperson_face_image', await chairImage.readAsBytes(), filename: 'chair.jpg'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('education_officer_face_image', officerImage.path));
        request.files.add(await http.MultipartFile.fromPath('chairperson_face_image', chairImage.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201) {
        throw "Server Error: ${response.body}";
      }

    } catch (e) { 
      if (uploadedUniImagePath != null) {
        await deleteImage(uploadedUniImagePath);
      }
      rethrow; 
    }
  }
}