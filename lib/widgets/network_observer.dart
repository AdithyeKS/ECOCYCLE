import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class NetworkObserver extends StatefulWidget {
  final Widget child;

  const NetworkObserver({super.key, required this.child});

  @override
  State<NetworkObserver> createState() => _NetworkObserverState();
}

class _NetworkObserverState extends State<NetworkObserver>
    with TickerProviderStateMixin {
  bool _isConnected = true;
  bool _showBanner = false;
  Timer? _hideBannerTimer;
  StreamSubscription<InternetStatus>? _subscription;

  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOut,
    ));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _subscription =
        InternetConnection().onStatusChange.listen((InternetStatus status) {
      if (!mounted) return;
      final isConnected = status == InternetStatus.connected;
      if (_isConnected == isConnected) return;

      setState(() {
        _isConnected = isConnected;
        _showBanner = true;
      });

      _hideBannerTimer?.cancel();
      _slideController?.forward(from: 0);

      if (isConnected) {
        _hideBannerTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _slideController?.reverse().then((_) {
              if (mounted) {
                setState(() => _showBanner = false);
              }
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _hideBannerTimer?.cancel();
    _subscription?.cancel();
    _slideController?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // ── Main app content ──────────────────────────────────────
          widget.child,

          // ── Full-screen offline blocker ───────────────────────────
          if (!_isConnected)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing wifi-off icon
                        if (_pulseAnimation != null)
                          FadeTransition(
                            opacity: _pulseAnimation!,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    Colors.red.shade700.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: Colors.red.shade400,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.wifi_off_rounded,
                                size: 48,
                                color: Colors.red.shade300,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          'No Internet Connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Please check your Wi-Fi or mobile data\nand try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Slide-in top banner (disconnected / reconnected) ──────
          if (_showBanner && _slideAnimation != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation!,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isConnected
                          ? Colors.green.shade600
                          : Colors.red.shade700,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isConnected
                                ? Colors.greenAccent.shade100
                                : Colors.red.shade200,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          _isConnected
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _isConnected
                                ? '✓  Reconnected – You\'re back online!'
                                : 'No Internet Connection',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        if (_isConnected) const SizedBox(width: 10),
                        if (_isConnected)
                          GestureDetector(
                            onTap: () {
                              _hideBannerTimer?.cancel();
                              _slideController?.reverse().then((_) {
                                if (mounted) {
                                  setState(() => _showBanner = false);
                                }
                              });
                            },
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
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
