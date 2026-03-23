import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anime.dart';
import '../models/anime_recommendation.dart';
import '../models/character.dart';
import '../models/user_anime_entry.dart';
import '../services/api_service.dart';
import '../services/user_anime_list_service.dart';
import '../widgets/ui_primitives.dart';

class AnimeDetailPage extends StatefulWidget {
  const AnimeDetailPage({super.key, required this.animeId});

  final int animeId;

  @override
  State<AnimeDetailPage> createState() => _AnimeDetailPageState();
}

class _AnimeDetailPageState extends State<AnimeDetailPage> {
  final ApiService _apiService = ApiService();
  final UserAnimeListService _libraryService = UserAnimeListService();

  late Future<Anime> _animeDetails;
  late Future<List<Character>> _characters;
  late Future<List<AnimeRecommendation>> _recommendations;

  UserAnimeEntry? _entry;
  bool _entryLoading = true;
  bool _entrySaving = false;
  String? _entryError;

  AnimeListStatus _selectedStatus = AnimeListStatus.planToWatch;
  int _episodesWatched = 0;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _animeDetails = _apiService.getAnimeDetails(widget.animeId);
    _characters = _apiService.getAnimeCharacters(widget.animeId);
    _recommendations = _apiService.getAnimeRecommendations(widget.animeId);
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    setState(() {
      _entryLoading = true;
      _entryError = null;
    });

    try {
      final existing = await _libraryService.fetchUserEntryForAnime(widget.animeId);
      if (!mounted) return;
      setState(() {
        _entry = existing;
        if (existing != null) {
          _selectedStatus = existing.status;
          _episodesWatched = existing.episodesWatched;
          _score = existing.score ?? 0;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entryError = 'Unable to load your library entry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _entryLoading = false;
        });
      }
    }
  }

  Future<void> _addToList(Anime anime) async {
    setState(() {
      _entrySaving = true;
      _entryError = null;
    });

    try {
      final created = await _libraryService.addAnimeToList(
        anime: anime,
        status: _selectedStatus,
        episodesWatched: _episodesWatched,
        score: _score,
      );

      if (!mounted) return;
      setState(() {
        _entry = created;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to your library.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entryError = 'Could not add anime to library.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _entrySaving = false;
        });
      }
    }
  }

  Future<void> _saveProgress() async {
    if (_entry == null) return;

    setState(() {
      _entrySaving = true;
      _entryError = null;
    });

    try {
      final updated = await _libraryService.updateProgress(
        animeId: widget.animeId,
        status: _selectedStatus,
        episodesWatched: _episodesWatched,
        score: _score,
      );

      if (!mounted) return;
      setState(() {
        _entry = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Library entry updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entryError = 'Could not update entry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _entrySaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anime Details'), centerTitle: true),
      body: AppGradientBackground(
        child: FutureBuilder<Anime>(
          future: _animeDetails,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SkeletonBox(height: 280),
                  SizedBox(height: 12),
                  SkeletonBox(height: 180),
                  SizedBox(height: 12),
                  SkeletonBox(height: 130),
                ],
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('No details found'));
            }

            final anime = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Card(
                  color: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              anime.imageUrl,
                              height: 280,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(anime.title, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _metaChip(Icons.tv, anime.type),
                            _metaChip(Icons.star, anime.score),
                            _metaChip(Icons.category, anime.genres.join(', ')),
                          ],
                        ),
                        if (anime.trailerUrl != null) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final url = Uri.parse(anime.trailerUrl!);
                              if (!await launchUrl(url)) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Could not open trailer.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Watch Trailer'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildLibrarySection(anime),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Synopsis', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(anime.synopsis),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Characters', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        _buildCharactersSection(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF161B22),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        _buildRecommendationsSection(),
                      ],
                    ),
                  ),
                ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLibrarySection(Anime anime) {
    if (_entryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('My Library', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              _entry == null ? 'Not added' : 'In library',
              style: TextStyle(
                color: _entry == null ? Colors.white60 : const Color(0xFF00BFAE),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<AnimeListStatus>(
          initialValue: _selectedStatus,
          decoration: const InputDecoration(labelText: 'Status'),
          items: AnimeListStatus.values
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(_statusLabel(status)),
                ),
              )
              .toList(),
          onChanged: _entrySaving
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedStatus = value;
                  });
                },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Episodes watched'),
            const Spacer(),
            IconButton(
              onPressed: _entrySaving || _episodesWatched == 0
                  ? null
                  : () => setState(() => _episodesWatched--),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_episodesWatched'),
            IconButton(
              onPressed: _entrySaving ? null : () => setState(() => _episodesWatched++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Score: $_score/10'),
        Slider(
          value: _score.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          label: '$_score',
          onChanged: _entrySaving
              ? null
              : (value) {
                  setState(() {
                    _score = value.toInt();
                  });
                },
        ),
        if (_entryError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_entryError!, style: const TextStyle(color: Colors.redAccent)),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _entrySaving
                ? null
                : () {
                    if (_entry == null) {
                      _addToList(anime);
                    } else {
                      _saveProgress();
                    }
                  },
            icon: _entrySaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_entry == null ? Icons.library_add : Icons.save),
            label: Text(_entry == null ? 'Add to List' : 'Save Changes'),
          ),
        ),
      ],
    );
  }

  Widget _buildCharactersSection() {
    return FutureBuilder<List<Character>>(
      future: _characters,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('Could not load characters.');
        }
        final characters = snapshot.data ?? const [];
        if (characters.isEmpty) {
          return const Text('No characters found.');
        }

        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final character = characters[index];
              return Container(
                width: 105,
                margin: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        character.imageUrl,
                        height: 100,
                        width: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      character.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsSection() {
    return FutureBuilder<List<AnimeRecommendation>>(
      future: _recommendations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Text('Could not load recommendations.');
        }
        final recommendations = snapshot.data ?? const [];
        if (recommendations.isEmpty) {
          return const Text('No recommendations found.');
        }

        return SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final recommendation = recommendations[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnimeDetailPage(animeId: recommendation.id),
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          recommendation.imageUrl,
                          height: 160,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recommendation.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AnimeListStatus status) {
    switch (status) {
      case AnimeListStatus.watching:
        return 'Watching';
      case AnimeListStatus.completed:
        return 'Completed';
      case AnimeListStatus.dropped:
        return 'Dropped';
      case AnimeListStatus.planToWatch:
        return 'Plan to watch';
    }
  }
}
