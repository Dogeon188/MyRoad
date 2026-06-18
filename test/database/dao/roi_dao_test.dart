import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';

void main() {
  late AppDatabase db;
  late RoiDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = RoiDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert and retrieve ROI', () async {
    final id = await dao.insertRoi('Japan Trip Research', 'Spots for Japan');
    final roi = await dao.getById(id);
    expect(roi != null, true);
    expect(roi!.name, 'Japan Trip Research');
    expect(roi.description, 'Spots for Japan');
  });

  test('watchAll returns stream of ROIs', () async {
    await dao.insertRoi('ROI 1', null);
    await dao.insertRoi('ROI 2', null);

    final rois = await dao.watchAll().first;
    expect(rois.length, 2);
  });

  test('update ROI', () async {
    final id = await dao.insertRoi('Old Name', null);
    await dao.updateRoi(id, name: 'New Name');

    final roi = await dao.getById(id);
    expect(roi!.name, 'New Name');
  });

  test('delete ROI', () async {
    final id = await dao.insertRoi('To Delete', null);
    await dao.deleteRoi(id);

    final roi = await dao.getById(id);
    expect(roi == null, true);
  });
}
