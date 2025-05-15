import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const DjenaApp());
}

class DjenaApp extends StatelessWidget {
  const DjenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Djena',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const DjenaHomePage(),
    );
  }
}

class DjenaHomePage extends StatefulWidget {
  const DjenaHomePage({super.key});

  @override
  State<DjenaHomePage> createState() => _DjenaHomePageState();
}

class _DjenaHomePageState extends State<DjenaHomePage> {
  final FlutterTts _tts = FlutterTts();
  final List<String> _historique = [];
  final List<String> _categories = ['Maison', 'Travail', 'Courses', 'Autre'];
  String _derniereCommandeVocale = "";
  String _transcription = "Prêt à recevoir des commandes";
  bool _chargementEnCours = false;
  final TextEditingController _tacheController = TextEditingController();
  String _categorieActuelle = 'Maison';

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  Future<void> _initTTS() async {
    try {
      await _tts.setLanguage("fr-FR");
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      debugPrint("Erreur TTS: $e");
    }
  }

  Future<File> _getFichierTaches() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/taches_djena.txt');
    } catch (e) {
      debugPrint("Erreur fichier: $e");
      rethrow;
    }
  }

  void _afficherSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _ajouterTache(String texte) async {
    try {
      if (texte.isEmpty) {
        _afficherSnack("Le texte de la tâche est vide");
        return;
      }

      final fichier = await _getFichierTaches();
      final date = DateFormat('dd/MM/yyyy').format(DateTime.now());

      String contenu = await fichier.exists() ? await fichier.readAsString() : "";
      
      final pattern = "[CATEGORIE] $_categorieActuelle";
      if (!contenu.contains(pattern)) contenu += "\n$pattern\n";

      final lignes = contenu.split('\n');
      final index = lignes.indexOf(pattern);
      lignes.insert(index + 1, "- [$date] $texte");

      await fichier.writeAsString(lignes.join('\n'));
      _historique.insert(0, "📝 [$date] tâche ajoutée à $_categorieActuelle");
      await _tts.speak("Tâche ajoutée dans $_categorieActuelle");
      setState(() {});
    } catch (e) {
      _afficherSnack("Erreur lors de l'ajout");
      debugPrint("Erreur _ajouterTache: $e");
    }
  }

  Future<void> _compterTachesCategorie() async {
    try {
      final fichier = await _getFichierTaches();
      if (!await fichier.exists()) {
        _afficherSnack("Aucune tâche trouvée");
        return;
      }

      final contenu = await fichier.readAsString();
      final lignes = contenu.split('\n');
      final count = lignes.where((line) => line.startsWith('- ')).length;

      _afficherSnack("Total: $count tâche(s)");
      await _tts.speak("Il y a $count tâches");
    } catch (e) {
      _afficherSnack("Erreur de comptage");
      debugPrint("Erreur _compterTachesCategorie: $e");
    }
  }

  Future<void> _lireTachesCategorie() async {
    try {
      final fichier = await _getFichierTaches();
      if (!await fichier.exists()) {
        _afficherSnack("Aucune tâche trouvée");
        return;
      }

      final contenu = await fichier.readAsString();
      _transcription = contenu;
      await _tts.speak("Voici vos tâches : $contenu");
      setState(() {});
    } catch (e) {
      _afficherSnack("Erreur de lecture");
      debugPrint("Erreur _lireTachesCategorie: $e");
    }
  }

  Future<void> _effacerTachesCategorie() async {
    try {
      final fichier = await _getFichierTaches();
      if (!await fichier.exists()) return;

      final contenu = await fichier.readAsString();
      final lignes = contenu.split('\n');
      final result = <String>[];
      bool inside = false;

      for (var line in lignes) {
        if (line == "[CATEGORIE] $_categorieActuelle") {
          inside = true;
          continue;
        }
        if (line.startsWith("[CATEGORIE]")) inside = false;
        if (!inside) result.add(line);
      }

      await fichier.writeAsString(result.join('\n'));
      await _tts.speak("Tâches supprimées");
      _historique.insert(0, "🗑️ $_categorieActuelle vidé");
      setState(() {});
    } catch (e) {
      _afficherSnack("Erreur de suppression");
      debugPrint("Erreur _effacerTachesCategorie: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Djena - Assistant Offline"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.mic),
              Tab(icon: Icon(Icons.list)),
            ],
          ),
        ),
        body: _chargementEnCours
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAccueil(),
                  _buildTaches(),
                ],
              ),
      ),
    );
  }

  Widget _buildAccueil() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_transcription),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _lireTachesCategorie,
            child: const Text("Lire les tâches"),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _compterTachesCategorie,
            child: const Text("Compter les tâches"),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _historique.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_historique[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaches() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButton<String>(
            value: _categorieActuelle,
            items: _categories.map((cat) => DropdownMenuItem(
              value: cat,
              child: Text(cat),
            )).toList(),
            onChanged: (value) => setState(() => _categorieActuelle = value!),
          ),
          TextField(
            controller: _tacheController,
            decoration: const InputDecoration(labelText: "Nouvelle tâche"),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => _ajouterTache(_tacheController.text),
                child: const Text("Ajouter"),
              ),
              ElevatedButton(
                onPressed: _effacerTachesCategorie,
                child: const Text("Vider"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}