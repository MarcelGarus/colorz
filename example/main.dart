import 'package:colorz/colorz.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          Container(height: 50, color: Colorz.itsStillBasicallyBlack),
          Container(height: 50, color: Colorz.midnightPlum),
          Container(height: 50, color: Colorz.blueRaspberryCrumble),
        ],
      ),
    );
  }
}
