import 'package:flutter/material.dart';
import 'package:ttact/Pages/Overseer/components/overseer_services.dart';
import 'package:ttact/Pages/Overseer/components/NeuWidgets.dart';
import 'package:ttact/Pages/Overseer/models/overseer_models.dart';
import 'package:ttact/Components/API.dart';

class OverseerCommunicationsTab extends StatefulWidget {
  final String overseerUid; // Firebase UID
  final String? committeeMemberName;
  final bool isLargeScreen;
  final String? committeeMemberRole;
  final String? faceUrl;

  OverseerCommunicationsTab({
    super.key,
    required this.overseerUid,
    this.committeeMemberName,
    this.committeeMemberRole,
    this.faceUrl,
    required this.isLargeScreen,
  });

  @override
  State<OverseerCommunicationsTab> createState() =>
      _OverseerCommunicationsTabState();
}

class _OverseerCommunicationsTabState extends State<OverseerCommunicationsTab> {
  final OverseerService _service = OverseerService();
  List<OverseerCommunication> _drafts = [];
  List<OverseerCommunication> _published = [];
  bool _isLoading = true;
  String? _overseerUuid; // UUID from backend

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch the overseer UUID using Firebase UID
      final overseer = await _service.fetchOverseerByUid(widget.overseerUid);
      if (overseer != null) {
        _overseerUuid = overseer.id;
      } else {
        if (mounted) {
          Api().showMessage(context, 'Overseer not found', 'Error', Colors.red);
        }
        setState(() => _isLoading = false);
        return;
      }

      final drafts = await _service.fetchCommunications(
        widget.overseerUid,
        isPublished: false,
      );
      final published = await _service.fetchCommunications(
        widget.overseerUid,
        isPublished: true,
      );
      setState(() {
        _drafts = drafts;
        _published = published;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        Api().showMessage(context, 'Failed to load data', 'Error', Colors.red);
      }
    }
  }

  void _showAddCommDialog() {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Api().neumoBaseColor(context),
        title: const Text(
          "Create Communication",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeuTextField(label: "Subject", controller: subjectCtrl),
              const SizedBox(height: 12),
              NeuTextField(
                label: "Message Body",
                controller: bodyCtrl,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: NeuButton(
                  onPressed: () async =>
                      _saveComm(ctx, subjectCtrl.text, bodyCtrl.text, false),
                  text: "Save Draft",
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NeuButton(
                  onPressed: () async =>
                      _saveComm(ctx, subjectCtrl.text, bodyCtrl.text, true),
                  text: "Publish",
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveComm(
    BuildContext dialogCtx,
    String subject,
    String body,
    bool isPublished,
  ) async {
    if (_overseerUuid == null) {
      Api().showMessage(
        context,
        'Overseer UUID not loaded',
        'Error',
        Colors.red,
      );
      return;
    }

    final newComm = OverseerCommunication(
      overseerId: _overseerUuid!, 
      overseerUid: widget.overseerUid, 
      subject: subject,
      messageBody: body,
      isPublished: isPublished,
    );
    Api().showLoading(context);
    final created = await _service.createCommunication(newComm);
    Navigator.pop(context);
    Navigator.pop(dialogCtx);
    if (created != null) {
      setState(() {
        if (isPublished)
          _published.insert(0, created);
        else
          _drafts.insert(0, created);
      });
      Api().showMessage(
        context,
        isPublished ? "Published!" : "Draft saved!",
        "Success",
        Colors.green,
      );
    } else {
      Api().showMessage(
        context,
        "Failed to send communication.",
        "Error",
        Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: neuDecoration(radius: 12),
                  child: TabBar(
                    labelColor: textColor,
                    unselectedLabelColor: Colors.grey,
                    indicator: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: const [
                      Tab(text: "Published"),
                      Tab(text: "Drafts"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCommList(_published, isPublished: true),
                      _buildCommList(_drafts, isPublished: false),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildCommList(
    List<OverseerCommunication> items, {
    required bool isPublished,
  }) {
    return Column(
      children: [
        if (items.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.message_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPublished ? "No published messages" : "No saved drafts",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 200,
                    child: NeuButton(
                      onPressed: _showAddCommDialog,
                      text: "Write New",
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 10),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: NeuCard(
                    padding: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.messageBody,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isPublished)
                              Text(
                                "👁️ ${item.readCount} Read",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            else
                              Text(
                                "📝 Draft",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            Text(
                              item.createdAt?.split('T')[0] ?? "",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: NeuButton(
              onPressed: _showAddCommDialog,
              text: "New Communication",
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
