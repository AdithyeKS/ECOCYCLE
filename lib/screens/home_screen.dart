import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ecocycle/screens/add_ewaste_screen.dart';
import 'package:ecocycle/screens/add_cloth_screen.dart';
import 'package:ecocycle/screens/add_plastic_screen.dart'; // NEW: Plastic screen import
import 'package:ecocycle/screens/profile_screen.dart';
import 'package:ecocycle/screens/rewards_screen.dart';
import 'package:ecocycle/screens/settings_screen.dart';
import 'package:ecocycle/screens/mission_screen.dart';
import 'package:ecocycle/screens/volunteer_application_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ecocycle/services/profile_service.dart';
import 'package:ecocycle/services/notification_service.dart';
import 'package:ecocycle/core/supabase_config.dart';
import 'package:ecocycle/screens/notifications_screen.dart';

enum MenuOption { volunteer, youtube, profile, settings }

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userRole = 'user';
  DateTime? _volunteerRequestedAt;
  bool _isDataLoading = true;
  final _profileService = ProfileService();
  final _notificationService = NotificationService();
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileStatus();
    _loadUnreadNotificationCount();
  }

  /// Fetches the current user's role and volunteer request status
  Future<void> _loadProfileStatus() async {
    final user = AppSupabase.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isDataLoading = false);
      return;
    }

    try {
      final profile = await _profileService.fetchProfile(user.id);
      if (profile != null && mounted) {
        setState(() {
          _userRole = profile['user_role']?.toString() ?? 'user';
          final requestedAtVal = profile['volunteer_requested_at'];
          if (requestedAtVal != null) {
            _volunteerRequestedAt =
                DateTime.tryParse(requestedAtVal.toString());
          }
          _isDataLoading = false;
        });
      }
    } catch (e) {
      // print(...);
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final userId = AppSupabase.client.auth.currentUser?.id;
      if (userId != null) {
        // Fetch user role
        final profile = await _profileService.fetchProfile(userId);
        final userRole = profile?['user_role'] as String? ?? 'user';

        final count = await _notificationService.getUnreadCount(userId,
            userRole: userRole);
        if (mounted) {
          setState(() {
            _unreadNotificationCount = count;
          });
        }
      }
    } catch (e) {
      // Silently fail, notification count is not critical
    }
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    // Refresh count after returning from notifications screen
    _loadUnreadNotificationCount();
  }

  /// Professional dashboard action card helper
  Widget _actionCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      Color color = Colors.green}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Eco-friendly slideshow card with automatic transitions
  Widget _ecoSlideshowCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  Colors.green.shade900.withValues(alpha: 0.5),
                  Colors.blue.shade900.withValues(alpha: 0.5),
                  Colors.purple.shade900.withValues(alpha: 0.5),
                ]
              : [
                  Colors.green.shade50,
                  Colors.blue.shade50,
                  Colors.purple.shade50,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const EcoSlideshowContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool requestPending =
        _userRole == 'user' && _volunteerRequestedAt != null;
    final bool canRequestVolunteer =
        _userRole == 'user' && _volunteerRequestedAt == null && !_isDataLoading;

    return Scaffold(
      appBar: AppBar(
        leading: PopupMenuButton<MenuOption>(
          icon: const Icon(Icons.menu),
          onSelected: (MenuOption result) async {
            switch (result) {
              case MenuOption.volunteer:
                _open(context, const VolunteerApplicationScreen());
                break;
              case MenuOption.youtube:
                // Open YouTube video in external browser/app
                const youtubeUrl =
                    'https://www.youtube.com/watch?v=MQLadfsvfLo';
                final uri = Uri.parse(youtubeUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr('could_not_launch_youtube'))),
                  );
                }
                break;
              case MenuOption.profile:
                _open(context, const ProfileScreen());
                break;
              case MenuOption.settings:
                _open(context, SettingsScreen(toggleTheme: widget.toggleTheme));
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<MenuOption>>[
            if (canRequestVolunteer)
              PopupMenuItem<MenuOption>(
                value: MenuOption.volunteer,
                child: Row(
                  children: [
                    Icon(Icons.volunteer_activism, color: Colors.yellow[800]),
                    const SizedBox(width: 8),
                    Text(tr('become_volunteer')),
                  ],
                ),
              ),
            PopupMenuItem<MenuOption>(
              value: MenuOption.youtube,
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill, color: Colors.red),
                  SizedBox(width: 8),
                  Text(tr('youtube_demo')),
                ],
              ),
            ),
            PopupMenuItem<MenuOption>(
              value: MenuOption.profile,
              child: Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: 8),
                  Text(tr('profile')),
                ],
              ),
            ),
            PopupMenuItem<MenuOption>(
              value: MenuOption.settings,
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text(tr('settings')),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          tr('app_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        flexibleSpace: Theme.of(context).brightness == Brightness.dark
            ? null
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF60AD5E)],
                  ),
                ),
              ),
        actions: [
          if (canRequestVolunteer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AnimatedVolunteerIcon(
                onPressed: () =>
                    _open(context, const VolunteerApplicationScreen()),
              ),
            )
          else if (requestPending)
            Tooltip(
              message: tr('application_pending_review'),
              child: IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('application_pending_review'))),
                ),
                icon: const Icon(Icons.hourglass_empty, color: Colors.orange),
              ),
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _openNotifications,
                tooltip: tr('notifications'),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 9
                          ? '9+'
                          : _unreadNotificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: widget.toggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Dashboard Welcome Section
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/ecocycle.png',
                      width: 64, height: 64),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('hello'),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(tr('welcome_msg'),
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ECO SLIDESHOW CARD: Dynamic content carousel
            _ecoSlideshowCard(context),
            const SizedBox(height: 24),

            // E-WASTE CARD: Direct to Add E-Waste
            _actionCard(
              context,
              icon: Icons.electric_bolt,
              title: tr('ewaste'),
              subtitle: tr('add_ewaste_sub'),
              color: Colors.deepOrange,
              onTap: () => _open(context, const AddEwasteScreen()),
            ),
            const SizedBox(height: 12),

            // CLOTHES CARD: Direct to Add Cloth
            _actionCard(
              context,
              icon: Icons.shopping_bag_outlined,
              title: tr('cloth'),
              subtitle: tr('add_cloth_sub'),
              color: Colors.indigo,
              onTap: () => _open(context, const AddClothScreen()),
            ),
            const SizedBox(height: 12),

            // PLASTIC WASTE CARD: Direct to Add Plastic
            _actionCard(
              context,
              icon: Icons.opacity,
              title: tr('plastic_waste'),
              subtitle: tr('recycle_bottles_containers'),
              color: Colors.blue,
              onTap: () => _open(context, const AddPlasticScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eco-friendly slideshow content with automatic transitions
class EcoSlideshowContent extends StatefulWidget {
  const EcoSlideshowContent({super.key});

  @override
  State<EcoSlideshowContent> createState() => _EcoSlideshowContentState();
}

class _EcoSlideshowContentState extends State<EcoSlideshowContent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;
  late List<Map<String, dynamic>> _slides;

  final List<Map<String, dynamic>> _motivations = [
    {
      'title': tr('motivation_reduce_reuse_recycle'),
      'subtitle': tr('motivation_three_rs'),
      'icon': Icons.refresh,
      'color': Colors.green,
      'action': tr('start_today'),
    },
    {
      'title': tr('motivation_waste_not'),
      'subtitle': tr('motivation_recycle_difference'),
      'icon': Icons.recycling,
      'color': Colors.blue,
      'action': tr('recycle_now'),
    },
    {
      'title': tr('motivation_think_global'),
      'subtitle': tr('motivation_local_global'),
      'icon': Icons.public,
      'color': Colors.purple,
      'action': tr('take_action'),
    },
    {
      'title': tr('motivation_nature_hurry'),
      'subtitle': tr('motivation_accomplished_lao'),
      'icon': Icons.park,
      'color': Colors.green,
      'action': tr('be_patient'),
    },
    {
      'title': tr('motivation_greatest_threat'),
      'subtitle': tr('motivation_belief_save'),
      'icon': Icons.warning,
      'color': Colors.red,
      'action': tr('act_now'),
    },
    {
      'title': tr('motivation_no_society'),
      'subtitle': tr('motivation_destroy_environment'),
      'icon': Icons.groups,
      'color': Colors.teal,
      'action': tr('protect_earth'),
    },
    {
      'title': tr('motivation_environment_meet'),
      'subtitle': tr('motivation_mutual_interest'),
      'icon': Icons.handshake,
      'color': Colors.orange,
      'action': tr('unite'),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeSlides();
    _startAutoSlide();
  }

  void _initializeSlides() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final dailyMotivation = _motivations[dayOfYear % _motivations.length];

    _slides = [
      {
        'title': tr('slideshow_title_1'),
        'subtitle': tr('slideshow_sub_1'),
        'icon': Icons.eco,
        'color': Colors.green,
        'action': tr('slideshow_action_1'),
      },
      {
        'title': tr('slideshow_title_2'),
        'subtitle': tr('slideshow_sub_2'),
        'icon': Icons.electric_bolt,
        'color': Colors.orange,
        'action': tr('slideshow_action_2'),
      },
      {
        'title': dailyMotivation['title'],
        'subtitle': dailyMotivation['subtitle'],
        'icon': dailyMotivation['icon'],
        'color': dailyMotivation['color'],
        'action': dailyMotivation['action'],
      },
      {
        'title': tr('slideshow_title_4'),
        'subtitle': tr('slideshow_sub_4'),
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'action': tr('slideshow_action_4'),
      },
      {
        'title': tr('slideshow_title_5'),
        'subtitle': tr('slideshow_sub_5'),
        'icon': Icons.track_changes,
        'color': Colors.teal,
        'action': tr('slideshow_action_5'),
      },
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _slides.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemCount: _slides.length,
          itemBuilder: (context, index) {
            final slide = _slides[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: slide['color'].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      slide['icon'],
                      color: slide['color'],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          slide['title'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: slide['color'].withValues(alpha: 0.9),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slide['subtitle'],
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 28,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              backgroundColor:
                                  slide['color'].withValues(alpha: 0.1),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              final action =
                                  slide['action']?.toString().toLowerCase() ??
                                      '';
                              if (action.contains('mission')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MissionScreen(),
                                  ),
                                );
                              } else if (action.contains('join us')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const VolunteerApplicationScreen(),
                                  ),
                                );
                              } else if (action.contains('view progress') ||
                                  action.contains('track your impact')) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RewardsScreen(),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(tr('action_not_implemented',
                                          namedArgs: {
                                        'action': slide['action']
                                      }))),
                                );
                              }
                            },
                            child: Text(
                              slide['action'],
                              style: TextStyle(
                                color: slide['color'],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Page indicators
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Volunteer Icon with Heartbeat Pulse + Soft Glow
class AnimatedVolunteerIcon extends StatefulWidget {
  final VoidCallback onPressed;

  const AnimatedVolunteerIcon({super.key, required this.onPressed});

  @override
  State<AnimatedVolunteerIcon> createState() => _AnimatedVolunteerIconState();
}

class _AnimatedVolunteerIconState extends State<AnimatedVolunteerIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Heartbeat animation controller - smooth 2.5 second cycle
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    // Gentle pulse scale (1.0 → 1.06)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Soft glow opacity (0.7 → 1.0)
    _glowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return IconButton(
            onPressed: widget.onPressed,
            icon: Icon(
              Icons.volunteer_activism,
              color: Color(0xFFFFF9C4).withValues(alpha: _glowAnimation.value),
              shadows: [
                Shadow(
                  color: Color(0xFFFFF59D)
                      .withValues(alpha: _glowAnimation.value * 0.6),
                  blurRadius: 8,
                ),
                Shadow(
                  color: Color(0xFFFFF9C4)
                      .withValues(alpha: _glowAnimation.value * 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            tooltip: tr('become_volunteer'),
          );
        },
      ),
    );
  }
}
