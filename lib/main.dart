import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart'; //im touching this !
import 'firebase_options.dart'; // Add this
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Firebase initialization error: $e\n$stackTrace');
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Firebase Error: $e'))),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: const LocalEventFinderApp(),
    );
  }
}

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}
