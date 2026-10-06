import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiapenang_fypnewdev/controllers/trip_controller.dart';

void main() {
  test('Dynamic stay duration and timeline respect short travel window (09:45 AM - 01:00 PM)', () {
    final controller = TripController();

    final places = [
      const ItineraryPlace(
        id: 'p1',
        name: 'Fort Cornwallis',
        area: 'George Town',
        description: 'Historic bastion',
        lat: 5.4206,
        lng: 100.3440,
        category: 'Historic',
      ),
      const ItineraryPlace(
        id: 'p2',
        name: 'Pinang Peranakan Mansion',
        area: 'George Town',
        description: 'Heritage mansion',
        lat: 5.4182,
        lng: 100.3409,
        category: 'Historic',
      ),
      const ItineraryPlace(
        id: 'p3',
        name: 'Armenian Street',
        area: 'George Town',
        description: 'Street murals',
        lat: 5.4149,
        lng: 100.3370,
        category: 'Art',
      ),
      const ItineraryPlace(
        id: 'p4',
        name: 'Gurney Drive Hawker Center',
        area: 'George Town',
        description: 'Seafront hawkers',
        lat: 5.4398,
        lng: 100.3090,
        category: 'Food',
      ),
    ];

    controller.setDraftItinerary(places);

    controller.setDepartTime(const TimeOfDay(hour: 9, minute: 45));
    controller.setEndTripTime(const TimeOfDay(hour: 13, minute: 0));

    expect(controller.draftItinerary.length, 4);

    // Verify no free time bridge in short trip
    final hasFreeTime = controller.timeline.any((t) => t is TimelineFreeTimeItem);
    expect(hasFreeTime, false);

    // Verify stay durations are dynamically budgeted (~30-45 mins each)
    for (final p in controller.draftItinerary) {
      expect(p.dynamicStayMinutes >= 20, true);
      expect(p.dynamicStayMinutes <= 55, true);
      print('Place: ${p.name} -> Stay: ${p.formattedStayDuration}, Visit Slot: ${p.bestVisitTime}');
    }

    // Verify last stop ends around 01:00 PM
    final lastStop = controller.draftItinerary.last;
    expect(lastStop.bestVisitTime != null, true);
    expect(lastStop.bestVisitTime!.contains('01:00 PM') || lastStop.bestVisitTime!.contains('12:55 PM') || lastStop.bestVisitTime!.contains('01:05 PM'), true);
    print('Last stop concludes at: ${lastStop.bestVisitTime}');
  });

  test('Full day trip (09:00 AM - 06:00 PM) includes midday free time bridge and expanded stay duration', () {
    final controller = TripController();

    final places = [
      const ItineraryPlace(
        id: 'p1',
        name: 'Fort Cornwallis',
        area: 'George Town',
        description: 'Historic bastion',
        lat: 5.4206,
        lng: 100.3440,
        category: 'Historic',
      ),
      const ItineraryPlace(
        id: 'p2',
        name: 'Pinang Peranakan Mansion',
        area: 'George Town',
        description: 'Heritage mansion',
        lat: 5.4182,
        lng: 100.3409,
        category: 'Historic',
      ),
      const ItineraryPlace(
        id: 'p3',
        name: 'Armenian Street',
        area: 'George Town',
        description: 'Street murals',
        lat: 5.4149,
        lng: 100.3370,
        category: 'Art',
      ),
      const ItineraryPlace(
        id: 'p4',
        name: 'Gurney Drive Hawker Center',
        area: 'George Town',
        description: 'Seafront hawkers',
        lat: 5.4398,
        lng: 100.3090,
        category: 'Food',
      ),
    ];

    controller.setDraftItinerary(places);

    controller.setDepartTime(const TimeOfDay(hour: 9, minute: 0));
    controller.setEndTripTime(const TimeOfDay(hour: 18, minute: 0));

    // Verify free time bridge IS present in 9-hour trip
    final hasFreeTime = controller.timeline.any((t) => t is TimelineFreeTimeItem);
    expect(hasFreeTime, true);

    // Verify stay durations expanded (e.g. 70-120 mins)
    for (final p in controller.draftItinerary) {
      expect(p.dynamicStayMinutes >= 60, true);
      print('Full day place: ${p.name} -> Stay: ${p.formattedStayDuration}, Visit Slot: ${p.bestVisitTime}');
    }
  });
}
