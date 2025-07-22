# UI Redesign Plan for Local Event Finder Flutter App

## Objective
Redesign the Flutter app UI to match the provided visual style with three main screens:
1. Discover Events
2. Event Details
3. Calendar/Events by Date

All existing functionalities must be fully integrated and functional.

---

## Screen 1: Discover Events (Leftmost Screen)

### Features to Implement
- App Bar with menu icon (navigate to Profile/Settings), greeting with user name, notification icon
- Search bar with functional input for event search/filter
- Featured Events section: horizontal scrollable event cards with image, title, "Book Now" button, rating/price
- Trending Events section: horizontal scrollable event cards with smaller image, date, title, attendees count, location
- Floating Action Button (FAB) to add new event (linked to event management)

### Mapping to Existing Code
- Base: `lib/screens/home/home_screen.dart` (refactor to new UI layout)
- Event cards: refactor existing `_EventCard` or create new widgets
- Search functionality: reuse existing search logic
- Navigation: use existing navigation to Profile, Event Details, Event Management

---

## Screen 2: Event Details (Middle Screen)

### Features to Implement
- App Bar with back button, title "Event Details", share icon
- Event header with large image, title, price
- Attendees count and Invite button (linked to sharing)
- Date & time display
- Location details with embedded map (reuse existing Map tab or static map)
- About Event section with description
- Edit/Delete buttons visible only to organizers (linked to event management)

### Mapping to Existing Code
- Base: `lib/screens/home/event_details_screen.dart` (refactor to new UI)
- Map integration: reuse `lib/screens/map/map_screen.dart` or embed static map
- Organizer controls: integrate with event management features

---

## Screen 3: Calendar/Events by Date (Rightmost Screen)

### Features to Implement
- App Bar with back button, month/year display, forward/back arrows to change month
- Calendar grid with selectable dates (highlight active/selected dates)
- Scrollable event list by date with event cards similar to Trending section
- FAB to add new event (same as Discover Events screen)

### Mapping to Existing Code
- New screen to be created, e.g., `lib/screens/home/calendar_events_screen.dart`
- Calendar widget: use Flutter calendar packages or custom implementation
- Event list: reuse event card widgets and data filtering logic
- Navigation and event detail linking as existing

---

## UI Components to Create/Refactor
- Custom AppBar widgets for each screen
- EventCard widget variants for Featured, Trending, Calendar lists
- Search bar widget with integrated filtering
- Calendar widget with date selection
- Floating Action Button consistent across screens
- Organizer controls (Edit/Delete buttons)

---

## Integration Points
- Authentication state and user info for greetings and access control
- Event data from Firestore for lists and details
- Booking and payment flows triggered from "Book Now" and payment buttons
- QR code ticket generation for free events
- Navigation between screens and tabs
- Notifications and sharing features

---

## Responsiveness and Styling
- Use flexible layouts (e.g., Flex, Expanded, MediaQuery) for responsiveness
- Follow provided color schemes, fonts (Inter if available), spacing, rounded corners, shadows
- Ensure UI adapts to different device sizes and orientations

---

## Follow-up Steps
- Implement UI components and screens as per plan
- Integrate existing functionalities and test flows
- Perform thorough testing of all features and UI responsiveness
- Iterate based on feedback and bug fixes

---

Please confirm if you approve this detailed UI redesign plan so I can proceed with implementation.
