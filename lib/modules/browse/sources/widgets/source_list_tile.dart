import 'package:flutter/material.dart';
import 'package:shiori/shiori.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/repositories/source_repository.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_profile_override_dialog.dart';
import 'package:mangayomi/modules/widgets/entry_badge_chip.dart';
import 'package:mangayomi/modules/widgets/tv_row_button.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/extension_icon_resolver.dart';
import 'package:mangayomi/services/mining/dictionary_profile_resolver.dart';
import 'package:mangayomi/utils/cached_network.dart';
import 'package:mangayomi/utils/item_type_localization.dart';
import 'package:mangayomi/utils/language.dart';

class SourceListTile extends StatelessWidget {
  final ItemType itemType;
  final Source source;

  bool get isLocal => source.name == "local" && source.lang == "";

  const SourceListTile({
    super.key,
    required this.source,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    final dictionaryProfileSourceId =
        DictionaryProfileResolver.overrideIdForSource(source);
    return Consumer(
      builder: (context, ref, child) => ListTile(
        onTap: () {
          if (!isLocal) {
            sourceRepository.markLastUsed(itemType, source.id);
          }
          context.push('/mangaHome', extra: (source, false));
        },
        leading: SourceIcon(iconUrl: source.iconUrl, source: source),
        subtitle: SourceMeta(source: source),
        title: Text(
          !isLocal
              ? source.name!
              : "${context.l10n.local_source} ${source.itemType.localized(context.l10n)}",
        ),
        // As wide as its actions: a longer word for "Latest" in another
        // language is not cut.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: ShioriSpace.s4,
          children: [
            ShioriButton.quiet(
              label: context.l10n.latest,
              onPressed: () =>
                  context.push('/mangaHome', extra: (source, true)),
            ),
            if (!isLocal && dictionaryProfileSourceId != null)
              IconButton(
                tooltip: 'Set dictionary profile',
                onPressed: () async {
                  await showDictionaryProfileOverrideDialog(
                    context: context,
                    overrideKey: DictionaryProfileResolver.sourceOverrideKey(
                      dictionaryProfileSourceId,
                    ),
                    autoProfile: DictionaryProfileResolver.resolve(
                      sourceLanguage:
                          DictionaryProfileResolver.sourceLanguageForSource(
                            source,
                          ),
                    ),
                    title: 'Dictionary profile for this source',
                  );
                },
                icon: const Icon(Symbols.menu_book_rounded),
              ),
            if (!isLocal)
              IconButton(
                padding: const EdgeInsets.all(0),
                onPressed: () {
                  sourceRepository.save(source..isPinned = !source.isPinned!);
                },
                tooltip: context.l10n.pin,
                icon: Icon(
                  Symbols.push_pin_rounded,
                  fill: source.isPinned! ? 1 : 0,
                  color: source.isPinned!
                      ? context.shiori.color.accentInk
                      : null,
                ),
              )
            else
              // The pin's room, kept so Latest lines up with the rows above.
              SizedBox.square(dimension: context.shiori.density.minTarget),
          ],
        ),
      ),
    );
  }
}

/// TV variant of [SourceListTile]: three independently d-pad-focusable buttons
/// in a row — the source (opens popular), Latest, and Pin — so the remote moves
/// Left/Right between them and Up/Down between rows. See #729.
class TvSourceRow extends StatelessWidget {
  final Source source;
  final ItemType itemType;
  final FocusNode? sourceNode;
  final FocusNode? latestNode;
  final FocusNode? pinNode;

  const TvSourceRow({
    super.key,
    required this.source,
    required this.itemType,
    this.sourceNode,
    this.latestNode,
    this.pinNode,
  });

  bool get isLocal => source.name == "local" && source.lang == "";

  void _openPopular(BuildContext context) {
    if (!isLocal) {
      final sources = sourceRepository.getByItemType(itemType);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var src in sources) {
        src
          ..lastUsed = src.id == source.id
          ..updatedAt = now;
      }
      sourceRepository.putAll(sources);
    }
    context.push('/mangaHome', extra: (source, false));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) => TvListRow(
        children: [
          Expanded(
            child: TvRowButton(
              focusNode: sourceNode,
              onTap: () => _openPopular(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShioriSpace.s12,
                  vertical: ShioriSpace.s8,
                ),
                child: Row(
                  children: [
                    SourceIcon(iconUrl: source.iconUrl, source: source),
                    const SizedBox(width: ShioriSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            !isLocal
                                ? source.name!
                                : "${context.l10n.local_source} ${source.itemType.localized(context.l10n)}",
                            style: context.shiori.text.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SourceMeta(source: source),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ShioriSpace.s8),
          TvRowButton(
            focusNode: latestNode,
            onTap: () => context.push('/mangaHome', extra: (source, true)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ShioriSpace.s12,
                vertical: ShioriSpace.s12,
              ),
              child: Text(
                context.l10n.latest,
                style: TextStyle(color: context.shiori.color.accentInk),
              ),
            ),
          ),
          if (!isLocal) ...[
            const SizedBox(width: ShioriSpace.s8),
            TvRowButton(
              focusNode: pinNode,
              onTap: () {
                sourceRepository.save(source..isPinned = !source.isPinned!);
              },
              child: Padding(
                padding: const EdgeInsets.all(ShioriSpace.s12),
                child: Icon(
                  Symbols.push_pin_rounded,
                  fill: source.isPinned! ? 1 : 0,
                  color: source.isPinned!
                      ? context.shiori.color.accentInk
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A source's or an extension's icon, on a quiet tile while it loads or
/// when it has none.
class SourceIcon extends StatelessWidget {
  const SourceIcon({
    super.key,
    required this.iconUrl,
    this.size = 37,
    this.source,
  });

  final String? iconUrl;

  /// When given, every icon its extension may have is tried in turn
  /// ([extensionIconCandidates]) before the placeholder.
  final Source? source;

  /// The side of the tile: a list row's by default, larger on a detail page.
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Icon(Symbols.extension_rounded, size: size * 0.6),
    );
    final url = iconUrl ?? '';
    final candidates = source != null
        ? extensionIconCandidates(source!)
        : [if (url.isNotEmpty) url];
    Widget candidate(int index) => index >= candidates.length
        ? placeholder
        : cachedNetworkImage(
            imageUrl: candidates[index],
            fit: BoxFit.contain,
            width: size,
            height: size,
            errorWidget: candidate(index + 1),
            useCustomNetworkImage: false,
          );
    return Container(
      height: size,
      width: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.shiori.color.ink2,
        borderRadius: BorderRadius.circular(ShioriShape.cover),
      ),
      child: candidate(0),
    );
  }
}

/// A source's language, and an NSFW badge when it carries one.
class SourceMeta extends StatelessWidget {
  const SourceMeta({super.key, required this.source});

  final Source source;

  @override
  Widget build(BuildContext context) {
    final tokens = context.shiori;
    return Row(
      spacing: ShioriSpace.s4,
      children: [
        // Shrinks before the trailing actions do, which the fork's
        // dictionary profile button makes wider on a phone.
        Flexible(
          child: Text(
            languageName(context, source.lang!.toLowerCase()),
            style: tokens.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (source.isNsfw ?? false)
          EntryBadgeChip(label: 'NSFW', tone: tokens.color.error),
      ],
    );
  }
}
