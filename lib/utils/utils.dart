import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' hide LocationAccuracy;

class Utils {
  static Future<Position?> getCurrentLocation() async {
    try {
      // Ensure Flutter binding is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Add delay to ensure plugins are loaded
      await Future.delayed(const Duration(milliseconds: 300));

      // First check if geolocator plugin is available
      bool isGeolocatorAvailable = await _checkGeolocatorAvailability();
      if (!isGeolocatorAvailable) {
        print('Geolocator plugin not available, using location package');
        return await _getLocationWithLocationPackage();
      }

      // Try with Geolocator
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try to enable location services
        bool serviceRequested = await Location().requestService();
        if (!serviceRequested) {
          print('Location service not enabled');
          return null;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return null;
      }

      // Get position with timeout
      // return await Geolocator.getCurrentPosition(
      //   desiredAccuracy: LocationAccuracy.high,
      // ).timeout(const Duration(seconds: 15), onTimeout: () {
      //   print('Timeout getting location');
      //   return null;
      // });

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Timeout getting location');
          throw TimeoutException('Location timeout');
        },
      );
    } catch (e) {
      print('Error fetching location with geolocator: $e');

      // Fallback to location package
      try {
        return await _getLocationWithLocationPackage();
      } catch (fallbackError) {
        print('Fallback location also failed: $fallbackError');
        return null;
      }
    }
  }

  static Future<bool> _checkGeolocatorAvailability() async {
    try {
      // Test if geolocator methods are available
      await Geolocator.isLocationServiceEnabled();
      return true;
    } catch (e) {
      print('Geolocator not available: $e');
      return false;
    }
  }

  static Future<Position?> _getLocationWithLocationPackage() async {
    try {
      Location location = Location();

      // Check if location service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          return null;
        }
      }

      // Check permission
      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
        if (permission != PermissionStatus.granted &&
            permission != PermissionStatus.grantedLimited) {
          return null;
        }
      }

      // Get location
      LocationData locationData = await location.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        return Position(
          latitude: locationData.latitude!,
          longitude: locationData.longitude!,
          timestamp: DateTime.now(),
          accuracy: locationData.accuracy ?? 0.0,
          altitude: locationData.altitude ?? 0.0,
          heading: locationData.heading ?? 0.0,
          speed: locationData.speed ?? 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );
      }

      return null;
    } catch (e) {
      print('Error getting location with location package: $e');
      return null;
    }
  }
}






// import 'package:flutter/material.dart';
// // ignore_for_file: depend_on_referenced_packages

// import 'package:geolocator/geolocator.dart';
// import 'package:location/location.dart';

// class Utils {
  
//   static Future<Position?> getCurrentLocation() async {
//     try {
//       // Ensure Flutter binding is initialized (usually in main)
//       WidgetsFlutterBinding.ensureInitialized();

//       // Delay execution until first frame
//       await Future.delayed(const Duration(milliseconds: 100));

//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         await Location().requestService();
//         return null;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) return null;
//       }
//       if (permission == LocationPermission.deniedForever) {
//         return Future.error(
//             'Location permissions are permanently denied, cannot request permissions.');
//       }

//       return await Geolocator.getCurrentPosition();
//     } catch (e) {
//       print('Error fetching location: $e');
//       return null;
//     }
//   }
// }







// // ignore_for_file: depend_on_referenced_packages

// import 'package:geolocator/geolocator.dart';
// import 'package:location/location.dart';

// class Utils {
//   static Future<Position?> getCurrentLocation() async {
//     bool serviceEnabled;
//     LocationPermission permission;

//     // Test if location services are enabled.
//     serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       // Location services are not enabled don't continue
//       // accessing the position and request users of the
//       // App to enable the location services.
//       await Location().requestService();
//       return null;
//     }
//     permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         // Permissions are denied, next time you could try
//         // requesting permissions again (this is also where
//         // Android's shouldShowRequestPermissionRationale
//         // returned true. According to Android guidelines
//         // your App should show an explanatory UI now.
//         return null;
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       // Permissions are denied forever, handle appropriately.
//       return Future.error('Location permissions are permanently denied, we cannot request permissions.');
//     }

//     // When we reach here, permissions are granted and we can
//     // continue accessing the position of the device.
//     return await Geolocator.getCurrentPosition();
//   }
// }
