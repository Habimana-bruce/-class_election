import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'candidate.dart';
import 'firebase_web_options.dart';
import 'weather.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb ? firebaseWebOptions : null,
  );
  runApp(const ClassElectionApp());
}

class ClassElectionApp extends StatelessWidget {
  const ClassElectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Class Election',

      // BLUE AND WHITE THEME
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F6FC),

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF07569B),
          brightness: Brightness.light,
          primary: const Color(0xFF07569B),
          onPrimary: Colors.white,
          surface: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF07569B),
          elevation: 0,
          centerTitle: false,
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x1A07569B),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFFDCE6F1),
            ),
          ),
        ),

        // INPUT FIELD DESIGN
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFDCE6F1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFDCE6F1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF07569B),
              width: 2,
            ),
          ),
        ),

        // BUTTON DESIGN
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF07569B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
        ),

        // BOTTOM NAVIGATION DESIGN
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFDCEAF8),
          elevation: 4,
        ),

        // PROGRESS BAR DESIGN
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFF07569B),
          linearTrackColor: Color(0xFFDCEAF8),
        ),
      ),

      // The gate decides: login screen or the election.
      home: const AuthGate(),
    );
  }
}

class ElectionHome extends StatefulWidget {
  const ElectionHome({super.key});

  @override
  State<ElectionHome> createState() => _ElectionHomeState();
}

class _ElectionHomeState extends State<ElectionHome> {
  final voterController = TextEditingController();
  final candidateController = TextEditingController();

  int selectedScreen = 0;

  // The candidates now live in Firestore. The screen listens to them.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> candidatesStream =
  myCandidates().orderBy('name').snapshots();

  // WEATHER (live data from the API): three states.
  Weather? weather;
  bool weatherLoading = true;
  String? weatherError;

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  // LOAD THE WEATHER FROM THE SERVER.
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

  // COMPUTED, NEVER SAVED: total votes.
  int totalVotesOf(List<Candidate> candidates) {
    return candidates.fold<int>(0, (sum, c) => sum + c.votes);
  }

  // CLEAN AND FORMAT NAMES.
  String cleanName(String input) {
    final trimmed = input.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final words = trimmed.split(RegExp(r'\s+'));

    return words.map((word) {
      final lower = word.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  // The voter's document id. A "/" is not allowed in a document id.
  String voterKey(String name) =>
      cleanName(name).toLowerCase().replaceAll('/', '-');

  // SHOW A MESSAGE.
  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // BLUE VOTE-SUCCESS SCREEN.
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                      ),
                    ),

                    const SizedBox(height: 32),

                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white,
                        ),
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

  // RECORD A VOTE.
  Future<void> castVote(Candidate candidate) async {
    final voter = cleanName(voterController.text);

    if (voter.isEmpty) {
      showMessage('Please enter your name first.');
      return;
    }

    try {
      final voterDoc = myVoters().doc(voterKey(voter));

      // Has this voter already voted?
      final existing = await voterDoc.get();
      if (!mounted) return;
      if (existing.exists) {
        showMessage('$voter has already voted.');
        return;
      }

      // One batch: remember the voter AND add 1 to the candidate.
      // Both happen, or none.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(voterDoc, {'name': voter, 'candidate': candidate.name});
      batch.update(
        myCandidates().doc(candidate.id),
        {'votes': FieldValue.increment(1)},
      );
      await batch.commit();

      if (!mounted) return;
      voterController.clear();
      showVoteSuccess(candidate.name);
    } catch (e) {
      if (!mounted) return;
      showMessage('Could not save your vote. Check your connection.');
    }
  }

  // ADD A CANDIDATE.
  Future<void> addCandidate() async {
    final name = cleanName(candidateController.text);

    if (name.isEmpty) {
      showMessage('Candidate name cannot be empty.');
      return;
    }

    try {
      final duplicate = await myCandidates()
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      if (!mounted) return;

      if (duplicate.docs.isNotEmpty) {
        showMessage('$name already exists.');
        return;
      }

      await myCandidates().add(Candidate(name: name).toMap());
      if (!mounted) return;
      candidateController.clear();
      showMessage('$name was added.');
    } catch (e) {
      if (!mounted) return;
      showMessage('Could not add the candidate. Check your connection.');
    }
  }

  // REMOVE A CANDIDATE WITH ZERO VOTES.
  Future<void> removeCandidate(Candidate candidate) async {
    if (candidate.votes > 0) {
      showMessage(
        'You cannot remove a candidate who has votes.',
      );
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

    try {
      await myCandidates().doc(candidate.id).delete();
      if (!mounted) return;
      showMessage('${candidate.name} was removed.');
    } catch (e) {
      if (!mounted) return;
      showMessage('Could not remove the candidate.');
    }
  }

  // RESET THE ELECTION.
  Future<void> confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset election?'),
        content: const Text(
          'This will clear all votes. Are you sure?',
        ),
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

    try {
      final voters = await myVoters().get();
      final candidates = await myCandidates().get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in voters.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in candidates.docs) {
        batch.update(doc.reference, {'votes': 0});
      }
      await batch.commit();

      if (!mounted) return;
      showMessage('Election has been reset.');
    } catch (e) {
      if (!mounted) return;
      showMessage('Could not reset the election.');
    }
  }

  // SELECTION SORT: HIGHEST VOTES FIRST.
  List<Candidate> rankedCandidates(List<Candidate> candidates) {
    final remaining = List<Candidate>.of(candidates);
    final ranked = <Candidate>[];

    while (remaining.isNotEmpty) {
      int bestIndex = 0;

      for (int i = 1; i < remaining.length; i++) {
        if (remaining[i].votes > remaining[bestIndex].votes) {
          bestIndex = i;
        }
      }

      ranked.add(remaining.removeAt(bestIndex));
    }

    return ranked;
  }

  // DETERMINE THE ELECTION RESULT.
  String electionResult(List<Candidate> candidates) {
    if (totalVotesOf(candidates) == 0) {
      return 'No votes yet';
    }

    if (candidates.isEmpty) {
      return 'No candidates available';
    }

    final highestVotes = candidates
        .map((candidate) => candidate.votes)
        .reduce((a, b) => a > b ? a : b);

    final leaders = candidates
        .where((candidate) => candidate.votes == highestVotes)
        .toList();

    if (leaders.length > 1) {
      final names = leaders.map((candidate) => candidate.name).join(' and ');
      return 'Tie between $names ($highestVotes votes each)';
    }

    return 'Winner: ${leaders.first.name}';
  }

  @override
  void dispose() {
    voterController.dispose();
    candidateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

      // The list comes from Firestore: loading, error, then data.
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: candidatesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load the election.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final candidates =
          snapshot.data!.docs.map(Candidate.fromDoc).toList();

          return IndexedStack(
            index: selectedScreen,
            children: [
              buildVoteScreen(candidates),
              buildResultsScreen(candidates),
            ],
          );
        },
      ),

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

  // WEATHER CARD: loading, error, or data.
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

  // VOTING SCREEN.
  Widget buildVoteScreen(List<Candidate> candidates) {
    final totalVotes = totalVotesOf(candidates);

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
                  style: const TextStyle(
                    color: Color(0xFF52677A),
                  ),
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

        // EMPTY STATE
        if (candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('No candidates yet. Add one below.'),
            ),
          ),

        ...candidates.map(
              (candidate) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFDCEAF8),
                foregroundColor: const Color(0xFF07569B),
                child: Text(
                  candidate.name[0],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                candidate.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
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

  // RESULTS SCREEN.
  Widget buildResultsScreen(List<Candidate> candidates) {
    final ranked = rankedCandidates(candidates);
    final totalVotes = totalVotesOf(candidates);

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
                colors: [
                  Color(0xFFE5F1FC),
                  Color(0xFFFFFFFF),
                ],
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
                  electionResult(candidates),
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

          final percentage =
          totalVotes == 0 ? 0.0 : candidate.votes / totalVotes * 100;

          final fraction = totalVotes == 0 ? 0.0 : candidate.votes / totalVotes;

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
                      Text(
                        medal,
                        style: const TextStyle(fontSize: 23),
                      ),

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