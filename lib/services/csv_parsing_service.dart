import 'package:csv/csv.dart';
import '../data/models/menu_item_model.dart';

/// Result returned after parsing a CSV file.
class CsvParseResult {
  final List<MenuItem> items;
  final List<String> errors;
  final int totalRows;
  final CsvFormat detectedFormat;

  const CsvParseResult({
    required this.items,
    required this.errors,
    required this.totalRows,
    required this.detectedFormat,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get validCount => items.where((i) => !i.hasError).length;
  int get errorCount => items.where((i) => i.hasError).length;
}

enum CsvFormat { simple, advanced, unknown }

class CsvParsingService {
  // ──────────────────────────────────────────────────────────
  //  Public Entry Point
  // ──────────────────────────────────────────────────────────

  CsvParseResult parse(String content, String restaurantId) {
    final normalised = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalised.trim().isEmpty) {
      return CsvParseResult(
        items: [],
        errors: ['File is empty.'],
        totalRows: 0,
        detectedFormat: CsvFormat.unknown,
      );
    }

    // ── Parse CSV manually — works with ALL csv package versions ────────────
    final List<List<dynamic>> rows = _parseCsv(normalised);

    if (rows.isEmpty || rows.first.isEmpty) {
      return CsvParseResult(
        items: [],
        errors: ['CSV has no header row.'],
        totalRows: 0,
        detectedFormat: CsvFormat.unknown,
      );
    }

    // Normalise header — also map "variant" → "variant_name" for OCR CSV
    final headers = rows.first
        .map((h) => h.toString().trim().toLowerCase().replaceAll(' ', '_'))
        .map((h) => h == 'variant' ? 'variant_name' : h)
        .toList();

    final format = _detectFormat(headers);
    if (format == CsvFormat.unknown) {
      return CsvParseResult(
        items: [],
        errors: [
          'Unrecognised CSV format. Expected columns: '
              '"name, price, category" (simple) or '
              '"name, category, variant_name, price" (advanced).'
        ],
        totalRows: rows.length - 1,
        detectedFormat: CsvFormat.unknown,
      );
    }

    final dataRows = rows.skip(1).toList();
    final List<String> globalErrors = [];

    final List<MenuItem> items = format == CsvFormat.simple
        ? _parseSimple(headers, dataRows, restaurantId, globalErrors)
        : _parseAdvanced(headers, dataRows, restaurantId, globalErrors);

    return CsvParseResult(
      items: items,
      errors: globalErrors,
      totalRows: dataRows.length,
      detectedFormat: format,
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Manual CSV parser — no dependency on CsvToListConverter
  //  Handles quoted fields, commas inside quotes, escaped quotes
  // ──────────────────────────────────────────────────────────

  List<List<dynamic>> _parseCsv(String content) {
    final rows = <List<dynamic>>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) continue;
      rows.add(_splitCsvLine(trimmed));
    }

    return rows;
  }

  List<dynamic> _splitCsvLine(String line) {
    final fields = <String>[];
    final buf    = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote inside quoted field
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }

    fields.add(buf.toString().trim());
    return fields;
  }

  // ──────────────────────────────────────────────────────────
  //  Format Detection
  // ──────────────────────────────────────────────────────────

  CsvFormat _detectFormat(List<String> headers) {
    final hasVariantName = headers.contains('variant_name');
    final hasName        = headers.contains('name');
    final hasPrice       = headers.contains('price');
    final hasCategory    = headers.contains('category');

    if (hasName && hasPrice && hasCategory && !hasVariantName) {
      return CsvFormat.simple;
    }
    if (hasName && hasCategory && hasVariantName && hasPrice) {
      return CsvFormat.advanced;
    }
    return CsvFormat.unknown;
  }

  // ──────────────────────────────────────────────────────────
  //  Simple CSV Parser  (name, price, category)
  // ──────────────────────────────────────────────────────────

  List<MenuItem> _parseSimple(
      List<String> headers,
      List<List<dynamic>> rows,
      String restaurantId,
      List<String> globalErrors,
      ) {
    final nameIdx  = headers.indexOf('name');
    final priceIdx = headers.indexOf('price');
    final catIdx   = headers.indexOf('category');

    final List<MenuItem> items = [];

    for (int i = 0; i < rows.length; i++) {
      final row     = rows[i];
      final lineNum = i + 2;

      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      final name     = _cell(row, nameIdx);
      final category = _cell(row, catIdx);
      final priceRaw = _cell(row, priceIdx);

      String? error;
      double price = 0;

      if (name.isEmpty) {
        error = 'Row $lineNum: Item name is missing.';
      } else if (category.isEmpty) {
        error = 'Row $lineNum: Category is missing for "$name".';
      } else {
        price = double.tryParse(priceRaw) ?? -1;
        if (price < 0) {
          error = 'Row $lineNum: Invalid price "$priceRaw" for "$name".';
        }
      }

      items.add(MenuItem(
        name: name.isEmpty ? 'Unnamed Item (Row $lineNum)' : name,
        categoryId: '',
        categoryName: category,
        restaurantId: restaurantId,
        variants: error == null
            ? [MenuVariant(name: 'Regular', price: price)]
            : [],
        hasError: error != null,
        errorMessage: error,
      ));
    }

    return items;
  }

  // ──────────────────────────────────────────────────────────
  //  Advanced CSV Parser
  //  Handles variant_name (manual) and variant (OCR)
  //  Both normalised to "variant_name" in the header step above
  // ──────────────────────────────────────────────────────────

  List<MenuItem> _parseAdvanced(
      List<String> headers,
      List<List<dynamic>> rows,
      String restaurantId,
      List<String> globalErrors,
      ) {
    final nameIdx    = headers.indexOf('name');
    final catIdx     = headers.indexOf('category');
    final variantIdx = headers.indexOf('variant_name');
    final priceIdx   = headers.indexOf('price');

    final Map<String, _AdvancedGroup> groups = {};

    for (int i = 0; i < rows.length; i++) {
      final row     = rows[i];
      final lineNum = i + 2;

      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      final name        = _cell(row, nameIdx);
      final category    = _cell(row, catIdx);
      final variantName = _cell(row, variantIdx);
      final priceRaw    = _cell(row, priceIdx);

      if (name.isEmpty) {
        globalErrors.add('Row $lineNum: Skipped — item name is missing.');
        continue;
      }

      final group = groups.putIfAbsent(
        name,
            () => _AdvancedGroup(name: name, category: category),
      );

      if (variantName.isEmpty) {
        group.errors.add('Row $lineNum: Variant name is missing for "$name".');
        continue;
      }

      final price = double.tryParse(priceRaw) ?? -1;
      if (price < 0) {
        group.errors.add(
            'Row $lineNum: Invalid price "$priceRaw" for "$name / $variantName".');
        continue;
      }

      group.variants.add(MenuVariant(name: variantName, price: price));
    }

    return groups.values.map((g) {
      final hasError = g.errors.isNotEmpty || g.variants.isEmpty;
      return MenuItem(
        name: g.name,
        categoryId: '',
        categoryName: g.category,
        restaurantId: restaurantId,
        variants: g.variants,
        hasError: hasError,
        errorMessage: hasError ? g.errors.join(' | ') : null,
      );
    }).toList();
  }

  String _cell(List<dynamic> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx].toString().trim();
  }

  // ──────────────────────────────────────────────────────────
  //  Sample CSV generators
  // ──────────────────────────────────────────────────────────

  String generateSimpleSampleCsv() =>
      'name,price,category\n'
          'Vanilla Ice Cream,40,Ice Cream\n'
          'Chocolate Ice Cream,50,Ice Cream\n'
          'Margherita Pizza,199,Pizza\n'
          'Pepperoni Pizza,249,Pizza\n';

  String generateAdvancedSampleCsv() =>
      'name,category,variant_name,price\n'
          'Vanilla Ice Cream,Ice Cream,Regular,40\n'
          'Vanilla Ice Cream,Ice Cream,Large,70\n'
          'Margherita Pizza,Pizza,Small,149\n'
          'Margherita Pizza,Pizza,Medium,199\n'
          'Margherita Pizza,Pizza,Large,299\n';
}

// Internal grouping helper
class _AdvancedGroup {
  final String name;
  final String category;
  final List<MenuVariant> variants = [];
  final List<String> errors = [];

  _AdvancedGroup({required this.name, required this.category});
}