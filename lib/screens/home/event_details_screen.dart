import 'package:flutter/material.dart';
import '../../models/event.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Event event = ModalRoute.of(context)!.settings.arguments as Event;

    return Scaffold(
      appBar: AppBar(title: Text(event.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(event.imageUrl!),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: ${event.date}'),
            const SizedBox(height: 8),
            Text('Category: ${event.category}'),
            const SizedBox(height: 8),
            if (event.description.isNotEmpty)
              Text('Description: ${event.description}'),
            const SizedBox(height: 8),
            if (event.price > 0)
              Text('Price: \$${event.price.toStringAsFixed(2)}'),
            // Add more details or actions as needed
          ],
        ),
      ),
    );
  }
}

extension on String {
  void operator >(int other) {}

  toStringAsFixed(int i) {}
}
