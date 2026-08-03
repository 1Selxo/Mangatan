# Embedded Mihon runtime notices

Mangatan's optional embedded Mihon-extension runtime contains:

- OpenJDK Mobile and the OpenJDK class library, distributed under GPLv2 with
  the Classpath Exception. Source and license texts are available from
  <https://github.com/openjdk/mobile> and
  <https://github.com/openjdk-mobile/ios-tools>.
- M-Extension-Server, distributed under the Mozilla Public License 2.0. The
  exact bundled source revision is
  `68645ae7a8b2ffd0954e9c6cba62427f54f95503`, vendored in this Mangatan
  source tree at `third_party/mihon_server`.
- NewPipe Extractor, distributed under GPL-3.0-or-later and linked into the
  server JAR. Its corresponding production source for release `v0.26.3`,
  commit `caae86c943857cc6e1a762e3488d6a14e9cf7800`, is vendored at
  `third_party/newpipe_extractor`.

Desktop bundles also carry the server and NewPipe license/source notices next
to the JAR. These components are provided without warranty.
