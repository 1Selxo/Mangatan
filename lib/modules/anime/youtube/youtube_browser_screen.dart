import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/services/youtube/youtube_service.dart';

class YouTubeBrowserScreen extends StatefulWidget {
  const YouTubeBrowserScreen({super.key});

  @override
  State<YouTubeBrowserScreen> createState() => _YouTubeBrowserScreenState();
}

class _YouTubeBrowserScreenState extends State<YouTubeBrowserScreen> {
  final _searchController = TextEditingController();
  final _youtube = YouTubeService();
  List<YouTubeBrowseItem> _results = const [];
  List<String> _history = const [];
  YouTubeBrowseItem? _collection;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _youtube.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await YouTubePreferences.searchHistory();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _search([String? suppliedQuery]) async {
    final query = (suppliedQuery ?? _searchController.text).trim();
    if (query.isEmpty) return;
    _searchController.text = query;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _collection = null;
    });
    try {
      await YouTubePreferences.rememberSearch(query);
      final results = await _youtube.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      await _loadHistory();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _openCollection(YouTubeBrowseItem item) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await _youtube.loadCollection(item);
      if (!mounted) return;
      setState(() {
        _collection = item;
        _results = videos;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  Future<void> _play(YouTubeBrowseItem item) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chapterId = await _youtube.prepareVideoForPlayback(item);
      if (!mounted) return;
      setState(() => _loading = false);
      await context.push('/animePlayerView', extra: chapterId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  void _leaveCollection() {
    setState(() {
      _collection = null;
      _results = const [];
      _error = null;
    });
  }

  Future<void> _showSettings() async {
    var quality = await YouTubePreferences.preferredQuality();
    var autoAdd = await YouTubePreferences.autoAddChannels();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('YouTube settings'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: quality,
                  decoration: const InputDecoration(
                    labelText: 'Preferred video quality',
                  ),
                  items: [
                    for (final value in youtubePreferredQualities)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => quality = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add opened channels to the library'),
                  subtitle: const Text(
                    'Off by default, matching Chimahon’s behavior.',
                  ),
                  value: autoAdd,
                  onChanged: (value) => setDialogState(() => autoAdd = value),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await YouTubePreferences.clearSearchHistory();
                      if (context.mounted) Navigator.pop(context);
                      await _loadHistory();
                    },
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Clear search history'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await YouTubePreferences.setPreferredQuality(quality);
                await YouTubePreferences.setAutoAddChannels(autoAdd);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _collection == null
            ? null
            : IconButton(
                tooltip: 'Back to search',
                onPressed: _leaveCollection,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text(_collection?.title ?? 'YouTube'),
        actions: [
          IconButton(
            tooltip: 'YouTube settings',
            onPressed: _showSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_collection == null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search YouTube or paste a video/playlist URL',
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
                ],
                onChanged: (_) => setState(() {}),
                onSubmitted: _search,
              ),
            ),
            if (_history.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 18),
                    label: Text(_history[index]),
                    onPressed: () => _search(_history[index]),
                  ),
                ),
              ),
          ],
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline_rounded),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? _YouTubeEmptyState(
                    hasSearch: _searchController.text.isNotEmpty,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return _YouTubeResultTile(
                        item: item,
                        onTap: _loading
                            ? null
                            : () => item.isVideo
                                  ? _play(item)
                                  : _openCollection(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _friendlyError(Object error) {
    final text = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
    if (text.contains('VideoUnplayableException')) {
      return 'This video is unavailable or cannot be played in your region.';
    }
    return 'YouTube could not load this request. $text';
  }
}

class _YouTubeResultTile extends StatelessWidget {
  const _YouTubeResultTile({required this.item, required this.onTap});

  final YouTubeBrowseItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isChannel = item.type == YouTubeBrowseItemType.channel;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SizedBox(
        width: 120,
        height: 68,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isChannel ? 50 : 8),
          child: item.thumbnailUrl.isEmpty
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(_icon),
                )
              : Image.network(
                  item.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Icon(_icon),
                  ),
                ),
        ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: item.subtitle.isEmpty
          ? null
          : Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Icon(item.isVideo ? Icons.play_arrow_rounded : _icon),
      onTap: onTap,
    );
  }

  IconData get _icon => switch (item.type) {
    YouTubeBrowseItemType.video => Icons.play_arrow_rounded,
    YouTubeBrowseItemType.channel => Icons.account_circle_rounded,
    YouTubeBrowseItemType.playlist => Icons.playlist_play_rounded,
  };
}

class _YouTubeEmptyState extends StatelessWidget {
  const _YouTubeEmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ondemand_video_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No YouTube results found'
                  : 'Search videos, channels and playlists',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Videos open in Mangatan’s full player with subtitles, '
              'frame OCR, mining and sentence audio.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
