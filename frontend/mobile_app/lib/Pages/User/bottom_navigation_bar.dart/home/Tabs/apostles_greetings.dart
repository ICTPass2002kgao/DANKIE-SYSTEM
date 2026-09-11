// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class ApostlesGreetings extends StatefulWidget {
  const ApostlesGreetings({super.key});
  @override
  State<ApostlesGreetings> createState() => _ApostlesGreetingsState();
}

class _ApostlesGreetingsState extends State<ApostlesGreetings>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedLang = 'en';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _allGreetings = [];
  bool _isLoading = true;

  final Map<String, String> _supportedLanguages = {
    'English': 'en',
    'Sepedi': 'nso',
    'Sesotho': 'st',
    'isiZulu': 'zu',
    'isiXhosa': 'xh',
    'Xitsonga': 'ts',
  };

  @override
  void initState() {
    super.initState();
    _fetchGreetingsFromBackend();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGreetingsFromBackend() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _allGreetings = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Returns a map of greeting -> matching language code (null if no match)
  Map<dynamic, String?> _findMatchingLanguage(
    List<dynamic> greetings,
    String query,
  ) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return {for (var g in greetings) g: null};

    final Map<dynamic, String?> matches = {};
    for (final greeting in greetings) {
      final contentMap = greeting['content_json'] is String
          ? jsonDecode(greeting['content_json'])
          : greeting['content_json'];
      String? matchLang;
      if (contentMap is Map) {
        for (final langCode in _supportedLanguages.values) {
          final langContent = contentMap[langCode];
          if (langContent is Map) {
            final title = langContent['title']?.toString().toLowerCase() ?? '';
            final message =
                langContent['message']?.toString().toLowerCase() ?? '';
            if (title.contains(q) || message.contains(q)) {
              matchLang = langCode;
              break;
            }
          }
        }
      }
      matches[greeting] = matchLang;
    }
    return matches;
  }

  List<dynamic> get filteredGreetings {
    if (_searchQuery.isEmpty) return _allGreetings;
    final q = _searchQuery.toLowerCase().trim();
    final matchMap = _findMatchingLanguage(_allGreetings, q);
    return _allGreetings.where((g) => matchMap[g] != null).toList();
  }

  // Helper to get matching language for a specific greeting (used in card)
  String? _getMatchingLangForGreeting(dynamic greeting) {
    if (_searchQuery.isEmpty) return null;
    final q = _searchQuery.toLowerCase().trim();
    final contentMap = greeting['content_json'] is String
        ? jsonDecode(greeting['content_json'])
        : greeting['content_json'];
    if (contentMap is Map) {
      for (final langCode in _supportedLanguages.values) {
        final langContent = contentMap[langCode];
        if (langContent is Map) {
          final title = langContent['title']?.toString().toLowerCase() ?? '';
          final message =
              langContent['message']?.toString().toLowerCase() ?? '';
          if (title.contains(q) || message.contains(q)) {
            return langCode;
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.1),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: true,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15.0,
                  vertical: 2.0,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: theme.primaryColor.withOpacity(0.6),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              if (mounted) setState(() => _searchQuery = value);
                            },
                          );
                        },
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search by Apostle, Year, or Message...',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                        child: Icon(
                          Icons.cancel_rounded,
                          color: theme.hintColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              height: 65,
              margin: const EdgeInsets.only(top: 5, bottom: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _supportedLanguages.length,
                itemBuilder: (context, index) {
                  String langName = _supportedLanguages.keys.elementAt(index);
                  String langCode = _supportedLanguages.values.elementAt(index);
                  bool isSelected = _selectedLang == langCode;
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 15,
                      top: 5,
                      bottom: 5,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedLang = langCode),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        child: NeumorphicContainer(
                          color: isSelected
                              ? theme.primaryColor
                              : neumoBaseColor,
                          isPressed: isSelected,
                          borderRadius: 25,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Center(
                            child: Text(
                              langName,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : theme.hintColor,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: false,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        color: theme.primaryColor,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Apostle\'s Greetings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CupertinoActivityIndicator(radius: 18))
                  : filteredGreetings.isEmpty
                  ? Center(
                      child: Text(
                        "No circulars found in the archive.",
                        style: TextStyle(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredGreetings.length,
                      itemBuilder: (context, index) {
                        final greeting = filteredGreetings[index];
                        // Find matching language for this greeting (if any)
                        final matchLang = _getMatchingLangForGreeting(greeting);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 25.0),
                          child: GreetingExpandableCard(
                            greetingData: greeting,
                            baseColor: neumoBaseColor,
                            searchQuery: _searchQuery,
                            selectedLang: _selectedLang, // Added parameter
                            matchingLang: matchLang,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class GreetingExpandableCard extends StatefulWidget {
  final Map<String, dynamic> greetingData;
  final Color baseColor;
  final String searchQuery;
  final String
  selectedLang; // Required parameter added for explicit language selection
  final String?
  matchingLang; // Language that matches the search query (null if none)

  const GreetingExpandableCard({
    Key? key,
    required this.greetingData,
    required this.baseColor,
    required this.searchQuery,
    required this.selectedLang,
    this.matchingLang,
  }) : super(key: key);

  @override
  State<GreetingExpandableCard> createState() => _GreetingExpandableCardState();
}

class _GreetingExpandableCardState extends State<GreetingExpandableCard> {
  bool _isExpanded = false;
  int _likes = 0;
  int _views = 0;
  bool _hasLiked = false;
  bool _hasViewed = false;
  bool _isFavorite = false;
  String _greetingId = '';

  @override
  void initState() {
    super.initState();
    _greetingId = widget.greetingData['id'].toString();
    _likes = widget.greetingData['likes'] ?? 0;
    _views = widget.greetingData['views'] ?? 0;
    _loadStatus();
    // Auto‑expand if there's a search match
    if (widget.searchQuery.trim().isNotEmpty && widget.matchingLang != null) {
      _isExpanded = true;
      // Register view once expanded (delayed to avoid build errors)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasViewed) _registerView();
      });
    }
  }

  @override
  void didUpdateWidget(GreetingExpandableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re‑evaluate expansion if search query or matching language changes
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.matchingLang != widget.matchingLang) {
      final shouldExpand =
          widget.searchQuery.trim().isNotEmpty && widget.matchingLang != null;
      if (shouldExpand && !_isExpanded) {
        setState(() => _isExpanded = true);
        if (!_hasViewed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _registerView();
          });
        }
      } else if (!shouldExpand && _isExpanded) {
        setState(() => _isExpanded = false);
      }
    }
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorite_greetings') ?? [];
    List<String> liked = prefs.getStringList('liked_greetings') ?? [];
    List<String> viewed = prefs.getStringList('viewed_greetings') ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favs.contains(_greetingId);
        _hasLiked = liked.contains(_greetingId);
        _hasViewed = viewed.contains(_greetingId);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorite_greetings') ?? [];
    setState(() {
      _isFavorite = !_isFavorite;
      if (_isFavorite) {
        favs.add(_greetingId);
      } else {
        favs.remove(_greetingId);
      }
    });
    await prefs.setStringList('favorite_greetings', favs);
  }

  Future<void> _registerView() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> viewed = prefs.getStringList('viewed_greetings') ?? [];
    if (viewed.contains(_greetingId)) return;

    setState(() {
      _hasViewed = true;
      _views++;
    });
    viewed.add(_greetingId);
    await prefs.setStringList('viewed_greetings', viewed);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/${_greetingId}/view_greeting/',
      );
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _views = data['views']);
      }
    } catch (e) {
      print('Error registering view: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_hasLiked) return;

    setState(() {
      _hasLiked = true;
      _likes++;
    });
    final prefs = await SharedPreferences.getInstance();
    List<String> liked = prefs.getStringList('liked_greetings') ?? [];
    liked.add(_greetingId);
    await prefs.setStringList('liked_greetings', liked);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/${_greetingId}/like/',
      );
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _likes = data['likes']);
      }
    } catch (e) {
      print('Error liking: $e');
    }
  }

  void _shareGreeting() {
    // Get content in the matching language (or selected language)
    final content = _getContent();
    final textToShare =
        "${content['title']}\n\n${content['message']}\n\n-- ${widget.greetingData['apostle']} (${widget.greetingData['year']})\n\nShared via Dankie App";
    Share.share(textToShare, subject: "Apostolic Greeting");
  }

  // Helper to get the appropriate content map (matching lang if available, else selected)
  Map<String, String> _getContent() {
    final contentMap = widget.greetingData['content_json'] is String
        ? jsonDecode(widget.greetingData['content_json'])
        : widget.greetingData['content_json'];

    // Fixed logic: Use matching language if searched, otherwise default to the selected language tab
    final langToUse = widget.matchingLang ?? widget.selectedLang;

    Map<String, dynamic>? langContent = contentMap[langToUse];
    if (langContent == null) {
      // fallback to English if the translation doesn't exist
      langContent = contentMap['en'] ?? {};
    }
    return {
      'title': langContent?['title'] ?? 'Greeting',
      'message': langContent?['message'] ?? '',
    };
  }

  Widget _buildHighlightedText(String text, TextStyle style) {
    final query = widget.searchQuery.trim();
    if (query.isEmpty || text.isEmpty) {
      return Text(text, style: style);
    }

    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(RegExp.escape(query), caseSensitive: false);
    int start = 0;
    for (final match in regExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style.copyWith(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    return Text.rich(TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _getContent();
    String imgUrl =
        widget.greetingData['image_url'] ?? 'assets/profile_placeholder.png';
    bool isNetworkImg = imgUrl.startsWith('http');

    return NeumorphicContainer(
      color: widget.baseColor,
      isPressed: false,
      borderRadius: 25,
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded && !_hasViewed) _registerView();
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NeumorphicContainer(
                  color: widget.baseColor,
                  isPressed: true,
                  borderRadius: 40,
                  padding: EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    backgroundImage: isNetworkImg
                        ? NetworkImage(imgUrl) as ImageProvider
                        : AssetImage(imgUrl),
                    onBackgroundImageError: (e, s) {},
                    child: isNetworkImg
                        ? null
                        : Icon(Icons.person, color: theme.primaryColor),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.greetingData['apostle'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        "${widget.greetingData['role']} • ${widget.greetingData['year']}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.hintColor,
                        ),
                      ),
                      // Show language indicator if we're using matching language
                      if (widget.matchingLang != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${widget.matchingLang!.toUpperCase()} match',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                NeumorphicContainer(
                  color: widget.baseColor,
                  isPressed: _isExpanded,
                  borderRadius: 20,
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: _buildHighlightedText(
              content['title'] ?? 'Greeting',
              TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor.withOpacity(0.85),
                height: 1.3,
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                SizedBox(height: 15),
                NeumorphicContainer(
                  color: widget.baseColor,
                  isPressed: true,
                  borderRadius: 20,
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: theme.primaryColor.withOpacity(0.2),
                        size: 30,
                      ),
                      SizedBox(height: 8),
                      _buildHighlightedText(
                        content['message'] ?? '',
                        TextStyle(
                          fontSize: 14.5,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Divider(color: theme.primaryColor.withOpacity(0.1), thickness: 1.5),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInteractionButton(
                icon: _hasLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: _hasLiked
                    ? Colors.redAccent
                    : theme.primaryColor.withOpacity(0.7),
                count: _likes.toString(),
                onTap: _toggleLike,
                theme: theme,
              ),
              _buildInteractionButton(
                icon: Icons.remove_red_eye_rounded,
                iconColor: theme.hintColor.withOpacity(0.6),
                count: _views.toString(),
                onTap: null,
                theme: theme,
              ),
              _buildInteractionButton(
                icon: _isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                iconColor: _isFavorite
                    ? Colors.orangeAccent
                    : theme.primaryColor.withOpacity(0.7),
                count: "Fav",
                onTap: _toggleFavorite,
                theme: theme,
              ),
              _buildInteractionButton(
                icon: Icons.ios_share_rounded,
                iconColor: theme.primaryColor.withOpacity(0.7),
                count: "Share",
                onTap: _shareGreeting,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color iconColor,
    required String count,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NeumorphicContainer(
        color: widget.baseColor,
        isPressed: false,
        borderRadius: 20,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            SizedBox(width: 6),
            Text(
              count,
              style: TextStyle(
                color: theme.hintColor.withOpacity(0.8),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
