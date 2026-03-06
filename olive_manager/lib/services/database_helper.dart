// Αρχείο: lib/services/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/olive_grove.dart';
import '../models/tasks.dart';

class DatabaseHelper {
  // Δημιουργούμε ένα Singleton (μόνο ένα instance της βάσης σε όλο το app)
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Άνοιγμα ή αρχικοποίηση της βάσης
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('olive_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath(); // Βρίσκει τον φάκελο του κινητού
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Δημιουργία των πινάκων με SQL
  Future _createDB(Database db, int version) async {
    // ΝΕΟ: Πίνακας Εργασιών
    await db.execute('''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      groveId TEXT NOT NULL,
      title TEXT NOT NULL,
      type TEXT NOT NULL,
      date TEXT NOT NULL,
      cost REAL NOT NULL,
      notes TEXT,
      FOREIGN KEY (groveId) REFERENCES groves (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE groves (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      area REAL NOT NULL,
      lat REAL,
      lng REAL
    )
    ''');
  }

  // --- Λειτουργίες (CRUD) ---

  // 1. Εισαγωγή Χωραφιού
  Future<void> insertGrove(OliveGrove grove) async {
    final db = await instance.database;
    await db.insert(
      'groves',
      grove.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Αν υπάρχει ίδιο ID, κάνε αντικατάσταση
    );
  }

  // 2. Ανάγνωση όλων των Χωραφιών
  Future<List<OliveGrove>> getAllGroves() async {
    final db = await instance.database;
    final result = await db.query(
      'groves',
    ); // Φέρνει τα πάντα από τον πίνακα 'groves'

    // Μετατρέπουμε τα Maps της βάσης σε λίστα από αντικείμενα OliveGrove
    return result.map((json) => OliveGrove.fromMap(json)).toList();
  }

  // --- Λειτουργίες για Εργασίες (Tasks) ---

  // Εισαγωγή νέας εργασίας
  Future<void> insertTask(Task task) async {
    final db = await instance.database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Ανάγνωση εργασιών ΜΟΝΟ για ένα συγκεκριμένο χωράφι
  Future<List<Task>> getTasksForGrove(String groveId) async {
    final db = await instance.database;

    // Φέρε όσα tasks έχουν το συγκεκριμένο groveId, ταξινομημένα με βάση την ημερομηνία
    final result = await db.query(
      'tasks',
      where: 'groveId = ?',
      whereArgs: [groveId],
      orderBy: 'date DESC', // Τα πιο πρόσφατα πρώτα
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  // Διαγραφή μίας εργασίας (Delete)
  Future<int> deleteTask(String id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Διαγραφή ενός Χωραφιού ΚΑΙ όλων των εργασιών του (Cascading Delete)
  Future<void> deleteGrove(String id) async {
    final db = await instance.database;

    // 1. Πρώτα διαγράφουμε όλες τις εργασίες που έχουν αυτό το groveId
    await db.delete('tasks', where: 'groveId = ?', whereArgs: [id]);

    // 2. Μετά διαγράφουμε το ίδιο το χωράφι από τον πίνακα groves
    await db.delete('groves', where: 'id = ?', whereArgs: [id]);
  }
}
