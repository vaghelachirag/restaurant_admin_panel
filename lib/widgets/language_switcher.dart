import 'package:flutter/material.dart';
import 'package:restaurant_admin_panel/services/localization_service.dart';

class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({super.key});

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  final LocalizationService _localizationService = LocalizationService();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language,
            size: 20,
            color: Theme.of(context).iconTheme.color,
          ),
          const SizedBox(width: 4),
          Text(
            LocalizationService.languageNames[_localizationService.currentLanguageCode] ?? 'English',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: Theme.of(context).iconTheme.color,
          ),
        ],
      ),
      onSelected: (String languageCode) {
        _localizationService.changeLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) {
        return LocalizationService.supportedLocales.map((locale) {
          final languageCode = locale.languageCode;
          final isSelected = languageCode == _localizationService.currentLanguageCode;
          
          return PopupMenuItem<String>(
            value: languageCode,
            child: Row(
              children: [
                Text(
                  LocalizationService.languageNames[languageCode] ?? languageCode,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(
                    Icons.check,
                    color: Theme.of(context).primaryColor,
                    size: 16,
                  ),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: localizationService.currentLanguageCode,
        underline: const SizedBox(),
        isDense: true,
        items: LocalizationService.supportedLocales.map((locale) {
          final languageCode = locale.languageCode;
          return DropdownMenuItem<String>(
            value: languageCode,
            child: Text(
              LocalizationService.languageNames[languageCode] ?? languageCode,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (String? newLanguage) {
          if (newLanguage != null) {
            localizationService.changeLanguage(newLanguage);
          }
        },
      ),
    );
  }
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService = LocalizationService();
    
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => LanguageDialog(
            currentLanguage: localizationService.currentLanguageCode,
            onLanguageSelected: (languageCode) {
              localizationService.changeLanguage(languageCode);
              Navigator.of(context).pop();
            },
          ),
        );
      },
      icon: const Icon(Icons.language),
      label: Text(
        LocalizationService.languageNames[localizationService.currentLanguageCode] ?? 'English',
      ),
    );
  }
}

class LanguageDialog extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageSelected;

  const LanguageDialog({
    super.key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).languageSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: LocalizationService.supportedLocales.map((locale) {
          final languageCode = locale.languageCode;
          final isSelected = languageCode == currentLanguage;
          
          return RadioListTile<String>(
            title: Text(
              LocalizationService.languageNames[languageCode] ?? languageCode,
            ),
            value: languageCode,
            groupValue: currentLanguage,
            onChanged: (value) {
              if (value != null) {
                onLanguageSelected(value);
              }
            },
            activeColor: Theme.of(context).primaryColor,
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).commonCancel),
        ),
      ],
    );
  }
}
