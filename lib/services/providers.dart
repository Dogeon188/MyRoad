import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';

final roiDaoProvider = Provider<RoiDao>((ref) {
  return RoiDao(ref.watch(appDatabaseProvider));
});

final zoneDaoProvider = Provider<ZoneDao>((ref) {
  return ZoneDao(ref.watch(appDatabaseProvider));
});

final regionDaoProvider = Provider<RegionDao>((ref) {
  return RegionDao(ref.watch(appDatabaseProvider));
});

final spotDaoProvider = Provider<SpotDao>((ref) {
  return SpotDao(ref.watch(appDatabaseProvider));
});
