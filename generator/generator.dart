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

const _url = 'https://colornames.org/download/colornames.zip';
const _generatedFilePath = 'lib/colorz.dart';
const _maxNumberOfColors = 9000;
const _numberOfRequiredUpvotes = 3;

Future<void> main() async {
  print('Generating Colorz library.');
  Console.init();
  final data = await _runTask('Downloading colornames...', _downloadColorNames);
  final unzipped = await _runTask('Unzipping data...', () => _unzip(data));
  final parsed = await _runTask('Parsing data...', () => _parse(unzipped));
  final sorted = await _runTask(
      'Preparing identifiers...', () => _prepareIdentifiers(parsed.toList()));
  final source = await _runTask('Generating source...',
      () => _generateSource(sorted.take(_maxNumberOfColors)));
  await _runTask(
      'Writing to $_generatedFilePath...', () => _writeSource(source));
  print('Generated Colorz library.');
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
    @required this.hexColor,
    @required this.identifierName,
    @required this.originalName,
    @required this.upvotes,
  })  : assert(hexColor != null),
        assert(identifierName != null),
        assert(originalName != null),
        assert(upvotes != null);

  final String hexColor;
  final String identifierName;
  final String originalName;
  final int upvotes;
}

Future<Set<NamedColor>> _parse(Uint8List bytes) async {
  final colors = <NamedColor>{};
  final lines = String.fromCharCodes(bytes)
      .split('\n')
      .skip(1) // first line is header
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
    identifierName: _nameToIdentifier(name),
    originalName: name,
    upvotes: int.parse(votes),
  );
}

String _nameToIdentifier(String colorName) {
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
  final reservedNames = ['class', 'switch', 'on', 'in', 'void'];

  colors = colors
      // Remove colors which are named like reserved dart keywords or could not be valid identifiers.
      .where((color) => color.identifierName.startsWith(RegExp('[a-z]|[A-Z]')))
      .where((color) => !reservedNames.contains(color.identifierName))
      // Remove colors with less than _numberOfRequiredUpvotes votes.
      .where((color) => color.upvotes >= _numberOfRequiredUpvotes)
      .toList();

  // Because we turn color names into Dart identifiers, two names may map to the
  // same identifier. For example, "Some blue" and "Some Blue" both map to
  // "someBlue". In these cases, we choose the more popular color.
  final colorsByName = colors.groupBy((color) => color.identifierName);
  colors = <NamedColor>[
    for (final name in colorsByName.keys)
      colorsByName[name].reduce((a, b) => a.upvotes > b.upvotes ? a : b),
  ];

  // Sort colors by name.
  return colors..sort((a, b) => a.identifierName.compareTo(b.identifierName));
}

String _generateSource(Iterable<NamedColor> colors) {
  return Template(
    File('generator/colorz.tmpl').readAsStringSync(),
    htmlEscapeValues: false,
  ).renderString({
    'date': DateFormat.yMMMd().format(DateTime.now()),
    'numberOfColors': _maxNumberOfColors,
    'numberOfRequiredUpvotes': _numberOfRequiredUpvotes,
    'method': [
      for (final color in colors)
        {
          'identifier': color.identifierName,
          'name': color.originalName,
          'hexColor': color.hexColor,
          'upvotes': color.upvotes,
        }
    ],
  });
}

Future<void> _writeSource(String source) =>
    File(_generatedFilePath).writeAsString(source);
