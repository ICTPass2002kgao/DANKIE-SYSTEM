// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ttact/Components/API.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/NeuDesign.dart';

class FindNearbyBranch extends StatefulWidget {
  const FindNearbyBranch({super.key});

  @override
  State<FindNearbyBranch> createState() => _FindNearbyBranchState();
}

class _FindNearbyBranchState extends State<FindNearbyBranch>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _mapLoadError = false; // Flag for map failure
  List<dynamic> _nearestCommunities = [];
  static const LatLng _defaultLocation = LatLng(-23.8962, 29.4486);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _currentPosition = _defaultLocation;
        _fetchCommunitiesFromDjango();
        setState(() => _isLoading = false);
        return;
      }
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print("GPS Error: $e");
      _currentPosition = _defaultLocation;
      if (mounted) setState(() => _isLoading = false);
    }
    _fetchCommunitiesFromDjango();
  }

  Future<void> _fetchCommunitiesFromDjango() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      String? token = await user.getIdToken();
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final url = Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/communities/');
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
            Map<String, dynamic> communityData = Map<String, dynamic>.from(item);
            communityData['distance'] = distanceInMeters;
            processedData.add(communityData);
          }
        }

        processedData.sort(
            (a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        List<Map<String, dynamic>> top5Communities =
            processedData.take(5).toList();

        if (_currentPosition != null) {
          newMarkers.add(
            Marker(
              markerId: const MarkerId('user_current_location'),
              position: _currentPosition!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
              infoWindow: const InfoWindow(
                title: 'Your Location',
                snippet: 'You are here',
              ),
              zIndex: 2,
            ),
          );
        }

        for (var item in top5Communities) {
          double lat = (item['latitude'] as num).toDouble();
          double lng = (item['longitude'] as num).toDouble();
          String name = item['community_name'] ?? "Unknown Branch";
          String districtName = item['district_elder_name'] ?? '';
          String uniqueMarkerId =
              item['id']?.toString() ?? "${name}_${lat}_${lng}";

          newMarkers.add(
            Marker(
              markerId: MarkerId(uniqueMarkerId),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
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
            _nearestCommunities = top5Communities;
            _markers = newMarkers;
          });
          _zoomToUserOrFitMarkers();
        }
      }
    } catch (e) {
      print("API Connection Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _zoomToUserOrFitMarkers() {
    if (_mapController == null) return;
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
          80,
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
      final Uri browserUrl = Uri.parse(
          "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
      await launchUrl(browserUrl, mode: LaunchMode.inAppBrowserView);
    }
  }

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
        child: _mapLoadError
            ? _buildFallbackMapError(theme)
            : _isLoading
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
                    myLocationEnabled: false,
                    myLocationButtonEnabled: true,
                    mapType: MapType.satellite,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    // Safe gesture recognizers (single factory)
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _zoomToUserOrFitMarkers();
                      // If map loaded, clear error flag
                      if (_mapLoadError) {
                        setState(() => _mapLoadError = false);
                      }
                    },
                    
                  ),
      ),
    );
  }

  Widget _buildFallbackMapError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.map_pin_slash, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Map unavailable',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your internet connection\nor verify the Google Maps API key.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _mapLoadError = false;
                _isLoading = true;
              });
              // Re-fetch and re-initialize map
              _fetchCommunitiesFromDjango();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Timer to detect if map failed to load
  void _startMapLoadTimer() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _mapController == null && !_isLoading) {
        setState(() {
          _mapLoadError = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    // Start timer only if not loading and map not loaded
    if (!_isLoading && _mapController == null && !_mapLoadError) {
      _startMapLoadTimer();
    }

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 40.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    horizontal: 20.0, vertical: 24.0),
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
                    _buildMapContainer(theme, 450),
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

  // Helper widget for nearest branches list (unchanged)
  Widget _buildNearestList(ThemeData theme) {
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );
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
            Icon(CupertinoIcons.list_bullet,
                color: Colors.grey[400], size: 20),
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
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(0.3),
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
}