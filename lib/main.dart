import 'package:country_code_picker/country_code_picker.dart';
import 'package:customer/utils/fire_store_utils.dart';
import 'package:customer/utils/notification_service.dart';
import 'package:customer/utils/utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:customer/app/modules/splash_screen/views/splash_screen_view.dart';
import 'package:customer/global_setting_controller.dart';
import 'package:customer/services/localization_service.dart';
import 'package:customer/theme/styles.dart';
import 'package:customer/utils/dark_theme_provider.dart';

import 'app/routes/app_pages.dart';
// import 'utils.dart'; // Your Utils.getCurrentLocation() here
// import 'firestore_utils.dart'; // Firestore functions

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase safely
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  configLoading();

  runApp(const MyApp());
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.circle
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = const Color(0xFFFEA735)
    ..backgroundColor = const Color(0xFFf5f6f6)
    ..indicatorColor = const Color(0xFFFEA735)
    ..textColor = const Color(0xFFFEA735)
    ..maskColor = const Color(0xFFf5f6f6)
    ..userInteractions = true
    ..dismissOnTap = false;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getCurrentAppTheme();

    // Call getUserData() safely after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await getUserData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    getCurrentAppTheme();
  }

  void getCurrentAppTheme() async {
    themeChangeProvider.darkTheme =
        await themeChangeProvider.darkThemePreference.getTheme();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => themeChangeProvider,
      child: Consumer<DarkThemeProvider>(
        builder: (context, value, child) {
          return Listener(
            onPointerUp: (_) {
              FocusScopeNode currentFocus = FocusScope.of(context);
              if (!currentFocus.hasPrimaryFocus &&
                  currentFocus.focusedChild != null) {
                currentFocus.focusedChild!.unfocus();
              }
            },
            child: GetMaterialApp(
              title: 'MyTaxi'.tr,
              debugShowCheckedModeBanner: false,
              theme: Styles.themeData(
                  themeChangeProvider.darkTheme == 0
                      ? true
                      : themeChangeProvider.darkTheme == 1
                          ? false
                          : themeChangeProvider.getSystemThem(),
                  context),
              localizationsDelegates: const [
                CountryLocalizations.delegate,
              ],
              locale: LocalizationService.locale,
              fallbackLocale: LocalizationService.locale,
              translations: LocalizationService(),
              builder: (context, child) {
                return SafeArea(
                  bottom: true,
                  top: false,
                  child: EasyLoading.init()(context, child),
                );
              },
              initialRoute: AppPages.INITIAL,
              getPages: AppPages.routes,
              home: GetBuilder<GlobalSettingController>(
                init: GlobalSettingController(),
                builder: (context) => const SplashScreenView(),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------- USER DATA ----------------------
Future<void> getUserData() async {
  // Show loading
  // Use your isLoading observable if needed
  try {
    String uid = FireStoreUtils.getCurrentUid();
    var userModel = await FireStoreUtils.getUserProfile(uid);

    if (userModel != null) {
      // Update profile data
      // ... your existing logic
      userModel.fcmToken = await NotificationService.getToken();
      await FireStoreUtils.updateUser(userModel);
      // Banner list
      var banners = await FireStoreUtils.getBannerList();
      // Set bannerList observable if using GetX

      // Get location safely
      await Utils.getCurrentLocation();
    }
  } catch (e) {
    print('Error in getUserData: $e');
  }
}











// import 'package:country_code_picker/country_code_picker.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:get/get.dart';
// import 'package:customer/app/modules/splash_screen/views/splash_screen_view.dart';
// import 'package:customer/global_setting_controller.dart';
// import 'package:customer/services/localization_service.dart';
// import 'package:customer/theme/styles.dart';
// import 'package:customer/utils/dark_theme_provider.dart';
// import 'package:provider/provider.dart';

// import 'app/routes/app_pages.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   try {
//     if (Firebase.apps.isEmpty) {
//       await Firebase.initializeApp();
//     }
//   } catch (e) {
//     print('Error initializing Firebase: $e');
//   }
//   configLoading();
//   runApp(MaterialApp(
//     debugShowCheckedModeBanner: false,
//     title: 'RWP',
//     theme: ThemeData(
//       primarySwatch: Colors.amber,
//       textTheme: Typography.englishLike2018.apply(fontSizeFactor: 1),
//     ),
//     home: const MyApp(),
//   ));
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
//   DarkThemeProvider themeChangeProvider = DarkThemeProvider();

//   @override
//   void initState() {
//     getCurrentAppTheme();
//     WidgetsBinding.instance.addObserver(this);
//     // WidgetsBinding.instance.addPostFrameCallback((_) {});
//     super.initState();
    
//   }




//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     getCurrentAppTheme();
//   }

//   void getCurrentAppTheme() async {
//     themeChangeProvider.darkTheme =
//         await themeChangeProvider.darkThemePreference.getTheme();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//       create: (_) {
//         return themeChangeProvider;
//       },
//       child: Consumer<DarkThemeProvider>(
//         builder: (context, value, child) {
//           return Listener(
//             onPointerUp: (_) {
//               FocusScopeNode currentFocus = FocusScope.of(context);
//               if (!currentFocus.hasPrimaryFocus &&
//                   currentFocus.focusedChild != null) {
//                 currentFocus.focusedChild!.unfocus();
//               }
//             },
//             child: GetMaterialApp(
//                 title: 'MyTaxi'.tr,
//                 debugShowCheckedModeBanner: false,
//                 theme: Styles.themeData(
//                     themeChangeProvider.darkTheme == 0
//                         ? true
//                         : themeChangeProvider.darkTheme == 1
//                             ? false
//                             : themeChangeProvider.getSystemThem(),
//                     context),
//                 localizationsDelegates: const [
//                   CountryLocalizations.delegate,
//                 ],
//                 locale: LocalizationService.locale,
//                 fallbackLocale: LocalizationService.locale,
//                 translations: LocalizationService(),
//                 builder: (context, child) {
//                   return SafeArea(
//                     bottom: true,
//                     top: false,
//                     child: EasyLoading.init()(context, child),
//                   );
//                 },
//                 initialRoute: AppPages.INITIAL,
//                 getPages: AppPages.routes,
//                 home: GetBuilder<GlobalSettingController>(
//                     init: GlobalSettingController(),
//                     builder: (context) {
//                       return const SplashScreenView();
//                     })),
//           );
//         },
//       ),
//     );
//   }
// }

// void configLoading() {
//   EasyLoading.instance
//     ..displayDuration = const Duration(milliseconds: 2000)
//     ..indicatorType = EasyLoadingIndicatorType.circle
//     ..loadingStyle = EasyLoadingStyle.custom
//     ..indicatorSize = 45.0
//     ..radius = 10.0
//     ..progressColor = const Color(0xFFFEA735)
//     ..backgroundColor = const Color(0xFFf5f6f6)
//     ..indicatorColor = const Color(0xFFFEA735)
//     ..textColor = const Color(0xFFFEA735)
//     ..maskColor = const Color(0xFFf5f6f6)
//     ..userInteractions = true
//     ..dismissOnTap = false;
// }
