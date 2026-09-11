// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Pages/tactso_pages/components/tactso_branch_minutes_pdf.dart';

class TactsoMeetingMinutesTab extends StatefulWidget {
  final bool isLargeScreen;
  final String branchId;
  final String universityName;
  final String committeeMemberName;
  final String committeeMemberRole;
  final String? faceUrl;

  const TactsoMeetingMinutesTab({
    Key? key,
    required this.isLargeScreen,
    required this.branchId,
    required this.universityName,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    this.faceUrl,
  }) : super(key: key);

  @override
  State<TactsoMeetingMinutesTab> createState() =>
      _TactsoMeetingMinutesTabState();
}

class _TactsoMeetingMinutesTabState extends State<TactsoMeetingMinutesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentSegment = 0;
  bool _isLoading = true;

  List<dynamic> _committeeMembers = [];
  List<dynamic> _allMeetings = [];

  // Form & Workspace State
  String? _activeMeetingId;
  final _titleController = TextEditingController();
  final _minutesController = TextEditingController();
  DateTime _selectedMeetingDate = DateTime.now();
  TimeOfDay _selectedMeetingTime = TimeOfDay.now();
  bool _isSubmitting = false;

  // NEW: invitation loading state
  bool _isInviting = false;

  // LiveKit WebRTC State
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isConnected = false;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isScreenSharing = false;

  // Real-time Action State
  bool _isHandRaised = false;
  Set<String> _raisedHands = {};

  List<Participant> _participants = [];
  Set<String> _liveAttendees = {};

  // --- ROLE VERIFICATION ---
  bool get _isSecretary {
    final role = widget.committeeMemberRole.toLowerCase();
    return role.contains('secretary');
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _disconnectFromLiveKit();
    _titleController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken() ?? '';

      // 1. Fetch Tactso Committee Members
      final commRes = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/branch_committee/?branch=${widget.branchId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (commRes.statusCode == 200) {
        var decoded = json.decode(commRes.body);
        List<dynamic> allMembers =
            (decoded is Map<String, dynamic> && decoded.containsKey('results'))
            ? decoded['results']
            : decoded;

        _committeeMembers = allMembers
            .where((m) => m['branch'].toString() == widget.branchId)
            .toList();
      }

      // 2. Fetch Meetings
      await _fetchMeetings(token);
    } catch (e) {
      print("Error initializing meeting minutes: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMeetings(String token) async {
    try {
      final res = await http.get(
        Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/tactso_meeting_minutes/?branch_id=${widget.branchId}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() {
          _allMeetings = json.decode(res.body);
          _allMeetings.sort((a, b) {
            DateTime dA = DateTime.parse(a['meeting_date']);
            DateTime dB = DateTime.parse(b['meeting_date']);
            return dB.compareTo(dA);
          });
        });
      }
    } catch (e) {
      print("Error fetching meetings: $e");
    }
  }

  // ===========================================================================
  // LIVEKIT WEBRTC LOGIC
  // ===========================================================================
  Future<void> _joinLiveMeeting() async {
    var micStatus = await Permission.microphone.request();
    var camStatus = await Permission.camera.request();

    if (micStatus.isDenied || camStatus.isDenied) {
      Api().showMessage(
        context,
        "Camera and Microphone permissions are required.",
        "Error",
        Colors.red,
      );
      return;
    }

    Api().showLoading(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final response = await http.post(
        Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tactso-livekit-token/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "branch_id": widget.branchId,
          "participant_name": widget.committeeMemberName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lkToken = data['token'];
        final lkUrl = data['livekit_url'];

        final roomOptions = RoomOptions(adaptiveStream: true, dynacast: true);

        _room = Room();
        _listener = _room!.createListener();
        _setUpLiveKitListeners();

        await _room!.connect(lkUrl, lkToken, roomOptions: roomOptions);

        await _room!.localParticipant?.setCameraEnabled(true);
        await _room!.localParticipant?.setMicrophoneEnabled(true);

        if (mounted) {
          Navigator.pop(context);
          setState(() {
            _isConnected = true;
            _liveAttendees.add(widget.committeeMemberName);
            _updateParticipantsList();
          });
        }
      } else {
        Navigator.pop(context);
        Api().showMessage(
          context,
          "Failed to connect to the meeting server.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      Navigator.pop(context);
      print("LiveKit Connection Error: $e");
      Api().showMessage(context, "Connection error: $e", "Error", Colors.red);
    }
  }

  void _setUpLiveKitListeners() {
    _listener?.on<ParticipantConnectedEvent>(
      (event) => _updateParticipantsList(),
    );
    _listener?.on<ParticipantDisconnectedEvent>(
      (event) => _updateParticipantsList(),
    );
    _listener?.on<TrackSubscribedEvent>((event) => _updateParticipantsList());
    _listener?.on<TrackUnsubscribedEvent>((event) => _updateParticipantsList());

    _listener?.on<DataReceivedEvent>((event) {
      if (!mounted) return;
      String dataStr = utf8.decode(event.data);
      try {
        var payload = json.decode(dataStr);
        String sender = payload['user'];

        if (payload['type'] == 'reaction') {
          Api().showMessage(
            context,
            "$sender reacted ${payload['emoji']}",
            "Reaction",
            Colors.blue,
          );
        } else if (payload['type'] == 'raise_hand') {
          setState(() => _raisedHands.add(sender));
          Api().showMessage(
            context,
            "$sender raised their hand ✋",
            "Hand Raised",
            Colors.orange,
          );
        } else if (payload['type'] == 'lower_hand') {
          setState(() => _raisedHands.remove(sender));
        }
      } catch (e) {
        print("Failed to parse data event: $e");
      }
    });
  }

  void _updateParticipantsList() {
    if (_room == null) return;
    setState(() {
      _participants = [
        _room!.localParticipant!,
        ..._room!.remoteParticipants.values,
      ];

      for (var p in _participants) {
        if (p.name.isNotEmpty) {
          _liveAttendees.add(p.name);
        }
      }
    });
  }

  Future<void> _toggleMic() async {
    if (_room?.localParticipant == null) return;
    final enabled = _room!.localParticipant!.isMicrophoneEnabled();
    await _room!.localParticipant!.setMicrophoneEnabled(!enabled);
    setState(() => _isMicMuted = enabled);
  }

  Future<void> _toggleCamera() async {
    if (_room?.localParticipant == null) return;
    final enabled = _room!.localParticipant!.isCameraEnabled();
    await _room!.localParticipant!.setCameraEnabled(!enabled);
    setState(() => _isCameraOff = enabled);
  }

  Future<void> _toggleScreenShare() async {
    if (_room?.localParticipant == null) return;
    final enabled = _room!.localParticipant!.isScreenShareEnabled();
    await _room!.localParticipant!.setScreenShareEnabled(!enabled);
    setState(() => _isScreenSharing = !enabled);
  }

  Future<void> _sendReaction(String emoji) async {
    if (_room?.localParticipant == null) return;
    final payload = json.encode({
      "type": "reaction",
      "emoji": emoji,
      "user": widget.committeeMemberName,
    });
    await _room!.localParticipant!.publishData(
      utf8.encode(payload),
      reliable: true,
    );
    Api().showMessage(context, "You reacted $emoji", "Reaction", Colors.blue);
  }

  Future<void> _toggleHandRaise() async {
    if (_room?.localParticipant == null) return;

    setState(() => _isHandRaised = !_isHandRaised);
    final type = _isHandRaised ? "raise_hand" : "lower_hand";
    final payload = json.encode({
      "type": type,
      "user": widget.committeeMemberName,
    });

    await _room!.localParticipant!.publishData(
      utf8.encode(payload),
      reliable: true,
    );

    if (_isHandRaised) {
      Api().showMessage(
        context,
        "You raised your hand ✋",
        "Hand Raised",
        Colors.orange,
      );
    }
  }

  Future<void> _disconnectFromLiveKit() async {
    await _listener?.dispose();
    await _room?.disconnect();
    _room = null;
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isScreenSharing = false;
        _isHandRaised = false;
        _raisedHands.clear();
        _participants.clear();
      });
    }
  }

  // ===========================================================================
  // BACKEND LOGIC (Auto-Save on Leave for Secretary Only)
  // ===========================================================================
  Future<void> _leaveMeeting() async {
    if (_isSecretary) {
      await _disconnectFromLiveKit();

      if (_titleController.text.trim().isEmpty) {
        _titleController.text =
            "Live Meeting - ${DateFormat('dd MMM yyyy').format(DateTime.now())}";
      }

      await _submitMinutes();
    } else {
      await _disconnectFromLiveKit();
      setState(() {
        _currentSegment = 2;
      });
    }
  }

  String _getMeetingStatus(Map<String, dynamic> meeting) {
    if (meeting['meeting_date'] == null) return "UNKNOWN";

    DateTime date = DateTime.parse(meeting['meeting_date']);
    TimeOfDay time = TimeOfDay(hour: 0, minute: 0);

    if (meeting['meeting_time'] != null &&
        meeting['meeting_time'].toString().isNotEmpty) {
      final parts = meeting['meeting_time'].toString().split(':');
      if (parts.length >= 2)
        time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
    }

    DateTime meetingDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    DateTime now = DateTime.now();

    if (now.isBefore(meetingDateTime.subtract(Duration(minutes: 15))))
      return "UPCOMING";
    else if (now.isAfter(meetingDateTime.add(Duration(hours: 2))))
      return "COMPLETED";
    else
      return "LIVE NOW";
  }

  Future<void> _submitMinutes() async {
    if (!_isSecretary) return;

    if (_titleController.text.trim().isEmpty) {
      Api().showMessage(
        context,
        "Please provide a meeting title.",
        "Validation Error",
        Colors.orange,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';

      String formattedTime =
          "${_selectedMeetingTime.hour.toString().padLeft(2, '0')}:${_selectedMeetingTime.minute.toString().padLeft(2, '0')}:00";

      _liveAttendees.add(widget.committeeMemberName);

      final body = {
        "branch": widget.branchId,
        "title": _titleController.text.trim(),
        "meeting_date": DateFormat('yyyy-MM-dd').format(_selectedMeetingDate),
        "meeting_time": formattedTime,
        "minutes_text": _minutesController.text.trim(),
        "present_members": _liveAttendees.toList(),
      };

      http.Response res;

      if (_activeMeetingId != null) {
        res = await http.patch(
          Uri.parse(
            '${Api().BACKEND_BASE_URL_DEBUG}/tactso_meeting_minutes/$_activeMeetingId/',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        );
      } else {
        res = await http.post(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/tactso_meeting_minutes/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        );
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        Api().showMessage(
          context,
          "Meeting and attendance saved.",
          "Success",
          Colors.green,
        );
        _titleController.clear();
        _minutesController.clear();
        setState(() {
          _activeMeetingId = null;
          _liveAttendees.clear();
          _selectedMeetingDate = DateTime.now();
          _selectedMeetingTime = TimeOfDay.now();
          _currentSegment = 2;
        });
        await _fetchMeetings(token);
      } else {
        Api().showMessage(
          context,
          "Failed to save meeting.",
          "Error",
          Colors.red,
        );
      }
    } catch (e) {
      Api().showMessage(context, "Server Error: $e", "Error", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ===========================================================================
  // NEW: INVITE ALL ATTENDEES (Secretary only)
  // ===========================================================================
  Future<void> _inviteAllAttendees() async {
    if (_committeeMembers.isEmpty) {
      Api().showMessage(
        context,
        "No committee members found to invite.",
        "Info",
        Colors.blue,
      );
      return;
    }

    // Ensure the meeting has a title (use placeholder if empty)
    String meetingTitle = _titleController.text.trim();
    if (meetingTitle.isEmpty) {
      meetingTitle = "TACTSO Branch Meeting";
    }

    String formattedDate = DateFormat(
      'EEEE, MMMM d, yyyy',
    ).format(_selectedMeetingDate);
    String formattedTime = _selectedMeetingTime.format(context);
    String secretaryName = widget.committeeMemberName;
    String meetingLink = "Please join via the TTact app."; // Could be improved

    setState(() => _isInviting = true);

    int sentCount = 0;
    int errorCount = 0;

    for (var member in _committeeMembers) {
      String? email = member['email']?.toString().trim();
      if (email == null || email.isEmpty) continue;

      String name =
          member['full_name']?.toString().trim() ?? 'Committee Member';

      String subject = "Invitation: $meetingTitle";
      String? currentUserEmail = member['email']?.toString();
      String message =
          """
Dear $name,

You are invited to the meeting: "$meetingTitle"
Date: $formattedDate
Time: $formattedTime

Please use the following login details to login on the Dankie app and go to the meeting workspace to join the meeting.

<strong>Email: $currentUserEmail</strong>  
<strong>Password: password123</strong>

Please ensure you are available to join via the Dankie app.

Best regards,
$secretaryName
${_isSecretary ? "Secretary" : "Deputy Secretary"} 
      """;

      try {
        await Api().sendEmail(email, subject, message, context);
        sentCount++;
      } catch (e) {
        print("Failed to send email to $email: $e");
        errorCount++;
      }
    }

    setState(() => _isInviting = false);

    if (sentCount > 0) {
      Api().showMessage(
        context,
        "Invitations sent to $sentCount member(s).${errorCount > 0 ? " $errorCount failed." : ""}",
        "Done",
        Colors.green,
      );
    } else {
      Api().showMessage(
        context,
        "No invitations could be sent. Please check member emails.",
        "Error",
        Colors.red,
      );
    }
  }

  // ===========================================================================
  // LAYOUT
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final neumoBase = Api().neumoBaseColor(context);

    if (_isLoading) {
      return Center(child: CupertinoActivityIndicator(radius: 16));
    }

    return Column(
      children: [
        _buildSegmentControl(neumoBase),
        SizedBox(height: 24),
        Expanded(
          child: _currentSegment == 0
              ? _buildPersonalDashboard(neumoBase)
              : _currentSegment == 1
              ? _buildMeetingWorkspace(neumoBase)
              : _buildPastMeetings(neumoBase),
        ),
      ],
    );
  }

  Widget _buildSegmentControl(Color neumoBase) {
    return NeumorphicContainer(
      borderRadius: 16,
      padding: EdgeInsets.all(4),
      color: neumoBase,
      child: CupertinoSlidingSegmentedControl<int>(
        backgroundColor: neumoBase,
        thumbColor: Theme.of(context).primaryColor.withOpacity(0.15),
        groupValue: _currentSegment,
        padding: EdgeInsets.all(4),
        children: {
          0: _segmentText("Dashboard", 0),
          1: _segmentText("Workspace", 1),
          2: _segmentText("Meetings", 2),
        },
        onValueChanged: (val) {
          if (val != null) {
            setState(() {
              _currentSegment = val;
              if (val == 1 && !_isConnected && _isSecretary) {
                _activeMeetingId = null;
                _titleController.clear();
                _minutesController.clear();
              }
            });
          }
        },
      ),
    );
  }

  Widget _segmentText(String title, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _currentSegment == index
              ? Theme.of(context).primaryColor
              : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == "LIVE NOW"
        ? Colors.green
        : (status == "UPCOMING" ? Colors.orange : Colors.grey);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    String initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
        : "?";
    return CircleAvatar(
      radius: 18,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
      child: Text(
        initials,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. PERSONAL DASHBOARD
  // ===========================================================================
  Widget _buildPersonalDashboard(Color neumoBase) {
    int totalMeetings = _allMeetings.length;
    int attendedCount = 0;

    for (var meeting in _allMeetings) {
      List<dynamic> present = meeting['present_members'] ?? [];
      if (present.contains(widget.committeeMemberName)) {
        attendedCount++;
      }
    }

    double attendancePct = totalMeetings == 0
        ? 0.0
        : (attendedCount / totalMeetings);
    Color progressColor = attendancePct >= 0.75
        ? Colors.green
        : (attendancePct >= 0.5 ? Colors.orange : Colors.red);

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, ${widget.committeeMemberName}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
            Text(
              widget.committeeMemberRole,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),

            NeumorphicContainer(
              padding: EdgeInsets.all(24),
              borderRadius: 16,
              color: neumoBase,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem(
                    "Total Meetings",
                    totalMeetings.toString(),
                    Icons.event_note,
                    Theme.of(context).primaryColor,
                  ),
                  Container(width: 1, height: 50, color: Colors.grey[300]),
                  _statItem(
                    "Attended",
                    attendedCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  Container(width: 1, height: 50, color: Colors.grey[300]),
                  _statItem(
                    "Missed",
                    (totalMeetings - attendedCount).toString(),
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            NeumorphicContainer(
              padding: EdgeInsets.all(24),
              borderRadius: 16,
              color: neumoBase,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Your Attendance Rate",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    height: 160,
                    width: 160,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: attendancePct,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                        Center(
                          child: Text(
                            "${(attendancePct * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    attendancePct >= 0.75
                        ? "Great job! You have excellent attendance."
                        : (attendancePct >= 0.5
                              ? "You're missing some meetings. Try to attend more."
                              : "Warning: Your attendance is very low."),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[900],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // ===========================================================================
  // 2. MEETING WORKSPACE (LiveKit Embedded + Role Based Views)
  // ===========================================================================
  Widget _buildMeetingWorkspace(Color neumoBase) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: widget.isLargeScreen
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildLiveVideoArea(neumoBase)),
                  SizedBox(width: 24),
                  Expanded(
                    flex: 5,
                    child: _isSecretary
                        ? _buildWorkspaceRight(neumoBase)
                        : _buildNonSecretaryWorkspace(neumoBase),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildLiveVideoArea(neumoBase),
                  SizedBox(height: 24),
                  _isSecretary
                      ? _buildWorkspaceRight(neumoBase)
                      : _buildNonSecretaryWorkspace(neumoBase),
                ],
              ),
      ),
    );
  }

  Widget _buildLiveVideoArea(Color neumoBase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Live Meeting",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey[900],
          ),
        ),
        SizedBox(height: 20),
        NeumorphicContainer(
          padding: EdgeInsets.all(_isConnected ? 0 : 24),
          borderRadius: 20,
          color: _isConnected ? Colors.black : neumoBase,
          child: _isConnected
              ? _buildConnectedVideoGrid()
              : _buildDisconnectedPrompt(),
        ),
      ],
    );
  }

  Widget _buildDisconnectedPrompt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: _buildStatusBadge(
            _activeMeetingId != null ? "LIVE NOW" : "UPCOMING",
          ),
        ),
        SizedBox(height: 24),
        Icon(Icons.wifi_tethering, color: Colors.green, size: 64),
        SizedBox(height: 16),
        Text(
          "Dankie Live Room",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.blueGrey[900],
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Join securely right inside the app.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _joinLiveMeeting(),
            icon: Icon(Icons.videocam, color: Colors.white, size: 20),
            label: Text(
              "START / JOIN LIVE",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedVideoGrid() {
    List<Widget> videoWidgets = [];
    for (var p in _participants) {
      var camTrack = p.videoTrackPublications
          .where((t) => t.source == TrackSource.camera)
          .firstOrNull
          ?.track;
      var screenTrack = p.videoTrackPublications
          .where((t) => t.source == TrackSource.screenShareVideo)
          .firstOrNull
          ?.track;

      bool hasRaisedHand = (p.identity == _room?.localParticipant?.identity)
          ? _isHandRaised
          : _raisedHands.contains(p.name);

      if (screenTrack != null) {
        videoWidgets.add(
          _buildVideoTile(
            screenTrack as VideoTrack,
            "${p.name} (Screen)",
            isHandRaised: false,
          ),
        );
      }
      if (camTrack != null) {
        videoWidgets.add(
          _buildVideoTile(
            camTrack as VideoTrack,
            p.name,
            isHandRaised: hasRaisedHand,
          ),
        );
      }
      if (camTrack == null && screenTrack == null) {
        videoWidgets.add(_buildAvatarTile(p.name, isHandRaised: hasRaisedHand));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            height: widget.isLargeScreen ? 400 : 300,
            color: Colors.black87,
            child: videoWidgets.isEmpty
                ? Center(child: CupertinoActivityIndicator())
                : GridView.count(
                    crossAxisCount: videoWidgets.length > 2 ? 2 : 1,
                    childAspectRatio: 4 / 3,
                    children: videoWidgets,
                  ),
          ),

          Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: _isMicMuted ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleMic,
                ),
                IconButton(
                  icon: Icon(
                    _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOff ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleCamera,
                ),
                IconButton(
                  icon: Icon(
                    _isScreenSharing
                        ? Icons.stop_screen_share
                        : Icons.screen_share,
                    color: _isScreenSharing ? Colors.blue : Colors.white,
                  ),
                  onPressed: _toggleScreenShare,
                  tooltip: "Share Screen",
                ),

                IconButton(
                  icon: Icon(
                    Icons.pan_tool,
                    color: _isHandRaised ? Colors.orange : Colors.white,
                  ),
                  onPressed: _toggleHandRaise,
                  tooltip: "Raise Hand",
                ),

                PopupMenuButton<String>(
                  icon: Icon(Icons.emoji_emotions, color: Colors.white),
                  color: Colors.grey[800],
                  tooltip: "React",
                  onSelected: (String emoji) => _sendReaction(emoji),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: '👍',
                          child: Text(
                            '👍 Thumbs Up',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: '❤️',
                          child: Text(
                            '❤️ Heart',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: '👏',
                          child: Text(
                            '👏 Clap',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: '😂',
                          child: Text(
                            '😂 Laugh',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                ),

                ElevatedButton.icon(
                  onPressed: _leaveMeeting,
                  icon: Icon(Icons.call_end, color: Colors.white, size: 16),
                  label: Text(
                    _isSecretary ? "LEAVE & SAVE" : "LEAVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile(
    VideoTrack track,
    String label, {
    bool isHandRaised = false,
  }) {
    return Container(
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VideoTrackRenderer(track),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (isHandRaised)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Text("✋", style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarTile(String name, {bool isHandRaised = false}) {
    return Container(
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                name,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (isHandRaised)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Text("✋", style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  // --- Right side view for Secretaries ---
  Widget _buildWorkspaceRight(Color neumoBase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isLargeScreen) SizedBox(height: 48),
        NeumorphicContainer(
          padding: EdgeInsets.all(24),
          borderRadius: 20,
          color: neumoBase,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Secretary Controls",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueGrey[900],
                ),
              ),
              Text(
                "You are responsible for recording the minutes.",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 20),

              _buildModernTextField(
                controller: _titleController,
                hint: "Meeting Title (e.g. Branch Meeting)",
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDatePicker()),
                  SizedBox(width: 16),
                  Expanded(child: _buildTimePicker()),
                ],
              ),
              SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Attendees (${_committeeMembers.length})",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  Text(
                    "Automated Live Tracking",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildAttendeesList(),
              SizedBox(height: 32),

              Text(
                "Meeting Minutes",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blueGrey[900],
                ),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: _minutesController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: "Enter meeting minutes here...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // NEW: Invite button for secretary
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isInviting ? null : _inviteAllAttendees,
                      icon: _isInviting
                          ? CupertinoActivityIndicator(color: Colors.white)
                          : Icon(Icons.email, color: Colors.white, size: 18),
                      label: Text(
                        _isInviting ? "SENDING..." : "INVITE ALL",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitMinutes,
                      icon: _isSubmitting
                          ? CupertinoActivityIndicator(color: Colors.white)
                          : Icon(Icons.save, color: Colors.white, size: 18),
                      label: Text(
                        "SAVE MINUTES",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Right side view for Standard Members ---
  Widget _buildNonSecretaryWorkspace(Color neumoBase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isLargeScreen) SizedBox(height: 48),
        NeumorphicContainer(
          padding: EdgeInsets.all(24),
          borderRadius: 20,
          color: neumoBase,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.doc_text,
                size: 48,
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              ),
              SizedBox(height: 16),
              Text(
                "Meeting Information",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueGrey[900],
                ),
              ),
              SizedBox(height: 8),
              Text(
                "You are joined as ${widget.committeeMemberName} (${widget.committeeMemberRole}).\n\n"
                "The Secretary and Deputy Secretary are responsible for recording the minutes. You do not need to fill out any forms.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Live Attendees",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blueGrey[900],
                  ),
                ),
              ),
              SizedBox(height: 16),
              _buildAttendeesList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey[500]) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedMeetingDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _selectedMeetingDate = picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.calendar, color: Colors.grey[500], size: 20),
            SizedBox(width: 12),
            Text(
              DateFormat('dd MMM yyyy').format(_selectedMeetingDate),
              style: TextStyle(color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: () async {
        TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: _selectedMeetingTime,
        );
        if (picked != null) setState(() => _selectedMeetingTime = picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.time, color: Colors.grey[500], size: 20),
            SizedBox(width: 12),
            Text(
              _selectedMeetingTime.format(context),
              style: TextStyle(color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesList() {
    if (_committeeMembers.isEmpty)
      return Text(
        "No committee members loaded.",
        style: TextStyle(color: Colors.grey),
      );
    return Column(
      children: _committeeMembers.take(4).map((member) {
        String name = member['full_name'] ?? member['name'] ?? 'Unknown';
        String role = member['portfolio'] ?? 'Member';
        bool isCurrentlyLive =
            _participants.any((p) => p.name == name) ||
            _liveAttendees.contains(name);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              _buildAvatar(name),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentlyLive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCurrentlyLive ? "Present" : "Invited",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCurrentlyLive ? Colors.green : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // 3. PAST MEETINGS CARDS
  // ===========================================================================
  Widget _buildPastMeetings(Color neumoBase) {
    if (_allMeetings.isEmpty)
      return Center(
        child: Text(
          "No meetings recorded yet.",
          style: TextStyle(color: Colors.grey),
        ),
      );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: widget.isLargeScreen
          ? GridView.builder(
              physics: BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 0.85,
              ),
              itemCount: _allMeetings.length,
              itemBuilder: (context, index) =>
                  _buildMeetingCard(_allMeetings[index], neumoBase),
            )
          : ListView.builder(
              physics: BouncingScrollPhysics(),
              itemCount: _allMeetings.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: _buildMeetingCard(_allMeetings[index], neumoBase),
              ),
            ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting, Color neumoBase) {
    final String title = meeting['title'] ?? 'Untitled Meeting';
    final String dateStr = meeting['meeting_date'] != null
        ? DateFormat(
            'dd MMM yyyy',
          ).format(DateTime.parse(meeting['meeting_date']))
        : 'Unknown Date';
    String timeStr = "";
    if (meeting['meeting_time'] != null &&
        meeting['meeting_time'].toString().isNotEmpty) {
      final parts = meeting['meeting_time'].toString().split(':');
      if (parts.length >= 2) timeStr = "${parts[0]}:${parts[1]}";
    }
    final attendeesCount = (meeting['present_members'] as List?)?.length ?? 0;
    final String status = _getMeetingStatus(meeting);

    return NeumorphicContainer(
      padding: EdgeInsets.all(20),
      borderRadius: 16,
      color: neumoBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(status),
                  Icon(Icons.more_vert, color: Colors.grey[400]),
                ],
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blueGrey[900],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    CupertinoIcons.calendar,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(CupertinoIcons.time, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    "$attendeesCount Attendees",
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          Column(
            children: [
              if (status != "COMPLETED")
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentSegment = 1;
                        if (_isSecretary) {
                          _activeMeetingId = meeting['id'].toString();
                          _titleController.text = meeting['title'] ?? '';
                          _minutesController.text =
                              meeting['minutes_text'] ?? '';

                          if (meeting['meeting_date'] != null) {
                            _selectedMeetingDate = DateTime.parse(
                              meeting['meeting_date'],
                            );
                          }
                          if (meeting['meeting_time'] != null &&
                              meeting['meeting_time'].toString().isNotEmpty) {
                            final parts = meeting['meeting_time']
                                .toString()
                                .split(':');
                            if (parts.length >= 2)
                              _selectedMeetingTime = TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              );
                          }
                        }
                      });
                      _joinLiveMeeting();
                    },
                    icon: Icon(Icons.videocam, color: Colors.white, size: 18),
                    label: Text(
                      "JOIN LIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              if (status != "COMPLETED") SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showMeetingDetails(meeting),
                  icon: Icon(
                    CupertinoIcons.doc_text,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  label: Text(
                    "VIEW MINUTES",
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. MEETING DETAILS DIALOG (View Mode)
  // ===========================================================================
  void _showMeetingDetails(Map<String, dynamic> meeting) {
    List<dynamic> presentMembers = meeting['present_members'] ?? [];
    String timeStr = "";
    if (meeting['meeting_time'] != null &&
        meeting['meeting_time'].toString().isNotEmpty) {
      final parts = meeting['meeting_time'].toString().split(':');
      if (parts.length >= 2) timeStr = "${parts[0]}:${parts[1]}";
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          child: Container(
            width: widget.isLargeScreen
                ? 600
                : MediaQuery.of(context).size.width * 0.95,
            padding: EdgeInsets.all(32),
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          meeting['title'] ?? 'Meeting',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Text(
                        meeting['meeting_date'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      SizedBox(width: 16),
                      Icon(
                        CupertinoIcons.time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Attendees (${presentMembers.length})",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      Text(
                        "View all",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  if (presentMembers.isEmpty)
                    Text(
                      "No one joined yet.",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: -10,
                      children: presentMembers
                          .take(5)
                          .map(
                            (name) => Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: _buildAvatar(name.toString()),
                            ),
                          )
                          .toList(),
                    ),
                  SizedBox(height: 32),
                  Text(
                    "Minutes",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    meeting['minutes_text'] != null &&
                            meeting['minutes_text'].toString().trim().isNotEmpty
                        ? meeting['minutes_text']
                        : "No minutes recorded.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await TactsoMeetingMinutesPdfGenerator.generateMinutesPDF(
                          context: context,
                          title: meeting['title'] ?? 'Meeting',
                          date: meeting['meeting_date'] ?? '',
                          overseerName: widget.universityName,
                          universityName: "TACTSO Branch",
                          loggerName: widget.committeeMemberName,
                          loggerRole: widget.committeeMemberRole,
                          attendees: List<String>.from(presentMembers),
                          minutesText: meeting['minutes_text'] ?? '',
                        );
                      },
                      icon: Icon(
                        CupertinoIcons.arrow_down_doc,
                        color: Theme.of(context).primaryColor,
                        size: 18,
                      ),
                      label: Text(
                        "DOWNLOAD PDF",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
