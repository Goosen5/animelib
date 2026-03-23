import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';
import '../services/api_service.dart';

class AnimeWordleScreen extends StatefulWidget {
  const AnimeWordleScreen({super.key});

  @override
  State<AnimeWordleScreen> createState() => _AnimeWordleScreenState();
}

class _AnimeWordleScreenState extends State<AnimeWordleScreen> {
  static const int _maxGuesses = 6;

  final ApiService _apiService = ApiService();
  final TextEditingController _guessController = TextEditingController();

  Anime? _dailyAnime;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  final List<_WordleGuess> _guesses = [];
  final List<Anime> _suggestions = [];

  Timer? _suggestDebounce;
  Anime? _selectedSuggestion;
  bool _isLoadingSuggestions = false;

  bool _isComplete = false;
  bool _isWin = false;

  @override
  void initState() {
    super.initState();
    _loadDailyGame();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _guessController.dispose();
    super.dispose();
  }

  String get _dayKey {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'anime_wordle_$date';
  }

  Future<void> _loadDailyGame() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final anime = await _apiService.getDailyAnime();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_dayKey);

      final restoredGuesses = <_WordleGuess>[];
      var restoredComplete = false;
      var restoredWin = false;

      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if ((decoded['target_id'] as num?)?.toInt() == anime.id) {
          final guessesJson = decoded['guesses'] as List<dynamic>? ?? const [];
          for (final item in guessesJson) {
            restoredGuesses
                .add(_WordleGuess.fromJson(item as Map<String, dynamic>));
          }
          restoredComplete = decoded['is_complete'] == true;
          restoredWin = decoded['is_win'] == true;
        }
      }

      if (!mounted) return;
      setState(() {
        _dailyAnime = anime;
        _guesses
          ..clear()
          ..addAll(restoredGuesses);
        _isComplete = restoredComplete;
        _isWin = restoredWin;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load today\'s anime. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitGuess() async {
    if (_dailyAnime == null || _isComplete || _isSubmitting) {
      return;
    }

    if (_guesses.length >= _maxGuesses) {
      return;
    }

    final rawGuess = _guessController.text.trim();
    if (rawGuess.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final guessedAnime = await _resolveGuessAnime(rawGuess);
      if (guessedAnime == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No matching anime found for "$rawGuess".';
        });
        return;
      }

      final target = _dailyAnime!;
      final isCorrect = guessedAnime.id == _dailyAnime!.id ||
          _normalize(guessedAnime.title) == _normalize(_dailyAnime!.title);

      final genresResult = _compareSets(target.genres, guessedAnime.genres);
      final tagsResult = _compareSets(target.tags, guessedAnime.tags);

      final yearComparison = _compareYear(target.year, guessedAnime.year);
      final scoreComparison =
          _compareScore(target.numericScore, guessedAnime.numericScore);
      final studioComparison =
          _compareText(target.primaryStudio, guessedAnime.primaryStudio);
      final sourceComparison = _compareText(target.source, guessedAnime.source);

      final guess = _WordleGuess(
        guessText: rawGuess,
        guessedTitle: guessedAnime.title,
        guessedYear: guessedAnime.year,
        guessedStudio: guessedAnime.primaryStudio,
        guessedSource: guessedAnime.source,
        guessedScore: guessedAnime.numericScore,
        isCorrect: isCorrect,
        yearComparison: yearComparison,
        scoreComparison: scoreComparison,
        studioComparison: studioComparison,
        sourceComparison: sourceComparison,
        genreComparison: _comparisonFromSetResult(genresResult),
        tagComparison: _comparisonFromSetResult(tagsResult),
        yearDirection: _directionArrow(
          targetValue: target.year?.toDouble(),
          guessValue: guessedAnime.year?.toDouble(),
        ),
        scoreDirection: _directionArrow(
          targetValue: target.numericScore,
          guessValue: guessedAnime.numericScore,
        ),
        matchedGenres: genresResult.matched,
        missingGenres: genresResult.missing,
        extraGenres: genresResult.extra,
        matchedTags: tagsResult.matched,
        missingTags: tagsResult.missing,
        extraTags: tagsResult.extra,
      );

      _guesses.add(guess);
      _guessController.clear();
      _selectedSuggestion = null;
      _suggestions.clear();

      if (isCorrect || _guesses.length >= _maxGuesses) {
        _isComplete = true;
        _isWin = isCorrect;
      }

      await _saveProgress();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not validate your guess right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _saveProgress() async {
    if (_dailyAnime == null) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'target_id': _dailyAnime!.id,
      'is_complete': _isComplete,
      'is_win': _isWin,
      'guesses': _guesses.map((g) => g.toJson()).toList(),
    };
    await prefs.setString(_dayKey, jsonEncode(payload));
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<Anime?> _resolveGuessAnime(String rawGuess) async {
    final selected = _selectedSuggestion;
    if (selected != null && _normalize(selected.title) == _normalize(rawGuess)) {
      return selected;
    }

    for (final suggestion in _suggestions) {
      if (_normalize(suggestion.title) == _normalize(rawGuess)) {
        return suggestion;
      }
    }

    return _apiService.resolveAnimeGuess(rawGuess);
  }

  void _onGuessChanged(String value) {
    _selectedSuggestion = null;
    _suggestDebounce?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _suggestions.clear();
        _isLoadingSuggestions = false;
      });
      return;
    }

    _suggestDebounce = Timer(const Duration(milliseconds: 260), () async {
      if (!mounted) return;
      setState(() {
        _isLoadingSuggestions = true;
      });

      try {
        final suggestions = await _apiService.getGuessSuggestions(
          query,
          limit: 8,
        );

        if (!mounted || _guessController.text.trim() != query) return;
        setState(() {
          _suggestions
            ..clear()
            ..addAll(suggestions);
        });
      } catch (_) {
        if (!mounted || _guessController.text.trim() != query) return;
        setState(() {
          _suggestions.clear();
        });
      } finally {
        if (mounted && _guessController.text.trim() == query) {
          setState(() {
            _isLoadingSuggestions = false;
          });
        }
      }
    });
  }

  _SetComparisonResult _compareSets(List<String> target, List<String> guess) {
    final targetMap = {for (final item in target) item.toLowerCase(): item};
    final guessMap = {for (final item in guess) item.toLowerCase(): item};

    final matched = <String>[];
    final missing = <String>[];
    final extra = <String>[];

    for (final entry in targetMap.entries) {
      if (guessMap.containsKey(entry.key)) {
        matched.add(entry.value);
      } else {
        missing.add(entry.value);
      }
    }

    for (final entry in guessMap.entries) {
      if (!targetMap.containsKey(entry.key)) {
        extra.add(entry.value);
      }
    }

    return _SetComparisonResult(
      matched: matched,
      missing: missing,
      extra: extra,
    );
  }

  _Comparison _comparisonFromSetResult(_SetComparisonResult result) {
    if (result.matched.isEmpty && result.missing.isEmpty && result.extra.isEmpty) {
      return _Comparison.unknown;
    }
    if (result.missing.isEmpty && result.extra.isEmpty) {
      return _Comparison.correct;
    }
    if (result.matched.isNotEmpty) {
      return _Comparison.close;
    }
    return _Comparison.wrong;
  }

  _Comparison _compareText(String target, String guess) {
    final left = _normalize(target);
    final right = _normalize(guess);
    if (left.isEmpty || right.isEmpty) {
      return _Comparison.unknown;
    }
    return left == right ? _Comparison.correct : _Comparison.wrong;
  }

  _Comparison _compareYear(int? target, int? guess) {
    if (target == null || guess == null) {
      return _Comparison.unknown;
    }
    final diff = (target - guess).abs();
    if (diff == 0) {
      return _Comparison.correct;
    }
    if (diff <= 2) {
      return _Comparison.close;
    }
    return _Comparison.wrong;
  }

  _Comparison _compareScore(double? target, double? guess) {
    if (target == null || guess == null) {
      return _Comparison.unknown;
    }
    final diff = (target - guess).abs();
    if (diff <= 0.2) {
      return _Comparison.correct;
    }
    if (diff <= 0.7) {
      return _Comparison.close;
    }
    return _Comparison.wrong;
  }

  String _directionArrow({double? targetValue, double? guessValue}) {
    if (targetValue == null || guessValue == null) {
      return '•';
    }
    if ((targetValue - guessValue).abs() < 0.0001) {
      return '=';
    }
    return guessValue < targetValue ? '↑' : '↓';
  }

  Color _comparisonColor(_Comparison comparison) {
    switch (comparison) {
      case _Comparison.correct:
        return const Color(0xFF3FD084);
      case _Comparison.close:
        return const Color(0xFFF2C14E);
      case _Comparison.wrong:
        return const Color(0xFFFF6B6B);
      case _Comparison.unknown:
        return const Color(0xFF9BA5B4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anime Wordle')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _dailyAnime == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadDailyGame,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 12),
                      _buildInputCard(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _buildGuessList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final remaining = (_maxGuesses - _guesses.length).clamp(0, _maxGuesses);

    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Anime Challenge',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Guesses left: $remaining / $_maxGuesses'),
            if (_isComplete && _dailyAnime != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isWin
                      ? const Color(0x3300BFAE)
                      : const Color(0x33FF6B6B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isWin
                      ? 'You got it! Answer: ${_dailyAnime!.title}'
                      : 'Out of guesses. Today\'s anime: ${_dailyAnime!.title}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _guessController,
              textInputAction: TextInputAction.done,
              onChanged: _onGuessChanged,
              onSubmitted: (_) => _submitGuess(),
              enabled: !_isComplete && !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Your guess',
                hintText: 'Type an anime title',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            if (_isLoadingSuggestions) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_suggestions.isNotEmpty && !_isComplete) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: const Color(0xFF10151D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final anime = _suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        anime.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${anime.year?.toString() ?? 'Unknown'} • '
                        '${anime.primaryStudio} • ${anime.type}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedSuggestion = anime;
                          _guessController.text = anime.title;
                          _guessController.selection = TextSelection.fromPosition(
                            TextPosition(offset: anime.title.length),
                          );
                          _suggestions.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isComplete || _isSubmitting ? null : _submitGuess,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Guess'),
              ),
            ),
            if (_error != null && _dailyAnime != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGuessList() {
    if (_guesses.isEmpty) {
      return const Center(
        child: Text('No guesses yet. Start by entering an anime title.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 980 ? 980.0 : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _buildTableHeader(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: _guesses.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final guess = _guesses[index];
                      return _buildGuessRow(guess, index + 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          _HeaderCell('Title', width: 220),
          _HeaderCell('Year', width: 90),
          _HeaderCell('Studio', width: 160),
          _HeaderCell('Source', width: 120),
          _HeaderCell('Score', width: 90),
          _HeaderCell('Genres', width: 200),
          _HeaderCell('Tags', width: 200),
        ],
      ),
    );
  }

  Widget _buildGuessRow(_WordleGuess guess, int guessNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tableCell(
            width: 220,
            child: Text(
              '$guessNumber. ${guess.guessedTitle}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: guess.isCorrect ? const Color(0xFF3FD084) : Colors.white,
              ),
            ),
          ),
          _tableCell(
            width: 90,
            child: _metricText(
              value: guess.guessedYear?.toString() ?? 'Unknown',
              direction: guess.yearDirection,
              comparison: guess.yearComparison,
            ),
          ),
          _tableCell(
            width: 160,
            child: Text(
              guess.guessedStudio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _comparisonColor(guess.studioComparison)),
            ),
          ),
          _tableCell(
            width: 120,
            child: Text(
              guess.guessedSource,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _comparisonColor(guess.sourceComparison)),
            ),
          ),
          _tableCell(
            width: 90,
            child: _metricText(
              value: guess.guessedScore?.toStringAsFixed(1) ?? 'Unknown',
              direction: guess.scoreDirection,
              comparison: guess.scoreComparison,
            ),
          ),
          _tableCell(
            width: 200,
            child: _buildTagColumn(
              matched: guess.matchedGenres,
              missing: guess.missingGenres,
              extra: guess.extraGenres,
              fallback: 'No genres',
            ),
          ),
          _tableCell(
            width: 200,
            child: _buildTagColumn(
              matched: guess.matchedTags,
              missing: guess.missingTags,
              extra: guess.extraTags,
              fallback: 'No tags',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricText({
    required String value,
    required String direction,
    required _Comparison comparison,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: _comparisonColor(comparison), fontSize: 14),
        children: [
          TextSpan(text: value),
          const TextSpan(text: ' '),
          TextSpan(
            text: direction,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTagColumn({
    required List<String> matched,
    required List<String> missing,
    required List<String> extra,
    required String fallback,
  }) {
    if (matched.isEmpty && missing.isEmpty && extra.isEmpty) {
      return Text(
        fallback,
        style: const TextStyle(color: Colors.white54),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in matched) _tagPill(item, const Color(0xFF3FD084)),
        for (final item in missing) _tagPill(item, const Color(0xFF9BA5B4)),
        for (final item in extra) _tagPill(item, const Color(0xFFFF6B6B)),
      ],
    );
  }

  Widget _tableCell({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  Widget _tagPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

}

class _WordleGuess {
  final String guessText;
  final String guessedTitle;
  final int? guessedYear;
  final String guessedStudio;
  final String guessedSource;
  final double? guessedScore;
  final bool isCorrect;
  final _Comparison yearComparison;
  final _Comparison scoreComparison;
  final _Comparison studioComparison;
  final _Comparison sourceComparison;
  final _Comparison genreComparison;
  final _Comparison tagComparison;
  final String yearDirection;
  final String scoreDirection;
  final List<String> matchedGenres;
  final List<String> missingGenres;
  final List<String> extraGenres;
  final List<String> matchedTags;
  final List<String> missingTags;
  final List<String> extraTags;

  _WordleGuess({
    required this.guessText,
    required this.guessedTitle,
    required this.guessedYear,
    required this.guessedStudio,
    required this.guessedSource,
    required this.guessedScore,
    required this.isCorrect,
    required this.yearComparison,
    required this.scoreComparison,
    required this.studioComparison,
    required this.sourceComparison,
    required this.genreComparison,
    required this.tagComparison,
    required this.yearDirection,
    required this.scoreDirection,
    required this.matchedGenres,
    required this.missingGenres,
    required this.extraGenres,
    required this.matchedTags,
    required this.missingTags,
    required this.extraTags,
  });

  Map<String, dynamic> toJson() {
    return {
      'guess_text': guessText,
      'guessed_title': guessedTitle,
      'guessed_year': guessedYear,
      'guessed_studio': guessedStudio,
      'guessed_source': guessedSource,
      'guessed_score': guessedScore,
      'is_correct': isCorrect,
      'year_comparison': yearComparison.name,
      'score_comparison': scoreComparison.name,
      'studio_comparison': studioComparison.name,
      'source_comparison': sourceComparison.name,
      'genre_comparison': genreComparison.name,
      'tag_comparison': tagComparison.name,
      'year_direction': yearDirection,
      'score_direction': scoreDirection,
      'matched_genres': matchedGenres,
      'missing_genres': missingGenres,
      'extra_genres': extraGenres,
      'matched_tags': matchedTags,
      'missing_tags': missingTags,
      'extra_tags': extraTags,
    };
  }

  factory _WordleGuess.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is! List) {
        return const [];
      }
      return raw.map((item) => item.toString()).toList();
    }

    _Comparison parseComparison(dynamic raw) {
      final value = raw?.toString() ?? '';
      for (final comparison in _Comparison.values) {
        if (comparison.name == value) {
          return comparison;
        }
      }
      return _Comparison.unknown;
    }

    return _WordleGuess(
      guessText: (json['guess_text'] ?? '').toString(),
      guessedTitle: (json['guessed_title'] ?? '').toString(),
      guessedYear: (json['guessed_year'] as num?)?.toInt(),
      guessedStudio: (json['guessed_studio'] ?? 'Unknown').toString(),
      guessedSource: (json['guessed_source'] ?? 'Unknown').toString(),
      guessedScore: (json['guessed_score'] as num?)?.toDouble(),
      isCorrect: json['is_correct'] == true,
      yearComparison: parseComparison(json['year_comparison']),
      scoreComparison: parseComparison(json['score_comparison']),
      studioComparison: parseComparison(json['studio_comparison']),
      sourceComparison: parseComparison(json['source_comparison']),
      genreComparison: parseComparison(json['genre_comparison']),
      tagComparison: parseComparison(json['tag_comparison']),
      yearDirection: (json['year_direction'] ?? '•').toString(),
      scoreDirection: (json['score_direction'] ?? '•').toString(),
      matchedGenres: parseList(json['matched_genres']),
      missingGenres: parseList(json['missing_genres']),
      extraGenres: parseList(json['extra_genres']),
      matchedTags: parseList(json['matched_tags']),
      missingTags: parseList(json['missing_tags']),
      extraTags: parseList(json['extra_tags']),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SetComparisonResult {
  const _SetComparisonResult({
    required this.matched,
    required this.missing,
    required this.extra,
  });

  final List<String> matched;
  final List<String> missing;
  final List<String> extra;
}

enum _Comparison {
  correct,
  close,
  wrong,
  unknown,
}
