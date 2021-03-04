import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:console/console.dart' hide Color;
import 'package:dartx/dartx.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:mustache/mustache.dart';

final _url = Uri.parse('https://colornames.org/download/colornames.zip');
const _generatedFilePath = 'lib/colorz.dart';
const _numberOfColors = 9000;

Future<void> main() async {
  print('Hello.');
  Console.init();
  final data = await _runTask('Downloading colornames...', _downloadColorNames);
  final unzipped = await _runTask('Unzipping data...', () => _unzip(data));
  final parsed = await _runTask('Parsing data...', () => _parse(unzipped));
  final sorted = await _runTask(
      'Preparing identifiers...', () => _prepareIdentifiers(parsed.toList()));
  final source = await _runTask('Generating source...',
      () => _generateSource(sorted.take(_numberOfColors)));
  await _runTask(
      'Writing to $_generatedFilePath...', () => _writeSource(source));
  print('Done.');
}

Future<T> _runTask<T>(String description, FutureOr<T> Function() task) async {
  Console.write("${description.padRight(30)}");
  final timeDisplay = TimeDisplay();
  timeDisplay.start();
  final result = await task();
  timeDisplay.stop();
  Console.write('\n');
  Console.resetTextColor();
  return result;
}

Future<Uint8List> _downloadColorNames() async {
  final response = await http.get(_url);
  if (response.statusCode != 200) {
    throw Exception("Fetching $_url failed.");
  }
  return response.bodyBytes;
}

Uint8List _unzip(Uint8List bytes) {
  final files = ZipDecoder().decodeBytes(bytes).files;
  final file = files.singleWhere((file) => file.name == 'colornames.txt');
  return file.content as Uint8List;
}

@immutable
class NamedColor {
  NamedColor({
    required this.hexColor,
    required this.name,
    required this.upvotes,
  });

  final String hexColor;
  final String name;
  final int upvotes;
}

Future<Set<NamedColor>> _parse(Uint8List bytes) async {
  final colors = <NamedColor>{};
  final lines = String.fromCharCodes(bytes)
      .split('\n')
      .skip(1)
      .where((line) => !line.startsWith('#'))
      .where((line) => line.isNotEmpty)
      .toList();
  var progress = 0;
  for (final line in lines) {
    colors.add(_parseColor(line));
    progress += 1;
    // Allow for the timer to update.
    if (progress % 1000 == 0) {
      await Future.delayed(Duration.zero);
    }
  }
  return colors;
}

NamedColor _parseColor(String line) {
  final parts = line.split(',').map((part) => part.trim()).toList();
  final hexCode = parts[0];
  final name = parts[1];
  final votes = parts[2];

  return NamedColor(
    hexColor: hexCode.toUpperCase(),
    name: _nameToMethodName(name),
    upvotes: int.parse(votes).round(),
  );
}

String _nameToMethodName(String colorName) {
  final words = colorName
      .replaceAll("'", '')
      .replaceAll('-', ' ')
      .replaceAll('/', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    final isFirst = i == 0;
    final isUpperCase = word == word.toUpperCase();
    words[i] = (isFirst ? word[0].toLowerCase() : word[0].toUpperCase()) +
        (isUpperCase ? word.substring(1).toLowerCase() : word.substring(1));
  }
  return words.join();
}

List<NamedColor> _prepareIdentifiers(List<NamedColor> colors) {
  final reservedNames = [
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', // .
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'hide',
    'if', 'implements', 'import', 'in', 'interface', 'is', 'library', 'mixin',
    'new', 'null', 'on', 'operator', 'part', 'rethrow', 'return', 'set', 'show',
    'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try',
    'typedef', 'var', 'void', 'void', 'while', 'with', 'yield',
  ];

  // Dart identifiers cannot start with numbers or other characters.
  colors = colors
      .where((color) => color.name.startsWith(RegExp('[a-z]|[A-Z]')))
      .where((color) => !reservedNames.contains(color.name))
      .toList();

  // Because we turn color names into Dart identifiers, two names may map to the
  // same identifier. For example, "Some blue" and "Some Blue" both map to
  // "someBlue". In these cases, we choose the more popular color.
  final colorsByName = colors.groupBy((color) => color.name);
  colors = <NamedColor>[
    for (final name in colorsByName.keys)
      colorsByName[name]!.reduce((a, b) => a.upvotes > b.upvotes ? a : b),
  ];

  // Sort colors by popularity.
  return colors..sort((a, b) => b.upvotes.compareTo(a.upvotes));
}

String _generateSource(Iterable<NamedColor> colors) {
  return Template(
    File('generator/colorz.tmpl').readAsStringSync(),
    htmlEscapeValues: false,
  ).renderString({
    'date': DateFormat.yMMMd().format(DateTime.now()),
    'numberOfColors': _numberOfColors,
    'method': {
      for (final color in colors)
        {
          'name': color.name,
          'hexColor': color.hexColor,
        }
    },
  });
}

Future<void> _writeSource(String source) =>
    File(_generatedFilePath).writeAsString(source);
