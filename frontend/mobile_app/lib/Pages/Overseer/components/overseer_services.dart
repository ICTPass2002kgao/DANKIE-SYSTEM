import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Overseer/models/overseer_models.dart';

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
    required List<Map<String, dynamic>> districtsData,
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

      // Step B: Send to Django
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
      request.fields['uid'] = uid;

      request.fields['districts'] = jsonEncode(districtsData);
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

  final String baseUrl = Api().BACKEND_BASE_URL_DEBUG;

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Overseer?> fetchOverseerByUid(String firebaseUid) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/overseers/?uid=$firebaseUid'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        return Overseer.fromJson(data.first);
      }
    }
    return null;
  }

  // ================= COMMITTEE MEMBERS =================
  Future<List<OverseerCommitteeMember>> fetchCommitteeMembers(
    String overseerUid,
  ) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/committee_members/?overseer_uid=$overseerUid'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => OverseerCommitteeMember.fromJson(e)).toList();
    }
    return [];
  }

  // ================= DIARY EVENTS =================
  Future<List<OverseerDiaryEvent>> fetchEvents(String overseerUid) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/overseer_diary_events/?overseer_uid=$overseerUid'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => OverseerDiaryEvent.fromJson(e)).toList();
    }
    return [];
  }

 Future<OverseerDiaryEvent?> createEvent({
  required String overseerUid,
  required String title,
  required String description,
  required String eventDate,
  required String location,
  XFile? poster,  // optional file
}) async {
  final headers = await _getAuthHeaders();
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/overseer_diary_events/'),
  );
  request.headers.addAll(headers);
  request.fields['overseer'] = overseerUid;
  request.fields['title'] = title;
  request.fields['description'] = description;
  request.fields['event_date'] = eventDate;
  request.fields['location'] = location;
  if (poster != null) {
    request.files.add(
      await http.MultipartFile.fromPath('poster', poster.path),
    );
  }
  final response = await request.send();
  if (response.statusCode == 201) {
    final json = await response.stream.bytesToString();
    return OverseerDiaryEvent.fromJson(jsonDecode(json));
  }
  return null;
}
  // ================= MEETING MINUTES =================
  Future<List<OverseerMeetingMinutes>> fetchMinutes(String overseerUid) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/overseer_meeting_minutes/?overseer_uid=$overseerUid'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => OverseerMeetingMinutes.fromJson(e)).toList();
    }
    return [];
  }

  Future<OverseerMeetingMinutes?> createMinutes(
    OverseerMeetingMinutes minutes,
  ) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/overseer_meeting_minutes/'),
      headers: headers,
      body: jsonEncode(minutes.toJson()),
    );
    if (response.statusCode == 201) {
      return OverseerMeetingMinutes.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  // ================= COMMUNICATIONS =================
  Future<List<OverseerCommunication>> fetchCommunications(
    String overseerUid, {
    bool? isPublished,
  }) async {
    final headers = await _getAuthHeaders();
    String url = '$baseUrl/overseer_communications/?overseer_uid=$overseerUid';
    if (isPublished != null) {
      url += '&is_published=$isPublished';
    }
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => OverseerCommunication.fromJson(e)).toList();
    }
    return [];
  }
 
Future<OverseerCommunication?> createCommunication(OverseerCommunication comm) async {
  final headers = await _getAuthHeaders();
  final response = await http.post(
    Uri.parse('$baseUrl/overseer_communications/'),
    headers: headers,
    body: jsonEncode(comm.toJson()),
  );
  if (response.statusCode == 201) {
    return OverseerCommunication.fromJson(jsonDecode(response.body));
  }
  print('Create communication failed: ${response.body}');
  return null;
}
}
