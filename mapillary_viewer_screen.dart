import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapillaryViewerScreen extends StatefulWidget {
  final String placeTitle;
  final String mapillaryImageId;
  final String clientToken;

  const MapillaryViewerScreen({
    super.key,
    required this.placeTitle,
    required this.mapillaryImageId,
    this.clientToken = 'MLY|YOUR_CLIENT_TOKEN_HERE',
  });

  @override
  State<MapillaryViewerScreen> createState() => _MapillaryViewerScreenState();
}

class _MapillaryViewerScreenState extends State<MapillaryViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isMotionEnabled = true;
  bool _isWebViewReady = false;

  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  DateTime? _lastGyroTime;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startGyroscope();
  }

  @override
  void dispose() {
    _stopGyroscope();
    super.dispose();
  }

  void _startGyroscope() {
    _gyroSubscription?.cancel();
    _lastGyroTime = null;

    _gyroSubscription = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
      (GyroscopeEvent event) {
        if (!_isMotionEnabled || !_isWebViewReady || _isLoading) return;

        final now = DateTime.now();
        if (_lastGyroTime == null) {
          _lastGyroTime = now;
          return;
        }

        final double dt = (now.difference(_lastGyroTime!).inMicroseconds) / 1000000.0;
        _lastGyroTime = now;

        // Skip abnormal gaps or tiny sensor noise
        if (dt > 0.2) return;
        if (event.y.abs() < 0.008 && event.x.abs() < 0.008) return;

        // Enhanced sensitivity multiplier for comfortable mobile wrist movement
        const double horizontalSensitivity = 2.5; // Significantly increased horizontal amplitude 陀螺仪的移动幅度与灵敏度显著提高
        const double verticalSensitivity = 1.8;   // Increased vertical pitch amplitude

        // event.y = Yaw (turning phone left/right around vertical axis in portrait mode)
        final double deltaX = -(event.y * dt) / (2.0 * 3.141592653589793) * horizontalSensitivity;

        // event.x = Pitch (tilting phone up/down)
        final double deltaY = (event.x * dt) / (3.141592653589793) * verticalSensitivity;

        _controller.runJavaScript('if(window.onGyroDelta) window.onGyroDelta($deltaX, $deltaY);');
      },
      onError: (e) {
        debugPrint('Gyroscope error: $e');
      },
    );
  }

  void _stopGyroscope() {
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
    _lastGyroTime = null;
  }

  void _initWebView() {
    final String htmlContent = _generateMapillaryHtml(
      imageId: widget.mapillaryImageId,
      clientToken: widget.clientToken,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isWebViewReady = true;
              });
              _controller.runJavaScript('if(window.setMotionEnabled) window.setMotionEnabled($_isMotionEnabled);');
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Mapillary WebView Error: ${error.description}');
          },
        ),
      )
      ..loadHtmlString(htmlContent);
  }

  void _toggleMotion() {
    setState(() {
      _isMotionEnabled = !_isMotionEnabled;
    });

    if (_isMotionEnabled) {
      _startGyroscope();
    } else {
      _stopGyroscope();
    }

    _controller.runJavaScript('if(window.setMotionEnabled) window.setMotionEnabled($_isMotionEnabled);');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        backgroundColor: _isMotionEnabled ? const Color(0xFF304FFE) : Colors.grey[850],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              _isMotionEnabled ? Icons.screen_rotation : Icons.touch_app,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isMotionEnabled
                    ? 'Motion Mode ON: Move phone to look around'
                    : 'Motion Mode OFF: Drag with finger to look around',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generates the HTML embedding MapillaryJS v4.1.0 with direct JavaScript gyro listener
  String _generateMapillaryHtml({
    required String imageId,
    required String clientToken,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>Mapillary In-App Viewer</title>
  
  <!-- Mapillary JS & CSS v4.1.0 via unpkg CDN -->
  <link href="https://unpkg.com/mapillary-js@4.1.0/dist/mapillary.css" rel="stylesheet" />
  <script src="https://unpkg.com/mapillary-js@4.1.0/dist/mapillary.js"></script>
  
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #000000;
      user-select: none;
      -webkit-user-select: none;
    }
    #mly {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div id="mly"></div>

  <script>
    let viewer = null;
    let isMotionEnabled = true;
    let isTouching = false;
    let isUpdating = false;

    let currentCenterX = 0.5;
    let currentCenterY = 0.5;
    let isCenterInitialized = false;

    document.addEventListener('DOMContentLoaded', () => {
      try {
        const { Viewer } = mapillary;
        viewer = new Viewer({
          accessToken: '$clientToken',
          container: 'mly',
          imageId: '$imageId',
          component: {
            cover: false,
            direction: true,
            sequence: true,
          }
        });

        // Initialize orientation baseline once viewer finishes loading
        setTimeout(syncCenter, 1000);

        // Bind touch/mouse events on container to preserve manual drag seamlessly
        const container = document.getElementById('mly');
        if (container) {
          container.addEventListener('touchstart', () => {
            isTouching = true;
          }, { passive: true });

          container.addEventListener('touchend', () => {
            isTouching = false;
            setTimeout(syncCenter, 100);
          }, { passive: true });

          container.addEventListener('mousedown', () => {
            isTouching = true;
          });

          container.addEventListener('mouseup', () => {
            isTouching = false;
            setTimeout(syncCenter, 100);
          });
        }
      } catch (err) {
        console.error("Mapillary init failed:", err);
      }
    });

    function syncCenter() {
      if (!viewer) return;
      try {
        viewer.getCenter().then(center => {
          if (center && center.length >= 2) {
            currentCenterX = center[0];
            currentCenterY = center[1];
            isCenterInitialized = true;
          }
        }).catch(() => {});
      } catch (e) {}
    }

    // Called from Flutter sensors_plus stream in real-time
    window.onGyroDelta = function(deltaX, deltaY) {
      if (!isMotionEnabled || isTouching || !viewer) return;

      if (!isCenterInitialized) {
        syncCenter();
        return;
      }

      currentCenterX = (currentCenterX + deltaX) % 1.0;
      if (currentCenterX < 0) currentCenterX += 1.0;

      currentCenterY = Math.max(0.08, Math.min(0.92, currentCenterY + deltaY));

      if (!isUpdating) {
        isUpdating = true;
        requestAnimationFrame(() => {
          try {
            viewer.setCenter([currentCenterX, currentCenterY]);
          } catch (err) {}
          isUpdating = false;
        });
      }
    };

    window.setMotionEnabled = function(enabled) {
      isMotionEnabled = Boolean(enabled);
      if (isMotionEnabled) {
        syncCenter();
      }
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.placeTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'In-App 360° Mapillary Viewer',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading 360° Panorama...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

          // Gyroscope / Motion Mode toggle button placed right below the grey sequence arrow box
          if (!_isLoading)
            Positioned(
              top: 52,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleMotion,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isMotionEnabled
                            ? const Color(0xFFFFEA00) // Colors.yellowAccent[400]
                            : Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isMotionEnabled
                              ? const Color(0xFFFFEA00)
                              : Colors.white54,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isMotionEnabled ? Icons.screen_rotation : Icons.touch_app,
                            color: _isMotionEnabled ? Colors.black : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isMotionEnabled ? 'Gyroscope: ON' : 'Gyroscope: OFF',
                            style: TextStyle(
                              fontFamily: 'Roboto Mono',
                              color: _isMotionEnabled ? Colors.black : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Floating helper hint banner at the bottom
          if (!_isLoading)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMotionEnabled ? Icons.screen_rotation : Icons.touch_app,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isMotionEnabled
                              ? 'Move phone or drag to look around 360°'
                              : 'Drag with finger to look around 360°',
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
