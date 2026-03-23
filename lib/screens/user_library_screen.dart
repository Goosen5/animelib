import 'package:flutter/material.dart';

import '../models/user_anime_entry.dart';
import '../services/user_anime_list_service.dart';
import '../widgets/ui_primitives.dart';
import 'anime_detail_screen.dart';

class UserLibraryScreen extends StatefulWidget {
  const UserLibraryScreen({super.key});

  @override
  State<UserLibraryScreen> createState() => _UserLibraryScreenState();
}

class _UserLibraryScreenState extends State<UserLibraryScreen> {
  final UserAnimeListService _libraryService = UserAnimeListService();

  bool _isLoading = true;
  String? _error;
  List<UserAnimeEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _libraryService.fetchUserList();
      if (!mounted) return;
      setState(() {
        _entries = entries;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your library right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _editEntry(UserAnimeEntry entry) async {
    AnimeListStatus selectedStatus = entry.status;
    int episodes = entry.episodesWatched;
    int? score = entry.score;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.animeTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AnimeListStatus>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: AnimeListStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Episodes watched'),
                      const Spacer(),
                      IconButton(
                        onPressed: episodes > 0
                            ? () => setModalState(() => episodes--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$episodes'),
                      IconButton(
                        onPressed: () => setModalState(() => episodes++),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Rating: ${score ?? 0}/10'),
                  Slider(
                    value: (score ?? 0).toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: '${score ?? 0}',
                    onChanged: (value) {
                      setModalState(() {
                        score = value.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    try {
      await _libraryService.updateProgress(
        animeId: entry.animeId,
        status: selectedStatus,
        episodesWatched: episodes,
        score: score,
      );

      await _loadLibrary();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update entry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Watching'),
              Tab(text: 'Completed'),
              Tab(text: 'Dropped'),
              Tab(text: 'Plan to watch'),
            ],
          ),
        ),
        body: AppGradientBackground(
          child: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: 5,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonBox(height: 128),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadLibrary,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildList(_entries),
                        _buildList(_entries.where((e) => e.status == AnimeListStatus.watching).toList()),
                        _buildList(_entries.where((e) => e.status == AnimeListStatus.completed).toList()),
                        _buildList(_entries.where((e) => e.status == AnimeListStatus.dropped).toList()),
                        _buildList(_entries.where((e) => e.status == AnimeListStatus.planToWatch).toList()),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildList(List<UserAnimeEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('No anime in this tab yet.'));
    }

    return RefreshIndicator(
      onRefresh: _loadLibrary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: entry.animeImageUrl == null
                        ? Container(
                            width: 70,
                            height: 100,
                            color: Colors.white10,
                            child: const Icon(Icons.movie),
                          )
                        : Image.network(
                            entry.animeImageUrl!,
                            width: 70,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.animeTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _pill('Status: ${_statusLabel(entry.status)}'),
                            _pill('Episodes: ${entry.episodesWatched}'),
                            _pill('Score: ${entry.score ?? '-'}'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AnimeDetailPage(animeId: entry.animeId),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Details'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _editEntry(entry),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Update'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
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
