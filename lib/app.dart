import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/app_storage_service.dart';
import 'core/services/face_detection_service.dart';
import 'core/services/mlkit_face_detection_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/viewmodels/auth_view_model.dart';
import 'features/home/screens/home_screen.dart';
import 'features/shared/widgets/phone_frame_wrapper.dart';
import 'features/study/viewmodels/study_view_model.dart';
import 'features/wallet/viewmodels/wallet_view_model.dart';

class StudyEarnApp extends StatefulWidget {
  const StudyEarnApp({super.key, required this.storage});

  final AppStorageService storage;

  @override
  State<StudyEarnApp> createState() => _StudyEarnAppState();
}

class _StudyEarnAppState extends State<StudyEarnApp> {
  late final FaceDetectionService _faceDetectionService;

  @override
  void initState() {
    super.initState();
    _faceDetectionService = MlKitFaceDetectionService();
  }

  @override
  void dispose() {
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStorageService storage = widget.storage;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(storage)..loadProfile(),
        ),
        ChangeNotifierProvider<WalletViewModel>(
          create: (_) => WalletViewModel(storage)..loadWallet(),
        ),
        Provider<FaceDetectionService>.value(value: _faceDetectionService),
        ChangeNotifierProxyProvider<FaceDetectionService, StudyViewModel>(
          create: (context) => StudyViewModel(
            faceDetectionService: context.read<FaceDetectionService>(),
          ),
          update: (context, service, previous) => previous ?? StudyViewModel(
            faceDetectionService: service,
          ),
        ),
      ],
      child: PhoneFrameWrapper(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'StudyEarn',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: const AppGate(),
        ),
      ),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        if (authViewModel.isLoading) {
          return const _SplashScreen();
        }

        if (!authViewModel.isLoggedIn) {
          return const LoginScreen();
        }

        return const HomeScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.primaryContainer.withValues(alpha: 0.9),
              colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading StudyEarn',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}