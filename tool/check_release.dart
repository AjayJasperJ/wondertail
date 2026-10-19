import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version =
      RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$', multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
  if (version == null) {
    throw StateError('pubspec.yaml needs a semantic version and build number.');
  }
  final changelog = File('CHANGELOG.md').readAsStringSync();
  final readme = File('README.md').readAsStringSync();
  final entries = RegExp(r'^## \[(\d+\.\d+\.\d+)\]', multiLine: true)
      .allMatches(changelog)
      .toList();
  if (entries.isEmpty || entries.first.group(1) != version) {
    throw StateError(
        'Add the current $version release at the top of CHANGELOG.md.');
  }
  if (!readme.contains('Current version: $version') ||
      !readme.contains('(CHANGELOG.md)')) {
    throw StateError(
        'README must state the current version and link CHANGELOG.md.');
  }
  print('Release documentation matches $version.');
}
