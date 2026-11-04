import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/candidate.dart';
import '../repositories/candidate_repository.dart';

class ElectionState extends ChangeNotifier {
  ElectionState(this._repo) {
    debugPrint('Brain born for ${_repo.uid}');
    _subscription = _repo.watchAll().listen(
          (list) {
        _candidates = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _error = 'Could not load the election.';
        notifyListeners();
      },
    );
  }

  final CandidateRepository _repo;
  StreamSubscription<List<Candidate>>? _subscription;

  List<Candidate> _candidates = [];
  bool _loading = true;
  String? _error;

  List<Candidate> get candidates => _candidates;
  bool get loading => _loading;
  String? get error => _error;

  // COMPUTED, NEVER SAVED
  int get totalVotes => _candidates.fold<int>(0, (sum, c) => sum + c.votes);

  // SELECTION SORT: HIGHEST VOTES FIRST.
  List<Candidate> get ranked {
    final remaining = List<Candidate>.of(_candidates);
    final result = <Candidate>[];
    while (remaining.isNotEmpty) {
      int best = 0;
      for (int i = 1; i < remaining.length; i++) {
        if (remaining[i].votes > remaining[best].votes) best = i;
      }
      result.add(remaining.removeAt(best));
    }
    return result;
  }

  String get result {
    if (_candidates.isEmpty) return 'No candidates available';
    if (totalVotes == 0) return 'No votes yet';
    final highest =
    _candidates.map((c) => c.votes).reduce((a, b) => a > b ? a : b);
    final leaders = _candidates.where((c) => c.votes == highest).toList();
    if (leaders.length > 1) {
      final names = leaders.map((c) => c.name).join(' and ');
      return 'Tie between $names ($highest votes each)';
    }
    return 'Winner: ${leaders.first.name}';
  }

  // Search (step 18)
  String _query = '';
  String get query => _query;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  List<Candidate> get visible => _candidates
      .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  // CLEAN AND FORMAT NAMES.
  String cleanName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).map((w) {
      final lower = w.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  String _voterKey(String name) =>
      cleanName(name).toLowerCase().replaceAll('/', '-');

  // ACTIONS: each returns an error message, or null when it worked.
  Future<String?> castVote(String rawName, Candidate candidate) async {
    final voter = cleanName(rawName);
    if (voter.isEmpty) return 'Please enter your name first.';
    try {
      final key = _voterKey(voter);
      if (await _repo.hasVoted(key)) return '$voter has already voted.';
      await _repo.recordVote(
          voterKey: key, voterName: voter, candidate: candidate);
      return null;
    } catch (e) {
      return 'Could not save your vote. Check your connection.';
    }
  }

  Future<String?> addCandidate(String rawName) async {
    final name = cleanName(rawName);
    if (name.isEmpty) return 'Candidate name cannot be empty.';
    try {
      if (await _repo.candidateExists(name)) return '$name already exists.';
      await _repo.addCandidate(Candidate(name: name));
      return null;
    } catch (e) {
      return 'Could not add the candidate. Check your connection.';
    }
  }

  Future<String?> removeCandidate(Candidate c) async {
    if (c.votes > 0) return 'You cannot remove a candidate who has votes.';
    try {
      await _repo.deleteCandidate(c.id);
      return null;
    } catch (e) {
      return 'Could not remove the candidate.';
    }
  }

  Future<String?> resetElection() async {
    try {
      await _repo.reset();
      return null;
    } catch (e) {
      return 'Could not reset the election.';
    }
  }

  @override
  void dispose() {
    debugPrint('Brain disposed: pipe closed');
    _subscription?.cancel();
    super.dispose();
  }
}