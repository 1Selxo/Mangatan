import 'dart:async';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/anime/providers/state_provider.dart';
import 'package:mangayomi/modules/anime/widgets/subtitle_view.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/subtitles/subtitle_regex_filters.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';

class FontSettingWidget extends ConsumerStatefulWidget {
  final bool hasSubtitleTrack;
  const FontSettingWidget({super.key, required this.hasSubtitleTrack});

  @override
  ConsumerState<FontSettingWidget> createState() => _FontSettingWidgetState();
}

class SubtitleFilterSettingWidget extends StatefulWidget {
  const SubtitleFilterSettingWidget({super.key});

  @override
  State<SubtitleFilterSettingWidget> createState() =>
      _SubtitleFilterSettingWidgetState();
}

class _SubtitleFilterSettingWidgetState
    extends State<SubtitleFilterSettingWidget> {
  @override
  void initState() {
    super.initState();
    unawaited(SubtitleRegexFilterState.initialize());
  }

  Future<void> _editCustomPattern(SubtitleRegexFilterOptions options) async {
    final controller = TextEditingController(text: options.customRegexPattern);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom subtitle regex'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: r'Pattern removed from every subtitle',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await SubtitleRegexFilterState.set(
      options.copyWith(customRegexPattern: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubtitleRegexFilterOptions>(
      valueListenable: SubtitleRegexFilterState.options,
      builder: (context, options, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _switch(
            'Remove speaker names',
            'Removes leading names such as “(John):”',
            options.removeSpeakerNames,
            (value) => options.copyWith(removeSpeakerNames: value),
          ),
          _switch(
            'Merge multiline subtitles',
            'Shows the current cue as one continuous line',
            options.mergeMultiline,
            (value) => options.copyWith(mergeMultiline: value),
          ),
          _switch(
            'Remove bracketed text',
            'Removes descriptions inside [square brackets]',
            options.removeBracketedText,
            (value) => options.copyWith(removeBracketedText: value),
          ),
          _switch(
            'Remove curly-braced text',
            'Removes formatting or descriptions inside {braces}',
            options.removeCurlyBracedText,
            (value) => options.copyWith(removeCurlyBracedText: value),
          ),
          _switch(
            'Remove uppercase lines',
            'Hides cues made entirely from uppercase letters',
            options.removeUppercaseLines,
            (value) => options.copyWith(removeUppercaseLines: value),
          ),
          _switch(
            'Remove music symbols',
            'Removes musical-note and karaoke marker symbols',
            options.removeMusicSymbols,
            (value) => options.copyWith(removeMusicSymbols: value),
          ),
          _switch(
            'Enable custom regex',
            'Apply your own multiline removal pattern',
            options.customRegexEnabled,
            (value) => options.copyWith(customRegexEnabled: value),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Custom regex pattern'),
            subtitle: Text(
              options.customRegexPattern.trim().isEmpty
                  ? 'Not configured'
                  : options.customRegexPattern,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editCustomPattern(options),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    SubtitleRegexFilterOptions Function(bool value) update,
  ) => SwitchListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: (value) {
      unawaited(SubtitleRegexFilterState.set(update(value)));
    },
  );
}

class _FontSettingWidgetState extends ConsumerState<FontSettingWidget> {
  @override
  Widget build(BuildContext context) {
    final subtitleSettings = ref.watch(subtitleSettingsStateProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!widget.hasSubtitleTrack)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.info_outline_rounded, size: 14),
                  ),
                  Flexible(
                    child: Text(context.l10n.no_subtite_warning_message),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconButton(
                Icons.remove,
                () {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(
                        subtitleSettings
                          ..fontSize = subtitleSettings.fontSize! - 1,
                        true,
                      );
                  setState(() {});
                },
                backgroundColor: context.dynamicWhiteBlackColor,
                iconColors: context.isLight ? Colors.white : Colors.black,
                size: 25,
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  controller: TextEditingController(
                    text: subtitleSettings.fontSize.toString(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final val = int.tryParse(v);
                    if (val != null) {
                      ref
                          .read(subtitleSettingsStateProvider.notifier)
                          .set(subtitleSettings..fontSize = val, true);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: context.l10n.font_size,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.dynamicThemeColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.dynamicThemeColor),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: context.dynamicThemeColor),
                    ),
                  ),
                ),
              ),
              iconButton(
                Icons.add,
                () {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(
                        subtitleSettings
                          ..fontSize = subtitleSettings.fontSize! + 1,
                        true,
                      );
                  setState(() {});
                },
                backgroundColor: context.dynamicWhiteBlackColor,
                iconColors: context.isLight ? Colors.white : Colors.black,
                size: 25,
              ),
              iconButton(
                Icons.format_bold,
                () {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(
                        subtitleSettings
                          ..useBold = !subtitleSettings.useBold!
                          ..fontWeight = null,
                        true,
                      );
                  setState(() {});
                },
                iconColors: subtitleSettings.useBold!
                    ? null
                    : context.dynamicWhiteBlackColor.withValues(alpha: 0.5),
              ),
              iconButton(
                Icons.format_italic,
                () {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(
                        subtitleSettings
                          ..useItalic = !subtitleSettings.useItalic!,
                        true,
                      );
                  setState(() {});
                },
                iconColors: subtitleSettings.useItalic!
                    ? null
                    : context.dynamicWhiteBlackColor.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconButton(
                Icons.vertical_align_top,
                () {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(
                        subtitleSettings
                          ..position = (subtitleSettings.position ?? 0) + 10,
                        true,
                      );
                  setState(() {});
                },
                backgroundColor: context.dynamicWhiteBlackColor,
                iconColors: context.isLight ? Colors.white : Colors.black,
                size: 25,
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  controller: TextEditingController(
                    text: (subtitleSettings.position ?? 0).toString(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  onChanged: (value) {
                    final position = int.tryParse(value);
                    if (position != null) {
                      ref
                          .read(subtitleSettingsStateProvider.notifier)
                          .set(subtitleSettings..position = position, true);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: context.l10n.subtitle_position,
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.dynamicThemeColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: context.dynamicThemeColor),
                    ),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: context.dynamicThemeColor),
                    ),
                  ),
                ),
              ),
              iconButton(
                Icons.vertical_align_bottom,
                () {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(
                        subtitleSettings
                          ..position = (subtitleSettings.position ?? 0) - 10,
                        true,
                      );
                  setState(() {});
                },
                backgroundColor: context.dynamicWhiteBlackColor,
                iconColors: context.isLight ? Colors.white : Colors.black,
                size: 25,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Lorem ipsum dolor sit amet",
              style: subtileTextStyle(ref).copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(subtitleSettingsStateProvider.notifier)
                  .set(
                    subtitleSettings
                      ..useItalic = false
                      ..useBold = false
                      ..fontWeight = null
                      ..fontSize = 45
                      ..position = 0
                      ..outlineThickness = null
                      ..shadowThickness = 0,
                    true,
                  );
              setState(() {});
            },
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );
  }
}

class ColorSettingWidget extends ConsumerStatefulWidget {
  final bool hasSubtitleTrack;
  const ColorSettingWidget({super.key, required this.hasSubtitleTrack});

  @override
  ConsumerState<ColorSettingWidget> createState() => _ColorSettingWidgetState();
}

class _ColorSettingWidgetState extends ConsumerState<ColorSettingWidget> {
  String selector = "text";

  Widget button(String text, String value, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(0),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      onPressed: () {
        setState(() {
          selector = value;
        });
      },
      child: Column(
        children: [
          Text(text, style: TextStyle(color: context.textColor)),
          Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              height: 25,
              width: 25,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: color,
                border: Border.all(
                  width: 2,
                  color: context.dynamicWhiteBlackColor,
                ),
              ),
            ),
          ),
          Text("#${color.hexCode}", style: TextStyle(color: context.textColor)),
          Icon(
            Icons.arrow_drop_down,
            color: selector != value ? Colors.transparent : context.textColor,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subSets = ref.watch(subtitleSettingsStateProvider);
    final textColor = Color.fromARGB(
      subSets.textColorA!,
      subSets.textColorR!,
      subSets.textColorG!,
      subSets.textColorB!,
    );
    final borderColor = Color.fromARGB(
      subSets.borderColorA!,
      subSets.borderColorR!,
      subSets.borderColorG!,
      subSets.borderColorB!,
    );
    final backgroundColor = Color.fromARGB(
      subSets.backgroundColorA!,
      subSets.backgroundColorR!,
      subSets.backgroundColorG!,
      subSets.backgroundColorB!,
    );
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!widget.hasSubtitleTrack)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.info_outline_rounded, size: 14),
                  ),
                  Flexible(
                    child: Text(context.l10n.no_subtite_warning_message),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: button(context.l10n.text, "text", textColor),
              ),
              Expanded(
                flex: 3,
                child: button(context.l10n.border, "border", borderColor),
              ),
              Expanded(
                flex: 3,
                child: button(
                  context.l10n.background,
                  "backgroud",
                  backgroundColor,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Lorem ipsum dolor sit amet",
              style: subtileTextStyle(ref).copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
          ),
          if (selector == "text") ...[
            rgbaFilterWidget(
              subSets.textColorA!,
              subSets.textColorR!,
              subSets.textColorG!,
              subSets.textColorB!,
              (val) {
                if (val.$3 == "r") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..textColorR = val.$1.toInt(), val.$2);
                } else if (val.$3 == "g") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..textColorG = val.$1.toInt(), val.$2);
                } else if (val.$3 == "b") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..textColorB = val.$1.toInt(), val.$2);
                } else {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..textColorA = val.$1.toInt(), val.$2);
                }
                setState(() {});
              },
              context,
            ),
          ] else if (selector == "border") ...[
            rgbaFilterWidget(
              subSets.borderColorA!,
              subSets.borderColorR!,
              subSets.borderColorG!,
              subSets.borderColorB!,
              (val) {
                if (val.$3 == "r") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..borderColorR = val.$1.toInt(), val.$2);
                } else if (val.$3 == "g") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..borderColorG = val.$1.toInt(), val.$2);
                } else if (val.$3 == "b") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..borderColorB = val.$1.toInt(), val.$2);
                } else {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..borderColorA = val.$1.toInt(), val.$2);
                }
                setState(() {});
              },
              context,
            ),
          ] else ...[
            rgbaFilterWidget(
              subSets.backgroundColorA!,
              subSets.backgroundColorR!,
              subSets.backgroundColorG!,
              subSets.backgroundColorB!,
              (val) {
                if (val.$3 == "r") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..backgroundColorR = val.$1.toInt(), val.$2);
                } else if (val.$3 == "g") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..backgroundColorG = val.$1.toInt(), val.$2);
                } else if (val.$3 == "b") {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..backgroundColorB = val.$1.toInt(), val.$2);
                } else {
                  ref
                      .read(subtitleSettingsStateProvider.notifier)
                      .set(subSets..backgroundColorA = val.$1.toInt(), val.$2);
                }
                setState(() {});
              },
              context,
            ),
          ],
          TextButton(
            onPressed: () {
              ref.read(subtitleSettingsStateProvider.notifier).resetColor();
              setState(() {});
            },
            child: Text(context.l10n.reset),
          ),
        ],
      ),
    );
  }
}

Widget iconButton(
  IconData icon,
  void Function()? onPressed, {
  Color? backgroundColor,
  Color? iconColors,
  double size = 35,
}) => Padding(
  padding: const EdgeInsets.all(5),
  child: SizedBox(
    height: size,
    width: size,
    child: IconButton(
      iconSize: size * 0.9,
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(backgroundColor),
      ),
      padding: const EdgeInsets.all(1),
      onPressed: onPressed,
      icon: Icon(icon, color: iconColors),
    ),
  ),
);
