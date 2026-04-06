abstract class StorageInterface {
  Future<void> saveData(
    List<dynamic> members,
    List<dynamic> transactions,
    List<dynamic> attendance,
    List<dynamic> classSessions,
    List<dynamic> gradeLevels,
    List<dynamic> studentGrades,
  );

  Future<Map<String, List<dynamic>>> loadAllData();
}

StorageInterface getStorage() => throw UnsupportedError('Cannot create a Storage');
