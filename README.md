<p align="center">
 <img width=200px height=200px src="assets/app_icons/icon-red.png"/>
</p>

<h1 align="center"> Mangatan </h1>

<div align="center">

 [![GitHub downloads](https://img.shields.io/github/downloads/1Selxo/Mangatan/total?label=downloads&labelColor=27303D&color=0D1117&logo=github&logoColor=FFFFFF&style=flat)](https://github.com/1Selxo/Mangatan/releases)
![star](https://img.shields.io/github/stars/1Selxo/Mangatan)
 [![Discord server](https://img.shields.io/badge/Discord-join-5865F2?logo=discord&logoColor=white)](https://discord.com/invite/Ak2sW9Nvr9)


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

## Download
Get the app from our [releases page](https://github.com/1Selxo/Mangatan/releases).

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
