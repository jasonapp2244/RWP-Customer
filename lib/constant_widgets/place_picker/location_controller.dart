// ignore_for_file: deprecated_member_use, depend_on_referenced_packages

import 'dart:async';
import 'package:customer/constant_widgets/place_picker/selected_location_model.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationController extends GetxController {
  GoogleMapController? mapController;
  var selectedLocation = Rxn<LatLng>();
  var selectedPlaceAddress = Rxn<Placemark>();
  var address = "Move the map to select a location".obs;
  var isLoading = false.obs;
  var locationPermissionGranted = false.obs;
  TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Initialize location permission
    checkAndRequestLocationPermission();
    searchController.addListener(() {
      if (searchController.text.trim().isEmpty) {
        getCurrentLocation();
      }
    });
  }

  Future<void> checkAndRequestLocationPermission() async {
    try {
      isLoading.value = true;

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled
        Get.snackbar(
          'Location Service Disabled',
          'Please enable location services to use this feature',
          snackPosition: SnackPosition.BOTTOM,
        );
        isLoading.value = false;
        return;
      }

      // Check location permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        // Permission denied forever - show dialog to open settings
        Get.defaultDialog(
          title: 'Location Permission Required',
          middleText:
              'Location permission is permanently denied. Please enable it from app settings.',
          textConfirm: 'Open Settings',
          textCancel: 'Cancel',
          onConfirm: () async {
            Get.back();
            await openAppSettings();
          },
          onCancel: () {
            Get.back();
          },
        );
        locationPermissionGranted.value = false;
        isLoading.value = false;
        return;
      }

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar(
            'Permission Denied',
            'Location permission is required to use this feature',
            snackPosition: SnackPosition.BOTTOM,
          );
          locationPermissionGranted.value = false;
          isLoading.value = false;
          return;
        }
      }

      // Permission granted
      locationPermissionGranted.value = true;

      // Now get current location
      await getCurrentLocation();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking location permission: $e');
      }
      Get.snackbar(
        'Error',
        'Failed to check location permission',
        snackPosition: SnackPosition.BOTTOM,
      );
      locationPermissionGranted.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      if (!locationPermissionGranted.value) {
        await checkAndRequestLocationPermission();
        return;
      }

      isLoading.value = true;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      selectedLocation.value = LatLng(position.latitude, position.longitude);

      // Move camera to current location
      if (mapController != null) {
        await mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: selectedLocation.value!,
              zoom: 15,
            ),
          ),
        );
      }

      // Get address for current location
      await getAddressFromLatLng(selectedLocation.value!);
    } on TimeoutException {
      Get.snackbar(
        'Timeout',
        'Getting location took too long. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }

      // Handle specific Geolocator errors
      if (e.toString().contains('PERMISSION_DENIED')) {
        Get.snackbar(
          'Permission Error',
          'Location permission denied. Please enable it in settings.',
          snackPosition: SnackPosition.BOTTOM,
        );
        locationPermissionGranted.value = false;
      } else if (e.toString().contains('SERVICE_DISABLED')) {
        Get.snackbar(
          'Location Service',
          'Location services are disabled. Please enable them.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to get current location. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
        // localeIdentifier: 'en_US', // Optional: set locale
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        selectedPlaceAddress.value = place;

        // Build address string
        String street = place.street ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String adminArea = place.administrativeArea ?? '';
        String country = place.country ?? '';

        // Create formatted address
        List<String> addressParts = [];
        if (street.isNotEmpty) addressParts.add(street);
        if (subLocality.isNotEmpty) addressParts.add(subLocality);
        if (locality.isNotEmpty) addressParts.add(locality);
        if (adminArea.isNotEmpty) addressParts.add(adminArea);
        if (country.isNotEmpty) addressParts.add(country);

        address.value = addressParts.join(', ');
      } else {
        address.value = "No address found for this location";
      }
    } on TimeoutException {
      address.value = "Timeout while fetching address";
    } catch (e) {
      if (kDebugMode) {
        print('Error getting address: $e');
      }
      address.value = "Error fetching address";
    }
  }

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;

    // If we already have a location, move camera to it
    if (selectedLocation.value != null) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: selectedLocation.value!,
            zoom: 15,
          ),
        ),
      );
    } else if (locationPermissionGranted.value) {
      // If we have permission but no location yet, get it
      getCurrentLocation();
    }
  }

  void onMapMoved(CameraPosition position) {
    selectedLocation.value = position.target;
    // Optionally: get address when map stops moving
    // Uncomment if you want to update address on every move
    // getAddressFromLatLng(position.target);
  }

  void onMapIdle() {
    // Get address when map stops moving
    if (selectedLocation.value != null) {
      getAddressFromLatLng(selectedLocation.value!);
    }
  }

  void confirmLocation() {
    if (selectedLocation.value != null && selectedPlaceAddress.value != null) {
      SelectedLocationModel selectedLocationModel = SelectedLocationModel(
          address: selectedPlaceAddress.value!,
          latLng: selectedLocation.value!);
      print("Selected location model: ${selectedLocationModel.toJson()}");
      Get.back(result: selectedLocationModel);
    } else {
      Get.snackbar(
        'Error',
        'Please select a location first',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void moveCameraTo(LatLng target) {
    try {
      selectedLocation.value = target;
      mapController?.animateCamera(CameraUpdate.newLatLng(target));
      getAddressFromLatLng(target);
    } catch (e) {
      if (kDebugMode) {
        print('Error moving camera: $e');
      }
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  // Helper method to retry permission
  Future<void> retryLocationPermission() async {
    await checkAndRequestLocationPermission();
  }
}

// // ignore_for_file: deprecated_member_use, depend_on_referenced_packages

// import 'dart:developer';

// import 'package:customer/constant_widgets/place_picker/selected_location_model.dart';
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:flutter/material.dart';

// class LocationController extends GetxController {
//   GoogleMapController? mapController;
//   var selectedLocation = Rxn<LatLng>();
//   var selectedPlaceAddress = Rxn<Placemark>();
//   var address = "Move the map to select a location".obs;
//   TextEditingController searchController = TextEditingController();

//   @override
//   void onInit() {
//     super.onInit();
//     getCurrentLocation();
//     searchController.addListener(() {
//       // Only reset to current location, do not trigger any API or prediction fetch
//       if (searchController.text.trim().isEmpty) {
//         // Optionally reset the selected location/address
//         getCurrentLocation();
//       }
//     });
//   }

//   Future<void> getCurrentLocation() async {
//     Position position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );

//     selectedLocation.value = LatLng(position.latitude, position.longitude);

//     mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: selectedLocation.value!, zoom: 15),
//       ),
//     );

//     getAddressFromLatLng(selectedLocation.value!);
//   }

//   Future<void> getAddressFromLatLng(LatLng latLng) async {
//     try {
//       List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
//       if (placemarks.isNotEmpty) {
//         Placemark place = placemarks.first;
//         selectedPlaceAddress.value = place;
//         address.value = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
//       }
//     } catch (e) {
//       if (kDebugMode) {
//         print(e);
//       }
//     }
//   }

//   void onMapMoved(CameraPosition position) {
//     selectedLocation.value = position.target;
//   }

//   void confirmLocation() {
//     if (selectedLocation.value != null) {
//       SelectedLocationModel selectedLocationModel = SelectedLocationModel(address: selectedPlaceAddress.value, latLng: selectedLocation.value);
//       log("Selected location model: ${selectedLocationModel.toJson()}");
//       Get.back(result: selectedLocationModel);
//     }
//   }

//   void moveCameraTo(LatLng target) {
//     selectedLocation.value = target;
//     mapController?.animateCamera(CameraUpdate.newLatLng(target));
//     getAddressFromLatLng(target);
//   }
// }
