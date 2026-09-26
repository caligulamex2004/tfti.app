class RawFeedEvent {
  final String id;
  final Map<String, dynamic> data;

  const RawFeedEvent({
    required this.id,
    required this.data,
  });
}

class FeedSnapshot {
  final String firstName;
  final List<String> blockedUids;
  final List<String> goatedUids;
  final Map<String, Map<String, dynamic>> myInvitesMap;
  final List<RawFeedEvent> events;

  const FeedSnapshot({
    required this.firstName,
    required this.blockedUids,
    required this.goatedUids,
    required this.myInvitesMap,
    required this.events,
  });

  static const FeedSnapshot empty = FeedSnapshot(
    firstName: "there",
    blockedUids: [],
    goatedUids: [],
    myInvitesMap: {},
    events: [],
  );
}

class FilteredFeedData {
  final List<Map<String, dynamic>> actionNeeded;
  final List<Map<String, dynamic>> agenda;
  final List<Map<String, dynamic>> declined;
  final List<Map<String, dynamic>> past;
  final List<Map<String, dynamic>> hidden;

  const FilteredFeedData({
    this.actionNeeded = const [],
    this.agenda = const [],
    this.declined = const [],
    this.past = const [],
    this.hidden = const [],
  });
}
