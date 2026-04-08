import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/olive_grove.dart';
import '../models/tasks.dart';
import '../models/harvest.dart';

class DatabaseHelper {
  // Δημιουργούμε ένα Singleton
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ΑΝΕΒΑΖΟΥΜΕ ΤΗΝ ΕΚΔΟΣΗ
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // ΠΡΟΣΘΗΚΗ ΑΝΑΒΑΘΜΙΣΗΣ
    );
  }

  // --- ΕΞΥΠΝΗ ΣΥΝΑΡΤΗΣΗ ΑΝΑΒΑΘΜΙΣΗΣ ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Ρωτάμε την SQLite για τις στήλες του πίνακα 'groves'
      var tableInfo = await db.rawQuery('PRAGMA table_info(groves)');

      // 2. Ελέγχουμε αν υπάρχει ήδη η στήλη 'treeCount'
      bool hasTreeCount = tableInfo.any(
        (column) => column['name'] == 'treeCount',
      );

      // 3. Αν ΔΕΝ υπάρχει, τότε μόνο την προσθέτουμε!
      if (!hasTreeCount) {
        try {
          await db.execute(
            'ALTER TABLE groves ADD COLUMN treeCount INTEGER DEFAULT 0',
          );
        } catch (e) {
          // Αν κάτι πάει στραβά, απλά το αγνοούμε (ίσως να μην υποστηρίζεται το ALTER TABLE)
        }
      }
    }
  }

  // Δημιουργία των πινάκων με SQL
  Future _createDB(Database db, int version) async {
    // Πίνακας Εργασιών
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
      treeCount INTEGER NOT NULL, -- ΠΡΟΣΘΗΚΗ ΕΔΩ ΓΙΑ ΝΕΕΣ ΕΓΚΑΤΑΣΤΑΣΕΙΣ
      lat REAL,
      lng REAL,
      boundaries TEXT
    )
    ''');

    // 3. Πίνακας Συγκομιδής
    await db.execute('''
CREATE TABLE harvests(
        id TEXT PRIMARY KEY,
        groveId TEXT,
        oilVolume REAL,
        olivesWeight REAL,
        acidity REAL,
        pricePerUnit REAL,
        date TEXT
      )
    ''');
  }

  //  Λειτουργίες (CRUD)

  // Εισαγωγή Χωραφιού
  Future<void> insertGrove(OliveGrove grove) async {
    final db = await instance.database;
    await db.insert(
      'groves',
      grove.toMap(),
      conflictAlgorithm:
          ConflictAlgorithm.replace, // Αν υπάρχει ίδιο ID, κάνε αντικατάσταση
    );
  }

  // Ενημερώνει ένα υπάρχον χωράφι
  Future<int> updateGrove(OliveGrove grove) async {
    Database db = await instance.database;
    return await db.update(
      'groves',
      grove.toMap(),
      where: 'id = ?',
      whereArgs: [grove.id],
    );
  }

  Future<int> updateTask(Task task) async {
    Database db = await instance.database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // Ανάγνωση όλων των Χωραφιών
  Future<List<OliveGrove>> getAllGroves() async {
    final db = await instance.database;
    final result = await db.query(
      'groves',
    ); // Φέρνει τα πάντα από τον πίνακα 'groves'

    // Μετατρέπουμε τα Maps της βάσης σε λίστα από αντικείμενα OliveGrove
    return result.map((json) => OliveGrove.fromMap(json)).toList();
  }

  // Λειτουργίες για Εργασίες (Tasks)

  // Εισαγωγή νέας εργασίας
  Future<void> insertTask(Task task) async {
    final db = await instance.database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Ανάγνωση εργασιών μονο για ένα συγκεκριμένο χωράφι
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

  // --- Λειτουργίες Συγκομιδής ---
  Future<void> insertHarvest(Harvest harvest) async {
    final db = await instance.database;
    await db.insert(
      'harvests',
      harvest.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Harvest>> getHarvestsForGrove(String groveId) async {
    final db = await instance.database;
    final result = await db.query(
      'harvests',
      where: 'groveId = ?',
      whereArgs: [groveId],
      orderBy: 'date DESC',
    );
    return result.map((json) => Harvest.fromMap(json)).toList();
  }

  // Cascading Delete
  Future<void> deleteGrove(String id) async {
    final db = await instance.database;
    await db.delete('tasks', where: 'groveId = ?', whereArgs: [id]);
    await db.delete('harvests', where: 'groveId = ?', whereArgs: [id]);
    await db.delete('groves', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHarvest(String id) async {
    final db = await instance.database;
    return await db.delete('harvests', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalExpenses({
    String filter = 'all',
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await instance.database;
    String whereClause = '';
    final now = DateTime.now();

    if (filter == 'year') {
      whereClause = "WHERE date LIKE '${now.year}-%'";
    } else if (filter == 'month') {
      final monthStr = now.month.toString().padLeft(2, '0');
      whereClause = "WHERE date LIKE '${now.year}-$monthStr-%'";
    } else if (filter == 'custom' && start != null && end != null) {
      // Φροντίζουμε η τελική ημερομηνία να πιάνει όλη τη μέρα (μέχρι τις 23:59:59)
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      whereClause =
          "WHERE date >= '${start.toIso8601String()}' AND date <= '${endOfDay.toIso8601String()}'";
    }

    final result = await db.rawQuery(
      'SELECT SUM(cost) as total FROM tasks $whereClause',
    );

    if (result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> getTotalOilProduction({
    String filter = 'all',
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await instance.database;
    String whereClause = '';
    final now = DateTime.now();

    if (filter == 'year') {
      whereClause = "WHERE date LIKE '${now.year}-%'";
    } else if (filter == 'month') {
      final monthStr = now.month.toString().padLeft(2, '0');
      whereClause = "WHERE date LIKE '${now.year}-$monthStr-%'";
    } else if (filter == 'custom' && start != null && end != null) {
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      whereClause =
          "WHERE date >= '${start.toIso8601String()}' AND date <= '${endOfDay.toIso8601String()}'";
    }

    final result = await db.rawQuery(
      'SELECT SUM(oilVolume) as total FROM harvests $whereClause',
    );

    if (result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Φέρνει όλες τις μελλοντικές εργασίες μαζί με το όνομα του χωραφιού
  Future<List<Map<String, dynamic>>> getUpcomingTasks() async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String(); // Η τωρινή στιγμή

    // Κάνουμε JOIN τον πίνακα tasks με τον πίνακα groves
    final result = await db.rawQuery(
      '''
      SELECT tasks.*, groves.name as groveName 
      FROM tasks 
      INNER JOIN groves ON tasks.groveId = groves.id 
      WHERE tasks.date > ? 
      ORDER BY tasks.date ASC
    ''',
      [now],
    ); // Ταξινομημένα από το πιο κοντινό στο πιο μακρινό

    return result;
  }

  // Ενημέρωση μίας υπάρχουσας συγκομιδής (Update)
  Future<int> updateHarvest(Harvest harvest) async {
    final db = await instance.database;
    return await db.update(
      'harvests',
      harvest.toMap(),
      where: 'id = ?',
      whereArgs: [harvest.id],
    );
  }

  // ΝΕΑ ΣΥΝΑΡΤΗΣΗ: Υπολογίζει τα συνολικά έσοδα κατευθείαν με SQL
  Future<double> getTotalRevenue({
    String filter = 'all',
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await instance.database;
    String whereClause = '';
    final now = DateTime.now();

    if (filter == 'year') {
      whereClause = "WHERE date LIKE '${now.year}-%'";
    } else if (filter == 'month') {
      final monthStr = now.month.toString().padLeft(2, '0');
      whereClause = "WHERE date LIKE '${now.year}-$monthStr-%'";
    } else if (filter == 'custom' && start != null && end != null) {
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      whereClause =
          "WHERE date >= '${start.toIso8601String()}' AND date <= '${endOfDay.toIso8601String()}'";
    }

    // Το SQL Query πολλαπλασιάζει Λίτρα με Τιμή για κάθε γραμμή και τα αθροίζει!
    final result = await db.rawQuery(
      'SELECT SUM(oilVolume * pricePerUnit) as total FROM harvests $whereClause',
    );

    if (result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }
}
