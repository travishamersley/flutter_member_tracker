// Stub for web_only.dart classes and functions

import 'package:flutter/material.dart';

Widget renderButton({GSIButtonConfiguration? configuration}) {
  return const SizedBox();
}

class GSIButtonConfiguration {
  final GSIButtonTheme? theme;
  const GSIButtonConfiguration({this.theme});
}

enum GSIButtonTheme { outline, filledBlue, filledBlack }
