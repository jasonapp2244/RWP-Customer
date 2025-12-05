// ignore_for_file: unnecessary_overrides

import 'dart:async';
import 'dart:developer';

import 'package:customer/app/models/banner_model.dart';
import 'package:customer/app/models/booking_model.dart';
import 'package:customer/app/models/location_lat_lng.dart';
import 'package:customer/app/models/user_model.dart';
import 'package:customer/constant/booking_status.dart';
import 'package:customer/constant/collection_name.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/utils/fire_store_utils.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart' hide LocationAccuracy;
import 'package:location/location.dart' as loc;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:location/location.dart';
// import 'package:location/location.dart';

import 'package:permission_handler/permission_handler.dart';

// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeController extends GetxController {
  final count = 0.obs;
  RxString profilePic = "https://firebasestorage.googleapis.com/v0/b/mytaxi-a8627.appspot.com/o/constant_assets%2F59.png?alt=media&token=a0b1aebd-9c01-45f6-9569-240c4bc08e23".obs;
  RxString name = ''.obs;
  RxString phoneNumber = ''.obs;
  RxList<BannerModel> bannerList = <BannerModel>[].obs;
  RxList<BookingModel> bookingList = <BookingModel>[].obs;
  PageController pageController = PageController();
  RxInt curPage = 0.obs;
  RxInt drawerIndex = 0.obs;
  RxBool isLoading = false.obs;
  RxBool hasLocationPermission = false.obs;
  RxString locationPermissionError = ''.obs;
  RxInt suggestionView = 3.obs;
  
  Location location = Location();

  @override
  void onInit() {
    super.onInit();
    initializeLocationAndData();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  Future<void> initializeLocationAndData() async {
    isLoading.value = true;
    
    try {
      // Get user data first
      await getUserData();
      
      // Check and request location permission
      await checkAndRequestLocationPermission();
      
      // If permission granted, start location updates
      if (hasLocationPermission.value) {
        await startLocationUpdates();
      }
      
      // Get ongoing booking
      getOngoingBooking();
      
      // Setup suggestion view
      setupSuggestionView();
      
    } catch (e) {
      log('Error initializing: $e');
      Get.snackbar(
        'Error',
        'Failed to initialize app. Please restart.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkAndRequestLocationPermission() async {
    try {
      log('Checking location permissions...');
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log('Location services are disabled');
        locationPermissionError.value = 'Location services are disabled. Please enable them.';
        hasLocationPermission.value = false;
        
        // Show dialog to enable location services
        Get.defaultDialog(
          title: 'Location Services Disabled',
          middleText: 'Please enable location services to use this app.',
          textConfirm: 'Open Settings',
          textCancel: 'Cancel',
          onConfirm: () async {
            Get.back();
            await Geolocator.openLocationSettings();
          },
        );
        return;
      }

      // Check location permission status
      LocationPermission permission = await Geolocator.checkPermission();
      log('Current permission status: $permission');
      
      if (permission == LocationPermission.deniedForever) {
        log('Permission denied forever');
        locationPermissionError.value = 'Location permission permanently denied. Please enable in app settings.';
        hasLocationPermission.value = false;
        
        // Show dialog to open app settings
        Get.defaultDialog(
          title: 'Permission Required',
          middleText: 'Location permission is permanently denied. Please enable it in app settings.',
          textConfirm: 'Open Settings',
          textCancel: 'Cancel',
          onConfirm: () async {
            Get.back();
            await openAppSettings();
          },
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        log('Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        
        if (permission == LocationPermission.denied) {
          log('Permission still denied after request');
          locationPermissionError.value = 'Location permission denied. Some features may not work.';
          hasLocationPermission.value = false;
          
          Get.snackbar(
            'Permission Denied',
            'Location permission is required for full functionality.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      // Permission granted
      log('Location permission granted: $permission');
      hasLocationPermission.value = true;
      locationPermissionError.value = '';
      
      // Request background location permission if needed
      if (permission == LocationPermission.whileInUse) {
        try {
          var bgPermission = await Permission.locationAlways.request();
          if (!bgPermission.isGranted) {
            log('Background location not granted, but foreground is OK');
          }
        } catch (e) {
          log('Error requesting background permission: $e');
        }
      }
      
    } catch (e) {
      log('Error checking location permissions: $e');
      hasLocationPermission.value = false;
      locationPermissionError.value = 'Error checking location permissions';
    }
  }

  Future<void> startLocationUpdates() async {
    try {
      if (!hasLocationPermission.value) {
        log('Cannot start location updates: No permission');
        return;
      }

      log('Starting location updates...');
      
      // Configure location settings - use integer values for location package
     await location.changeSettings(
  accuracy: loc.LocationAccuracy.high,
  distanceFilter: double.parse(Constant.driverLocationUpdate.toString()),
  interval: 10000,
);

      // Enable background mode (only if we have proper permission)
      try {
        await location.enableBackgroundMode(enable: true);
        log('Background mode enabled');
      } catch (e) {
        log('Cannot enable background mode: $e');
        // Continue with foreground updates only
      }

      // Get initial location
      await getInitialLocation();

      // Start listening to location updates
      location.onLocationChanged.listen((locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          log('Location updated: ${locationData.latitude}, ${locationData.longitude}');
          Constant.currentLocation = LocationLatLng(
            latitude: locationData.latitude!, 
            longitude: locationData.longitude!
          );
        }
      }, onError: (error) {
        log('Location stream error: $error');
        
        if (error.toString().contains('PERMISSION_DENIED')) {
          hasLocationPermission.value = false;
          locationPermissionError.value = 'Location permission lost. Please grant permission again.';
          
          Get.snackbar(
            'Permission Lost',
            'Location permission was revoked. Please grant permission again.',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );
        }
      });

      log('Location updates started successfully');
      
    } catch (e) {
      log('Error starting location updates: $e');
      hasLocationPermission.value = false;
      locationPermissionError.value = 'Failed to start location updates';
      
      // Try to re-request permission
      Future.delayed(const Duration(seconds: 2), () {
        checkAndRequestLocationPermission();
      });
    }
  }

  Future<void> getInitialLocation() async {
    try {
      log('Getting initial location...');
      
      // Try to get current position using Geolocator's LocationAccuracy enum
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:geo.LocationAccuracy.high, // Use Geolocator's constant
        timeLimit: const Duration(seconds: 10),
      ).catchError((error) {
        log('Error getting current position: $error');
        throw error;
      });

      log('Got initial location: ${position.latitude}, ${position.longitude}');
      Constant.currentLocation = LocationLatLng(
        latitude: position.latitude, 
        longitude: position.longitude
      );
      
    } on TimeoutException catch (_) {
      log('Timeout getting initial location');
      Get.snackbar(
        'Location Timeout',
        'Getting location took too long. Please check your connection.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      log('Error getting initial location: $e');
      // Don't show error here, as background updates might still work
    }
  }

  Future<void> getUserData() async {
    try {
      UserModel? userModel = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      
      await checkActiveStatus();
      
      if (userModel != null) {
        // Update profile picture
        profilePic.value = (userModel.profilePic ?? "").isNotEmpty
            ? userModel.profilePic ?? Constant.defaultProfilePic
            : Constant.defaultProfilePic;
        
        name.value = userModel.fullName ?? '';
        phoneNumber.value = (userModel.countryCode ?? '') + (userModel.phoneNumber ?? '');
        
        // Update FCM token
        userModel.fcmToken = await NotificationService.getToken();
        await FireStoreUtils.updateUser(userModel);
        
        // Get banners
        await FireStoreUtils.getBannerList().then((value) {
          bannerList.value = value ?? [];
        });

        log('User data loaded successfully');
      } else {
        log('User model is null');
      }
    } catch (e) {
      log('Error in getUserData: $e');
      Get.snackbar(
        'Error',
        'Failed to load user data',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void getOngoingBooking() {
    try {
      FireStoreUtils.fireStore
          .collection(CollectionName.bookings)
          .where('bookingStatus', whereIn: [
            BookingStatus.bookingAccepted,
            BookingStatus.bookingPlaced,
            BookingStatus.bookingOngoing,
            BookingStatus.driverAssigned,
          ])
          .where("customerId", isEqualTo: FireStoreUtils.getCurrentUid())
          .orderBy("createAt", descending: true)
          .snapshots()
          .listen(
            (event) {
              bookingList.value = event.docs
                  .map((doc) => BookingModel.fromJson(doc.data()))
                  .toList();
              log('Ongoing bookings updated: ${bookingList.length} bookings');
            },
            onError: (error) {
              log('Error listening to bookings: $error');
            },
          );
    } catch (e) {
      log('Error setting up booking listener: $e');
    }
  }

  Future<void> checkActiveStatus() async {
    try {
      final userModel = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (userModel != null && userModel.isActive == false) {
        Get.defaultDialog(
          titlePadding: const EdgeInsets.only(top: 16),
          title: "Account Disabled",
          middleText: "Your account has been disabled. Please contact the administrator.",
          titleStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          barrierDismissible: false,
          onWillPop: () async {
            SystemNavigator.pop();
            return false;
          },
        );
      }
    } catch (e) {
      log('Error checking active status: $e');
    }
  }

  void setupSuggestionView() {
    try {
      if (Constant.isInterCitySharingBid == true && 
          Constant.isParcelBid == true && 
          Constant.isInterCitySharingBid == true) {
        suggestionView.value = 3;
      } else if (Constant.isInterCitySharingBid == false && 
                 Constant.isInterCitySharingBid == false) {
        suggestionView.value = 2;
      } else {
        suggestionView.value = 1;
      }
    } catch (e) {
      log('Error setting up suggestion view: $e');
      suggestionView.value = 1;
    }
  }

  // Method to retry location permission
  Future<void> retryLocationPermission() async {
    locationPermissionError.value = '';
    await checkAndRequestLocationPermission();
    
    if (hasLocationPermission.value) {
      await startLocationUpdates();
    }
  }

  Future<void> deleteUserAccount() async {
    try {
      await FirebaseFirestore.instance
          .collection(CollectionName.users)
          .doc(FireStoreUtils.getCurrentUid())
          .delete();

      await FirebaseAuth.instance.currentUser!.delete();
      
      log('User account deleted successfully');
    } on FirebaseAuthException catch (error) {
      log("Firebase Auth Exception : $error");
      Get.snackbar(
        'Error',
        'Failed to delete account: ${error.message}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      log("Error : $error");
      Get.snackbar(
        'Error',
        'Failed to delete account',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}






// // ignore_for_file: unnecessary_overrides

// import 'dart:async';
// import 'package:location/location.dart' show Location, LocationAccuracy;
// import 'package:customer/app/models/banner_model.dart';
// import 'package:customer/app/models/booking_model.dart';
// import 'package:customer/app/models/location_lat_lng.dart';
// import 'package:customer/app/models/user_model.dart';
// import 'package:customer/constant/booking_status.dart';
// import 'package:customer/constant/collection_name.dart';
// import 'package:customer/constant/constant.dart';
// import 'package:customer/utils/fire_store_utils.dart';
// import 'package:customer/utils/notification_service.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:geolocator/geolocator.dart' hide LocationAccuracy;
// // import 'package:location/location.dart' hide LocationAccuracy;
// import 'package:permission_handler/permission_handler.dart';

// // ignore_for_file: depend_on_referenced_packages
// import 'package:cloud_firestore/cloud_firestore.dart';

// class HomeController extends GetxController {
//   final count = 0.obs;
//   RxString profilePic = "https://firebasestorage.googleapis.com/v0/b/mytaxi-a8627.appspot.com/o/constant_assets%2F59.png?alt=media&token=a0b1aebd-9c01-45f6-9569-240c4bc08e23".obs;
//   RxString name = ''.obs;
//   RxString phoneNumber = ''.obs;
//   RxList<BannerModel> bannerList = <BannerModel>[].obs;
//   RxList<BookingModel> bookingList = <BookingModel>[].obs;
//   PageController pageController = PageController();
//   RxInt curPage = 0.obs;
//   RxInt drawerIndex = 0.obs;
//   RxBool isLoading = false.obs;
//   RxBool hasLocationPermission = false.obs;
//   RxString locationPermissionError = ''.obs;
//   RxInt suggestionView = 3.obs;
  
//   Location location = Location();

//   @override
//   void onInit() {
//     super.onInit();
//     initializeLocationAndData();
//   }

//   @override
//   void onReady() {
//     super.onReady();
//   }

//   @override
//   void onClose() {
//     pageController.dispose();
//     super.onClose();
//   }

//   Future<void> initializeLocationAndData() async {
//     isLoading.value = true;
    
//     try {
//       // Get user data first
//       await getUserData();
      
//       // Check and request location permission
//       await checkAndRequestLocationPermission();
      
//       // If permission granted, start location updates
//       if (hasLocationPermission.value) {
//         await startLocationUpdates();
//       }
      
//       // Get ongoing booking
//       getOngoingBooking();
      
//       // Setup suggestion view
//       setupSuggestionView();
      
//     } catch (e) {
//     print('Error initializing: $e');
//       Get.snackbar(
//         'Error',
//         'Failed to initialize app. Please restart.',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   Future<void> checkAndRequestLocationPermission() async {
//     try {
//       print('Checking location permissions...');
      
//       // Check if location services are enabled
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         print('Location services are disabled');
//         locationPermissionError.value = 'Location services are disabled. Please enable them.';
//         hasLocationPermission.value = false;
        
//         // Show dialog to enable location services
//         Get.defaultDialog(
//           title: 'Location Services Disabled',
//           middleText: 'Please enable location services to use this app.',
//           textConfirm: 'Open Settings',
//           textCancel: 'Cancel',
//           onConfirm: () async {
//             Get.back();
//             await Geolocator.openLocationSettings();
//           },
//         );
//         return;
//       }

//       // Check location permission status
//       LocationPermission permission = await Geolocator.checkPermission();
//       print('Current permission status: $permission');
      
//       if (permission == LocationPermission.deniedForever) {
//         print('Permission denied forever');
//         locationPermissionError.value = 'Location permission permanently denied. Please enable in app settings.';
//         hasLocationPermission.value = false;
        
//         // Show dialog to open app settings
//         Get.defaultDialog(
//           title: 'Permission Required',
//           middleText: 'Location permission is permanently denied. Please enable it in app settings.',
//           textConfirm: 'Open Settings',
//           textCancel: 'Cancel',
//           onConfirm: () async {
//             Get.back();
//             await openAppSettings();
//           },
//         );
//         return;
//       }

//       if (permission == LocationPermission.denied) {
//         print('Permission denied, requesting...');
//         permission = await Geolocator.requestPermission();
        
//         if (permission == LocationPermission.denied) {
//           print('Permission still denied after request');
//           locationPermissionError.value = 'Location permission denied. Some features may not work.';
//           hasLocationPermission.value = false;
          
//           Get.snackbar(
//             'Permission Denied',
//             'Location permission is required for full functionality.',
//             snackPosition: SnackPosition.BOTTOM,
//             duration: const Duration(seconds: 3),
//           );
//           return;
//         }
//       }

//       // Permission granted
//       print('Location permission granted: $permission');
//       hasLocationPermission.value = true;
//       locationPermissionError.value = '';
      
//       // Request background location permission if needed
//       if (permission == LocationPermission.whileInUse) {
//         try {
//           var bgPermission = await Permission.locationAlways.request();
//           if (!bgPermission.isGranted) {
//             print('Background location not granted, but foreground is OK');
//           }
//         } catch (e) {
//           print('Error requesting background permission: $e');
//         }
//       }
      
//     } catch (e) {
//       print('Error checking location permissions: $e');
//       hasLocationPermission.value = false;
//       locationPermissionError.value = 'Error checking location permissions';
//     }
//   }

//   Future<void> startLocationUpdates() async {
//     try {
//       if (!hasLocationPermission.value) {
//         print('Cannot start location updates: No permission');
//         return;
//       }

//       print('Starting location updates...');
      
//       // Configure location settings
//       await location.changeSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: double.parse(Constant.driverLocationUpdate.toString()),
//         interval: 10000,
//       );

//       // Enable background mode (only if we have proper permission)
//       try {
//         await location.enableBackgroundMode(enable: true);
//         print('Background mode enabled');
//       } catch (e) {
//         print('Cannot enable background mode: $e');
//         // Continue with foreground updates only
//       }

//       // Get initial location
//       await getInitialLocation();

//       // Start listening to location updates
//       location.onLocationChanged.listen((locationData) {
//         if (locationData.latitude != null && locationData.longitude != null) {
//           print('Location updated: ${locationData.latitude}, ${locationData.longitude}');
//           Constant.currentLocation = LocationLatLng(
//             latitude: locationData.latitude!, 
//             longitude: locationData.longitude!
//           );
//         }
//       }, onError: (error) {
//         print('Location stream error: $error');
        
//         if (error.toString().contains('PERMISSION_DENIED')) {
//           hasLocationPermission.value = false;
//           locationPermissionError.value = 'Location permission lost. Please grant permission again.';
          
//           Get.snackbar(
//             'Permission Lost',
//             'Location permission was revoked. Please grant permission again.',
//             snackPosition: SnackPosition.BOTTOM,
//             duration: const Duration(seconds: 3),
//           );
//         }
//       });

//       print('Location updates started successfully');
      
//     } catch (e) {
//       print('Error starting location updates: $e');
//       hasLocationPermission.value = false;
//       locationPermissionError.value = 'Failed to start location updates';
      
//       // Try to re-request permission
//       Future.delayed(const Duration(seconds: 2), () {
//         checkAndRequestLocationPermission();
//       });
//     }
//   }

//   Future<void> getInitialLocation() async {
//     try {
//       print('Getting initial location...');
      
//       // Try to get current position
//       Position position = await Geolocator.getCurrentPosition(
        
//         desiredAccuracy: LocationAccuracy.high,
//         timeLimit: const Duration(seconds: 10),
//       ).catchError((error) {
//         print('Error getting current position: $error');
//         throw error;
//       });

//       print('Got initial location: ${position.latitude}, ${position.longitude}');
//       Constant.currentLocation = LocationLatLng(
//         latitude: position.latitude, 
//         longitude: position.longitude
//       );
      
//     } on TimeoutException catch (_) {
//       print('Timeout getting initial location');
//       Get.snackbar(
//         'Location Timeout',
//         'Getting location took too long. Please check your connection.',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     } catch (e) {
//       print('Error getting initial location: $e');
//       // Don't show error here, as background updates might still work
//     }
//   }

//   Future<void> getUserData() async {
//     try {
//       UserModel? userModel = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      
//       await checkActiveStatus();
      
//       if (userModel != null) {
//         // Update profile picture
//         profilePic.value = (userModel.profilePic ?? "").isNotEmpty
//             ? userModel.profilePic ?? Constant.defaultProfilePic
//             : Constant.defaultProfilePic;
        
//         name.value = userModel.fullName ?? '';
//         phoneNumber.value = (userModel.countryCode ?? '') + (userModel.phoneNumber ?? '');
        
//         // Update FCM token
//         userModel.fcmToken = await NotificationService.getToken();
//         await FireStoreUtils.updateUser(userModel);
        
//         // Get banners
//         await FireStoreUtils.getBannerList().then((value) {
//           bannerList.value = value ?? [];
//         });

//         print('User data loaded successfully');
//       } else {
//         print('User model is null');
//       }
//     } catch (e) {
//       print('Error in getUserData: $e');
//       Get.snackbar(
//         'Error',
//         'Failed to load user data',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     }
//   }

//   void getOngoingBooking() {
//     try {
//       FireStoreUtils.fireStore
//           .collection(CollectionName.bookings)
//           .where('bookingStatus', whereIn: [
//             BookingStatus.bookingAccepted,
//             BookingStatus.bookingPlaced,
//             BookingStatus.bookingOngoing,
//             BookingStatus.driverAssigned,
//           ])
//           .where("customerId", isEqualTo: FireStoreUtils.getCurrentUid())
//           .orderBy("createAt", descending: true)
//           .snapshots()
//           .listen(
//             (event) {
//               bookingList.value = event.docs
//                   .map((doc) => BookingModel.fromJson(doc.data()))
//                   .toList();
//               print('Ongoing bookings updated: ${bookingList.length} bookings');
//             },
//             onError: (error) {
//               print('Error listening to bookings: $error');
//             },
//           );
//     } catch (e) {
//       print('Error setting up booking listener: $e');
//     }
//   }

//   Future<void> checkActiveStatus() async {
//     try {
//       final userModel = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
//       if (userModel != null && userModel.isActive == false) {
//         Get.defaultDialog(
//           titlePadding: const EdgeInsets.only(top: 16),
//           title: "Account Disabled",
//           middleText: "Your account has been disabled. Please contact the administrator.",
//           titleStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
//           barrierDismissible: false,
//           onWillPop: () async {
//             SystemNavigator.pop();
//             return false;
//           },
//         );
//       }
//     } catch (e) {
//       print('Error checking active status: $e');
//     }
//   }

//   void setupSuggestionView() {
//     try {
//       if (Constant.isInterCitySharingBid == true && 
//           Constant.isParcelBid == true && 
//           Constant.isInterCitySharingBid == true) {
//         suggestionView.value = 3;
//       } else if (Constant.isInterCitySharingBid == false && 
//                  Constant.isInterCitySharingBid == false) {
//         suggestionView.value = 2;
//       } else {
//         suggestionView.value = 1;
//       }
//     } catch (e) {
//       print('Error setting up suggestion view: $e');
//       suggestionView.value = 1;
//     }
//   }

//   // Method to retry location permission
//   Future<void> retryLocationPermission() async {
//     locationPermissionError.value = '';
//     await checkAndRequestLocationPermission();
    
//     if (hasLocationPermission.value) {
//       await startLocationUpdates();
//     }
//   }

//   Future<void> deleteUserAccount() async {
//     try {
//       await FirebaseFirestore.instance
//           .collection(CollectionName.users)
//           .doc(FireStoreUtils.getCurrentUid())
//           .delete();

//       await FirebaseAuth.instance.currentUser!.delete();
      
//       print('User account deleted successfully');
//     } on FirebaseAuthException catch (error) {
//       print("Firebase Auth Exception : $error");
//       Get.snackbar(
//         'Error',
//         'Failed to delete account: ${error.message}',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     } catch (error) {
//       print("Error : $error");
//       Get.snackbar(
//         'Error',
//         'Failed to delete account',
//         snackPosition: SnackPosition.BOTTOM,
//       );
//     }
//   }
// }









// // ignore_for_file: unnecessary_overrides

// import 'dart:developer';

// import 'package:customer/app/models/banner_model.dart';
// import 'package:customer/app/models/booking_model.dart';
// import 'package:customer/app/models/location_lat_lng.dart';
// import 'package:customer/app/models/user_model.dart';
// import 'package:customer/constant/booking_status.dart';
// import 'package:customer/constant/collection_name.dart';
// import 'package:customer/constant/constant.dart';
// import 'package:customer/utils/fire_store_utils.dart';
// import 'package:customer/utils/notification_service.dart';
// import 'package:customer/utils/utils.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:location/location.dart';

// // ignore_for_file: depend_on_referenced_packages
// import 'package:cloud_firestore/cloud_firestore.dart';

// class HomeController extends GetxController {
//   final count = 0.obs;
//   RxString profilePic = "https://firebasestorage.googleapis.com/v0/b/mytaxi-a8627.appspot.com/o/constant_assets%2F59.png?alt=media&token=a0b1aebd-9c01-45f6-9569-240c4bc08e23".obs;
//   RxString name = ''.obs;
//   RxString phoneNumber = ''.obs;
//   RxList<BannerModel> bannerList = <BannerModel>[].obs;
//   RxList<BookingModel> bookingList = <BookingModel>[].obs;
//   PageController pageController = PageController();
//   RxInt curPage = 0.obs;
//   RxInt drawerIndex = 0.obs;
//   RxBool isLoading = false.obs;

//   RxInt suggestionView = 3.obs;



//   @override
//   void onInit() {
//     getUserData();
//     getOngoingBooking();
//     updateCurrentLocation();
//     super.onInit();
//   }

//   @override
//   void onReady() {
//     super.onReady();
//   }

//   @override
//   void onClose() {}

//   Future<void> getUserData() async {
//     isLoading.value = true;

//     UserModel? userModel = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
//     await checkActiveStatus();
//     if (userModel != null) {
//       profilePic.value = (userModel.profilePic ?? "").isNotEmpty
//           ? userModel.profilePic ?? "https://firebasestorage.googleapis.com/v0/b/mytaxi-a8627.appspot.com/o/constant_assets%2F59.png?alt=media&token=a0b1aebd-9c01-45f6-9569-240c4bc08e23"
//           : "https://firebasestorage.googleapis.com/v0/b/mytaxi-a8627.appspot.com/o/constant_assets%2F59.png?alt=media&token=a0b1aebd-9c01-45f6-9569-240c4bc08e23";
//       name.value = userModel.fullName ?? '';
//       phoneNumber.value = (userModel.countryCode ?? '') + (userModel.phoneNumber ?? '');
//       userModel.fcmToken = await NotificationService.getToken();
//       await FireStoreUtils.updateUser(userModel);
//       await FireStoreUtils.getBannerList().then((value) {
//         bannerList.value = value ?? [];
//       });

//       await Utils.getCurrentLocation();
//     }
//   }

//   void getOngoingBooking() {
//     FireStoreUtils.fireStore
//         .collection(CollectionName.bookings)
//         .where('bookingStatus', whereIn: [
//           BookingStatus.bookingAccepted,
//           BookingStatus.bookingPlaced,
//           BookingStatus.bookingOngoing,
//           BookingStatus.driverAssigned,
//         ])
//         .where("customerId", isEqualTo: FireStoreUtils.getCurrentUid())
//         .orderBy("createAt", descending: true)
//         .snapshots()
//         .listen((event) {
//           bookingList.value = event.docs.map((doc) => BookingModel.fromJson(doc.data())).toList();
//         });
//   }

//   Future<void> checkActiveStatus() async {
//     final userModel = await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
//     if (userModel != null && userModel.isActive == false) {
//       Get.defaultDialog(
//         titlePadding: const EdgeInsets.only(top: 16),
//         title: "Account Disabled",
//         middleText: "Your account has been disabled. Please contact the administrator.",
//         titleStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
//         barrierDismissible: false,
//         onWillPop: () async {
//           SystemNavigator.pop();
//           return false;
//         },
//       );
//     }
//   }

//   Location location = Location();

//   Future<void> updateCurrentLocation() async {
//     final permissionStatus = await location.hasPermission();
//     if (permissionStatus == PermissionStatus.granted) {
//       location.enableBackgroundMode(enable: true);
//       location.changeSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: double.parse(Constant.driverLocationUpdate.toString()),
//         interval: 10000,
//       );
//       location.onLocationChanged.listen((locationData) {
//         log("asdf------>");
//         log(locationData.toString());
//         Constant.currentLocation = LocationLatLng(latitude: locationData.latitude, longitude: locationData.longitude);
//       });
//     } else {
//       location.requestPermission().then((permissionStatus) {
//         if (permissionStatus == PermissionStatus.granted) {
//           location.enableBackgroundMode(enable: true);
//           location.changeSettings(accuracy: LocationAccuracy.high, distanceFilter: double.parse(Constant.driverLocationUpdate.toString()), interval: 10000);
//           location.onLocationChanged.listen((locationData) async {
//             Constant.currentLocation = LocationLatLng(latitude: locationData.latitude, longitude: locationData.longitude);
//           });
//         }
//       });
//     }

//     if (Constant.isInterCitySharingBid == true && Constant.isParcelBid == true && Constant.isInterCitySharingBid == true) {
//       suggestionView.value = 3;
//     } else if (Constant.isInterCitySharingBid == false && Constant.isInterCitySharingBid == false) {
//       suggestionView.value = 2;
//     } else {
//       suggestionView.value = 1;
//     }
//     isLoading.value = false;
//     update();
//   }

//   Future<void> deleteUserAccount() async {
//     try {
//       await FirebaseFirestore.instance.collection(CollectionName.users).doc(FireStoreUtils.getCurrentUid()).delete();

//       await FirebaseAuth.instance.currentUser!.delete();
//     } on FirebaseAuthException catch (error) {
//       log("Firebase Auth Exception : $error");
//     } catch (error) {
//       log("Error : $error");
//     }
//   }
// }
