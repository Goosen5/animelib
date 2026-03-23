import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/anime.dart';
import '../models/genre.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/ui_primitives.dart';
import 'aniguessr_screen.dart';
import 'anime_detail_screen.dart';
import 'anime_wordle_screen.dart';
import 'recommendations_screen.dart';
import 'statistics_dashboard_screen.dart';
import 'user_library_screen.dart';
import 'user_profile_screen.dart';

enum _MoreAction {
  recommendations,
  statistics,
  profile,
}

class AnimeHomeScreen extends ConsumerStatefulWidget {
  const AnimeHomeScreen({super.key, required this.title});

  final String title;

  @override
  ConsumerState<AnimeHomeScreen> createState() => _AnimeHomeScreenState();
}

class _AnimeHomeScreenState extends ConsumerState<AnimeHomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  final List<Anime> _animeList = [];
  List<Genre> _genres = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  int _page = 1;
  String _searchQuery = '';
  int? _selectedGenreId;

  @override
  void initState() {
    super.initState();
    _fetchAnime(reset: true);
    _fetchGenres();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnime({bool reset = false}) async {
    if (!mounted || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (reset) {
      _page = 1;
      _animeList.clear();
      _hasMore = true;
    }

    try {
      List<Anime> newAnime;
      if (_searchQuery.isEmpty) {
        newAnime =
            await _apiService.getTopAnime(page: _page, genreId: _selectedGenreId);
      } else {
        newAnime = await _apiService.searchAnime(_searchQuery, page: _page);
      }

      if (!mounted) return;
      setState(() {
        _animeList.addAll(newAnime);
        _page++;
        _hasMore = newAnime.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load anime. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchGenres() async {
    try {
      _genres = await _apiService.getGenres();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Keep browsing available even if genres fail.
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
      _selectedGenreId = null;
    });
    _fetchAnime(reset: true);
  }

  void _onFilter(int? genreId) {
    setState(() {
      _selectedGenreId = genreId;
      _searchQuery = '';
      _searchController.clear();
    });
    _fetchAnime(reset: true);
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimeWordleScreen()),
              );
            },
            tooltip: 'Anime Wordle',
            icon: const Icon(Icons.grid_view_rounded),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AniGuessrScreen()),
              );
            },
            tooltip: 'AniGuessr',
            icon: const Icon(Icons.casino_outlined),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserLibraryScreen()),
              );
            },
            tooltip: 'My Library',
            icon: const Icon(Icons.video_library_outlined),
          ),
          PopupMenuButton<_MoreAction>(
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _MoreAction.recommendations:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecommendationsScreen()),
                  );
                  break;
                case _MoreAction.statistics:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StatisticsDashboardScreen(),
                    ),
                  );
                  break;
                case _MoreAction.profile:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MoreAction.recommendations,
                child: Text('Recommendations'),
              ),
              PopupMenuItem(
                value: _MoreAction.statistics,
                child: Text('Statistics'),
              ),
              PopupMenuItem(
                value: _MoreAction.profile,
                child: Text('Profile'),
              ),
            ],
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AppGradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 420;
            final crossAxisCount = constraints.maxWidth < 560
                ? 2
                : constraints.maxWidth < 860
                    ? 3
                    : 4;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(isCompact ? 12 : 16, 10, isCompact ? 12 : 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onSubmitted: _onSearch,
                              decoration: const InputDecoration(
                                hintText: 'Search anime title...',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _selectedGenreId,
                            hint: const Text('Genre'),
                            items: _genres
                                .map((genre) => DropdownMenuItem<int>(
                                      value: genre.id,
                                      child: Text(genre.name),
                                    ))
                                .toList(),
                            onChanged: _onFilter,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: const Color(0x55FF5A66),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _fetchAnime(reset: _animeList.isEmpty),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _isLoading && _animeList.isEmpty
                        ? _buildSkeletonGrid(crossAxisCount)
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (!_isLoading &&
                                  _hasMore &&
                                  scrollInfo.metrics.pixels >=
                                      scrollInfo.metrics.maxScrollExtent - 40) {
                                _fetchAnime();
                              }
                              return true;
                            },
                            child: GridView.builder(
                              key: const PageStorageKey<String>('anime-home-grid'),
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 10 : 14,
                                vertical: 8,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.66,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: _animeList.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < _animeList.length) {
                                  final anime = _animeList[index];
                                  return TweenAnimationBuilder<double>(
                                    duration: Duration(milliseconds: 160 + (index % 8) * 50),
                                    curve: Curves.easeOutCubic,
                                    tween: Tween(begin: 0.95, end: 1.0),
                                    builder: (context, scale, child) => Transform.scale(
                                      scale: scale,
                                      child: child,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AnimeDetailPage(animeId: anime.id),
                                          ),
                                        );
                                      },
                                      child: Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              anime.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Colors.white10,
                                                child: const Icon(Icons.broken_image),
                                              ),
                                            ),
                                            const DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [Color(0x11000000), Color(0xCC000000)],
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: 8,
                                              right: 8,
                                              bottom: 8,
                                              child: Text(
                                                anime.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                if (_isLoading) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid(int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.66,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: crossAxisCount * 3,
      itemBuilder: (context, index) => const SkeletonBox(height: double.infinity),
    );
  }
}
