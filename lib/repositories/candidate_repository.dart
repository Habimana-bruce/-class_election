

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/candidate.dart';

class CandidateRepository {
  CandidateRepository(this.uid);

  final String uid;

  DocumentReference<Map<String, dynamic>> get _user =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _candidates =>
      _user.collection('candidates');

  CollectionReference<Map<String, dynamic>> get _voters =>
      _user.collection('voters');

  Stream<List<Candidate>> watchAll() => _candidates
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Candidate.fromDoc).toList());

  Future<bool> candidateExists(String name) async {
    final r = await _candidates.where('name', isEqualTo: name).limit(1).get();
    return r.docs.isNotEmpty;
  }

  Future<void> addCandidate(Candidate c) => _candidates.add(c.toMap());

  Future<void> deleteCandidate(String id) => _candidates.doc(id).delete();

  Future<bool> hasVoted(String voterKey) async =>
      (await _voters.doc(voterKey).get()).exists;

  // One batch: remember the voter AND add 1 to the candidate.
  Future<void> recordVote({
    required String voterKey,
    required String voterName,
    required Candidate candidate,
  }) {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_voters.doc(voterKey),
        {'name': voterName, 'candidate': candidate.name});
    batch.update(_candidates.doc(candidate.id),
        {'votes': FieldValue.increment(1)});
    return batch.commit();
  }

  Future<void> reset() async {
    final voters = await _voters.get();
    final candidates = await _candidates.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in voters.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in candidates.docs) {
      batch.update(doc.reference, {'votes': 0});
    }
    await batch.commit();
  }
}