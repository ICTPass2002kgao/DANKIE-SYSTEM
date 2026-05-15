// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// YOUR PROJECT IMPORTS
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class ApostlesGreetings extends StatefulWidget {
  const ApostlesGreetings({super.key});

  @override
  State<ApostlesGreetings> createState() => _ApostlesGreetingsState();
}

class _ApostlesGreetingsState extends State<ApostlesGreetings> {
  String _selectedLang = 'en';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
        setState(() {
          _allGreetings = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Fetch error: $e');
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get filteredGreetings {
    if (_searchQuery.isEmpty) return _allGreetings;
    final query = _searchQuery.toLowerCase();
    return _allGreetings.where((greeting) {
      final apostle = greeting['apostle'].toString().toLowerCase();
      final year = greeting['year'].toString().toLowerCase();
      return apostle.contains(query) || year.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
            // NEUMORPHIC SEARCH BAR
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10.0,
              ),
              child: NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: true, // Inset effect to look like an input field
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
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search by Apostle or Year...',
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

            // NEUMORPHIC LANGUAGE SELECTOR
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
                          isPressed: isSelected, // Pressed down when active
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

            // PREMIUM NEUMORPHIC TOP HEADER
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

            // LIST OF GREETINGS
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

                        // Safe cast for JSON handling
                        final Map<String, dynamic> contentMap =
                            greeting['content_json'] is String
                            ? jsonDecode(greeting['content_json'])
                            : greeting['content_json'];

                        // Language Fallback
                        Map<String, dynamic>? localizedContent =
                            contentMap[_selectedLang];
                        if (localizedContent == null) {
                          localizedContent =
                              contentMap['en'] ?? contentMap['zu'];
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 25.0),
                          child: GreetingExpandableCard(
                            greetingData: greeting,
                            localizedContent: localizedContent!
                                .cast<String, String>(),
                            baseColor: neumoBaseColor,
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

// =======================================================================
// CUSTOM EXPANDABLE GREETING CARD (Premium Neumorphic Design)
// =======================================================================

class GreetingExpandableCard extends StatefulWidget {
  final Map<String, dynamic> greetingData;
  final Map<String, String> localizedContent;
  final Color baseColor;

  const GreetingExpandableCard({
    Key? key,
    required this.greetingData,
    required this.localizedContent,
    required this.baseColor,
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

  @override
  void initState() {
    super.initState();
    _likes = widget.greetingData['likes'] ?? 0;
    _views = widget.greetingData['views'] ?? 0;
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorite_greetings') ?? [];
    List<String> liked = prefs.getStringList('liked_greetings') ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favs.contains(widget.greetingData['id']);
        _hasLiked = liked.contains(widget.greetingData['id']);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorite_greetings') ?? [];

    setState(() {
      _isFavorite = !_isFavorite;
      if (_isFavorite) {
        favs.add(widget.greetingData['id']);
      } else {
        favs.remove(widget.greetingData['id']);
      }
    });

    await prefs.setStringList('favorite_greetings', favs);
  }

  Future<void> _registerView() async {
    if (_hasViewed) return;
    _hasViewed = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/${widget.greetingData['id']}/view_greeting/',
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
    if (_hasLiked) return; // Prevent multi-likes for UI purity

    setState(() {
      _hasLiked = true;
      _likes++;
    });

    final prefs = await SharedPreferences.getInstance();
    List<String> liked = prefs.getStringList('liked_greetings') ?? [];
    liked.add(widget.greetingData['id']);
    await prefs.setStringList('liked_greetings', liked);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/${widget.greetingData['id']}/like/',
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
    final textToShare =
        "${widget.localizedContent['title']}\n\n${widget.localizedContent['message']}\n\n-- ${widget.greetingData['apostle']} (${widget.greetingData['year']})\n\nShared via Dankie App";
    Share.share(textToShare, subject: "Apostolic Greeting");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          // HEADER ROW (Profile, Name, Toggle Button)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
              if (_isExpanded) _registerView();
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

          // TITLE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0),
            child: Text(
              widget.localizedContent['title'] ?? 'Greeting',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.primaryColor.withOpacity(0.85),
                height: 1.3,
              ),
            ),
          ),

          // EXPANDABLE TEXT CONTENT
          AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: SizedBox(width: double.infinity), // Collapsed state
            secondChild: Column(
              children: [
                SizedBox(height: 15),
                NeumorphicContainer(
                  color: widget.baseColor,
                  isPressed: true, // Inset text area for readability
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
                      Text(
                        widget.localizedContent['message'] ?? '',
                        style: TextStyle(
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

          // NEUMORPHIC TACTILE ACTIONS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // LIKE
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

              // VIEWS (Non-clickable, but styled identically)
              _buildInteractionButton(
                icon: Icons.remove_red_eye_rounded,
                iconColor: theme.hintColor.withOpacity(0.6),
                count: _views.toString(),
                onTap: null,
                theme: theme,
              ),

              // FAVORITE
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

              // SHARE
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

  // Helper widget for the tactile bottom buttons
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
