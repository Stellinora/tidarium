import 'package:flutter/material.dart';

import 'features/home/home_page.dart';
import 'ui/theme.dart';

class TidariumApp extends StatelessWidget {
  const TidariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidarium',
      debugShowCheckedModeBanner: false,
      theme: buildTidariumTheme(Brightness.light),
      darkTheme: buildTidariumTheme(Brightness.dark),
      home: const HomePage(),
    );
  }
}
