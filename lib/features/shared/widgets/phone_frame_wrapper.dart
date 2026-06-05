import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps the entire app in a phone-ratio container when running on
/// desktop or web, so the app looks like a native mobile app.
class PhoneFrameWrapper extends StatelessWidget {
  const PhoneFrameWrapper({super.key, required this.child});

  final Widget child;

  // Phone aspect ratio: 9:19.5 (similar to modern Android/iPhone)
  static const double _phoneWidth = 390.0;
  static const double _phoneHeight = 844.0;
  static const double _phoneAspectRatio = _phoneWidth / _phoneHeight;

  @override
  Widget build(BuildContext context) {
    // On real mobile devices, just show the app normally
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.macOS &&
        defaultTargetPlatform != TargetPlatform.windows &&
        defaultTargetPlatform != TargetPlatform.linux) {
      return child;
    }

    // Use Directionality (not Scaffold) so we don't need MaterialApp ancestor
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0A0A0A),
        child: SizedBox.expand(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableH = constraints.maxHeight - 32;
                final double availableW = constraints.maxWidth - 32;

                double frameH = availableH;
                double frameW = frameH * _phoneAspectRatio;

                if (frameW > availableW) {
                  frameW = availableW;
                  frameH = frameW / _phoneAspectRatio;
                }

                // Cap at max phone size
                if (frameW > _phoneWidth * 1.2) {
                  frameW = _phoneWidth * 1.2;
                  frameH = frameW / _phoneAspectRatio;
                }

                return Container(
                  width: frameW + 16,
                  height: frameH + 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(52),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 60,
                        spreadRadius: 10,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.05),
                        blurRadius: 1,
                        spreadRadius: 0,
                        offset: const Offset(0, -1),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF3A3A3C),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Stack(
                      children: [
                        // App content
                        SizedBox(
                          width: frameW,
                          height: frameH,
                          child: MediaQuery(
                            data: MediaQueryData(
                              size: Size(frameW, frameH),
                              padding: const EdgeInsets.only(top: 44, bottom: 34),
                              viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                              devicePixelRatio: 2.0,
                            ),
                            child: child,
                          ),
                        ),

                        // Dynamic Island / Notch
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),

                        // Home indicator bar at bottom
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 130,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
