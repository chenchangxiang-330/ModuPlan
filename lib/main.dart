import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/store.dart';
import 'ui/common.dart';
import 'ui/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: cover,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  try {
    runApp(DayBlocksApp(store: await LedgerStore.open()));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('本地数据库未能打开，请关闭 App 后重试。\n错误：$e')),
            ),
          ),
        ),
      ),
    );
  }
}

class DayBlocksApp extends StatelessWidget {
  final LedgerStore store;
  const DayBlocksApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '三段日程',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        surface: paper,
      ).copyWith(
        primary: green,
        onPrimary: paperSurface,
        onSurface: ink,
        outline: const Color(0xffa6a38e),
        outlineVariant: notebookLine,
        surfaceContainerHighest: const Color(0xffeeeadc),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ink, height: 1.5),
        bodyMedium: TextStyle(color: ink, height: 1.5),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: paperSurface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: notebookShape.copyWith(
          side: const BorderSide(color: notebookLine),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: paperSurface,
        surfaceTintColor: Colors.transparent,
        shape: notebookShape,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: notebookShape,
        clipBehavior: Clip.antiAlias,
        dragHandleColor: Color(0xffb4b09a),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: paperSurface,
        surfaceTintColor: Colors.transparent,
        shape: notebookShape,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: paperSurface,
        shape: notebookShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: notebookLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: notebookLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: notebookControlShape,
        side: BorderSide(color: notebookLine),
        backgroundColor: paperSurface,
        selectedColor: Color(0xffe6ead8),
        labelStyle: TextStyle(fontFamily: 'Roboto', color: green, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(color: notebookLine, thickness: .7),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: notebookControlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: notebookControlShape,
          side: const BorderSide(color: notebookLine),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: notebookControlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: notebookControlShape,
          foregroundColor: green,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: green,
        contentTextStyle: TextStyle(color: paperSurface),
        behavior: SnackBarBehavior.floating,
        shape: notebookControlShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cover,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xffe7e9d7),
        indicatorShape: notebookControlShape,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? ink : paper,
          size: 23,
        )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: paper,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        )),
      ),
    ),
    home: HomePage(store: store),
  );
}
