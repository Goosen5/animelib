import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../widgets/ui_primitives.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserProfileService _profileService = UserProfileService();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _avatarUrlController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _displayNameController.text = profile.displayName ?? '';
        _avatarUrlController.text = profile.avatarUrl ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load profile.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await _profileService.upsertProfile(
        displayName: _displayNameController.text,
        avatarUrl: _avatarUrlController.text,
      );
      if (!mounted) return;
      setState(() {
        _profile = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save profile.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AppGradientBackground(
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    SkeletonBox(height: 180),
                    SizedBox(height: 12),
                    SkeletonBox(height: 170),
                  ],
                ),
              )
            : _error != null && _profile == null
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
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: Colors.white10,
                                backgroundImage: (_avatarUrlController.text.trim().isEmpty)
                                    ? null
                                    : NetworkImage(_avatarUrlController.text.trim()),
                                child: _avatarUrlController.text.trim().isEmpty
                                    ? const Icon(Icons.person, size: 34)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayNameController.text.trim().isEmpty
                                          ? 'Anime Fan'
                                          : _displayNameController.text.trim(),
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_profile?.email ?? ''),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _displayNameController,
                                decoration: const InputDecoration(labelText: 'Display Name'),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _avatarUrlController,
                                decoration: const InputDecoration(labelText: 'Avatar URL'),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 8),
                                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                              ],
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _saving ? null : _save,
                                child: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Save Profile'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
