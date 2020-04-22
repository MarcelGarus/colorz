import 'package:colorz/colorz.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Column(
        children: [
          Container(height: 50, color: Colorz.aDisneyVillain),
          Container(height: 50, color: Colorz.almostMidnight),
          Container(height: 50, color: Colorz.raspberryFruityCream),
        ],
      ),
    );
  }
}
