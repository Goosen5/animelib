import 'package:flutter/material.dart';

import '../models/user_stats.dart';
import '../services/statistics_service.dart';
import '../widgets/ui_primitives.dart';

class StatisticsDashboardScreen extends StatefulWidget {
  const StatisticsDashboardScreen({super.key});

  @override
  State<StatisticsDashboardScreen> createState() => _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen> {
  final StatisticsService _statisticsService = StatisticsService();

  bool _loading = true;
  String? _error;
  UserStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await _statisticsService.getUserStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load statistics.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: AppGradientBackground(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SkeletonBox(height: 120),
                  SizedBox(height: 12),
                  SkeletonBox(height: 220),
                ],
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _stats == null
                    ? const Center(child: Text('No stats available.'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _kpi('Total', _stats!.total.toString()),
                                  _kpi('Avg Score', _stats!.averageScore.toStringAsFixed(1)),
                                  _kpi('Completion', '${(_stats!.completionRate * 100).round()}%'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('List Distribution', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 12),
                                  _bar('Watching', _stats!.watching, _stats!.total, const Color(0xFF37E2D5)),
                                  const SizedBox(height: 8),
                                  _bar('Completed', _stats!.completed, _stats!.total, const Color(0xFF5BFF8A)),
                                  const SizedBox(height: 8),
                                  _bar('Dropped', _stats!.dropped, _stats!.total, const Color(0xFFFF7A7A)),
                                  const SizedBox(height: 8),
                                  _bar('Plan to Watch', _stats!.planToWatch, _stats!.total, const Color(0xFF9FA9FF)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _bar(String label, int value, int total, Color color) {
    final ratio = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$value'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: ratio,
            color: color,
            backgroundColor: Colors.white12,
          ),
        ),
      ],
    );
  }
}
