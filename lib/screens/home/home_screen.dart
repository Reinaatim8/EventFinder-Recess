import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';
import 'bookevent_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'addingevent.dart';
import '../home/event_management_screen.dart';
import '../../models/event.dart';
import '../map/map_screen.dart';

final GlobalKey<_BookingsTabState> bookingsTabKey = GlobalKey<_BookingsTabState>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Event> events = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }
//fetch events from firestore
  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('events').get();
      setState(() {
        events = snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
        _isLoading = false;
      });
      print('Fetched ${events.length} events');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addEvent(Event event) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set(event.toFirestore());
      setState(() {
        events.add(event);
      });
      print('Event added to Firestore: ${event.id}, organizerId: ${event.organizerId}');
    } catch (e) {
      print('Error adding event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // (iii) Track booking/payment status per event
  final Map<String, String> _eventStatus = {};

// (i) Show bottom sheet with event details and actions
  void _showEventDetailsModal(Event event) {
    showDialog(
      context: context,
      //shape: const RoundedRectangleBorder(
       // borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      builder: (_) => AlertDialog (
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 20),
            if (_eventStatus[event.id] != 'Reserved')
        // return Padding(
        //   padding: const EdgeInsets.all(20.0),
        //   child: Column(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        //       Text(event.title,
        //           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        //       const SizedBox(height: 10),
        //       Text(event.description),
        //       const SizedBox(height: 20),
        //       Row(
        //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        //         children: [
                  ElevatedButton(
                    onPressed: () {
                      bookingsTabKey.currentState?.addBooking({
                        'id': DateTime.now().millisecondsSinceEpoch,
                        'event': event.title,
                        'total': event.price,
                        'paid': false,
                      });
                      setState(() {
                        _eventStatus[event.id] = 'Reserved';
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Event Reserved!'),
                          backgroundColor: Colors.orange,
<<<<<<< HEAD
                        ),
                      );
                    },
                    child: const Text('Book Event'),
                  ),
                  if (_eventStatus[event.id] == 'Reserved')
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                        'Event Reserved',
                        style: TextStyle(
                         color: Colors.orange,
                         fontWeight: FontWeight.bold,
                         ),
                      ),),
=======
                          textColor: Colors.white,
                           fontSize: 19.0,
                         );
                      },
                      child: const Text('Book Event'),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: () {
                        // UNBOOK logic
                        bookingsTabKey.currentState?.removeBookingByTitle(event.title); // You'll create this method next
                        setState(() {
                          _eventStatus[event.id] = 'Reservation Cancelled!';
                        });
                        Navigator.pop(context);
                        Fluttertoast.showToast(
                          msg: "Reservation Cancelled!",
                          toastLength: Toast.LENGTH_LONG,
                          gravity: ToastGravity.CENTER, // or CENTER
                          backgroundColor: Colors.grey,
                          textColor: Colors.pink,
                          fontSize: 18.0,
                        );

                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 246, 105, 50)),
                      child: const Text('Cancel Reseravtion'),
                    ),
                  ],
              const SizedBox(height: 10),
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            total: event.price,
                            onPaymentSuccess: () {
                              bookingsTabKey.currentState?.addBooking({
                                'id': DateTime.now().millisecondsSinceEpoch,
                                'event': event.title,
                                'total': event.price,
                                'paid': true,
                              });
                              setState(() {
                                _eventStatus[event.id] = 'Paid';
                              });
                            },
                          ),
                        ),
                      );
                    },
                    
                    
                    child: const Text('Pay For Event'),
                  ),
                 TextButton(
                     onPressed: () {
                       Navigator.pop(context);
                     },
                  child: const Text(
                   'Cancel',
                       style: TextStyle(color: Colors.red),
                 ),
                 ),
                ],
              ),

          ),
        );
  }

  List<Widget> _getScreens() => [
        HomeTab(events: events, onAddEvent: _addEvent, onEventTap: _showEventDetailsModal, eventStatus: _eventStatus,),
        SearchTab(events: events),
        BookingsTab(key: bookingsTabKey),
        const ProfileScreen(),
        const MapScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
<<<<<<< HEAD
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getScreens()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
         BottomNavigationBarItem(
           icon: Icon(Icons.map),
           label: 'Map',
         ),
       ],
      ),
=======
      backgroundColor:const Color.fromARGB(255, 25, 25, 95),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getScreens()[_selectedIndex],
            bottomNavigationBar: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color.fromARGB(255, 25, 25, 95),
                          width: 0.2,
                          
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(50),
                          topRight: Radius.circular(50),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),

                        ),
                        
                        ),
            child: ConvexAppBar(
                      style: TabStyle.react, // other styles: fixedCircle, flip, reactCircle
                      backgroundColor:Color.fromARGB(255, 25, 25, 95),
                      activeColor:Colors.orange,
                      color:Colors.white,
                      height: 60,
                      // elevation: 5,
              curveSize: 100,
                      curve: Curves.easeInOut,
             
              items: const [
                TabItem(icon: Icons.home, title: 'Home'),
                TabItem(icon: Icons.search, title: 'Search'),
                TabItem(icon: Icons.bookmark, title: 'Bookings'),
                TabItem(icon: Icons.person, title: 'Profile'),
                TabItem(icon: Icons.map, title: 'Map'),
              ],
              initialActiveIndex: _selectedIndex,
              onTap: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),),

>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
    );
  }
}

class HomeTab extends StatelessWidget {
  final List<Event> events;
  final Function(Event) onAddEvent;
  final Function(Event) onEventTap; // (i) Used to trigger event details bottom sheet
  final Map<String, String> eventStatus;
  const HomeTab({Key? key,
    required this.events,
    required this.onAddEvent,
    required this.onEventTap,
    required this.eventStatus,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Map<String, List<Event>> eventsByDate = {};
    for (var event in events) {
      eventsByDate.putIfAbsent(event.date, () => []).add(event);
    }

    var sortedDates = eventsByDate.keys.toList()..sort();

    List<Widget> eventWidgets = [];
    for (var date in sortedDates) {
      eventWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Text(
            date,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
      );
      eventWidgets.addAll(
        eventsByDate[date]!.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
                child: _EventCard(
                  event: entry.value,
                  onTap: () => onEventTap(entry.value),
                  status: eventStatus[entry.value.id],
                ),
              ),
            ),
      );
    }

    return Scaffold(
<<<<<<< HEAD
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
=======
     backgroundColor: Colors.white,
      body: Stack(
        children:[
          // Background image
        //   Positioned.fill(
        //     child: Image.asset(
        //       'assets/images/blue2.jpeg',
        //       fit: BoxFit.cover,

        //     ),  
        // ),
      SafeArea(
        child: SingleChildScrollView( 
        child: Column(
          children: [
            // Header section with title and search bar
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color:const Color.fromARGB(255, 25, 25, 95),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(80,),
                    bottomRight: Radius.circular(80),
                    
                    
                  ),
                  
                  boxShadow:[
                      BoxShadow(
                        color: Colors.black,
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),] 
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          
                          Image.asset(
                              'assets/images/logoo.jpeg',
                              height: 50, // adjust as needed
                            ),


                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  _showAddEventDialog(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color:const Color.fromARGB(255, 25, 25, 95),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ProfileScreen()),
                                  );
                                },
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.person,
                                    color: const Color.fromARGB(255, 25, 25, 95),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () {
                                  final authProvider = Provider.of<AuthProvider>(
                                      context,
                                      listen: false);
                                  if (authProvider.user != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EventManagementScreen(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please log in to manage events')),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.event_note,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Discover ',
                              style: TextStyle(
                                color: Colors.orange, 
                                fontSize: 20,
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                             TextSpan(
                              text: 'Amazing Events Near You....',
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 18,
                              ),
                             ),],),),
                             const SizedBox(height: 23),
                             const SizedBox(height: 15),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search events.....',
                            prefixIcon: Icon(Icons.search, color:const Color.fromARGB(255, 25, 25, 95), size: 20,),
                            border: InputBorder.none,
                            //focusedBorder: InputBorder(color:Colors.yellow),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchTab(
                                  events: events,
                                  onEventTap: onEventTap,
                                  eventStatus: _eventStatus,
                                ),
                    ),
<<<<<<< HEAD
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchTab(events: events),
                        ),
                      );
                    },
                  ),
=======
                    );
                                },
                       ),
                    ),
                  ],
            ),
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                ),
             ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  
                  child: Row(
                    children: [
<<<<<<< HEAD
                      _CategoryChip(label: 'All', isSelected: true, events: events),
=======
                      _CategoryChip(label: 'All', isSelected: true, events: events,onEventTap: onEventTap,),
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Concert', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Conference', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Workshop', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Sports', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Festival', events: events),
                      const SizedBox(width: 10),
<<<<<<< HEAD
                      _CategoryChip(label: 'Networking', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Exhibition', events: events),
=======
                      _CategoryChip(label: 'Networking', events: events,onEventTap: onEventTap),
                      const SizedBox(width: 10, ),
                      _CategoryChip(label: 'Exhibition', events: events,onEventTap: onEventTap),
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Theater', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Comedy', events: events),
                      const SizedBox(width: 10),
                      _CategoryChip(label: 'Other', events: events),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              if (events.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(50.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Try changing your filter or search criteria',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Events (${events.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Column(
                        children: eventWidgets,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ],
    ),);
  }

  void _showAddEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(onAddEvent: onAddEvent),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final List<Event> events;

  const _CategoryChip({
    required this.label,
    this.isSelected = false,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchTab(events: events),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
           color: isSelected ? Colors.orange: Colors.black.withOpacity(0.05),
          // color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          // backgroundColor: isSelected ? const Color.fromARGB(255, 25, 25, 95) : Colors.white,
          
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white :const Color.fromARGB(255, 25, 25, 95),
            //  backgroundColor: isSelected ? const Color.fromARGB(255, 25, 25, 95) : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final String? status;

  const _EventCard({required this.event, required this.onTap, this.status});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
<<<<<<< HEAD
        onTap: onTap,


      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
=======
        onTap: () {
          if (isPast) {
            Fluttertoast.showToast(
              msg: "Oops! Event Passed, Sorry!",
              backgroundColor: Colors.red,
              textColor: Colors.white,
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.CENTER,
              fontSize: 18.0,
            );
          } else {
            onTap?.call();
          }
        },
          child: Opacity(
            opacity: isPast ? 0.3 : 1.0,
          child: Container(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            decoration: BoxDecoration(
              // color:  Colors.blue.shade50,
              color: Colors.white,
              borderRadius: BorderRadius.circular(0),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white,
                  width: 0,
                ),
              ),
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl != null)
<<<<<<< HEAD
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
=======
              ColorFiltered(
                colorFilter: isPast
                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                 child: Image.network(
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                  event.imageUrl!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  
                 
                  

                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: const Color.fromARGB(255, 111, 110, 110),
                      child: Icon(
                        _getCategoryIcon(event.category),
                        size: 60,
                        color: Colors.grey[400],
                      ),
                    );
                  },
                ),),
              ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (event.imageUrl == null)
                        Container(
                          padding: const EdgeInsets.all(0),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _getCategoryIcon(event.category),
                            color: Color.fromARGB(255, 25, 25, 95),
                            size: 30,
                          ),
                        ),
                      if (event.imageUrl == null) const SizedBox(width: 15),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
<<<<<<< HEAD
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
=======
                            Row(
                              children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          //decoration: TextDecoration.underline,
                                          backgroundColor: Colors.transparent,
                                          color: Colors.black,
                                        ),
                                      ),
                                      
                                  
                                  const SizedBox(height: 8),
                                    (event.price == '0' || event.price == '0.0' || event.price == '0.00') ?
                                      Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Free Entry',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ):
                              
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 250, 186, 137),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                 child:Text(
                                   (event.price == '0' || event.price == '0.0' || event.price == '0.00')
                                       ? 'Free Entry'
                                       : 'Entry Fee: UGX ${event.price}',
                                   style: const TextStyle(
                                     color: Colors.black,
                                     fontWeight: FontWeight.bold,
                                ),),),],),),
                                // Shortcut icons row
                                const SizedBox(height: 8),
                                
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isBooked ? Icons.bookmark : Icons.bookmark_border,
                                        color: isBooked ? Colors.orange : Colors.grey,
                                        size: 35,
                                      ),
                                      tooltip: isBooked ? 'Cancel Booking' : 'Book Event',
                                      onPressed: () {
                                        if (!isPast) {
                                          onBookToggle();
                                        } else {
                                          Fluttertoast.showToast(
                                            msg: "Cannot book past event",
                                            backgroundColor: Colors.red,
                                            textColor: Colors.white,
                                            toastLength: Toast.LENGTH_LONG,
                                            gravity: ToastGravity.CENTER,
                                            fontSize: 16.0,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 13),
                                    IconButton(
                                      icon: Icon(
                                        Icons.payment,
                                        color: Color.fromARGB(255, 25, 25, 95),
                                        size: 35,
                                      ),
                                      tooltip: 'Pay for Event',
                                      
                                      onPressed: () {
                                        if (!isPast) {
                                          // Navigate to payment screen or show payment dialog
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CheckoutScreen(
                                                total: event.price is num
                                                    ? event.price.toDouble()
                                                    : double.tryParse(event.price.toString()) ?? 0.0,
                                                onPaymentSuccess: () {
                                                  // Optionally update UI or state after payment success
                                                  Fluttertoast.showToast(
                                                    msg: "Payment Successful!",
                                                    backgroundColor: Colors.green,
                                                    textColor: Colors.white,
                                                    toastLength: Toast.LENGTH_LONG,
                                                    gravity: ToastGravity.CENTER,
                                                    fontSize: 16.0,
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        } else {
                                          Fluttertoast.showToast(
                                            msg: "Cannot pay for past event",
                                            backgroundColor: Colors.red,
                                            textColor: Colors.white,
                                            toastLength: Toast.LENGTH_LONG,
                                            gravity: ToastGravity.CENTER,
                                            fontSize: 16.0,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 19, color: Colors.green),
                                const SizedBox(width: 5),
                                Text(
                                  event.date,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                               Icon(Icons.location_on,
                                    size: 17, color: Colors.red),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    event.location,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                    ),
<<<<<<< HEAD
                                  ),
                                ),
=======
                                    overflow: TextOverflow.ellipsis, 
                                    maxLines: 2,
                                    softWrap: false,
                                  ),),
                                
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
                              ],
                            ),
                            if (status != null)
                             Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                color: status == 'Paid'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                             ),
                              child: Text(
                               status!,
                               style: TextStyle(
                                 color: status == 'Paid' ? Colors.green : Colors.orange,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 12,
                                  ),
                                ),
                              ),
                             ],),),
                            // if (event.description.isNotEmpty)
                            //   Padding(
                            //     padding: const EdgeInsets.only(top: 8.0),
                            //     child: Text(
                            //       event.description,
                            //       maxLines: 2,
                            //       overflow: TextOverflow.ellipsis,
                            //       style: TextStyle(color: Colors.grey[700]),
                            //       ),
                               // ),
                                ],
                              ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 25, 25, 95).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          event.category,
                          style: TextStyle(
                            color: Color.fromARGB(255, 25, 25, 95),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    
                  
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      event.description,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
<<<<<<< HEAD
              ),)
            );
         // ],
       // ),
    //   ),
    // );
  }
=======
              ),
              ),],
            ),),
            ),);
            }
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'concert':
      case 'festival':
        return Icons.music_note;
      case 'conference':
        return Icons.computer;
      case 'workshop':
        return Icons.build;
      case 'sports':
        return Icons.sports;
      case 'networking':
        return Icons.group;
      case 'exhibition':
        return Icons.museum;
      case 'theater':
        return Icons.theater_comedy;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.event;
    }
  }
}

class SearchTab extends StatefulWidget {
  final List<Event> events;

<<<<<<< HEAD
  const SearchTab({Key? key, required this.events}) : super(key: key);

  @override
  State<SearchTab> createState() => _SearchTabState();
}

=======
  const SearchTab({Key? key, required this.events,required this.onEventTap,
    required this.eventStatus,
}) : super(key: key);
       
  @override
  State<SearchTab> createState() => _SearchTabState();
}
 
>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
class _SearchTabState extends State<SearchTab> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<Event> _filteredEvents = [];
<<<<<<< HEAD

=======
  List<Event> upcomingEvents = [];
   List<Event> pastEvents = [];   
  DateTime parseEventDate(String input) {
    try {
      final parts = input.split('/');
      if (parts.length != 3) return DateTime(1900);

      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? 1900;

      return DateTime(year, month, day);
    } catch (e) {
      print("Date parse error for '$input': $e");
      return DateTime(1900);
    }
  }

>>>>>>> b29ef5c71fe2575e608696386940e59c92e1ce38
  final List<String> _categories = [
    'All',
    'Concert',
    'Conference',
    'Workshop',
    'Sports',
    'Festival',
    'Networking',
    'Exhibition',
    'Theater',
    'Comedy',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _filteredEvents = widget.events;
    _filterEvents();
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = widget.events.where((event) {
        final matchesSearch = event.title
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            event.description
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            event.location
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
        final matchesCategory =
            _selectedCategory == 'All' || event.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white, 
        toolbarHeight: 90,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
         
              title: Column(
                 mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
               RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Search',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' Events',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 4),
              const Text(
                'Find Events that Match your Interests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              ],),
              
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/blue2.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Main content    
      Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color:Color.fromARGB(255, 25, 25, 95) ,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    fillColor: Colors.white,
                    filled: true,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(

                      borderRadius: const BorderRadius.all(
                        Radius.circular(30),
                      ),
                      
                      
                     
                    ),
                  ),
                  onChanged: (value) => _filterEvents(),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryFilterChip(
                          label: category,
                          isSelected: _selectedCategory == category,
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                            _filterEvents();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Try changing your filter or search criteria',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _EventCard(event: _filteredEvents[index], onTap: () {  },),
                      );
                    },
                  ),
       ), ], ),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.transparent,
          ),
          
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Color.fromARGB(255, 25, 25, 95),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class BookingsTab extends StatefulWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  List<Map<String, dynamic>> bookings = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  void _fetchBookings() async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;

    if (userId == null) return;

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        bookings = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      print("Error fetching bookings: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error fetching bookings'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void addBooking(Map<String, dynamic> booking) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    // setState(() {
    //   bookings.add(booking);
    // });
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': userId,
        'event': booking['event'],
        'price': booking['total'],
        'paid': booking['paid'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      _fetchBookings();
    } catch (e) {
      print("Error saving booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving booking'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Color.fromARGB(255, 25, 25, 95),
        foregroundColor: Colors.white,
        toolbarHeight: 80,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
      body: bookings.isEmpty
          ? const Center(child: Text('No bookings yet.'))
          : ListView.builder(
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return ListTile(
            title: Text(booking['event'] ?? ''),
            subtitle: Text('Total: €${booking['price']}'),
            trailing: booking['paid'] == true
                ? const Text('Paid', style: TextStyle(color: Colors.green))
                : ElevatedButton(
              child: const Text('Checkout'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      total: booking['price'],
                      onPaymentSuccess: () {
                        setState(() {
                          bookings[index]['paid'] = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment Successful!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
