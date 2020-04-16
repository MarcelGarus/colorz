import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:console/console.dart' hide Color;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:mustache/mustache.dart';

const _url = 'https://colornames.org/download/colornames.zip';
const _generatedFilePath = 'lib/colorz.dart';

Future<void> main() async {
  print('Hello.');
  Console.init();
  final data = await _runTask('Downloading colornames...', _downloadColorNames);
  final unzipped = await _runTask('Unzipping data...', () => _unzip(data));
  final parsed = await _runTask('Parsing data...', () => _parse(unzipped));
  final sorted = await _runTask(
      'Sorting ${parsed.length} colors...', () => _sortByPopularity(parsed));
  final source = await _runTask(
      'Generating source...', () => _generateSource(sorted.take(1000000)));
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
    @required this.hexColor,
    @required this.name,
    @required this.upvotes,
  })  : assert(hexColor != null),
        assert(name != null),
        assert(upvotes != null);

  final String hexColor;
  final String name;
  final int upvotes;
}

Future<Set<NamedColor>> _parse(Uint8List bytes) async {
  final colors = <NamedColor>{};
  final lines = String.fromCharCodes(bytes)
      .split('\n')
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
  final confidence = parts[2];
  final votes = parts[3];

  return NamedColor(
    hexColor: hexCode.toUpperCase(),
    name: _nameToMethodName(name),
    upvotes: (int.parse(votes) * double.parse(confidence)).round(),
  );
}

String _nameToMethodName(String colorName) {
  final words = colorName
      .replaceAll("'", '')
      .replaceAll('-', ' ')
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

List<NamedColor> _sortByPopularity(Iterable<NamedColor> colors) {
  return colors.toList()..sort((a, b) => b.upvotes.compareTo(a.upvotes));
}

String _generateSource(Iterable<NamedColor> colors) {
  return Template(
    File('generator/colorz.tmpl').readAsStringSync(),
    htmlEscapeValues: false,
  ).renderString({
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
