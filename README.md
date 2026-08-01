<p align="center">
 <img width=200px height=200px src="assets/app_icons/icon-red.png"/>
</p>

<h1 align="center"> Mangatan </h1>

<div align="center">

 [![GitHub downloads](https://img.shields.io/github/downloads/1Selxo/Mangatan/total?label=downloads&labelColor=27303D&color=0D1117&logo=github&logoColor=FFFFFF&style=flat)](https://github.com/1Selxo/Mangatan/releases)
![star](https://img.shields.io/github/stars/1Selxo/Mangatan)
 [![Discord server](https://img.shields.io/badge/Discord-join-5865F2?logo=discord&logoColor=white)](https://discord.gg/SqwE6b7Bb)


 Mangatan is an open-source desktop app for reading manga and novels, watching anime, and learning languages through dictionary lookup, OCR, subtitle mining, and Anki export.
</div>

## Features

<div align="left">

Features include:
* Reading manga, webtoons, comics, novels, animes, movies, and more.
* Local reading of content.
* A configurable reader with multiple viewers, reading directions and other settings.
* Tracker support for anime and manga: [MyAnimeList](https://myanimelist.net/), [AniList](https://anilist.co/), [SIMKL](https://simkl.com/), [trakt](https://app.trakt.tv/) and [Kitsu](https://kitsu.io/) support.
* Categories to organize your library.
* Light and dark themes.
* Create backups locally to read offline or to your desired cloud service.

</div>


## Screenshots

<table>
  <tr>
    <td width="50%" align="center">
      <strong>Manga Shelf</strong><br><br>
      <img src="assets/screenshots/manga-shelf.jpg" alt="Mangatan manga shelf" width="100%">
    </td>
    <td width="50%" align="center">
      <strong>Manga Lookup</strong><br><br>
      <img src="assets/screenshots/manga-lookup.jpg" alt="Dictionary lookup while reading manga" width="100%">
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <strong>Anime Lookup</strong><br><br>
      <img src="assets/screenshots/anime-lookup.jpg" alt="OCR dictionary lookup while watching anime" width="100%">
    </td>
    <td width="50%" align="center">
      <strong>Novel Lookup</strong><br><br>
      <img src="assets/screenshots/novel-lookup.jpg" alt="Dictionary lookup while reading a Japanese novel" width="100%">
    </td>
  </tr>
  <tr>
    <td colspan="2" align="center">
      <strong>Dictionary</strong><br><br>
      <img src="assets/screenshots/dictionary.jpg" alt="Mangatan dictionary search" width="75%">
    </td>
  </tr>
</table>

## Download

Get Mangatan from the [releases page](https://github.com/1Selxo/Mangatan/releases).

### Android

Looking for the Android version? See [Chimahon](https://github.com/sohilsayed/chimahon).

## iOS Sideloading Sources
<a href="https://intradeus.github.io/http-protocol-redirector?r=altstore://source?url=https://raw.githubusercontent.com/1Selxo/Mangatan/refs/heads/main/repo/source.json"><img alt="AltStore Source" src="repo/images/buttons/altstore_button.png" width="150"></a>
&nbsp;
<a href="https://intradeus.github.io/http-protocol-redirector?r=feather://source/https://raw.githubusercontent.com/1Selxo/Mangatan/refs/heads/main/repo/source.json"><img alt="Feather Source" src="repo/images/buttons/feather_button.png" width="150"></a>
&nbsp;
<a href="https://intradeus.github.io/http-protocol-redirector?r=sidestore://source?url=https://raw.githubusercontent.com/1Selxo/Mangatan/refs/heads/main/repo/source.json"><img alt="Sidestore Source" src="repo/images/buttons/sidestore_button.png" width="150"></a>
&nbsp;
<a href="https://raw.githubusercontent.com/1Selxo/Mangatan/refs/heads/main/repo/source.json"><img alt="Direct URL Source" src="repo/images/buttons/url_button.png" width="150"></a>

Release IPAs are intentionally unsigned. AltStore, SideStore, Feather, Sideloadly, and similar tools sign the app with your Apple ID during installation.

To build an IPA without publishing a release, open **Actions → Build iOS sideload IPA → Run workflow**. Download the IPA from the completed run's artifacts. Pushing a `v*` tag also attaches the IPA to that GitHub release and refreshes the sideloading source.

### Anki on iOS

The iOS build exports cards through AnkiMobile callbacks instead of
AnkiConnect. In **Settings → Dictionary → Anki**, tap **Refresh** once to open
AnkiMobile and import its current decks, note types, and fields. Mining then
opens AnkiMobile to add the note and returns to Mangatan when the note succeeds;
images and audio are transferred locally during that callback.

Japanese word audio is enabled by default with JapanesePod101, Jisho.org, and
LanguagePod101. Audio sources are ordered fallbacks: add, remove, edit, or move
multiple built-in and custom URL/JSON sources from the same Anki settings page.

# Contributing

Contributions are welcome!

To get started with extension development, see the archived upstream [Dart extension guide](https://github.com/kodjodevf/mangayomi-extensions/blob/main/CONTRIBUTING-DART.md) or [JavaScript extension guide](https://github.com/kodjodevf/mangayomi-extensions/blob/main/CONTRIBUTING-JS.md).

## Using flutter_rust_bridge

To run and build this app, you need to have
[Flutter SDK](https://docs.flutter.dev/get-started/install)
and [Rust toolchain](https://www.rust-lang.org/tools/install)
installed on your system.
You can check that your system is ready with the commands below.
Note that all the Flutter subcomponents should be installed.

```bash
rustc --version
flutter doctor
```

You also need to have the CLI tool for flutter_rust_bridge ready.

```bash
cargo install 'flutter_rust_bridge_codegen'
```

run the following command:

```bash
flutter_rust_bridge_codegen generate
```

Now you can run and build this app just like any other Flutter projects.

```bash
flutter run
```

### macOS quick build

On macOS, use the helper script to build the desktop app and open it:

```bash
./scripts/build_macos.sh
```

Useful options:

```bash
./scripts/build_macos.sh --release
./scripts/build_macos.sh --clean --no-open
```



## License

    Copyright 2023 Moustapha Kodjo Amadou

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3 of the License.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.


## Disclaimer

 Mangatan does not host any content, and the developers of this application are not affiliated with content providers available on the internet.
