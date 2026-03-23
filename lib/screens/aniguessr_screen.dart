import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/aniguessr_round.dart';
import '../services/api_service.dart';

enum AniGuessrDifficulty { easy, hard }

class AniGuessrScreen extends StatefulWidget {
  const AniGuessrScreen({super.key});

  @override
  State<AniGuessrScreen> createState() => _AniGuessrScreenState();
}

class _AniGuessrScreenState extends State<AniGuessrScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _guessController = TextEditingController();

  AniGuessrDifficulty _difficulty = AniGuessrDifficulty.easy;
  AniGuessrRound? _round;
  bool _loadingRound = true;
  bool _checking = false;
  String? _error;
  String? _resultMessage;

  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _roundsPlayed = 0;

  @override
  void initState() {
    super.initState();
    _loadNextRound();
  }

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  Future<void> _loadNextRound() async {
    setState(() {
      _loadingRound = true;
      _error = null;
      _resultMessage = null;
      _guessController.clear();
    });

    try {
      final round = await _apiService.getRandomAnimeRound();
      if (!mounted) return;
      setState(() {
        _round = round;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load a random anime. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRound = false;
        });
      }
    }
  }

  Future<void> _submitGuess() async {
    if (_round == null || _checking) return;

    final guess = _guessController.text.trim();
    if (guess.isEmpty) return;

    setState(() {
      _checking = true;
    });

    final isCorrect = _matchesGuess(
      guess,
      _round!.acceptedTitles,
    );

    setState(() {
      _roundsPlayed++;
      if (isCorrect) {
        _streak++;
        if (_streak > _bestStreak) {
          _bestStreak = _streak;
        }
        _score += 10 + (_streak > 1 ? 2 : 0);
        _resultMessage = 'Correct! It was ${_round!.displayTitle}.';
      } else {
        _streak = 0;
        _score = (_score - 2).clamp(0, 1 << 31);
        _resultMessage = 'Wrong guess. Answer: ${_round!.displayTitle}.';
      }
      _checking = false;
    });
  }

  bool _matchesGuess(String guess, List<String> acceptedTitles) {
    final normalizedGuess = _normalize(guess);
    for (final title in acceptedTitles) {
      final normalizedTitle = _normalize(title);
      if (normalizedGuess == normalizedTitle) {
        return true;
      }
      if (normalizedGuess.isNotEmpty &&
          normalizedTitle.isNotEmpty &&
          (normalizedTitle.contains(normalizedGuess) ||
              normalizedGuess.contains(normalizedTitle))) {
        return true;
      }
    }
    return false;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final imageSigma = _difficulty == AniGuessrDifficulty.easy ? 0.0 : 8.0;

    return Scaffold(
      appBar: AppBar(title: const Text('AniGuessr')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatsCard(),
              const SizedBox(height: 12),
              _buildDifficultyCard(),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFF161B22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _loadingRound
                      ? const SizedBox(
                          height: 320,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _error != null
                          ? SizedBox(
                              height: 320,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_error!),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: _loadNextRound,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _round == null
                              ? const SizedBox(
                                  height: 320,
                                  child: Center(child: Text('No round available')),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ImageFiltered(
                                    imageFilter: ImageFilter.blur(
                                      sigmaX: imageSigma,
                                      sigmaY: imageSigma,
                                    ),
                                    child: Image.network(
                                      _round!.imageUrl,
                                      height: 320,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        height: 320,
                                        color: Colors.white10,
                                        child: const Center(
                                          child: Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  ),
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
                    children: [
                      TextField(
                        controller: _guessController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitGuess(),
                        decoration: const InputDecoration(
                          labelText: 'Your guess',
                          hintText: 'Type the anime title',
                          prefixIcon: Icon(Icons.psychology_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loadingRound || _checking ? null : _submitGuess,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Validate'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _loadingRound ? null : _loadNextRound,
                              icon: const Icon(Icons.skip_next),
                              label: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                      if (_resultMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_resultMessage!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('Score', '$_score'),
            _statItem('Streak', '$_streak'),
            _statItem('Best', '$_bestStreak'),
            _statItem('Rounds', '$_roundsPlayed'),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyCard() {
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.tune),
            const SizedBox(width: 10),
            const Text('Difficulty'),
            const Spacer(),
            SegmentedButton<AniGuessrDifficulty>(
              segments: const [
                ButtonSegment(
                  value: AniGuessrDifficulty.easy,
                  label: Text('Easy'),
                ),
                ButtonSegment(
                  value: AniGuessrDifficulty.hard,
                  label: Text('Hard'),
                ),
              ],
              selected: {_difficulty},
              onSelectionChanged: (selection) {
                setState(() {
                  _difficulty = selection.first;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
