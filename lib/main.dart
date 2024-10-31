import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sleepsanity_qc_test/PairedDevice.dart';

import 'BLEManager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleManager()), // Ensure BleManager is available globally
      ],
      child: MaterialApp(
        title: 'SleepSanity',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const PairedDevicesPage(),
      ),
    );
  }
}
