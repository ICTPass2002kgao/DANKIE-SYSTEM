// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/Overseer/Services/pdf_generator_service.dart';

class ReportsTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  final Uint8List? logoBytes;

  const ReportsTab({
    super.key,
    required this.isLargeScreen,
    this.logoBytes,
    required this.committeeMemberName,
    required this.committeeMemberRole,
    required this.faceUrl,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  // --- Selection State ---
  String? _selectedDistrictElder;
  String? _selectedCommunityName;
  String _selectedProvince = '';
  String _overseerCode = '';
  String _overseerRegion = '';
  Map<String, dynamic>? _overseerData;

  // --- Time Travel State ---
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isViewingHistory = false;

  // --- Financial Data State ---
  double _week1Sum = 0.0;
  double _week2Sum = 0.0;
  double _week3Sum = 0.0;
  double _week4Sum = 0.0;

  // --- Date State ---
  DateTime? _dateWeek1;
  DateTime? _dateWeek2;
  DateTime? _dateWeek3;
  DateTime? _dateWeek4;
  DateTime? _dateMonthEnd;
  DateTime? _dateOthers;
  DateTime? _dateRent;
  DateTime? _dateWine;
  DateTime? _datePower;
  DateTime? _dateSundries;
  DateTime? _dateCouncil;
  DateTime? _dateEquipment;

  // --- Input Controllers ---
  final TextEditingController _monthEndController = TextEditingController();
  final TextEditingController _othersController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _wineController = TextEditingController();
  final TextEditingController _powerController = TextEditingController();
  final TextEditingController _sundriesController = TextEditingController();
  final TextEditingController _councilController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();

  // --- Calculated Totals ---
  double _totalIncome = 0.0;
  double _totalExpenditure = 0.0;
  double _creditBalance = 0.0;

  final String baseUrl = Api().BACKEND_BASE_URL_DEBUG;

  // --- NEUMORPHISM STYLE CONSTANTS ---
  final Color _baseColor = const Color(0xFFE0E5EC);
  final Color _shadowLight = Colors.white;
  final Color _shadowDark = const Color(0xFFA3B1C6);
  final Color _textColor = const Color(0xFF4A5568);

  BoxDecoration _neuDecoration({double radius = 16, bool isPressed = false}) {
    return BoxDecoration(
      color: _baseColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isPressed
          ? []
          : [
              BoxShadow(
                color: _shadowDark.withOpacity(0.5),
                offset: const Offset(6, 6),
                blurRadius: 12,
              ),
              BoxShadow(
                color: _shadowLight,
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
            ],
    );
  }

  BoxDecoration _neuInnerDecoration({double radius = 8}) {
    // Simulated inner shadow/inset look for TextFields
    return BoxDecoration(
      color: const Color(0xFFD1D9E6),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchOverseerDetails();
    _setupListeners();
  }

  void _setupListeners() {
    _monthEndController.addListener(_calculateTotals);
    _othersController.addListener(_calculateTotals);
    _rentController.addListener(_calculateTotals);
    _wineController.addListener(_calculateTotals);
    _powerController.addListener(_calculateTotals);
    _sundriesController.addListener(_calculateTotals);
    _councilController.addListener(_calculateTotals);
    _equipmentController.addListener(_calculateTotals);
  }

  @override
  void dispose() {
    _monthEndController.dispose();
    _othersController.dispose();
    _rentController.dispose();
    _wineController.dispose();
    _powerController.dispose();
    _sundriesController.dispose();
    _councilController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  // --- 1. Fetch Basic Info (Django) ---
  Future<void> _fetchOverseerDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    try {
      final String? token = await user?.getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/overseers/?uid=$uid'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _overseerData = data.first;
            _selectedProvince = _overseerData?['province'] ?? '';
            _overseerCode = _overseerData?['code'] ?? '';
            _overseerRegion = _overseerData?['region'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching overseer: $e");
    }
  }

  // --- 2. Master Fetch Logic (Django) ---
  Future<void> _fetchData() async {
    if (_selectedDistrictElder == null || _selectedCommunityName == null) {
      _resetFinancialsLocally();
      return;
    }

    Api().showLoading(context);

    try {
      final String? token = await FirebaseAuth.instance.currentUser
          ?.getIdToken();
      final docId =
          "${_selectedCommunityName}_${_selectedYear}_$_selectedMonth";

      final response = await http.get(
        Uri.parse('$baseUrl/monthly_reports/?id=$docId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      bool isArchived = false;
      if (response.statusCode == 200) {
        final List reports = jsonDecode(response.body);
        isArchived = reports.isNotEmpty;
        if (isArchived) {
          _populateReportSummary(reports.first);
        }
      }

      setState(() {
        _isViewingHistory = isArchived;
      });

      if (isArchived) {
        await _fetchHistoricalCommunityFinancials();
      } else {
        await _fetchLiveCommunityFinancials();
        _clearFields();
      }

      _calculateTotals();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error fetching data: $e");
      Api().showMessage(context, "Error loading data", "Error", Colors.red);
    }
  }

  void _resetFinancialsLocally() {
    setState(() {
      _week1Sum = 0.0;
      _week2Sum = 0.0;
      _week3Sum = 0.0;
      _week4Sum = 0.0;
      _totalIncome = 0.0;
      _totalExpenditure = 0.0;
      _creditBalance = 0.0;
      _clearFields();
    });
  }

  Future<void> _fetchLiveCommunityFinancials() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final String? token = await user?.getIdToken();

    String query =
        'overseer_uid=$uid&district_elder_name=$_selectedDistrictElder&community_name=$_selectedCommunityName';

    final url = Uri.parse('$baseUrl/users/?$query');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        List users = jsonDecode(response.body);
        double w1 = 0, w2 = 0, w3 = 0, w4 = 0;

        for (var d in users) {
          w1 += double.tryParse(d['week1'].toString()) ?? 0.0;
          w2 += double.tryParse(d['week2'].toString()) ?? 0.0;
          w3 += double.tryParse(d['week3'].toString()) ?? 0.0;
          w4 += double.tryParse(d['week4'].toString()) ?? 0.0;
        }

        setState(() {
          _week1Sum = w1;
          _week2Sum = w2;
          _week3Sum = w3;
          _week4Sum = w4;
        });
      }
    } catch (e) {
      print("Error fetching live financials: $e");
    }
  }

  Future<void> _fetchHistoricalCommunityFinancials() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final String? token = await user?.getIdToken();

    String query =
        'overseer_uid=$uid&district_elder=$_selectedDistrictElder&community=$_selectedCommunityName&year=$_selectedYear&month=$_selectedMonth';

    final url = Uri.parse('$baseUrl/contribution_history/?$query');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        List history = jsonDecode(response.body);
        double w1 = 0, w2 = 0, w3 = 0, w4 = 0;

        for (var d in history) {
          w1 += double.tryParse(d['week1'].toString()) ?? 0.0;
          w2 += double.tryParse(d['week2'].toString()) ?? 0.0;
          w3 += double.tryParse(d['week3'].toString()) ?? 0.0;
          w4 += double.tryParse(d['week4'].toString()) ?? 0.0;
        }

        setState(() {
          _week1Sum = w1;
          _week2Sum = w2;
          _week3Sum = w3;
          _week4Sum = w4;
        });
      }
    } catch (e) {
      print("Error fetching history: $e");
    }
  }

  void _populateReportSummary(Map<String, dynamic> d) {
    setState(() {
      _monthEndController.text = (d['month_end'] ?? 0.0).toString();
      _othersController.text = (d['others'] ?? 0.0).toString();
      _rentController.text = (d['rent'] ?? 0.0).toString();
      _wineController.text = (d['wine'] ?? 0.0).toString();
      _powerController.text = (d['power'] ?? 0.0).toString();
      _sundriesController.text = (d['sundries'] ?? 0.0).toString();
      _councilController.text = (d['council'] ?? 0.0).toString();
      _equipmentController.text = (d['equipment'] ?? 0.0).toString();

      DateTime? parseDate(dynamic val) {
        if (val == null || val.toString().isEmpty) return null;
        try {
          return DateTime.parse(val.toString());
        } catch (e) {
          return null;
        }
      }

      _dateWeek1 = parseDate(d['date_week1']);
      _dateWeek2 = parseDate(d['date_week2']);
      _dateWeek3 = parseDate(d['date_week3']);
      _dateWeek4 = parseDate(d['date_week4']);
      _dateMonthEnd = parseDate(d['date_month_end']);
      _dateOthers = parseDate(d['date_others']);
      _dateRent = parseDate(d['date_rent']);
      _dateWine = parseDate(d['date_wine']);
      _datePower = parseDate(d['date_power']);
      _dateSundries = parseDate(d['date_sundries']);
      _dateCouncil = parseDate(d['date_council']);
      _dateEquipment = parseDate(d['date_equipment']);
    });
  }

  void _clearFields() {
    setState(() {
      _monthEndController.clear();
      _othersController.clear();
      _rentController.clear();
      _wineController.clear();
      _powerController.clear();
      _sundriesController.clear();
      _councilController.clear();
      _equipmentController.clear();
      _dateWeek1 = null;
      _dateWeek2 = null;
      _dateWeek3 = null;
      _dateWeek4 = null;
      _dateMonthEnd = null;
      _dateOthers = null;
      _dateRent = null;
      _dateWine = null;
      _datePower = null;
      _dateSundries = null;
      _dateCouncil = null;
      _dateEquipment = null;
    });
  }

  void _calculateTotals() {
    if (_selectedCommunityName == null) {
      setState(() {
        _totalIncome = 0.0;
        _totalExpenditure = 0.0;
        _creditBalance = 0.0;
      });
      return;
    }

    double parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    double incomeExtras = parse(_monthEndController) + parse(_othersController);
    double calculatedIncome =
        _week1Sum + _week2Sum + _week3Sum + _week4Sum + incomeExtras;

    double expenses =
        parse(_rentController) +
        parse(_wineController) +
        parse(_powerController) +
        parse(_sundriesController) +
        parse(_councilController) +
        parse(_equipmentController);

    setState(() {
      _totalIncome = calculatedIncome;
      _totalExpenditure = expenses;
      _creditBalance = _totalIncome - _totalExpenditure;
    });
  }

  bool _validateFinancials() {
    List<String> errors = [];

    void check(String label, double amount, DateTime? date) {
      if (amount > 0 && date == null) {
        errors.add(
          "$label has an amount of R${amount.toStringAsFixed(2)} but NO DATE selected.",
        );
      }
    }

    double parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    check("Week 1 Offering", _week1Sum, _dateWeek1);
    check("Week 2 Offering", _week2Sum, _dateWeek2);
    check("Week 3 Offering", _week3Sum, _dateWeek3);
    check("Week 4 Offering", _week4Sum, _dateWeek4);
    check("Month End", parse(_monthEndController), _dateMonthEnd);
    check("Others", parse(_othersController), _dateOthers);

    check("Rent", parse(_rentController), _dateRent);
    check("Wine & Wafers", parse(_wineController), _dateWine);
    check("Power & Lights", parse(_powerController), _datePower);
    check("Sundries", parse(_sundriesController), _dateSundries);
    check("Central Council", parse(_councilController), _dateCouncil);
    check("Equipment", parse(_equipmentController), _dateEquipment);

    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: _baseColor,
          title: const Text(
            "Missing Dates",
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You cannot proceed until dates are set for all financial entries:",
                style: TextStyle(color: _textColor),
              ),
              const SizedBox(height: 15),
              ...errors.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "• $e",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  ReportPdfData _buildCurrentPdfData() {
    String overseerName = "Overseer";
    if (_overseerData != null) {
      String n =
          _overseerData!['name'] ??
          _overseerData!['overseer_initials_surname'] ??
          '';
      if (n.isNotEmpty) overseerName = n;
    }

    double parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

    return ReportPdfData(
      districtElder: _selectedDistrictElder!,
      communityName: _selectedCommunityName!,
      province: _selectedProvince,
      overseerName: overseerName,
      overseerCode: _overseerCode,
      region: _overseerRegion,
      month: _selectedMonth,
      year: _selectedYear,
      logoBytes: widget.logoBytes,
      isViewingHistory: _isViewingHistory,
      week1Sum: _week1Sum,
      week2Sum: _week2Sum,
      week3Sum: _week3Sum,
      week4Sum: _week4Sum,
      monthEnd: parse(_monthEndController),
      others: parse(_othersController),
      totalIncome: _totalIncome,
      rent: parse(_rentController),
      wine: parse(_wineController),
      power: parse(_powerController),
      sundries: parse(_sundriesController),
      council: parse(_councilController),
      equipment: parse(_equipmentController),
      totalExpenditure: _totalExpenditure,
      creditBalance: _creditBalance,
      dateWeek1: _dateWeek1,
      dateWeek2: _dateWeek2,
      dateWeek3: _dateWeek3,
      dateWeek4: _dateWeek4,
      dateMonthEnd: _dateMonthEnd,
      dateOthers: _dateOthers,
      dateRent: _dateRent,
      dateWine: _dateWine,
      datePower: _datePower,
      dateSundries: _dateSundries,
      dateCouncil: _dateCouncil,
      dateEquipment: _dateEquipment,
    );
  }

  void _openPdfPreviewScreen(ReportPdfData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              data.isViewingHistory
                  ? "Archived Balance Sheet"
                  : "Report Generated",
            ),
            backgroundColor: _baseColor,
            foregroundColor: _textColor,
            elevation: 0,
            iconTheme: IconThemeData(color: _textColor),
          ),
          body: Container(
            color: _baseColor,
            child: PdfPreview(
              build: (format) =>
                  PdfGeneratorService.generatePdfDocument(format, data),
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowSharing: true,
              allowPrinting: true,
              pdfFileName:
                  "Report_${data.communityName}_${data.year}_${data.month}.pdf",
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _archiveAndGenerateReport() async {
    if (_selectedDistrictElder == null || _selectedCommunityName == null) {
      Api().showMessage(
        context,
        "Select a specific community to Archive.",
        "Error",
        Colors.red,
      );
      return;
    }

    if (!_validateFinancials()) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _baseColor,
        title: const Text(
          "⚠ Finalize & Archive?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "You are about to close the month of ${_getMonthName(_selectedMonth)} $_selectedYear for $_selectedCommunityName.\n\n"
          "1. This will ARCHIVE all data to history.\n"
          "2. It will RESET live member contributions to 0.00.\n"
          "3. You can print the PDF afterwards.",
          style: TextStyle(color: _textColor, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Container(
            decoration: _neuDecoration(radius: 8),
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "CONFIRM",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    Api().showLoading(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      final String? token = await user?.getIdToken();

      double parse(TextEditingController c) =>
          double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

      final payload = {
        'overseer_uid': uid,
        'district_elder': _selectedDistrictElder,
        'community': _selectedCommunityName,
        'year': _selectedYear,
        'month': _selectedMonth,
        'province': _selectedProvince,
        'report_data': {
          'month_end': parse(_monthEndController),
          'others': parse(_othersController),
          'rent': parse(_rentController),
          'wine': parse(_wineController),
          'power': parse(_powerController),
          'sundries': parse(_sundriesController),
          'council': parse(_councilController),
          'equipment': parse(_equipmentController),
          'date_week1': _dateWeek1?.toIso8601String(),
          'date_week2': _dateWeek2?.toIso8601String(),
          'date_week3': _dateWeek3?.toIso8601String(),
          'date_week4': _dateWeek4?.toIso8601String(),
          'date_month_end': _dateMonthEnd?.toIso8601String(),
          'date_others': _dateOthers?.toIso8601String(),
          'date_rent': _dateRent?.toIso8601String(),
          'date_wine': _dateWine?.toIso8601String(),
          'date_power': _datePower?.toIso8601String(),
          'date_sundries': _dateSundries?.toIso8601String(),
          'date_council': _dateCouncil?.toIso8601String(),
          'date_equipment': _dateEquipment?.toIso8601String(),
        },
        'expenses_data': {
          'overseer_uid': uid,
          'district_elder_name': _selectedDistrictElder,
          'community_name': _selectedCommunityName,
          'month': _selectedMonth,
          'year': _selectedYear,
          'province': _selectedProvince,
          'expense_central': parse(_councilController),
          'expense_rent': parse(_rentController),
          'expense_other':
              parse(_powerController) +
              parse(_sundriesController) +
              parse(_equipmentController),
          'expense_mine': 0.0,
          'total_income': _totalIncome,
          'total_expenses': _totalExpenditure,
          'total_banked': _creditBalance,
        },
      };

      final response = await http.post(
        Uri.parse('$baseUrl/monthly_reports/archive_month/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to archive: ${response.body}");
      }

      OverseerAuditLogs.logAction(
        action: "ARCHIVED",
        details: "Archived report for $_selectedCommunityName via Django",
        committeeMemberName: widget.committeeMemberName,
        committeeMemberRole: widget.committeeMemberRole,
        universityCommitteeFace: widget.faceUrl,
      );

      setState(() {
        _week1Sum = 0.0;
        _week2Sum = 0.0;
        _week3Sum = 0.0;
        _week4Sum = 0.0;
      });

      await _fetchData();

      Navigator.pop(context);

      Api().showMessage(
        context,
        "Month Archived Successfully. All weekly amounts have been reset.",
        "Success",
        Colors.green,
      );
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(context, "Error: $e", "Error", Colors.red);
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    Function(DateTime) onPicked,
  ) async {
    if (_isViewingHistory) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.blueAccent,
            colorScheme: ColorScheme.light(primary: Colors.blueAccent),
            dialogBackgroundColor: _baseColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _baseColor,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: EdgeInsets.all(widget.isLargeScreen ? 30 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Monthly Financial Report",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildTimeSelectors(),
                const SizedBox(height: 20),
                _buildOrgDropdowns(),
                const SizedBox(height: 20),

                if (_selectedDistrictElder != null &&
                    _selectedCommunityName != null) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    decoration: _neuDecoration(radius: 12),
                    child: Center(
                      child: Text(
                        "Viewing Community: $_selectedCommunityName",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  if (_isViewingHistory)
                    Container(
                      margin: const EdgeInsets.only(bottom: 25),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _baseColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.shade200,
                            offset: const Offset(4, 4),
                            blurRadius: 10,
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            offset: Offset(-4, -4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.amber.shade800,
                            size: 28,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              "Status: ARCHIVED / CLOSED \nViewing Report: ${_getMonthName(_selectedMonth)} $_selectedYear",
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  _buildFinancialInputSection(),
                  const SizedBox(height: 40),

                  if (_isViewingHistory) ...[
                    Container(
                      decoration: _neuDecoration(radius: 12),
                      child: CustomOutlinedButton(
                        onPressed: () {
                          final data = _buildCurrentPdfData();
                          _openPdfPreviewScreen(data);
                        },
                        text: "View Archived Balance Sheet (PDF)",
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        width: double.infinity,
                      ),
                    ),
                  ] else ...[
                    Container(
                      decoration: _neuDecoration(radius: 12),
                      child: CustomOutlinedButton(
                        onPressed: () {
                          final data = _buildCurrentPdfData();
                          _openPdfPreviewScreen(data);
                        },
                        text: "Preview Draft (Does not Archive)",
                        backgroundColor: _baseColor,
                        foregroundColor: _textColor,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Container(
                      decoration: _neuDecoration(radius: 12),
                      child: CustomOutlinedButton(
                        onPressed: _archiveAndGenerateReport,
                        text: "Finalize Month & Generate Report",
                        backgroundColor: Colors.redAccent.shade700,
                        foregroundColor: Colors.white,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Clicking this will Save to History and Reset Members amounts.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ] else if (_selectedDistrictElder != null) ...[
                  SizedBox(height: 40),
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(30),
                      decoration: _neuInnerDecoration(radius: 16),
                      child: Text(
                        "Please select a specific Community to view financials.",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelectors() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: _neuDecoration(radius: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedMonth,
              dropdownColor: _baseColor,
              icon: Icon(Icons.keyboard_arrow_down, color: _textColor),
              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
              items: List.generate(
                12,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text(_getMonthName(index + 1)),
                ),
              ),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _fetchData();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 25),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: _neuDecoration(radius: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: _baseColor,
              icon: Icon(Icons.keyboard_arrow_down, color: _textColor),
              style: TextStyle(color: _textColor, fontWeight: FontWeight.bold),
              items: List.generate(
                10,
                (index) => DropdownMenuItem(
                  value: 2024 + index,
                  child: Text("${2024 + index}"),
                ),
              ),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _fetchData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const m = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return m[month];
  }

  Widget _buildOrgDropdowns() {
    if (_overseerData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    List districts = _overseerData!['districts'] ?? [];
    List<String> elders = districts
        .map((e) => e['district_elder_name'].toString())
        .toList();
    List<String> communities = [];
    if (_selectedDistrictElder != null) {
      var dist = districts.firstWhere(
        (e) => e['district_elder_name'] == _selectedDistrictElder,
        orElse: () => null,
      );
      if (dist != null) {
        communities = (dist['communities'] as List)
            .map((c) => c['community_name'].toString())
            .toList();
      }
    }

    final elderDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _neuDecoration(radius: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDistrictElder,
          hint: Text(
            "Select District Elder",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          isExpanded: true,
          dropdownColor: _baseColor,
          icon: Icon(Icons.arrow_drop_down, color: _textColor),
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          items: elders
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            setState(() {
              _selectedDistrictElder = val;
              _selectedCommunityName = null;
            });
            _fetchData();
          },
        ),
      ),
    );

    final communityDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _neuDecoration(radius: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCommunityName,
          hint: Text(
            "Select Community",
            style: TextStyle(color: Colors.grey.shade600),
          ),
          isExpanded: true,
          dropdownColor: _baseColor,
          icon: Icon(Icons.arrow_drop_down, color: _textColor),
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          items: communities
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedCommunityName = val);
            if (val != null) _fetchData();
          },
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              elderDropdown,
              const SizedBox(height: 20),
              communityDropdown,
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: elderDropdown),
              const SizedBox(width: 25),
              Expanded(child: communityDropdown),
            ],
          );
        }
      },
    );
  }

  Widget _buildFinancialInputSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        if (isMobile) {
          return Column(
            children: [
              _buildIncomeCard(),
              const SizedBox(height: 30),
              _buildExpenditureCard(),
              const SizedBox(height: 30),
              _buildSummaryCard(),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildIncomeCard()),
                  const SizedBox(width: 30),
                  Expanded(child: _buildExpenditureCard()),
                ],
              ),
              const SizedBox(height: 30),
              _buildSummaryCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: _neuDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green.shade600),
              const SizedBox(width: 10),
              Text(
                "Income / Receipts",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _incomeRow(
            "Week 1 (Auto)",
            _week1Sum,
            _dateWeek1,
            (d) => _dateWeek1 = d,
          ),
          _incomeRow(
            "Week 2 (Auto)",
            _week2Sum,
            _dateWeek2,
            (d) => _dateWeek2 = d,
          ),
          _incomeRow(
            "Week 3 (Auto)",
            _week3Sum,
            _dateWeek3,
            (d) => _dateWeek3 = d,
          ),
          _incomeRow(
            "Week 4 (Auto)",
            _week4Sum,
            _dateWeek4,
            (d) => _dateWeek4 = d,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: Colors.white, thickness: 1.5, height: 1),
          ),
          _inputRow(
            "Month End",
            _monthEndController,
            _dateMonthEnd,
            (d) => _dateMonthEnd = d,
          ),
          const SizedBox(height: 15),
          _inputRow(
            "Others",
            _othersController,
            _dateOthers,
            (d) => _dateOthers = d,
          ),
          const SizedBox(height: 25),
          _totalBlock("Total Income", _totalIncome, Colors.green.shade700),
        ],
      ),
    );
  }

  Widget _buildExpenditureCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: _neuDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_down, color: Colors.red.shade600),
              const SizedBox(width: 10),
              Text(
                "Expenditure",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          _inputRow(
            "Rent Period",
            _rentController,
            _dateRent,
            (d) => _dateRent = d,
          ),
          const SizedBox(height: 15),
          _inputRow(
            "Wine & Wafers",
            _wineController,
            _dateWine,
            (d) => _dateWine = d,
          ),
          const SizedBox(height: 15),
          _inputRow(
            "Power & Lights",
            _powerController,
            _datePower,
            (d) => _datePower = d,
          ),
          const SizedBox(height: 15),
          _inputRow(
            "Sundries",
            _sundriesController,
            _dateSundries,
            (d) => _dateSundries = d,
          ),
          const SizedBox(height: 15),
          _inputRow(
            "Central Council",
            _councilController,
            _dateCouncil,
            (d) => _dateCouncil = d,
          ),
          const SizedBox(height: 15),
          _inputRow(
            "Equipment",
            _equipmentController,
            _dateEquipment,
            (d) => _dateEquipment = d,
          ),
          const SizedBox(height: 25),
          _totalBlock(
            "Total Expenditure",
            _totalExpenditure,
            Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _neuDecoration(radius: 20).copyWith(
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            "CREDIT BALANCE\n(Amount Banked):",
            style: TextStyle(
              color: _textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: _neuInnerDecoration(radius: 12),
            child: Text(
              "R ${_creditBalance.toStringAsFixed(2)}",
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalBlock(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _neuInnerDecoration(radius: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _textColor,
              fontSize: 15,
            ),
          ),
          Text(
            "R ${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeRow(
    String label,
    double value,
    DateTime? date,
    Function(DateTime) onDateSet,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _pickDate(context, onDateSet),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _baseColor,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: _shadowDark.withOpacity(0.3),
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                        BoxShadow(
                          color: _shadowLight,
                          blurRadius: 2,
                          offset: Offset(-1, -1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: Colors.blueAccent.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          date == null
                              ? "Select Date"
                              : "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueAccent.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: _neuInnerDecoration(radius: 8),
              child: Text(
                "R ${value.toStringAsFixed(2)}",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputRow(
    String label,
    TextEditingController controller,
    DateTime? date,
    Function(DateTime) onDateSet,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickDate(context, onDateSet),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _baseColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _shadowDark.withOpacity(0.3),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                      BoxShadow(
                        color: _shadowLight,
                        blurRadius: 2,
                        offset: Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: Colors.blueAccent.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        date == null
                            ? "Set Date"
                            : "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 1,
          child: Container(
            height: 42,
            decoration: _neuInnerDecoration(radius: 8),
            child: TextField(
              controller: controller,
              readOnly: _isViewingHistory,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                prefixText: "R ",
                prefixStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
