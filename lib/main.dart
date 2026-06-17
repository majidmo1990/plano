import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'dart:convert';
import 'dart:async';

void main() => runApp(const PlanoApp());

class PlanoApp extends StatelessWidget {
  const PlanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پلنو',
      theme: ThemeData(
        fontFamily: 'Vazir',
        primaryColor: const Color(0xFF044541),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF044541),
          secondary: Color(0xFFe5f557),
        ),
        useMaterial3: true,
      ),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const PlannerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  final String _apiUrl = 'http://181.41.194.56:5001/analyze';

  Future<void> _sendToAI() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _result = 'لطفاً متنی بنویسید');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'در حال ارسال...';
    });

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': _controller.text}),
          )
          .timeout(const Duration(seconds: 30));

      setState(() {
        _result = 'Status: ${response.statusCode}\nBody: ${response.body}';
      });
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پلنو'),
        centerTitle: true,
        backgroundColor: const Color(0xFF044541),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'برنامه‌ات را بنویس...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendToAI,
              child: Text(_isLoading ? 'در حال تحلیل...' : 'تحلیل با هوش مصنوعی'),
            ),
            const SizedBox(height: 20),
            if (_result.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_result),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
