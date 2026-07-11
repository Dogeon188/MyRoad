import 'package:flutter/material.dart';

Color spotColor(String type, {int? colorValue}) {
  if (colorValue != null) return Color(colorValue);
  return switch (type) {
    'restaurant' => Colors.orange,
    'hotel' ||
    'checkin' ||
    'checkout' ||
    'luggage' ||
    'depart' ||
    'return' => Colors.purple,
    'online' => Colors.teal,
    'custom' => Colors.grey,
    'transfer' => Colors.indigo,
    _ => Colors.blue,
  };
}

IconData spotIcon(String type, {int? iconCode}) {
  if (iconCode != null) return IconData(iconCode, fontFamily: 'MaterialIcons');
  return switch (type) {
    'restaurant' => Icons.restaurant,
    'hotel' => Icons.hotel,
    'checkin' => Icons.login,
    'checkout' => Icons.logout,
    'luggage' => Icons.luggage,
    'depart' => Icons.directions_walk,
    'return' => Icons.night_shelter,
    'online' => Icons.videocam,
    'custom' => Icons.star_outline,
    'transfer' => Icons.directions_bus,
    _ => Icons.place,
  };
}

const spotIconChoices = <IconData>[
  Icons.place,
  Icons.restaurant,
  Icons.hotel,
  Icons.local_cafe,
  Icons.shopping_bag,
  Icons.museum,
  Icons.park,
  Icons.church,
  Icons.temple_buddhist,
  Icons.temple_hindu,
  Icons.castle,
  Icons.beach_access,
  Icons.hiking,
  Icons.attractions,
  Icons.photo_camera,
  Icons.local_bar,
  Icons.spa,
  Icons.pool,
  Icons.fitness_center,
  Icons.stadium,
  Icons.theater_comedy,
  Icons.nightlife,
  Icons.train,
  Icons.flight,
  Icons.directions_bus,
  Icons.directions_boat,
  Icons.local_pharmacy,
  Icons.local_hospital,
  Icons.school,
  Icons.store,
  Icons.star,
  Icons.favorite,
];

const spotColorChoices = <Color>[
  Colors.blue,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.red,
  Colors.green,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.brown,
  Colors.cyan,
  Colors.grey,
];
