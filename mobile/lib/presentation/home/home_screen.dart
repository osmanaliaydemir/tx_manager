import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:tx_manager_mobile/core/theme/app_theme.dart';
import 'package:tx_manager_mobile/data/repositories/suggestion_repository.dart';
import 'package:tx_manager_mobile/domain/entities/content_suggestion.dart';
import 'package:tx_manager_mobile/domain/entities/user_profile.dart';
import 'package:tx_manager_mobile/data/repositories/user_repository.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final CardSwiperController controller = CardSwiperController();
  late AnimationController _animController;

  List<ContentSuggestion> _suggestions = [];
  bool _isLoading = true;
  UserProfile? _user;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _loadData();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await ref.read(userRepositoryProvider).getMyProfile();
    if (mounted) setState(() => _user = user);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    var items = await ref.read(suggestionRepositoryProvider).getSuggestions();

    if (items.isEmpty) {
      await ref.read(suggestionRepositoryProvider).triggerGeneration();
      await Future.delayed(const Duration(seconds: 4));
      items = await ref.read(suggestionRepositoryProvider).getSuggestions();
    }

    if (mounted) {
      setState(() {
        _suggestions = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        Colors.black,
                        Color(0xFF1A1A2E),
                        _animController.value,
                      )!,
                      Color.lerp(
                        Color(0xFF0F0F1A),
                        Colors.black,
                        _animController.value,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // Blur Mesh (Optional, keeping simple for perf)
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : _suggestions.isEmpty
                      ? _buildEmptyState()
                      : _buildSwiper(),
                ),
                // _buildBottomBar() // Moved to overlay or removed if swipe is enough
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ... (build method same)

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Günün Stratejisi",
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _user != null
                    ? "Merhaba, ${_user!.name}"
                    : "Senin için seçilenler",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _showProfileMenu,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.premiumGradient,
              ),
              child: CircleAvatar(
                backgroundColor: Colors.black,
                radius: 20,
                backgroundImage:
                    _user != null && _user!.profileImageUrl.isNotEmpty
                    ? NetworkImage(_user!.profileImageUrl)
                    : null,
                child: _user == null || _user!.profileImageUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              if (_user != null) ...[
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _user!.profileImageUrl.isNotEmpty
                      ? NetworkImage(_user!.profileImageUrl)
                      : null,
                  child: _user!.profileImageUrl.isEmpty
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _user!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "@${_user!.username}",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Çıkış Yap",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext); // Close sheet using sheetContext
                  await ref.read(userRepositoryProvider).logout();
                  if (mounted) context.go('/login'); // Use HomeScreen context
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 80,
            color: AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            "Analiz Ediliyor...",
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            "Yapay zeka içerik üretiyor",
            style: TextStyle(color: Colors.white30),
          ),
        ],
      ),
    );
  }

  Widget _buildSwiper() {
    return CardSwiper(
      controller: controller,
      cardsCount: _suggestions.length,
      onSwipe: _onSwipe,
      numberOfCardsDisplayed: 3,
      backCardOffset: const Offset(0, 35),
      padding: const EdgeInsets.all(24),
      cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
        return _buildCard(_suggestions[index]);
      },
    );
  }

  bool _onSwipe(int previous, int? current, CardSwiperDirection direction) {
    final suggestion = _suggestions[previous];
    if (direction == CardSwiperDirection.right) {
      ref.read(suggestionRepositoryProvider).acceptSuggestion(suggestion.id);
    } else if (direction == CardSwiperDirection.left) {
      ref.read(suggestionRepositoryProvider).rejectSuggestion(suggestion.id);
    }
    return true;
  }

  Widget _buildCard(ContentSuggestion suggestion) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF252A34).withValues(alpha: 0.8),
                const Color(0xFF121212).withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPill("AI Önerisi", AppTheme.accentColor),
                        _buildPill(
                          suggestion.riskAssessment,
                          _getRiskColor(suggestion.riskAssessment),
                          outlined: true,
                        ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    Text(
                      suggestion.suggestedText,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: "Inter",
                      ),
                    ),
                    const Spacer(flex: 3),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.insights,
                            color: Colors.blueGrey[200],
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              suggestion.rationale,
                              style: TextStyle(
                                color: Colors.blueGrey[100],
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Actions Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(String text, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: outlined ? 0.5 : 0)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    if (risk.toLowerCase() == 'high') return Colors.redAccent;
    if (risk.toLowerCase() == 'medium') return Colors.orangeAccent;
    return const Color(0xFF00C853);
  }
}
