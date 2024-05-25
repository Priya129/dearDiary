import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppStyle{
  static Color bgColor = Color(0xFFe2e2ff);
  static Color mainColor = Color(0xFFB483F1);
  static Color accentColor = Color(0xFF0065FF);

  static List<Color> cardsColor = [

    Colors.red.shade100,
    Colors.pink.shade100,
    Colors.green.shade100,
    Colors.purple.shade100,
    Colors.indigo.shade200,
    Colors.deepPurple.shade100,
    Colors.blueGrey.shade100,
    Colors.teal.shade100,
    Colors.pink.shade100,
    Colors.lightBlue.shade100,

  ];

  static List<String> imagePaths = [
    'assets/image1.jpg',
    'assets/image2.jpg',
    'assets/image3.jpg',

  ];
  static TextStyle mainTitle=
      GoogleFonts.roboto(fontSize: 18.0, fontWeight: FontWeight.normal);

  static TextStyle mainContent=
  GoogleFonts.italiana(fontSize: 22.0, fontWeight: FontWeight.bold);
  static TextStyle dateTitle=
  GoogleFonts.roboto(fontSize: 15.0, fontWeight: FontWeight.w400);


}