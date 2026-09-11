import 'dart:convert';

class OverseerDiaryEvent {
  final String? id;
  final String overseerUid;
  final String title;
  final String description;
  final String eventDate; // ISO 8601 date string
  final String location;
  final String posterUrl;
  final String? createdBy;
  final String? createdAt;

  OverseerDiaryEvent({
    this.id,
    required this.overseerUid,
    required this.title,
    this.description = '',
    required this.eventDate,
    this.location = '',
    this.posterUrl = '',
    this.createdBy,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'overseer': overseerUid,
    'title': title,
    'description': description,
    'event_date': eventDate,
    'location': location,
    'poster_url': posterUrl,
  };

  factory OverseerDiaryEvent.fromJson(Map<String, dynamic> json) {
    return OverseerDiaryEvent(
      id: json['id']?.toString(),
      overseerUid: json['overseer_uid'] ?? json['overseer'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      eventDate: json['event_date'] ?? '',
      location: json['location'] ?? '',
      posterUrl: json['poster_url'] ?? '',
      createdBy: json['created_by']?.toString() ?? 'Unknown',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class OverseerMeetingMinutes {
  final String? id;
  final String overseerUid;
  final String title;
  final String meetingDate;
  final String minutesText;
  final List<String> presentMemberIds; // for request
  final List<Map<String, dynamic>>
  presentMembers; // for response (list of {id, full_name})
  final String? createdBy;
  final String? createdAt;

  OverseerMeetingMinutes({
    this.id,
    required this.overseerUid,
    required this.title,
    required this.meetingDate,
    this.minutesText = '',
    this.presentMemberIds = const [],
    this.presentMembers = const [],
    this.createdBy,
    this.createdAt,
  });
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'overseer': overseerUid,
      'title': title,
      'meeting_date': meetingDate,
      'minutes_text': minutesText,
    };
    if (presentMemberIds.isNotEmpty) {
      json['present_member_ids'] = presentMemberIds;
    }
    return json;
  }

  factory OverseerMeetingMinutes.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parsedMembers = [];
    if (json['present_members'] != null) {
      final raw = json['present_members'];
      if (raw is List) {
        parsedMembers = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }

    return OverseerMeetingMinutes(
      id: json['id']?.toString(),
      overseerUid: json['overseer_uid'] ?? json['overseer'] ?? '',
      title: json['title'] ?? '',
      meetingDate: json['meeting_date'] ?? '',
      minutesText: json['minutes_text'] ?? '',
      presentMembers: parsedMembers,
      createdBy: json['created_by']?.toString() ?? 'Unknown',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Overseer {
  final String id; // UUID from backend
  final String uid; // Firebase UID

  Overseer({required this.id, required this.uid});

  factory Overseer.fromJson(Map<String, dynamic> json) {
    return Overseer(id: json['id']?.toString() ?? '', uid: json['uid'] ?? '');
  }
}

// lib/Pages/Overseer/models/overseer_models.dart

class OverseerCommunication {
  final String? overseerId;
  final String overseerUid; // Firebase UID (used as the value for 'overseer')
  final String subject;
  final String messageBody;
  final bool isPublished;
  final int readCount;
  final String? createdBy;
  final String? createdAt;
  final String? sentAt;
  final List<String>? attachments;

  OverseerCommunication({
    this.overseerId,
    required this.overseerUid,
    required this.subject,
    required this.messageBody,
    this.isPublished = false,
    this.readCount = 0,
    this.createdBy,
    this.createdAt,
    this.sentAt,
    this.attachments,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'overseer': overseerId, // send Firebase UID as the overseer field
      'subject': subject,
      'message_body': messageBody,
      'is_published': isPublished,
      'attachments': attachments ?? [],
    };
    return json;
  }

  factory OverseerCommunication.fromJson(Map<String, dynamic> json) {
    return OverseerCommunication(
      overseerId: json['id']?.toString(),
      overseerUid: json['overseer_uid'] ?? json['overseer'] ?? '',
      subject: json['subject'] ?? '',
      messageBody: json['message_body'] ?? '',
      isPublished: json['is_published'] ?? false,
      readCount: json['read_count'] ?? 0,
      createdBy: json['created_by']?.toString() ?? 'Unknown',
      createdAt: json['created_at'] ?? '',
      sentAt: json['sent_at'] ?? '',
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
    );
  }
}

class OverseerCommitteeMember {
  final String id;
  final String fullName;
  final String portfolio;

  OverseerCommitteeMember({
    required this.id,
    required this.fullName,
    required this.portfolio,
  });

  factory OverseerCommitteeMember.fromJson(Map<String, dynamic> json) {
    return OverseerCommitteeMember(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      portfolio: json['portfolio'] ?? '',
    );
  }
}

