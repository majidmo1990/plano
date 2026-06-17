import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const PlanoApp());
}

Future<void> _requestPermissions() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

void showNotification(String title, String body, int id) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'plano_channel',
    'پلنو',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    platformChannelSpecifics,
  );
}

class PlanoApp extends StatelessWidget {
  const PlanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پلنو',
      theme: ThemeData(
        fontFamily: 'Vazirmatn',
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
  List<Map<String, dynamic>> _timedTasks = [];
  List<Map<String, dynamic>> _untimedTasks = [];
  bool _isLoading = false;
  String _error = '';
  final String _apiUrl = 'http://181.41.194.56:5001/analyze';

  String _extractJson(String text) {
    int start = text.indexOf('{');
    int end = text.lastIndexOf('}') + 1;
    if (start != -1 && end > start) {
      return text.substring(start, end);
    }
    return '{"timed_tasks": [], "untimed_tasks": []}';
  }

  Future<void> _sendToAI() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _error = 'لطفاً متنی بنویسید');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _timedTasks = [];
      _untimedTasks = [];
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

        List<Map<String, dynamic>> newTimed = [];
        List<Map<String, dynamic>> newUntimed = [];

        if (parsed['timed_tasks'] != null) {
          newTimed = List<Map<String, dynamic>>.from(parsed['timed_tasks']);
          for (var task in newTimed) {
            task['done'] = false;
          }
          newTimed.sort((a, b) => (a['time'] ?? '00:00').compareTo(b['time'] ?? '00:00'));
        }

        if (parsed['untimed_tasks'] != null) {
          newUntimed = List<Map<String, dynamic>>.from(parsed['untimed_tasks']);
          for (var task in newUntimed) {
            task['done'] = false;
          }
        }

        setState(() {
          _timedTasks = newTimed;
          _untimedTasks = newUntimed;
        });

        // تنظیم نوتیفیکیشن برای کارهای زمان‌دار
        for (var task in newTimed) {
          if (task['time'] != null && task['time'].toString().isNotEmpty) {
            final timeParts = task['time'].split(':');
            if (timeParts.length == 2) {
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              final now = DateTime.now();
              final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
              if (scheduledTime.isAfter(now)) {
                final delay = scheduledTime.difference(now);
                Future.delayed(delay, () {
                  showNotification(
                    '⏰ یادآوری پلنو',
                    '${task['title']} - ساعت ${task['time']}',
                    task['title'].hashCode,
                  );
                });
              }
            }
          }
        }

        _controller.clear();
      } else {
        setState(() => _error = 'خطا: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'خطا: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleTask(bool isTimed, int index) {
    setState(() {
      if (isTimed) {
        _timedTasks[index]['done'] = !(_timedTasks[index]['done'] ?? false);
        if (_timedTasks[index]['done'] == true) {
          showNotification(
            '🎉 تبریک!',
            'کار "${_timedTasks[index]['title']}" انجام شد',
            _timedTasks[index]['title'].hashCode,
          );
        }
      } else {
        _untimedTasks[index]['done'] = !(_untimedTasks[index]['done'] ?? false);
        if (_untimedTasks[index]['done'] == true) {
          showNotification(
            '🎉 تبریک!',
            'کار "${_untimedTasks[index]['title']}" انجام شد',
            _untimedTasks[index]['title'].hashCode,
          );
        }
      }
    });
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'بالا':
        return Colors.red.shade500;
      case 'پایین':
        return Colors.green.shade500;
      default:
        return const Color(0xFFe5f557);
    }
  }

  Widget _buildTaskList(String title, List<Map<String, dynamic>> tasks, bool isTimed) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(isTimed ? Icons.access_time : Icons.list, size: 20, color: const Color(0xFF044541)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF044541),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
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
                onChanged: (_) => _toggleTask(isTimed, index),
                activeColor: const Color(0xFF044541),
              ),
              title: Text(
                task['title'] ?? 'بدون عنوان',
                style: TextStyle(
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : Colors.black87,
                ),
              ),
              subtitle: isTimed && task['time'] != null
                  ? Text('⏰ ${task['time']}', style: const TextStyle(fontSize: 12))
                  : null,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPriorityColor(task['priority']),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  task['priority'] ?? 'متوسط',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'برنامه امروزت را بنویس',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF044541),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'مثال: فردا ساعت ۶ بیداری، باشگاه، مراقبه',
                    hintStyle: const TextStyle(color: Colors.grey),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
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
                  ),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_timedTasks.isNotEmpty || _untimedTasks.isNotEmpty)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTaskList('⏰ برنامه زمان‌دار', _timedTasks, true),
                        _buildTaskList('📋 کارهای بدون زمان مشخص', _untimedTasks, false),
                      ],
                    ),
                  ),
                )
              else if (!_isLoading && _error.isEmpty)
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
