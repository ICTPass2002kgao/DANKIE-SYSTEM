// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'dart:convert'; // For parsing JSON
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ttact/Components/API.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http; // Connect to Django
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED FOR SECURE TOKEN
import 'package:ttact/Components/NeuDesign.dart';

class FindNearbyBranch extends StatefulWidget {
  const FindNearbyBranch({super.key});

  @override
  State<FindNearbyBranch> createState() => _FindNearbyBranchState();
}

class _FindNearbyBranchState extends State<FindNearbyBranch> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  bool _isLoading = true;
  List<dynamic> _nearestCommunities = []; // Store the top 5 nearest communities

  // Default fallback (Polokwane/Limpopo for testing if GPS fails completely)
  static const LatLng _defaultLocation = LatLng(-23.8962, 29.4486);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // 1. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Even if denied, try to load map with communities based on default location
        _currentPosition = _defaultLocation;
        _fetchCommunitiesFromDjango();
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2. Get User Position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }

      // 3. Fetch Data from Django
      _fetchCommunitiesFromDjango();
    } catch (e) {
      print("GPS Error: $e");
      // Still fetch communities even if GPS fails, using default location
      _currentPosition = _defaultLocation;
      _fetchCommunitiesFromDjango();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> addresses = [];
  Future<void> _fetchCommunitiesFromDjango() async {
    try {
      // SECURE FIX: Grab the current user and their token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Blocked: No user is currently logged in.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String? token = await user.getIdToken();
      if (token == null) {
        print("❌ Blocked: Could not retrieve Firebase token.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // REPLACE WITH YOUR ACTUAL DJANGO IP ADDRESS
      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/');

      // SECURE FIX: Attach the Authorization header
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        Set<Marker> newMarkers = {};

        LatLng referencePosition = _currentPosition ?? _defaultLocation;

        // Calculate distance for each community
        List<Map<String, dynamic>> processedData = [];
        for (var item in data) {
          if (item['latitude'] != null && item['longitude'] != null) {
            double lat = (item['latitude'] as num).toDouble();
            double lng = (item['longitude'] as num).toDouble();

            double distanceInMeters = Geolocator.distanceBetween(
              referencePosition.latitude,
              referencePosition.longitude,
              lat,
              lng,
            );

            // Create a new map to safely add the distance without modifying immutable dynamic types
            Map<String, dynamic> communityData = Map<String, dynamic>.from(
              item,
            );
            communityData['distance'] = distanceInMeters;
            processedData.add(communityData);
          }
        }

        // Sort by distance (closest first)
        processedData.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );

        // Take only the top 5 nearest communities
        List<Map<String, dynamic>> top5Communities = processedData
            .take(5)
            .toList();

        // 1. Add Marker for the User's Current Location (Blue color to distinguish)
        if (_currentPosition != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('user_current_location'),
              position: _currentPosition!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue, // Set explicitly to Blue
              ),
              infoWindow: const InfoWindow(
                title: 'Your Location',
                snippet: 'You are here',
              ),
              zIndex: 2, // Ensure it shows above other markers
            ),
          );
        }

        // 2. Add Markers ONLY for the top 5 nearest communities (Purple/Violet color)
        for (var item in top5Communities) {
          double lat = (item['latitude'] as num).toDouble();
          double lng = (item['longitude'] as num).toDouble();
          String name = item['community_name'] ?? "Unknown Branch";
          String districtName = item['district_elder_name'] ?? '';
          // String overseer = item['overseer_initials_surname'] ?? '';

          // BUG FIX: Generate a strict unique ID since Django doesn't send the DB 'id'
          String uniqueMarkerId =
              item['id']?.toString() ?? "${name}_${lat}_${lng}";

          newMarkers.add(
            Marker(
              markerId: MarkerId(uniqueMarkerId),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet, // Set explicitly to Purple/Violet
              ),
              infoWindow: InfoWindow(
                title: '$name ($districtName)',
                snippet: "Tap for Directions",
                onTap: () => _launchNavigation(lat, lng),
              ),
            ),
          );
        }

        if (mounted) {
          setState(() {
            addresses = processedData;
            _nearestCommunities = top5Communities;
            _markers = newMarkers;
          });

          // Once data is loaded, try to focus the camera
          _zoomToUserOrFitMarkers();
        }
      } else {
        print("Django Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("API Connection Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SMART ZOOM LOGIC ---
  void _zoomToUserOrFitMarkers() {
    if (_mapController == null) return;

    // We now prioritize fitting both the user AND the nearby markers in view
    if (_markers.isNotEmpty) {
      List<LatLng> points = _markers.map((m) => m.position).toList();

      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (var point in points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          80, // Padding
        ),
      );
    } else if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 14.0),
        ),
      );
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      // Fallback for devices without Google Maps app
      final Uri browserUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
      );
      await launchUrl(browserUrl, mode: LaunchMode.inAppBrowserView);
    }
  }

  // --- UI BUILDER METHODS ---

  Widget _buildIntroCard(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.location_solid,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'New to the area?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Don\'t worry, Dankie will assist you in finding the nearest branch seamlessly.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContainer(ThemeData theme, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: _isLoading
            ? Center(
                child: Api().isIOSPlatform
                    ? CupertinoActivityIndicator(radius: 16)
                    : CircularProgressIndicator(
                        strokeWidth: 3,
                        color: theme.primaryColor,
                      ),
              )
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? _defaultLocation,
                  zoom: 14,
                ),
                markers: _markers,
                myLocationEnabled:
                    false, // Turned off native blue dot to rely on custom Blue marker
                myLocationButtonEnabled: true,
                mapType: MapType.satellite,
                zoomControlsEnabled: false, // Cleaner look
                compassEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _zoomToUserOrFitMarkers();
                },
              ),
      ),
    );
  }

  Widget _buildNearestList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Top 5 Nearest Branches",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            Icon(CupertinoIcons.list_bullet, color: Colors.grey[400], size: 20),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: Center(
              child: Column(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    "Calculating distances...",
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else if (_nearestCommunities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: Center(
              child: Text(
                "No nearby branches found.",
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
              ),
            ),
          )
        else
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _nearestCommunities.length,
            itemBuilder: (context, index) {
              final item = _nearestCommunities[index];
              double distanceInKm = item['distance'] / 1000;

              final Color neumoBaseColor = Color.alphaBlend(
                theme.primaryColor.withOpacity(0.08),
                theme.scaffoldBackgroundColor,
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: neumoBaseColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(3, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (item['latitude'] != null &&
                          item['longitude'] != null) {
                        _launchNavigation(
                          (item['latitude'] as num).toDouble(),
                          (item['longitude'] as num).toDouble(),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [ 
                          Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.location_on_rounded,
                                color: theme.primaryColor,
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['community_name'] ?? "Unknown Branch",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['district_elder_name'] ??
                                      'No District Data',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Right Distance & Button
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${distanceInKm.toStringAsFixed(1)} km",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  "Navigate",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Desktop / Tablet Landscape Layout
          if (constraints.maxWidth > 800) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 40.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Map
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Interactive Map",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMapContainer(theme, 650),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIntroCard(context, theme),
                          const SizedBox(height: 40),
                          _buildNearestList(theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    _buildIntroCard(context, theme),
                    const SizedBox(height: 32),
                    Text(
                      "Interactive Map",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMapContainer(
                      theme,
                      450,
                    ), // slightly taller on mobile for better view
                    const SizedBox(height: 36),
                    _buildNearestList(theme),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
