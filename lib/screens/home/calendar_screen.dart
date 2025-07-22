import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/event.dart';
import '../home/event_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  final List<Event> events;

  const CalendarScreen({Key? key, required this.events}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Event> _eventsForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _updateEventsForSelectedDay();
  }

  void _updateEventsForSelectedDay() {
    setState(() {
      _eventsForSelectedDay = widget.events.where((event) {
        final eventDateParts = event.date.split('/');
        if (eventDateParts.length != 3) return false;
        final day = int.tryParse(eventDateParts[0]) ?? 0;
        final month = int.tryParse(eventDateParts[1]) ?? 0;
        final year = int.tryParse(eventDateParts[2]) ?? 0;
        final eventDate = DateTime(year, month, day);
        return _selectedDay != null &&
            eventDate.year == _selectedDay!.year &&
            eventDate.month == _selectedDay!.month &&
            eventDate.day == _selectedDay!.day;
      }).toList();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _updateEventsForSelectedDay();
  }

  void _onMonthChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthYear = "${_focusedDay.month}, ${_focusedDay.year}";

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: Text(monthYear),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              final nextMonth = DateTime(_focusedDay.year, _focusedDay.month + 1);
              setState(() {
                _focusedDay = nextMonth;
                _selectedDay = null;
              });
              _updateEventsForSelectedDay();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: _onDaySelected,
            onPageChanged: _onMonthChanged,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: _eventsForSelectedDay.isEmpty
                ? const Center(child: Text('No events for selected date.'))
                : ListView.builder(
                    itemCount: _eventsForSelectedDay.length,
                    itemBuilder: (context, index) {
                      final event = _eventsForSelectedDay[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsScreen(),
                              settings: RouteSettings(arguments: event),
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: event.imageUrl != null
                                ? Image.network(
                                    event.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.event),
                            title: Text(event.title),
                            subtitle: Text('+0 Going\n${event.location}'),
                            isThreeLine: true,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Link to add event functionality
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
