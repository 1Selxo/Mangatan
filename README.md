<p align="center">
 <img width=200px height=200px src="assets/app_icons/icon-red.png"/>
</p>

<h1 align="center"> Mangayomi </h1>

<div align="center">

 [![GitHub downloads](https://img.shields.io/github/downloads/kodjodevf/mangayomi/total?label=downloads&labelColor=27303D&color=0D1117&logo=github&logoColor=FFFFFF&style=flat)](https://github.com/kodjodevf/mangayomi/releases)
![star](https://img.shields.io/github/stars/kodjodevf/mangayomi)
 [![Discord server](https://img.shields.io/discord/1157628512077893666.svg?label=&labelColor=6A7EC2&color=7389D8&logo=discord&logoColor=FFFFFF)](https://discord.com/invite/EjfBuYahsP) 


Mangayomi is an open-source Flutter app for reading manga, novels, and watching animes across multiple platforms.
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
Get the app from our [releases page](https://github.com/kodjodevf/mangayomi/releases).

## iOS Sideloading Sources
<a href="https://intradeus.github.io/http-protocol-redirector?r=altstore://source?url=https://raw.githubusercontent.com/kodjodevf/mangayomi/refs/heads/main/repo/source.json"><img alt="AltStore Source" src="repo/images/buttons/altstore_button.png" width="150"></a>
&nbsp;
<a href="https://intradeus.github.io/http-protocol-redirector?r=feather://source/https://raw.githubusercontent.com/kodjodevf/mangayomi/refs/heads/main/repo/source.json"><img alt="Feather Source" src="repo/images/buttons/feather_button.png" width="150"></a>
&nbsp;
<a href="https://intradeus.github.io/http-protocol-redirector?r=sidestore://source?url=https://raw.githubusercontent.com/kodjodevf/mangayomi/refs/heads/main/repo/source.json"><img alt="Sidestore Source" src="repo/images/buttons/sidestore_button.png" width="150"></a>
&nbsp;
<a href="https://raw.githubusercontent.com/kodjodevf/mangayomi/refs/heads/main/repo/source.json"><img alt="Direct URL Source" src="repo/images/buttons/url_button.png" width="150"></a>

Note: Only future releases (> 0.5.2) will be signed (and therefore have AltStore/SideStore compatibility).

# Contributing

Contributions are welcome!

To get started with extension development, see [CONTRIBUTING-DART.md](https://github.com/kodjodevf/mangayomi-extensions/blob/main/CONTRIBUTING-DART.md) for create sources in Dart or [CONTRIBUTING-JS.md](https://github.com/kodjodevf/mangayomi-extensions/blob/main/CONTRIBUTING-JS.md) for create sources in JavaScript.

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

Mangayomi is not hosting any kind of content and the developer(s) of this application does not have any affiliation with the content providers that are freely available in the internet.
