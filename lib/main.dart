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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF044541),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
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
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;
  int _score = 0;
  late Jalali _selectedDate;
  final String _apiUrl = 'http://181.41.194.56:5001/analyze';

  @override
  void initState() {
    super.initState();
    _selectedDate = Jalali.now();
    _loadTasks();
  }

  String _getDateKey() {
    return 'tasks_${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}';
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDateKey();
    final String? tasksString = prefs.getString(key);
    if (tasksString != null) {
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(jsonDecode(tasksString));
        _calculateScore();
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDateKey();
    await prefs.setString(key, jsonEncode(_tasks));
    _calculateScore();
  }

  void _calculateScore() {
    if (_tasks.isEmpty) {
      setState(() => _score = 0);
      return;
    }
    final doneCount = _tasks.where((t) => t['done'] == true).length;
    setState(() => _score = ((doneCount / _tasks.length) * 100).round());
  }

  String _extractJson(String text) {
    int start = text.indexOf('{');
    int end = text.lastIndexOf('}') + 1;
    if (start != -1 && end > start) {
      return text.substring(start, end);
    }
    return '{"tasks": []}';
  }

  Future<void> _sendToAI() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': _controller.text}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String resultString = data['result'] ?? '';
        String cleanJson = _extractJson(resultString);
        final parsed = jsonDecode(cleanJson);
        
        List<Map<String, dynamic>> newTasks = [];
        if (parsed['tasks'] != null) {
          newTasks = List<Map<String, dynamic>>.from(parsed['tasks']);
        } else if (parsed['timed_tasks'] != null) {
          newTasks = List<Map<String, dynamic>>.from(parsed['timed_tasks']);
        }
        
        for (var task in newTasks) {
          task['done'] = false;
        }
        
        setState(() => _tasks = newTasks);
        _saveTasks();
        _controller.clear();
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleTask(int index) async {
    setState(() {
      _tasks[index]['done'] = !(_tasks[index]['done'] ?? false);
    });
    await _saveTasks();
  }

  String _getFormattedDate() {
    final monthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return '${_selectedDate.day} ${monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.addDays(days);
    });
    _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('پلنو'),
        centerTitle: true,
        backgroundColor: const Color(0xFF044541),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF044541).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // تاریخ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF044541)),
                    onPressed: () => _changeDate(-1),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF044541), const Color(0xFF044541).withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getFormattedDate(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF044541)),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // امتیاز
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF044541), const Color(0xFF044541).withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'امتیاز امروز',
                      style: TextStyle(color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFe5f557),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$_score',
                        style: const TextStyle(
                          color: Color(0xFF044541),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ورودی متن
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'برنامه‌ات را بنویس...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // دکمه تحلیل
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendToAI,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'در حال تحلیل...' : 'تحلیل با هوش مصنوعی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF044541),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 16),

              // لیست کارها
              if (_tasks.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final isDone = task['done'] ?? false;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: isDone,
                            onChanged: (_) => _toggleTask(index),
                            activeColor: const Color(0xFF044541),
                          ),
                          title: Text(
                            task['title'] ?? 'بدون عنوان',
                            style: TextStyle(
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone ? Colors.grey : Colors.black87,
                            ),
                          ),
                          subtitle: task['time'] != null
                              ? Text('⏰ ${task['time']}')
                              : null,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: task['priority'] == 'بالا'
                                  ? Colors.red.shade100
                                  : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              task['priority'] ?? 'متوسط',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text(
                      'هیچ کاری ثبت نشده',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
