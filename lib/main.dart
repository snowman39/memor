import 'package:flutter/material.dart';
import 'package:memor/pages/memo_page.dart';
import 'package:memor/models/memo_space_database.dart';
import 'package:memor/theme/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MemoSpaceDatabase.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MemoSpaceDatabase()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memor',
      debugShowCheckedModeBanner: false,
      home: const MemoPage(),
      theme: Provider.of<ThemeProvider>(context).themeData,
    );
  }
}
