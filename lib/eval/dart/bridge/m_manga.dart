import 'package:d4rt/d4rt.dart';
import 'package:mangayomi/eval/model/m_chapter.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/models/manga.dart';

List<T> unwrapBridgedList<T extends Object>(List? values) {
  if (values == null) return [];

  return values.map((value) {
    final nativeValue = value is BridgedInstance
        ? value.nativeObject
        : value;
    if (nativeValue is T) return nativeValue;
    throw StateError(
      'Expected $T from the Dart extension bridge, '
      'but received ${nativeValue.runtimeType}.',
    );
  }).toList();
}

class MMangaBridge {
  final mMangaBridgedClass = BridgedClass(
    nativeType: MManga,
    name: 'MManga',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        return MManga(
          artist: namedArgs.get<String?>('artist'),
          author: namedArgs.get<String?>('author'),
          description: namedArgs.get<String?>('description'),
          genre: unwrapBridgedList<String>(namedArgs.get<List?>('genre')),
          status: namedArgs.get<Status?>('status') ?? Status.unknown,
          imageUrl: namedArgs.get<String?>('imageUrl'),
          link: namedArgs.get<String?>('link'),
          chapters: unwrapBridgedList<MChapter>(
            namedArgs.get<List?>('chapters'),
          ),
          name: namedArgs.get<String?>('name'),
        );
      },
    },
    getters: {
      'name': (visitor, target) => (target as MManga).name,
      'artist': (visitor, target) => (target as MManga).artist,
      'author': (visitor, target) => (target as MManga).author,
      'description': (visitor, target) => (target as MManga).description,
      'genre': (visitor, target) => (target as MManga).genre,
      'status': (visitor, target) => (target as MManga).status,
      'imageUrl': (visitor, target) => (target as MManga).imageUrl,
      'link': (visitor, target) => (target as MManga).link,
      'chapters': (visitor, target) => (target as MManga).chapters,
    },
    setters: {
      'name': (visitor, target, value) =>
          (target as MManga).name = value as String?,
      'artist': (visitor, target, value) =>
          (target as MManga).artist = value as String?,
      'author': (visitor, target, value) =>
          (target as MManga).author = value as String?,
      'description': (visitor, target, value) =>
          (target as MManga).description = value as String?,
      'genre': (visitor, target, value) =>
          (target as MManga).genre = unwrapBridgedList<String>(value as List?),
      'status': (visitor, target, value) =>
          (target as MManga).status = value as Status?,
      'imageUrl': (visitor, target, value) =>
          (target as MManga).imageUrl = value as String?,
      'link': (visitor, target, value) =>
          (target as MManga).link = value as String,
      'chapters': (visitor, target, value) =>
          (target as MManga).chapters = unwrapBridgedList<MChapter>(
            value as List?,
          ),
    },
  );
  void registerBridgedClasses(D4rt interpreter) {
    interpreter.registerBridgedClass(
      mMangaBridgedClass,
      'package:mangayomi/bridge_lib.dart',
    );
  }
}
