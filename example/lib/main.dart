import 'package:colorz/colorz.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorz = {
      'tardis': Colorz.tardis,
      'driedToothpaste': Colorz.driedToothpaste,
      'greenBanana': Colorz.greenBanana,
      'cookieMonsterCottonCandy': Colorz.cookieMonsterCottonCandy,
      'unoReverseCardBlue': Colorz.unoReverseCardBlue,
      'darkRavenclawBlue': Colorz.darkRavenclawBlue,
      'arabicaMint': Colorz.arabicaMint,
      'pickleyCactus': Colorz.pickleyCactus,
      'margesHair': Colorz.margesHair,
    };

    return MaterialApp(
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in colorz.entries)
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  color: entry.value,
                  child: SelectableText(entry.key),
                ),
              )
          ],
        ),
      ),
    );
  }
}
