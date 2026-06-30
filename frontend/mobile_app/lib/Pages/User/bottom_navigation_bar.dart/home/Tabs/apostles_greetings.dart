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

// Added AutomaticKeepAliveClientMixin to preserve state when switching tabs
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
    _searchController.dispose(); // Fixed memory leak by disposing controller
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

  List<dynamic> get filteredGreetings {
    if (_searchQuery.isEmpty) return _allGreetings;
    final query = _searchQuery.toLowerCase().trim();
    return _allGreetings.where((greeting) {
      // Search by apostle and year
      final apostle = greeting['apostle'].toString().toLowerCase();
      final year = greeting['year'].toString().toLowerCase();
      if (apostle.contains(query) || year.contains(query)) return true;

      // Search in all language content (title and message)
      final contentMap = greeting['content_json'] is String
          ? jsonDecode(greeting['content_json'])
          : greeting['content_json'];
      if (contentMap is Map) {
        for (final langContent in contentMap.values) {
          if (langContent is Map) {
            final title = langContent['title']?.toString().toLowerCase() ?? '';
            final message =
                langContent['message']?.toString().toLowerCase() ?? '';
            if (title.contains(query) || message.contains(query)) return true;
          }
        }
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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
                          // Implemented debouncing to prevent UI jank while typing
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
                        final Map<String, dynamic> contentMap =
                            greeting['content_json'] is String
                            ? jsonDecode(greeting['content_json'])
                            : greeting['content_json'];
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
  String _greetingId = '';

  @override
  void initState() {
    super.initState();
    _greetingId = widget.greetingData['id'].toString(); // Ensure string
    _likes = widget.greetingData['likes'] ?? 0;
    _views = widget.greetingData['views'] ?? 0;
    _loadStatus();
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
    // Prevent multiple views
    final prefs = await SharedPreferences.getInstance();
    List<String> viewed = prefs.getStringList('viewed_greetings') ?? [];
    if (viewed.contains(_greetingId)) return; // already viewed

    // Update local state
    setState(() {
      _hasViewed = true;
      _views++;
    });
    viewed.add(_greetingId);
    await prefs.setStringList('viewed_greetings', viewed);

    // Send to backend
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
    // Prevent multiple likes
    if (_hasLiked) return;

    // Update local state
    setState(() {
      _hasLiked = true;
      _likes++;
    });
    final prefs = await SharedPreferences.getInstance();
    List<String> liked = prefs.getStringList('liked_greetings') ?? [];
    liked.add(_greetingId);
    await prefs.setStringList('liked_greetings', liked);

    // Send like to backend
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
