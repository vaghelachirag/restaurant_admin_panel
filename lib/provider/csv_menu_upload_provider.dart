import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category_model.dart';
import '../data/models/menu_item_model.dart';
import '../services/category_service.dart';
import '../services/csv_parsing_service.dart';
import '../services/menu_batch_service.dart';


final csvParsingServiceProvider = Provider<CsvParsingService>(
      (_) => CsvParsingService(),
);

final categoryServiceProvider = Provider<CategoryService>(
      (_) => CategoryService(),
);

final menuBatchServiceProvider = Provider<MenuBatchService>(
      (_) => MenuBatchService(),
);

enum UploadStep { idle, parsing, resolvingCategories, saving, done, error }

class CsvUploadState {
  final UploadStep step;
  final List<MenuItem> items;
  final Map<String, CategoryModel> categoryMap;
  final CsvParseResult? parseResult;
  final String? errorMessage;
  final int savedCount;
  final int totalToSave;

  const CsvUploadState({
    this.step = UploadStep.idle,
    this.items = const [],
    this.categoryMap = const {},
    this.parseResult,
    this.errorMessage,
    this.savedCount = 0,
    this.totalToSave = 0,
  });

  bool get isLoading =>
      step == UploadStep.parsing ||
          step == UploadStep.resolvingCategories ||
          step == UploadStep.saving;

  double get saveProgress =>
      totalToSave == 0 ? 0 : savedCount / totalToSave;

  int get validItemCount => items.where((i) => !i!.hasError).length;
  int get errorItemCount => items.where((i) => i.hasError).length;

  CsvUploadState copyWith({
    UploadStep? step,
    List<MenuItem>? items,
    Map<String, CategoryModel>? categoryMap,
    CsvParseResult? parseResult,
    String? errorMessage,
    int? savedCount,
    int? totalToSave,
  }) {
    return CsvUploadState(
      step: step ?? this.step,
      items: items ?? this.items,
      categoryMap: categoryMap ?? this.categoryMap,
      parseResult: parseResult ?? this.parseResult,
      errorMessage: errorMessage,
      savedCount: savedCount ?? this.savedCount,
      totalToSave: totalToSave ?? this.totalToSave,
    );
  }
}


class CsvUploadNotifier extends StateNotifier<CsvUploadState> {
  final CsvParsingService _csvService;
  final CategoryService _categoryService;
  final MenuBatchService _batchService;

  CsvUploadNotifier({
    required CsvParsingService csvService,
    required CategoryService categoryService,
    required MenuBatchService batchService,
  })  : _csvService = csvService,
        _categoryService = categoryService,
        _batchService = batchService,
        super(const CsvUploadState());



  Future<void> parseCsv(String content, String restaurantId) async {
    state = state.copyWith(step: UploadStep.parsing);

    try {
      // Parse CSV
      final result = _csvService.parse(content, restaurantId);

      if (result.items.isEmpty && result.hasErrors) {
        state = state.copyWith(
          step: UploadStep.error,
          errorMessage: result.errors.join('\n'),
        );
        return;
      }

      // Fetch categories once
      state = state.copyWith(step: UploadStep.resolvingCategories);
      final catMap = await _categoryService.fetchAll(restaurantId);

      state = state.copyWith(
        step: UploadStep.idle,
        items: result.items,
        categoryMap: catMap,
        parseResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        step: UploadStep.error,
        errorMessage: 'Parsing failed: ${e.toString()}',
      );
    }
  }

  // ── Step 2: Edit individual item ──────────────────────────

  void updateItem(int index, MenuItem updated) {
    final list = List<MenuItem>.from(state.items);
    list[index] = updated;
    state = state.copyWith(items: list);
  }

  void removeItem(int index) {
    final list = List<MenuItem>.from(state.items);
    list.removeAt(index);
    state = state.copyWith(items: list);
  }

  // ── Step 3: Save All ──────────────────────────────────────

  Future<void> saveAll(String restaurantId) async {
    state = state.copyWith(
      step: UploadStep.resolvingCategories,
      savedCount: 0,
    );

    try {
      // Resolve / auto-create categories
      final resolved = await _categoryService.resolveCategories(
        restaurantId: restaurantId,
        items: state.items,
        existingCategories: state.categoryMap,
      );

      final validCount = resolved.items.where((i) => !i.hasError).length;
      state = state.copyWith(
        items: resolved.items,
        categoryMap: resolved.categoryMap,
        step: UploadStep.saving,
        totalToSave: validCount,
      );

      // Batch insert
      await _batchService.saveItems(
        restaurantId: restaurantId,
        items: resolved.items,
        onProgress: (saved, total) {
          state = state.copyWith(savedCount: saved, totalToSave: total);
        },
      );

      state = state.copyWith(
        step: UploadStep.done,
        savedCount: validCount,
      );
    } catch (e) {
      state = state.copyWith(
        step: UploadStep.error,
        errorMessage: 'Save failed: ${e.toString()}',
      );
    }
  }

  void reset() {
    state = const CsvUploadState();
  }
}

// ─────────────────────────────────────────────
//  Family Provider (per-restaurantId)
// ─────────────────────────────────────────────

final csvUploadProvider = StateNotifierProvider.family<
    CsvUploadNotifier, CsvUploadState, String>(
      (ref, restaurantId) => CsvUploadNotifier(
    csvService: ref.read(csvParsingServiceProvider),
    categoryService: ref.read(categoryServiceProvider),
    batchService: ref.read(menuBatchServiceProvider),
  ),
);