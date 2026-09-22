import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mangayomi/services/hachidori/hachidori_link_controller.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';

class HachidoriLinkSection extends StatefulWidget {
  const HachidoriLinkSection({
    super.key,
    required this.controller,
    required this.localControls,
  });

  final HachidoriLinkController controller;
  final Widget localControls;

  @override
  State<HachidoriLinkSection> createState() => _HachidoriLinkSectionState();
}

class HachidoriDictionaryLibraryPanel extends HachidoriLinkSection {
  const HachidoriDictionaryLibraryPanel({
    super.key,
    required super.controller,
    required super.localControls,
  });
}

class _HachidoriLinkSectionState extends State<HachidoriLinkSection> {
  late final TextEditingController _addressController;
  HachidoriProbeResult? _probeResult;
  String? _probedAddress;
  String? _error;
  bool _initializing = true;
  bool _probing = false;
  bool _linking = false;
  bool _unlinking = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.controller.configuration.address,
    )..addListener(_handleAddressChanged);
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(covariant HachidoriLinkSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _addressController.text = widget.controller.configuration.address;
    unawaited(_initialize());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _addressController
      ..removeListener(_handleAddressChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (mounted) setState(() => _initializing = true);
    try {
      await widget.controller.initialize();
      if (!mounted) return;
      final savedAddress = widget.controller.configuration.address;
      if (_addressController.text.trim().isEmpty && savedAddress.isNotEmpty) {
        _addressController.text = savedAddress;
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _describeError(error));
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _handleAddressChanged() {
    final address = _addressController.text.trim();
    if (_probedAddress == address) {
      if (mounted) setState(() {});
      return;
    }
    if (!mounted) return;
    setState(() {
      _probeResult = null;
      _probedAddress = null;
      _error = null;
    });
  }

  Future<void> _probe() async {
    final address = _addressController.text.trim();
    if (address.isEmpty || _probing || _linking) return;
    setState(() {
      _probing = true;
      _probeResult = null;
      _probedAddress = null;
      _error = null;
    });
    try {
      final result = await widget.controller.probe(address);
      if (!mounted || address != _addressController.text.trim()) return;
      setState(() {
        _probeResult = result;
        _probedAddress = address;
      });
    } on Object catch (error) {
      if (mounted && address == _addressController.text.trim()) {
        setState(() => _error = _describeError(error));
      }
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  Future<void> _link() async {
    final address = _addressController.text.trim();
    if (_probeResult == null ||
        _probedAddress != address ||
        _linking ||
        _probing) {
      return;
    }
    setState(() {
      _linking = true;
      _error = null;
    });
    try {
      await widget.controller.link(address);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _describeError(error));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _unlink() async {
    if (_unlinking) return;
    setState(() {
      _unlinking = true;
      _error = null;
    });
    try {
      await widget.controller.unlink();
      if (!mounted) return;
      setState(() {
        _probeResult = null;
        _probedAddress = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = _describeError(error));
    } finally {
      if (mounted) setState(() => _unlinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linked = widget.controller.remoteEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: linked ? _buildLinked(context) : _buildUnlinked(context),
            ),
          ),
        ),
        if (!linked) widget.localControls,
      ],
    );
  }

  Widget _buildUnlinked(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final address = _addressController.text.trim();
    final canProbe =
        address.isNotEmpty && !_initializing && !_probing && !_linking;
    final canLink =
        _probeResult != null &&
        _probedAddress == address &&
        !_probing &&
        !_linking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: Icons.hub_outlined,
          title: 'Hachidori shared library',
          subtitle:
              'Use dictionary sharing through hachidori-anki. Enable network '
              'sharing on the host when connecting from another device.',
          color: scheme.primary,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('hachidori-address-field'),
          controller: _addressController,
          enabled: !_initializing && !_linking,
          autocorrect: false,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Hachidori address',
            hintText: '192.168.1.20:8771',
            helperText: 'The default sharing port is 8771.',
            prefixIcon: Icon(Icons.lan_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _probe(),
        ),
        if (_probeResult case final result?) ...[
          const SizedBox(height: 12),
          _ProbeSummary(result: result),
        ],
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          _StatusMessage(
            icon: Icons.error_outline,
            message: error,
            color: scheme.error,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: canProbe ? _probe : null,
              icon: _probing
                  ? const _ButtonProgress()
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Test connection'),
            ),
            FilledButton.icon(
              onPressed: canLink ? _link : null,
              icon: _linking ? const _ButtonProgress() : const Icon(Icons.link),
              label: const Text('Link library'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinked(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.controller.clientState;
    final host = state.host;
    final dictionaries = state.dictionaries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: Icons.link,
          title: 'Hachidori shared library',
          subtitle: 'Manage shared dictionaries in the Hachidori host.',
          color: scheme.tertiary,
          trailing: OutlinedButton.icon(
            onPressed: _unlinking ? null : _unlink,
            icon: _unlinking
                ? const _ButtonProgress()
                : const Icon(Icons.link_off),
            label: const Text('Unlink'),
          ),
        ),
        const SizedBox(height: 14),
        _StatusMessage(
          icon: state.ready
              ? Icons.check_circle_outline
              : state.error != null
              ? Icons.error_outline
              : Icons.sync,
          message: [
            if (host != null) '${host.name} ${host.version}',
            if (state.connecting) 'Connecting',
            ?state.error,
            if (host == null && !state.connecting && state.error == null)
              'Waiting for host status',
          ].join(' • '),
          color: state.error != null ? scheme.error : scheme.tertiary,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          _StatusMessage(
            icon: Icons.error_outline,
            message: error,
            color: scheme.error,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Host dictionaries',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              _dictionaryCountLabel(dictionaries.length),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (dictionaries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No host dictionary metadata is available yet. Mangatan will '
              'refresh this read-only list when the host reconnects.',
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var index = 0; index < dictionaries.length; index++) ...[
                  _HostDictionaryTile(dictionary: dictionaries[index]),
                  if (index != dictionaries.length - 1)
                    Divider(height: 1, color: scheme.outlineVariant),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

class _ProbeSummary extends StatelessWidget {
  const _ProbeSummary({required this.result});

  final HachidoriProbeResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _StatusMessage(
      icon: Icons.check_circle_outline,
      message:
          '${result.host.name} ${result.host.version} • '
          '${_dictionaryCountLabel(result.host.dictionaryCount)}',
      color: scheme.primary,
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class _HostDictionaryTile extends StatelessWidget {
  const _HostDictionaryTile({required this.dictionary});

  final HachidoriDictionaryInfo dictionary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = <String>[
      if (dictionary.termCount > 0) '${dictionary.termCount} terms',
      if (dictionary.frequencyCount > 0)
        '${dictionary.frequencyCount} frequencies',
      if (dictionary.pitchCount > 0) '${dictionary.pitchCount} pitch entries',
      if (dictionary.kanjiCount > 0) '${dictionary.kanjiCount} Kanji entries',
      if (dictionary.mediaCount > 0) '${dictionary.mediaCount} media files',
    ];
    return ListTile(
      leading: Icon(
        dictionary.enabled ? Icons.menu_book : Icons.menu_book_outlined,
      ),
      title: Text(
        dictionary.displayName?.trim().isNotEmpty == true
            ? dictionary.displayName!
            : dictionary.title,
      ),
      subtitle: details.isEmpty ? null : Text(details.join(' • ')),
      trailing: DecoratedBox(
        decoration: BoxDecoration(
          color: (dictionary.enabled ? scheme.primary : scheme.outline)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            dictionary.enabled ? 'Enabled' : 'Disabled',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: dictionary.enabled ? scheme.primary : scheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

String _dictionaryCountLabel(int count) =>
    '$count ${count == 1 ? 'dictionary' : 'dictionaries'}';

String _describeError(Object error) {
  if (error case HachidoriException(:final message)) return message;
  return error.toString();
}
