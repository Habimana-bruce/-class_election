import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/candidate.dart';
import '../state/election_state.dart';
import '../weather.dart';

class ElectionHome extends StatefulWidget {
  const ElectionHome({super.key});

  @override
  State<ElectionHome> createState() => _ElectionHomeState();
}

class _ElectionHomeState extends State<ElectionHome> {
  final voterController = TextEditingController();
  final candidateController = TextEditingController();

  int selectedScreen = 0;

  // WEATHER (API data, not Firestore): ephemeral state, stays here.
  Weather? weather;
  bool weatherLoading = true;
  String? weatherError;

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {
    setState(() {
      weatherLoading = true;
      weatherError = null;
    });
    try {
      final result = await fetchWeather();
      if (!mounted) return;
      setState(() {
        weather = result;
        weatherLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        weatherLoading = false;
        weatherError =
        'Could not load the weather. Check your internet connection.';
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showVoteSuccess(String candidateName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF07569B),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'You voted!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 76,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your vote for $candidateName was recorded.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                    const SizedBox(height: 32),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to candidates'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ACTIONS: read the brain BEFORE the first await.
  Future<void> castVote(Candidate candidate) async {
    final election = context.read<ElectionState>();
    final error = await election.castVote(voterController.text, candidate);
    if (!mounted) return;
    if (error != null) {
      showMessage(error);
      return;
    }
    voterController.clear();
    showVoteSuccess(candidate.name);
  }

  Future<void> addCandidate() async {
    final election = context.read<ElectionState>();
    final name = election.cleanName(candidateController.text);
    final error = await election.addCandidate(candidateController.text);
    if (!mounted) return;
    if (error != null) {
      showMessage(error);
      return;
    }
    candidateController.clear();
    showMessage('$name was added.');
  }

  Future<void> removeCandidate(Candidate candidate) async {
    final election = context.read<ElectionState>();
    if (candidate.votes > 0) {
      showMessage('You cannot remove a candidate who has votes.');
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this candidate?'),
        content: Text(candidate.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final error = await election.removeCandidate(candidate);
    if (!mounted) return;
    showMessage(error ?? '${candidate.name} was removed.');
  }

  Future<void> confirmReset() async {
    final election = context.read<ElectionState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset election?'),
        content: const Text('This will clear all votes. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await election.resetElection();
    if (!mounted) return;
    showMessage(error ?? 'Election has been reset.');
  }

  @override
  void dispose() {
    voterController.dispose();
    candidateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final election = context.watch<ElectionState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Class Election',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset election',
            onPressed: confirmReset,
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _body(election),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedScreen,
        onDestinationSelected: (index) {
          setState(() {
            selectedScreen = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.how_to_vote_outlined),
            selectedIcon: Icon(Icons.how_to_vote),
            label: 'Vote',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Results',
          ),
        ],
      ),
    );
  }

  Widget _body(ElectionState election) {
    if (election.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(election.error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (election.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return IndexedStack(
      index: selectedScreen,
      children: [
        buildVoteScreen(election),
        buildResultsScreen(election),
      ],
    );
  }

  Widget buildWeatherCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: weatherLoading
            ? const Center(child: CircularProgressIndicator())
            : weatherError != null
            ? Column(
          children: [
            const Icon(Icons.wifi_off, size: 36),
            const SizedBox(height: 8),
            Text(weatherError!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: loadWeather,
              child: const Text('Retry'),
            ),
          ],
        )
            : Row(
          children: [
            const Icon(
              Icons.wb_sunny,
              size: 36,
              color: Color(0xFF07569B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Election day weather in Kigali',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${weather!.temperature.round()}°C · ${describe(weather!.code)}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildVoteScreen(ElectionState election) {
    final candidates = election.candidates;
    final visible = election.visible;
    final totalVotes = election.totalVotes;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        buildWeatherCard(),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.how_to_vote,
                  size: 34,
                  color: Color(0xFF07569B),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose your class representative',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF123B5D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Votes recorded: $totalVotes',
                  style: const TextStyle(color: Color(0xFF52677A)),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: voterController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your full name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Candidates',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF123B5D),
          ),
        ),
        const SizedBox(height: 8),

        // Search (step 18): the text lives in the brain.
        TextField(
          onChanged: (v) => context.read<ElectionState>().setQuery(v),
          decoration: const InputDecoration(
            labelText: 'Search candidates',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No candidates yet. Add one below.')),
          )
        else if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No candidate matches your search.')),
          ),

        ...visible.map(
              (candidate) => Card(
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFDCEAF8),
                foregroundColor: const Color(0xFF07569B),
                child: Text(
                  candidate.name[0],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                candidate.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${candidate.votes} votes'),
              trailing: FilledButton(
                onPressed: () => castVote(candidate),
                child: const Text('Vote'),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),
        const Text(
          'Manage candidates',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF123B5D),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: candidateController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'New candidate name',
            prefixIcon: Icon(Icons.person_add_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => addCandidate(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: addCandidate,
            icon: const Icon(Icons.person_add),
            label: const Text('Add candidate'),
          ),
        ),
        const SizedBox(height: 8),
        ...candidates.map(
              (candidate) => Card(
            child: ListTile(
              title: Text(candidate.name),
              subtitle: Text('${candidate.votes} votes'),
              trailing: IconButton(
                tooltip: 'Remove candidate',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF07569B),
                ),
                onPressed: () => removeCandidate(candidate),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildResultsScreen(ElectionState election) {
    final ranked = election.ranked;
    final totalVotes = election.totalVotes;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFE5F1FC), Color(0xFFFFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: Color(0xFF07569B),
                ),
                const SizedBox(height: 12),
                Text(
                  election.result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF07569B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Total votes: $totalVotes',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF52677A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Candidate Rankings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF123B5D),
          ),
        ),
        const SizedBox(height: 10),
        if (totalVotes == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No votes yet. Percentages will appear after voting.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ...List.generate(ranked.length, (index) {
          final candidate = ranked[index];
          final fraction =
          totalVotes == 0 ? 0.0 : candidate.votes / totalVotes;
          final percentage = fraction * 100;

          final medal = switch (index) {
            0 => '🥇',
            1 => '🥈',
            2 => '🥉',
            _ => '${index + 1}.',
          };

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 23)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          candidate.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF123B5D),
                          ),
                        ),
                      ),
                      Text(
                        '${candidate.votes} votes',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF07569B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFDCEAF8),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF07569B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF52677A),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}