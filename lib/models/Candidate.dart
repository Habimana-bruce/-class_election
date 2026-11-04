import 'package:cloud_firestore/cloud_firestore.dart';

class Candidate {
  Candidate({this.id = '', required this.name, this.votes = 0});

  final String id;
  final String name;
  final int votes;

  Map<String, dynamic> toMap() => {'name': name, 'votes': votes};

  factory Candidate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Candidate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      votes: (data['votes'] as num?)?.toInt() ?? 0,
    );
  }
}