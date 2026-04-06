import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'en';

  Locale _currentLocale = const Locale(_defaultLanguage);
  Map<String, dynamic> _translations = {};

  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal() {
    // Initialize with default language immediately
    _loadTranslations(_defaultLanguage);
  }

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;

  static List<Locale> get supportedLocales => const [
    Locale('en'),
    Locale('hi'),
    Locale('gu'),
  ];

  static Map<String, String> get languageNames => {
    'en': 'English',
    'hi': 'हिंदी',
    'gu': 'ગુજરાતી',
  };

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey) ?? _defaultLanguage;

      _loadTranslations(savedLanguage);
      _currentLocale = Locale(savedLanguage);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language: $e');
      _loadTranslations(_defaultLanguage);
      _currentLocale = const Locale(_defaultLanguage);
      notifyListeners();
    }
  }

  void _loadTranslations(String languageCode) {
    try {
      _translations = _getStaticTranslations(languageCode);
      debugPrint('Loaded translations for $languageCode: ${_translations.keys}');
    } catch (e) {
      debugPrint('Error loading translations for $languageCode: $e');
      _translations = {};
    }
  }

  Future<void> _loadTranslationsAsync(String languageCode) async {
    _loadTranslations(languageCode);
  }

  Map<String, dynamic> _getStaticTranslations(String languageCode) {
    switch (languageCode) {
      case 'en':
        return {
          "app_name": "Restaurant Admin Panel",
          "dashboard": {
            "title": "Dashboard",
            "total_orders": "Total Orders",
            "total_revenue": "Total Revenue",
            "pending_orders": "Pending Orders",
            "completed_orders": "Completed Orders",
            "today": "Today",
            "this_week": "This Week",
            "this_month": "This Month",
            "new_order": "New Order",
            "received": "Received",
            "qr_saved": "QR saved!",
            "error": "Error",
            "copy_link": "Copy Link",
            "copied": "Copied!",
            "download_qr": "Download QR",
            "sign_out_question": "Sign Out?",
            "sign_out_description": "You'll need to sign in again to access the panel.",
            "cancel": "Cancel",
            "sign_out": "Sign Out",
            "logout_error": "Logout error",
            "restaurant": "Restaurant",
            "admin_panel": "Admin Panel",
            "logout": "Logout",
            "categories": "Categories",
            "menu_items": "Menu Items",
            "orders": "Orders",
            "from_yesterday": "from yesterday",
            "sales_details": "Sales Details"
          },
          "login": {
            "title": "Login",
            "email": "Email",
            "password": "Password",
            "login_button": "Login",
            "forgot_password": "Forgot Password?",
            "dont_have_account": "Don't have an account?",
            "sign_up": "Sign Up"
          },
          "categories": {"title": "Categories"},
          "menu_items": {"title": "Menu Items"},
          "customer_menu": {"title": "Customer Menu"},
          "menu_link": {"title": "Menu Link"},
          "managers": {"title": "Managers"},
          "category": {
            "add_category": "Add Category",
            "edit_category": "Edit Category",
            "delete_category": "Delete Category",
            "category_name": "Category name",
            "position": "Position",
            "save_category": "Save Category",
            "update_category": "Update Category",
            "upload_image": "Upload Image",
            "no_categories_yet": "No categories yet",
            "items": "items",
            "category_added_success": "Category added successfully!",
            "category_updated_success": "Category updated successfully!",
            "error_adding_category": "Error adding category",
            "error_updating_category": "Error updating category",
            "please_enter_category_name": "Please enter a category name",
            "please_fill_all_required_fields": "Please fill all required fields",
            "adding_category": "Adding category, please wait...",
            "updating_category": "Updating category, please wait...",
            "are_you_sure_delete": "Are you sure you want to delete",
            "this_action_cannot_be_undone": "This action cannot be undone.",
            "enter_position": "Enter position (0 for first)",
            "enter_category_name": "Enter category name",
            "create_new_section": "Create a new section for your menu.",
            "update_name_of_section": "Update name of this menu section.",
            "remove_this_section": "Remove this section from your menu.",
            "category_placeholder": "e.g. Starters, Desserts"
          },
          "menu": {
            "add_menu_item": "Add Menu Item",
            "edit_menu_item": "Edit Menu Item",
            "delete_menu_item": "Delete Menu Item",
            "menu_items": "Menu Items",
            "item_image": "Item Image",
            "item_description": "Description",
            "item_name": "Item Name",
            "food_type": "Food Type",
            "variants": "Variants",
            "variant_name": "Variant Name",
            "price": "Price",
            "add_another_variant": "Add Another Variant",
            "save_menu_item": "Save Menu Item",
            "update_menu_item": "Update Menu Item",
            "menu_item_added_success": "Menu item added successfully!",
            "menu_item_updated_success": "Menu item updated successfully!",
            "menu_item_deleted_success": "Menu item deleted successfully",
            "error_adding_menu_item": "Error adding menu item",
            "error_updating_menu_item": "Error updating menu item",
            "error_deleting_menu_item": "Error deleting menu item",
            "please_enter_item_name": "Please enter item name",
            "upload_dish_image": "Upload dish image. This image is shown in customer menu.",
            "upload_or_change_dish_image": "Upload or change dish image. This image is shown in customer menu.",
            "dish_image_description": "Upload dish image. This image is shown in customer menu.",
            "change_image": "Change Image",
            "veg": "Veg",
            "non_veg": "Non-Veg",
            "no_menu_items": "No menu items",
            "no_results_for_search": "No results for your search",
            "search_menu_items": "Search menu items...",
            "failed_to_load_menu": "Failed to load menu",
            "are_you_sure_delete_menu_item": "Are you sure you want to delete this menu item?",
            "update_details_of_menu_item": "Update the details of this menu item.",
            "create_new_dish": "Create a new dish for your menu.",
            "enter_item_name": "Enter item name",
            "enter_item_description": "Enter item description (optional)",
            "select_category": "Select Category",
            "adding_menu_item": "Adding...",
            "updating_menu_item": "Updating..."
          },
          "orders": {
            "title": "Orders",
            "today_orders": "Today — {count} orders",
            "no_orders": "No {filter} orders",
            "all": "All",
            "pending": "Pending",
            "preparing": "Preparing", 
            "ready": "Ready",
            "served": "Served",
            "completed": "Completed",
            "table": "Table",
            "dine_in": "Dine In",
            "takeaway": "Takeaway",
            "guest": "Guest",
            "more_items": "+{count} more item{plural}",
            "mark_as_preparing": "Mark as Preparing",
            "mark_as_ready": "Mark as Ready", 
            "mark_as_served": "Mark as Served",
            "mark_as_completed": "Mark as Completed",
            "showing_results": "Showing {start}–{end} of {total}",
            "logout": "Logout",
            "logout_confirmation": "Are you sure you want to logout?"
          },
          "settings": {
            "title": "Settings",
            "restaurant_settings": "Restaurant Settings",
            "manage_restaurant_info": "Manage your restaurant information",
            "restaurant_logo": "Restaurant Logo",
            "upload_logo": "Upload Restaurant Logo",
            "update_logo": "Update Restaurant Logo",
            "change_logo": "Change Logo",
            "remove_logo": "Remove",
            "logo_description": "This logo appears on bills and the customer menu. Use a square image for best results (PNG or JPG, max 512×512px).",
            "logo_pending_upload": "New logo will be saved when you tap Save",
            "no_logo": "No Logo",
            "restaurant_information": "Restaurant Information",
            "restaurant_name": "Restaurant Name",
            "address": "Address",
            "contact_number": "Contact Number",
            "whatsapp_number": "WhatsApp Number",
            "gst_number": "GST Number",
            "operating_hours": "Operating Hours",
            "opening_time": "Opening Time",
            "closing_time": "Closing Time",
            "billing_settings": "Billing Settings",
            "enable_gst": "Enable GST",
            "enable_gst_description": "Apply GST on all orders.",
            "enable_packaging_charge": "Enable Packaging Charge",
            "enable_packaging_charge_description": "Add packaging charge for parcel orders.",
            "gst_percentage": "GST %",
            "cess_percentage": "Cess %",
            "packaging_charge": "Packaging Charge",
            "language_settings": "Language Settings",
            "app_language": "App Language",
            "language_description": "Choose your preferred language for the admin panel. This will change the language across all screens.",
            "language_changed": "Language changed to {language}",
            "language_preference_saved": "Language preference will be saved and applied automatically when you restart the app.",
            "additional_notes": "Additional Notes",
            "add_note": "Add Note",
            "save_settings": "Save Settings",
            "settings_saved_success": "Restaurant information saved successfully!",
            "error_saving_settings": "Error: {error}"
          },
          "managers": {
            "title": "Managers",
            "manage_managers": "Manage your restaurant managers",
            "add_manager": "Add Manager",
            "edit_manager": "Edit Manager",
            "manager_name": "Manager Name",
            "email_address": "Email Address",
            "password": "Password",
            "new_password_optional": "New Password (leave blank to keep)",
            "status": "Status",
            "active": "Active",
            "inactive": "Inactive",
            "cancel": "Cancel",
            "save_changes": "Save Changes",
            "enter_full_name": "Enter full name",
            "enter_email_address": "Enter email address",
            "enter_password": "Enter password",
            "enter_new_password_optional": "Enter new password (optional)",
            "name_required": "Name is required",
            "email_required": "Email is required",
            "enter_valid_email": "Enter a valid email",
            "password_required": "Password is required",
            "password_min_length": "Password must be at least 6 characters",
            "manager_added_success": "Manager added successfully!",
            "manager_updated": "Manager updated!",
            "password_reset_email_sent": "Password reset email sent to manager.",
            "manager_activated": "Manager activated.",
            "manager_deactivated": "Manager deactivated.",
            "delete_manager": "Delete Manager?",
            "delete_manager_confirmation": "Are you sure you want to delete \"{name}\"? This action cannot be undone.",
            "manager_deleted": "Manager deleted.",
            "email_already_registered": "This email is already registered.",
            "invalid_email_address": "Invalid email address.",
            "password_weak": "Password must be at least 6 characters.",
            "error_occurred": "An error occurred.",
            "no_managers_yet": "No Managers Yet",
            "tap_add_manager_to_start": "Tap Add Manager to get started.",
            "error_loading_managers": "Error loading managers",
            "managers_total": "{count} manager{plural}s} total",
            "deactivate": "Deactivate",
            "activate": "Activate",
            "edit": "Edit",
            "delete": "Delete"
          },
          "common": {
            "and": "and",
            "yes": "Yes",
            "no": "No",
            "ok": "OK",
            "cancel": "Cancel",
            "save": "Save",
            "delete": "Delete",
            "edit": "Edit",
            "add": "Add",
            "search": "Search",
            "filter": "Filter",
            "loading": "Loading...",
            "error": "Error",
            "success": "Success",
            "warning": "Warning",
            "info": "Information"
          }
        };
      case 'hi':
        return {
          "app_name": "रेस्टोरेंट एडमिन पैनल",
          "dashboard": {
            "title": "डैशबोर्ड",
            "total_orders": "कुल ऑर्डर",
            "total_revenue": "कुल राजस्व",
            "pending_orders": "लंबित ऑर्डर",
            "completed_orders": "पूर्ण ऑर्डर",
            "today": "आज",
            "this_week": "इस सप्ताह",
            "this_month": "इस महीने",
            "new_order": "नया ऑर्डर",
            "received": "प्राप्त",
            "qr_saved": "QR सेव हो गया!",
            "error": "त्रुटि",
            "copy_link": "लिंक कॉपी करें",
            "copied": "कॉपी हो गया!",
            "download_qr": "QR डाउनलोड करें",
            "sign_out_question": "साइन आउट करें?",
            "sign_out_description": "पैनल एक्सेस करने के लिए आपको फिर से लॉगिन करना होगा।",
            "cancel": "रद्द करें",
            "sign_out": "साइन आउट",
            "logout_error": "लॉगआउट त्रुटि",
            "restaurant": "रेस्टोरेंट",
            "admin_panel": "एडमिन पैनल",
            "logout": "लॉगआउट",
            "categories": "श्रेणियां",
            "menu_items": "मेनू आइटम",
            "orders": "ऑर्डर",
            "from_yesterday": "कल से",
            "sales_details": "बिक्री विवरण"
          },
          "login": {
            "title": "लॉगिन",
            "email": "ईमेल",
            "password": "पासवर्ड",
            "login_button": "लॉगिन करें",
            "forgot_password": "पासवर्ड भूल गए?",
            "dont_have_account": "खाता नहीं है?",
            "sign_up": "साइन अप करें"
          },
          "categories": {"title": "श्रेणियां"},
          "menu_items": {"title": "मेनू आइटम"},
          "customer_menu": {"title": "ग्राहक मेनू"},
          "menu_link": {"title": "मेनू लिंक"},
          "managers": {"title": "प्रबंधक"},
          "category": {
            "add_category": "श्रेणी जोड़ें",
            "edit_category": "श्रेणी संपादित करें",
            "delete_category": "श्रेणी हटाएं",
            "category_name": "श्रेणी का नाम",
            "position": "स्थिति",
            "save_category": "श्रेणी सेव करें",
            "update_category": "श्रेणी अपडेट करें",
            "upload_image": "छवि अपलोड करें",
            "no_categories_yet": "अभी तक कोई श्रेणी नहीं",
            "items": "आइटम",
            "category_added_success": "श्रेणी सफलतापूर्वक जोड़ी गई!",
            "category_updated_success": "श्रेणी सफलतापूर्वक अपडेट की गई!",
            "error_adding_category": "श्रेणी जोड़ने में त्रुटि",
            "error_updating_category": "श्रेणी अपडेट करने में त्रुटि",
            "please_enter_category_name": "कृपया श्रेणी का नाम दर्ज करें",
            "please_fill_all_required_fields": "कृपया सभी आवश्यक फ़ील्ड भरें",
            "adding_category": "श्रेणी जोड़ी जा रही है, कृपया प्रतीक्षा करें...",
            "updating_category": "श्रेणी अपडेट की जा रही है, कृपया प्रतीक्षा करें...",
            "are_you_sure_delete": "क्या आप वाकई हटाना चाहते हैं",
            "this_action_cannot_be_undone": "यह क्रिया पूर्ववत नहीं की जा सकती।",
            "enter_position": "स्थिति दर्ज करें (0 पहले के लिए)",
            "enter_category_name": "श्रेणी का नाम दर्ज करें",
            "create_new_section": "अपने मेनू के लिए एक नया अनुभाग बनाएं।",
            "update_name_of_section": "इस मेनू अनुभाग का नाम अपडेट करें।",
            "remove_this_section": "अपने मेनू से इस अनुभाग को हटाएं।",
            "category_placeholder": "उदा. स्टार्टर्स, डेसर्ट"
          },
          "menu": {
            "add_menu_item": "मेनू आइटम जोड़ें",
            "edit_menu_item": "मेनू आइटम संपादित करें",
            "delete_menu_item": "मेनू आइटम हटाएं",
            "menu_items": "मेनू आइटम",
            "item_image": "आइटम छवि",
            "item_description": "विवरण",
            "item_name": "आइटम का नाम",
            "food_type": "भोजन प्रकार",
            "variants": "वेरिएंट",
            "variant_name": "वेरिएंट का नाम",
            "price": "मूल्य",
            "add_another_variant": "दूसरा वेरिएंट जोड़ें",
            "save_menu_item": "मेनू आइटम सेव करें",
            "update_menu_item": "मेनू आइटम अपडेट करें",
            "menu_item_added_success": "मेनू आइटम सफलतापूर्वक जोड़ा गया!",
            "menu_item_updated_success": "मेनू आइटम सफलतापूर्वक अपडेट हुआ!",
            "menu_item_deleted_success": "मेनू आइटम सफलतापूर्वक हटा दिया गया",
            "error_adding_menu_item": "मेनू आइटम जोड़ने में त्रुटि",
            "error_updating_menu_item": "मेनू आइटम अपडेट करने में त्रुटि",
            "error_deleting_menu_item": "मेनू आइटम हटाने में त्रुटि",
            "please_enter_item_name": "कृपया आइटम का नाम दर्ज करें",
            "upload_dish_image": "डिश छवि अपलोड करें। यह छवि ग्राहक मेनू में दिखाई जाती है।",
            "upload_or_change_dish_image": "डिश छवि अपलोड या बदलें। यह छवि ग्राहक मेनू में दिखाई जाती है।",
            "dish_image_description": "डिश छवि अपलोड करें। यह छवि ग्राहक मेनू में दिखाई जाती है।",
            "change_image": "छवि बदलें",
            "veg": "शाकाहारी",
            "non_veg": "नॉन-वेज",
            "no_menu_items": "कोई मेनू आइटम नहीं",
            "no_results_for_search": "आपकी खोज के लिए कोई परिणाम नहीं",
            "search_menu_items": "मेनू आइटम खोजें...",
            "failed_to_load_menu": "मेनू लोड करने में विफल",
            "are_you_sure_delete_menu_item": "क्या आप वाकई इस मेनू आइटम को हटाना चाहते हैं?",
            "update_details_of_menu_item": "इस मेनू आइटम का विवरण अपडेट करें।",
            "create_new_dish": "अपने मेनू के लिए एक नई डिश बनाएं।",
            "enter_item_name": "आइटम का नाम दर्ज करें",
            "enter_item_description": "आइटम विवरण दर्ज करें (वैकल्पिक)",
            "select_category": "श्रेणी चुनें",
            "adding_menu_item": "जोड़ा जा रहा है...",
            "updating_menu_item": "अपडेट हो रहा है..."
          },
          "orders": {
            "title": "ऑर्डर",
            "today_orders": "आज — {count} ऑर्डर",
            "no_orders": "कोई {filter} ऑर्डर नहीं",
            "all": "सभी",
            "pending": "लंबित",
            "preparing": "तैयार हो रहा है",
            "ready": "तैयार",
            "served": "परोसा गया",
            "completed": "पूर्ण",
            "table": "टेबल",
            "dine_in": "डाइन इन",
            "takeaway": "टेकअवे",
            "guest": "अतिथि",
            "more_items": "+{count} और आइटम{plural}",
            "mark_as_preparing": "तैयार करने के लिए मार्क करें",
            "mark_as_ready": "तैयार के लिए मार्क करें",
            "mark_as_served": "परोसने के लिए मार्क करें",
            "mark_as_completed": "पूर्ण के लिए मार्क करें",
            "showing_results": "{start}–{end} का {total} में दिखा रहे हैं",
            "logout": "लॉगआउट",
            "logout_confirmation": "क्या आप लॉगआउट करना चाहते हैं?"
          },
          "settings": {
            "title": "सेटिंग्स",
            "restaurant_settings": "रेस्टोरेंट सेटिंग्स",
            "manage_restaurant_info": "अपनी रेस्टोरेंट जानकारी प्रबंधित करें",
            "restaurant_logo": "रेस्टोरेंट लोगो",
            "upload_logo": "रेस्टोरेंट लोगो अपलोड करें",
            "update_logo": "रेस्टोरेंट लोगो अपडेट करें",
            "change_logo": "लोगो बदलें",
            "remove_logo": "हटाएं",
            "logo_description": "यह लोगो बिल और ग्राहक मेनू पर दिखाई देता है। सर्वोत्तम परिणामों के लिए एक वर्ग छवि का उपयोग करें (PNG या JPG, अधिकतम 512×512px)।",
            "logo_pending_upload": "जब आप सेव करेंगे तब नया लोगो सेव हो जाएगा",
            "no_logo": "कोई लोगो नहीं",
            "restaurant_information": "रेस्टोरेंट जानकारी",
            "restaurant_name": "रेस्टोरेंट का नाम",
            "address": "पता",
            "contact_number": "संपर्क नंबर",
            "whatsapp_number": "व्हाट्सएप नंबर",
            "gst_number": "GST नंबर",
            "operating_hours": "संचालन के समय",
            "opening_time": "खुलने का समय",
            "closing_time": "बंद होने का समय",
            "billing_settings": "बिलिंग सेटिंग्स",
            "enable_gst": "GST सक्षम करें",
            "enable_gst_description": "सभी ऑर्डर पर GST लागू करें।",
            "enable_packaging_charge": "पैकेजिंग शुल्क सक्षम करें",
            "enable_packaging_charge_description": "पार्सल ऑर्डर के लिए पैकेजिंग शुल्क जोड़ें।",
            "gst_percentage": "GST %",
            "cess_percentage": "Cess %",
            "packaging_charge": "पैकेजिंग शुल्क",
            "language_settings": "भाषा सेटिंग्स",
            "app_language": "ऐप भाषा",
            "language_description": "एडमिन पैनल के लिए अपनी पसंदीदा भाषा चुनें। यह सभी स्क्रीन पर भाषा बदल देगा।",
            "language_changed": "भाषा {language} में बदली गई",
            "language_preference_saved": "भाषा प्राथमिकता सेव हो जाएगी और ऐप को पुनः प्रारंभ करने पर स्वचालित रूप से लागू हो जाएगी।",
            "additional_notes": "अतिरिक्त नोट्स",
            "add_note": "नोट जोड़ें",
            "save_settings": "सेटिंग्स सेव करें",
            "settings_saved_success": "रेस्टोरेंट जानकारी सफलतापूर्वक सेव हो गई!",
            "error_saving_settings": "त्रुटि: {error}"
          },
          "managers": {
            "title": "मैनेजर्स",
            "manage_managers": "अपने रेस्टोरेंट मैनेजर्स प्रबंधित करें",
            "add_manager": "मैनेजर जोड़ें",
            "edit_manager": "मैनेजर संपादित करें",
            "manager_name": "मैनेजर का नाम",
            "email_address": "ईमेल पता",
            "password": "पासवर्ड",
            "new_password_optional": "नया पासवर्ड (रखने के लिए खाली छोड़ें)",
            "status": "स्थिति",
            "active": "सक्रिय",
            "inactive": "निष्क्रिय",
            "cancel": "रद्द करें",
            "save_changes": "परिवर्तन सेव करें",
            "enter_full_name": "पूरा नाम दर्ज करें",
            "enter_email_address": "ईमेल पता दर्ज करें",
            "enter_password": "पासवर्ड दर्ज करें",
            "enter_new_password_optional": "नया पासवर्ड दर्ज करें (वैकल्पिक)",
            "name_required": "नाम आवश्यक है",
            "email_required": "ईमेल आवश्यक है",
            "enter_valid_email": "वैध ईमेल दर्ज करें",
            "password_required": "पासवर्ड आवश्यक है",
            "password_min_length": "पासवर्ड कम से कम 6 अक्षरों का होना चाहिए",
            "manager_added_success": "मैनेजर सफलतापूर्वक जोड़ा गया!",
            "manager_updated": "मैनेजर अपडेट किया गया!",
            "password_reset_email_sent": "मैनेजर को पासवर्ड रीसेट ईमेल भेजी गई।",
            "manager_activated": "मैनेजर सक्रिय कर दिया गया।",
            "manager_deactivated": "मैनेजर निष्क्रिय कर दिया गया।",
            "delete_manager": "मैनेजर हटाएं?",
            "delete_manager_confirmation": "क्या आप वाकई \"{name}\" को हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।",
            "manager_deleted": "मैनेजर हटा दिया गया।",
            "email_already_registered": "यह ईमेल पहले से पंजीकृत है।",
            "invalid_email_address": "अवैध ईमेल पता।",
            "password_weak": "पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।",
            "error_occurred": "एक त्रुटि हुई।",
            "no_managers_yet": "अभी तक कोई मैनेजर नहीं",
            "tap_add_manager_to_start": "शुरू करने के लिए मैनेजर जोड़ें टैप करें।",
            "error_loading_managers": "मैनेजर लोड करने में त्रुटि",
            "managers_total": "कुल {count} मैनेजर{plural}s",
            "deactivate": "निष्क्रिय करें",
            "activate": "सक्रिय करें",
            "edit": "संपादित करें",
            "delete": "हटाएं"
          },
          "common": {
            "and": "और",
            "yes": "हां",
            "no": "नहीं",
            "ok": "ठीक है",
            "cancel": "रद्द करें",
            "save": "सेव करें",
            "delete": "हटाएं",
            "edit": "संपादित करें",
            "add": "जोड़ें",
            "search": "खोजें",
            "filter": "फ़िल्टर",
            "loading": "लोड हो रहा है...",
            "error": "त्रुटि",
            "success": "सफलता",
            "warning": "चेतावनी",
            "info": "जानकारी"
          }
        };
      case 'gu':
        return {
          "app_name": "રેસ્ટોરન્ટ એડમિન પેનલ",
          "dashboard": {
            "title": "ડેશબોર્ડ",
            "total_orders": "કુલ ઓર્ડર",
            "total_revenue": "કુલ આવક",
            "pending_orders": "બાકી ઓર્ડર",
            "completed_orders": "પૂર્ણ થયેલા ઓર્ડર",
            "today": "આજે",
            "this_week": "આ અઠવાડિયે",
            "this_month": "આ મહિને",
            "new_order": "નવો ઓર્ડર",
            "received": "મળેલ",
            "qr_saved": "QR સેવ થયું!",
            "error": "ભૂલ",
            "copy_link": "લિંક કૉપી કરો",
            "copied": "કૉપી થયું!",
            "download_qr": "QR ડાઉનલોડ કરો",
            "sign_out_question": "સાઇન આઉટ કરશો?",
            "sign_out_description": "પેનલ ઍક્સેસ કરવા માટે ફરીથી લૉગિન કરવું પડશે.",
            "cancel": "રદ કરો",
            "sign_out": "સાઇન આઉટ",
            "logout_error": "લૉગઆઉટ ભૂલ",
            "restaurant": "રેસ્ટોરન્ટ",
            "admin_panel": "એડમિન પેનલ",
            "logout": "લૉગઆઉટ",
            "categories": "શ્રેણીઓ",
            "menu_items": "મેનુ આઇટમ્સ",
            "orders": "ઓર્ડર",
            "from_yesterday": "ગઈકાલથી",
            "sales_details": "વેચાણ વિગતો"
          },
          "login": {
            "title": "લોગિન",
            "email": "ઈમેલ",
            "password": "પાસવર્ડ",
            "login_button": "લોગિન કરો",
            "forgot_password": "પાસવર્ડ ભૂલ્યા?",
            "dont_have_account": "એકાઉન્ટ નથી?",
            "sign_up": "સાઇન અપ કરો"
          },
          "categories": {"title": "શ્રેણીઓ"},
          "menu_items": {"title": "મેનૂ આઇટમ"},
          "customer_menu": {"title": "ગ્રાહક મેનૂ"},
          "menu_link": {"title": "મેનૂ લિંક"},
          "managers": {"title": "મેનેજર"},
          "category": {
            "add_category": "શ્રેણી ઉમેરો",
            "edit_category": "શ્રેણી સંપાદિત કરો",
            "delete_category": "શ્રેણી કાઢી નાખો",
            "category_name": "શ્રેણીનું નામ",
            "position": "સ્થિતિ",
            "save_category": "શ્રેણી સાચવો",
            "update_category": "શ્રેણી અપડેટ કરો",
            "upload_image": "છવિ અપલોડ કરો",
            "no_categories_yet": "હજુ સુધી કોઈ શ્રેણીઓ નથી",
            "items": "વસ્તુઓ",
            "category_added_success": "શ્રેણી સફળતાપૂર્વક ઉમેરાઈ!",
            "category_updated_success": "શ્રેણી સફળતાપૂર્વક અપડેટ થઈ!",
            "error_adding_category": "શ્રેણી ઉમેરવામાં ભૂલ",
            "error_updating_category": "શ્રેણી અપડેટ કરવામાં ભૂલ",
            "please_enter_category_name": "કૃપા કરીને શ્રેણીનું નામ દાખલ કરો",
            "please_fill_all_required_fields": "કૃપા કરીને બધા આવશ્યક ફીલ્ડ ભરો",
            "adding_category": "શ્રેણી ઉમેરાઈ રહી છે, કૃપા કરીને રાહ જુઓ...",
            "updating_category": "શ્રેણી અપડેટ થઈ રહી છે, કૃપા કરીને રાહ જુઓ...",
            "are_you_sure_delete": "શું તમે ખરેખર કાઢી નાખવા માંગો છો",
            "this_action_cannot_be_undone": "આ ક્રિયા પૂર્વવત કરી શકાતી નથી.",
            "enter_position": "સ્થિતિ દાખલ કરો (0 પહેલા માટે)",
            "enter_category_name": "શ્રેણીનું નામ દાખલ કરો",
            "create_new_section": "તમારા મેનૂ માટે એક નવો વિભાગ બનાવો.",
            "update_name_of_section": "આ મેનૂ વિભાગનું નામ અપડેટ કરો.",
            "remove_this_section": "તમારા મેનૂમાંથી આ વિભાગ કાઢી નાખો.",
            "category_placeholder": "દા.ત. સ્ટાર્ટર્સ, ડેસર્ટ"
          },
          "menu": {
            "add_menu_item": "મેનૂ આઇટમ ઉમેરો",
            "edit_menu_item": "મેનૂ આઇટમ સંપાદિત કરો",
            "delete_menu_item": "મેનૂ આઇટમ કાઢી નાખો",
            "menu_items": "મેનૂ આઇટમ",
            "item_image": "આઇટમ છવિ",
            "item_description": "વર્ણન",
            "item_name": "આઇટમનું નામ",
            "food_type": "ભોજનનો પ્રકાર",
            "variants": "વેરિઅન્ટ",
            "variant_name": "વેરિઅન્ટનું નામ",
            "price": "કિંમત",
            "add_another_variant": "બીજો વેરિઅન્ટ ઉમેરો",
            "save_menu_item": "મેનૂ આઇટમ સાચવો",
            "update_menu_item": "મેનૂ આઇટમ અપડેટ કરો",
            "menu_item_added_success": "મેનૂ આઇટમ સફળતાપૂર્વક ઉમેરાયો!",
            "menu_item_updated_success": "મેનૂ આઇટમ સફળતાપૂર્વક અપડેટ થયો!",
            "menu_item_deleted_success": "મેનૂ આઇટમ સફળતાપૂર્વક કાઢી નાખાયો",
            "error_adding_menu_item": "મેનૂ આઇટમ ઉમેરવામાં ભૂલ",
            "error_updating_menu_item": "મેનૂ આઇટમ અપડેટ કરવામાં ભૂલ",
            "error_deleting_menu_item": "મેનૂ આઇટમ કાઢી નાખવામાં ભૂલ",
            "please_enter_item_name": "કૃપા કરીને આઇટમનું નામ દાખલ કરો",
            "upload_dish_image": "ડિશ છવિ અપલોડ કરો. આ છવિ ગ્રાહક મેનૂમાં દર્શાય છે.",
            "upload_or_change_dish_image": "ડિશ છવિ અપલોડ અથવા બદલો. આ છવિ ગ્રાહક મેનૂમાં દર્શાય છે.",
            "dish_image_description": "ડિશ છવિ અપલોડ કરો. આ છવિ ગ્રાહક મેનૂમાં દર્શાય છે.",
            "change_image": "છવિ બદલો",
            "veg": "શાકાહારી",
            "non_veg": "નોન-વેજ",
            "no_menu_items": "કોઈ મેનૂ આઇટમ નથી",
            "no_results_for_search": "તમારી શોધ માટે કોઈ પરિણામ નથી",
            "search_menu_items": "મેનૂ આઇટમ શોધો...",
            "failed_to_load_menu": "મેનૂ લોડ કરવામાં નિષ્ફળ",
            "are_you_sure_delete_menu_item": "શું તમે ખરેખર આ મેનૂ આઇટમને કાઢી નાખવા માંગો છો?",
            "update_details_of_menu_item": "આ મેનૂ આઇટમની વિગતો અપડેટ કરો.",
            "create_new_dish": "તમારા મેનૂ માટે એક નવી ડિશ બનાવો.",
            "enter_item_name": "આઇટમનું નામ દાખલ કરો",
            "enter_item_description": "આઇટમ વર્ણન દાખલ કરો (વૈકલ્પિક)",
            "select_category": "શ્રેણી પસંદ કરો",
            "adding_menu_item": "ઉમેરાઈ રહ્યું છે...",
            "updating_menu_item": "અપડેટ થઈ રહ્યું છે..."
          },
          "orders": {
            "title": "ઓર્ડર",
            "today_orders": "આજે — {count} ઓર્ડર",
            "no_orders": "કોઈ {filter} ઓર્ડર નથી",
            "all": "બધા",
            "pending": "બાકી",
            "preparing": "તૈયાર થઈ રહ્યું છે",
            "ready": "તૈયાર",
            "served": "પરોસાયેલ",
            "completed": "પૂર્ણ",
            "table": "ટેબલ",
            "dine_in": "ડાઇન ઇન",
            "takeaway": "ટેકઅવે",
            "guest": "મહેમાન",
            "more_items": "+{count} વધારાની વસ્તુ{plural}",
            "mark_as_preparing": "તૈયાર કરવા માટે માર્ક કરો",
            "mark_as_ready": "તૈયાર માટે માર્ક કરો",
            "mark_as_completed": "પૂર્ણ માટે માર્ક કરો",
            "showing_results": "{total} માંથી {start}–{end} બતાવી રહ્યા છીએ",
            "logout": "લૉગઆઉટ",
            "logout_confirmation": "શું તમે લૉગઆઉટ કરવા માંગો છો?"
          },
          "settings": {
            "title": "સેટિંગ્સ",
            "restaurant_settings": "રેસ્ટોરન્ટ સેટિંગ્સ",
            "manage_restaurant_info": "તમારી રેસ્ટોરન્ટ જાણકારી સંચાલિત કરો",
            "restaurant_logo": "રેસ્ટોરન્ટ લોગો",
            "upload_logo": "રેસ્ટોરન્ટ લોગો અપલોડ કરો",
            "update_logo": "રેસ્ટોરન્ટ લોગો અપડેટ કરો",
            "change_logo": "લોગો બદલો",
            "remove_logo": "દૂર કરો",
            "logo_description": "આ લોગો બિલ અને ગ્રાહક મેનૂ પર દેખાય છે. શ્રેષ્ઠ પરિણામો માટે ચોરસ છવિનો ઉપયોગ કરો (PNG અથવા JPG, મહત્તમ 512×512px)।",
            "logo_pending_upload": "જ્યારે તમે સેવ કરશો ત્યારે નવું લોગો સેવ થઈ જશે",
            "no_logo": "કોઈ લોગો નથી",
            "restaurant_information": "રેસ્ટોરન્ટ જાણકારી",
            "restaurant_name": "રેસ્ટોરન્ટનું નામ",
            "address": "સરનામું",
            "contact_number": "સંપર્ક નંબર",
            "whatsapp_number": "વોટ્સએપ નંબર",
            "gst_number": "GST નંબર",
            "operating_hours": "સંચાલન સમય",
            "opening_time": "ખોલવાનો સમય",
            "closing_time": "બંધ કરવાનો સમય",
            "billing_settings": "બિલિંગ સેટિંગ્સ",
            "enable_gst": "GST સક્ષમ કરો",
            "enable_gst_description": "બધા ઓર્ડર પર GST લાગુ કરો.",
            "enable_packaging_charge": "પેકેજિંગ ચાર્જ સક્ષમ કરો",
            "enable_packaging_charge_description": "પાર્સલ ઓર્ડર માટે પેકેજિંગ ચાર્જ ઉમેરો.",
            "gst_percentage": "GST %",
            "cess_percentage": "Cess %",
            "packaging_charge": "પેકેજિંગ ચાર્જ",
            "language_settings": "ભાષા સેટિંગ્સ",
            "app_language": "એપ ભાષા",
            "language_description": "એડમિન પેનલ માટે તમારી પસંદગીદા ભાષા પસંદ કરો. આ બધી સ્ક્રીન પર ભાષા બદલી દેશે.",
            "language_changed": "ભાષા {language} માં બદલાઈ",
            "language_preference_saved": "ભાષા પસંદગી સેવ થઈ જશે અને એપને પુનઃપ્રારંભ કરતી વખતે સ્વચાલિત રીતે લાગુ થશે.",
            "additional_notes": "વધારાના નોટ્સ",
            "add_note": "નોટ ઉમેરો",
            "save_settings": "સેટિંગ્સ સેવ કરો",
            "settings_saved_success": "રેસ્ટોરન્ટ જાણકારી સફળતાપૂર્વક સેવ થઈ!",
            "error_saving_settings": "ભૂલ: {error}"
          },
          "managers": {
            "title": "મેનેજર્સ",
            "manage_managers": "તમારા રેસ્ટોરન્ટ મેનેજર્સ સંચાલિત કરો",
            "add_manager": "મેનેજર ઉમેરો",
            "edit_manager": "મેનેજર સંપાદિત કરો",
            "manager_name": "મેનેજરનું નામ",
            "email_address": "ઈમેલ સરનામું",
            "password": "પાસવર્ડ",
            "new_password_optional": "નવું પાસવર્ડ (રાખવા માટે જવા રહે)",
            "status": "સ્થિતિ",
            "active": "સક્રિય",
            "inactive": "નિષ્ક્રિય",
            "cancel": "રદ કરો",
            "save_changes": "ફેરફરતન સેવ કરો",
            "enter_full_name": "પૂરું નામ દાખડ કરો",
            "enter_email_address": "ઈમેલ સરનામું દાખડ કરો",
            "enter_password": "પાસવર્ડ દાખડ કરો",
            "enter_new_password_optional": "નવું પાસવર્ડ દાખડ કરો (વૈકલ્પિક)",
            "name_required": "નામ આવશ્યક છે",
            "email_required": "ઈમેલ આવશ્યક છે",
            "enter_valid_email": "માન્ય ઈમેલ દાખડ કરો",
            "password_required": "પાસવર્ડ આવશ્યક છે",
            "password_min_length": "પાસવર્ડ ઓછામાં 6 અક્ષરોનું હોવી જોઈએ",
            "manager_added_success": "મેનેજર સફળતાપૂર્વક ઉમેરાયો!",
            "manager_updated": "મેનેજર અપડેટ કરાયો!",
            "password_reset_email_sent": "મેનેજરને પાસવર્ડ રીસેટ ઈમેલ ભેજી.",
            "manager_activated": "મેનેજર સક્રિય કરાયો.",
            "manager_deactivated": "મેનેજર નિષ્ક્રિય કરાયો.",
            "delete_manager": "મેનેજર હટાવો?",
            "delete_manager_confirmation": "શું તમે વાકઈ \"{name}\" ને હટાવવા માંગે છે? આ ક્રિયા પૂર્વવત નથી કરી શકાય.",
            "manager_deleted": "મેનેજર હટાઈ ગયો.",
            "email_already_registered": "આ ઈમેલ પહેલાથી રજિસ્ટર્ડ થયેલ છે.",
            "invalid_email_address": "અમાન્ય ઈમેલ સરનામું.",
            "password_weak": "પાસવર્ડ ઓછામાં 6 અક્ષરોનું હોવી જોઈએ.",
            "error_occurred": "એક ભૂલ થઈ.",
            "no_managers_yet": "અભી સુધી કોઈ મેનેજર નથી",
            "tap_add_manager_to_start": "શરૂ કરવા માટે મેનેજર ઉમેરો ટેપ કરો.",
            "error_loading_managers": "મેનેજર લોડ કરવામાં ભૂલ",
            "managers_total": "કુલ {count} મેનેજર{plural}s",
            "deactivate": "નિષ્ક્રિય કરો",
            "activate": "સક્રિય કરો",
            "edit": "સંપાદિત કરો",
            "delete": "હટાવો"
          },
          "common": {
            "and": "અને",
            "yes": "હા",
            "no": "ના",
            "ok": "બરાબર",
            "cancel": "રદ કરો",
            "save": "સેવ કરો",
            "delete": "કાઢી નાખો",
            "edit": "સંપાદિત કરો",
            "add": "ઉમેરો",
            "search": "શોધો",
            "filter": "ફિલ્ટર",
            "loading": "લોડ થઈ રહ્યું છે...",
            "error": "ભૂલ",
            "success": "સફળતા",
            "warning": "ચેતવણી",
            "info": "માહિતી"
          }
        };
      default:
        return {};
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (!supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      return;
    }

    try {
      _loadTranslations(languageCode);
      _currentLocale = Locale(languageCode);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);

      notifyListeners();
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }

  String translate(String key) {
    if (_translations.isEmpty) {
      debugPrint('Translations not loaded, returning key: $key');
      return key;
    }

    final keys = key.split('.');
    dynamic value = _translations;

    for (final k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
       // debugPrint('Translation key not found: $key (missing: $k)');
        return key; // Return key if translation not found
      }
    }

    final result = value?.toString() ?? key;
   // debugPrint('Translation: $key -> $result');
    return result;
  }
}

class AppLocalizations {
  final LocalizationService _service;

  AppLocalizations(this._service);

  static AppLocalizations of(BuildContext context) {
    final inheritedWidget = context.dependOnInheritedWidgetOfExactType<InheritedLocalizations>();
    if (inheritedWidget == null) {
      // Return a fallback instance with default translations
      return AppLocalizations(LocalizationService());
    }
    return AppLocalizations(inheritedWidget.service);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Login
  String get appName => _service.translate('app_name');
  String get loginTitle => _service.translate('login.title');
  String get email => _service.translate('login.email');
  String get password => _service.translate('login.password');
  String get loginButton => _service.translate('login.login_button');
  String get forgotPassword => _service.translate('login.forgot_password');
  String get dontHaveAccount => _service.translate('login.dont_have_account');
  String get signUp => _service.translate('login.sign_up');

  // Dashboard
  String get dashboardTitle => _service.translate('dashboard.title');
  String get totalOrders => _service.translate('dashboard.total_orders');
  String get totalRevenue => _service.translate('dashboard.total_revenue');
  String get pendingOrders => _service.translate('dashboard.pending_orders');
  String get completedOrders => _service.translate('dashboard.completed_orders');
  String get today => _service.translate('dashboard.today');
  String get thisWeek => _service.translate('dashboard.this_week');
  String get thisMonth => _service.translate('dashboard.this_month');
  String get newOrder => _service.translate('dashboard.new_order');
  String get received => _service.translate('dashboard.received');
  String get qrSaved => _service.translate('dashboard.qr_saved');
  String get error => _service.translate('dashboard.error');
  String get menuQrLink => _service.translate('dashboard.menu_qr_link');
  String get copyLink => _service.translate('dashboard.copy_link');
  String get downloadQr => _service.translate('dashboard.download_qr');
  String get copied => _service.translate('dashboard.copied');
  String get signOutQuestion => _service.translate('dashboard.sign_out_question');
  String get signOutDescription => _service.translate('dashboard.sign_out_description');
  String get cancel => _service.translate('dashboard.cancel');
  String get signOut => _service.translate('dashboard.sign_out');
  String get logoutError => _service.translate('dashboard.logout_error');
  String get restaurant => _service.translate('dashboard.restaurant');
  String get adminPanel => _service.translate('dashboard.admin_panel');
  String get logout => _service.translate('dashboard.logout');
  String get categories => _service.translate('dashboard.categories');
  String get menuItems => _service.translate('dashboard.menu_items');
  String get orders => _service.translate('dashboard.orders');
  String get fromYesterday => _service.translate('dashboard.from_yesterday');
  String get salesDetails => _service.translate('dashboard.sales_details');

  // Menu
  String get menuTitle => _service.translate('menu.title');
  String get items => _service.translate('menu.items');
  String get addItem => _service.translate('menu.add_item');
  String get editItem => _service.translate('menu.edit_item');
  String get deleteItem => _service.translate('menu.delete_item');
  String get itemName => _service.translate('menu.item_name');
  String get price => _service.translate('menu.price');
  String get description => _service.translate('menu.description');
  String get category => _service.translate('menu.category');
  String get available => _service.translate('menu.available');
  String get notAvailable => _service.translate('menu.not_available');

  // Orders
  String get ordersTitle => _service.translate('orders.title');
  String get todayOrders => _service.translate('orders.today_orders');
  String get noOrders => _service.translate('orders.no_orders');
  String get all => _service.translate('orders.all');
  String get pending => _service.translate('orders.pending');
  String get preparing => _service.translate('orders.preparing');
  String get ready => _service.translate('orders.ready');
  String get served => _service.translate('orders.served');
  String get completed => _service.translate('orders.completed');
  String get table => _service.translate('orders.table');
  String get dineIn => _service.translate('orders.dine_in');
  String get takeaway => _service.translate('orders.takeaway');
  String get guest => _service.translate('orders.guest');
  String get moreItems => _service.translate('orders.more_items');
  String get markAsPreparing => _service.translate('orders.mark_as_preparing');
  String get markAsReady => _service.translate('orders.mark_as_ready');
  String get markAsServed => _service.translate('orders.mark_as_served');
  String get markAsCompleted => _service.translate('orders.mark_as_completed');
  String get showingResults => _service.translate('orders.showing_results');
  String get ordersLogout => _service.translate('orders.logout');
  String get logoutConfirmation => _service.translate('orders.logout_confirmation');

  // Settings
  String get settingsTitle => _service.translate('settings.title');
  String get restaurantSettings => _service.translate('settings.restaurant_settings');
  String get manageRestaurantInfo => _service.translate('settings.manage_restaurant_info');
  String get restaurantLogo => _service.translate('settings.restaurant_logo');
  String get uploadLogo => _service.translate('settings.upload_logo');
  String get updateLogo => _service.translate('settings.update_logo');
  String get changeLogo => _service.translate('settings.change_logo');
  String get removeLogo => _service.translate('settings.remove_logo');
  String get logoDescription => _service.translate('settings.logo_description');
  String get logoPendingUpload => _service.translate('settings.logo_pending_upload');
  String get noLogo => _service.translate('settings.no_logo');
  String get restaurantInformation => _service.translate('settings.restaurant_information');
  String get restaurantName => _service.translate('settings.restaurant_name');
  String get address => _service.translate('settings.address');
  String get contactNumber => _service.translate('settings.contact_number');
  String get whatsappNumber => _service.translate('settings.whatsapp_number');
  String get gstNumber => _service.translate('settings.gst_number');
  String get operatingHours => _service.translate('settings.operating_hours');
  String get openingTime => _service.translate('settings.opening_time');
  String get closingTime => _service.translate('settings.closing_time');
  String get billingSettings => _service.translate('settings.billing_settings');
  String get enableGst => _service.translate('settings.enable_gst');
  String get enableGstDescription => _service.translate('settings.enable_gst_description');
  String get enablePackagingCharge => _service.translate('settings.enable_packaging_charge');
  String get enablePackagingChargeDescription => _service.translate('settings.enable_packaging_charge_description');
  String get gstPercentage => _service.translate('settings.gst_percentage');
  String get cessPercentage => _service.translate('settings.cess_percentage');
  String get packagingCharge => _service.translate('settings.packaging_charge');
  String get languageSettings => _service.translate('settings.language_settings');
  String get appLanguage => _service.translate('settings.app_language');
  String get languageDescription => _service.translate('settings.language_description');
  String get languageChanged => _service.translate('settings.language_changed');
  String get languagePreferenceSaved => _service.translate('settings.language_preference_saved');
  String get additionalNotes => _service.translate('settings.additional_notes');
  String get addNote => _service.translate('settings.add_note');
  String get saveSettings => _service.translate('settings.save_settings');
  String get settingsSavedSuccess => _service.translate('settings.settings_saved_success');
  String get errorSavingSettings => _service.translate('settings.error_saving_settings');

  // Managers
  String get managersTitle => _service.translate('managers.title');
  String get manageManagers => _service.translate('managers.manage_managers');
  String get addManager => _service.translate('managers.add_manager');
  String get editManager => _service.translate('managers.edit_manager');
  String get managerName => _service.translate('managers.manager_name');
  String get emailAddress => _service.translate('managers.email_address');
  String get newPasswordOptional => _service.translate('managers.new_password_optional');
  String get status => _service.translate('managers.status');
  String get active => _service.translate('managers.active');
  String get inactive => _service.translate('managers.inactive');
  String get saveChanges => _service.translate('managers.save_changes');
  String get enterFullName => _service.translate('managers.enter_full_name');
  String get enterEmailAddress => _service.translate('managers.enter_email_address');
  String get enterPassword => _service.translate('managers.enter_password');
  String get enterNewPasswordOptional => _service.translate('managers.enter_new_password_optional');
  String get nameRequired => _service.translate('managers.name_required');
  String get emailRequired => _service.translate('managers.email_required');
  String get enterValidEmail => _service.translate('managers.enter_valid_email');
  String get passwordRequired => _service.translate('managers.password_required');
  String get passwordMinLength => _service.translate('managers.password_min_length');
  String get managerAddedSuccess => _service.translate('managers.manager_added_success');
  String get managerUpdated => _service.translate('managers.manager_updated');
  String get passwordResetEmailSent => _service.translate('managers.password_reset_email_sent');
  String get managerActivated => _service.translate('managers.manager_activated');
  String get managerDeactivated => _service.translate('managers.manager_deactivated');
  String get deleteManager => _service.translate('managers.delete_manager');
  String get deleteManagerConfirmation => _service.translate('managers.delete_manager_confirmation');
  String get managerDeleted => _service.translate('managers.manager_deleted');
  String get emailAlreadyRegistered => _service.translate('managers.email_already_registered');
  String get invalidEmailAddress => _service.translate('managers.invalid_email_address');
  String get passwordWeak => _service.translate('managers.password_weak');
  String get errorOccurred => _service.translate('managers.error_occurred');
  String get noManagersYet => _service.translate('managers.no_managers_yet');
  String get tapAddManagerToStart => _service.translate('managers.tap_add_manager_to_start');
  String get errorLoadingManagers => _service.translate('managers.error_loading_managers');
  String get deactivate => _service.translate('managers.deactivate');
  String get activate => _service.translate('managers.activate');

  // Common
  String get and => _service.translate('common.and');
  String get yes => _service.translate('common.yes');
  String get no => _service.translate('common.no');
  String get ok => _service.translate('common.ok');
  String get commonCancel => _service.translate('common.cancel');
  String get commonSave => _service.translate('common.save');
  String get delete => _service.translate('common.delete');
  String get edit => _service.translate('common.edit');
  String get add => _service.translate('common.add');
  String get search => _service.translate('common.search');
  String get filter => _service.translate('common.filter');
  String get loading => _service.translate('common.loading');
  String get success => _service.translate('common.success');
  String get warning => _service.translate('common.warning');
  String get info => _service.translate('common.info');

  // Sidebar nav labels (used via translate(key) in _getSidebarItems)
  String get categoriesTitle => _service.translate('categories.title');
  String get menuItemsTitle => _service.translate('menu_items.title');
  String get customerMenuTitle => _service.translate('customer_menu.title');
  String get menuLinkTitle => _service.translate('menu_link.title');


  // Category Page
  String get addCategory => _service.translate('category.add_category');
  String get editCategory => _service.translate('category.edit_category');
  String get deleteCategory => _service.translate('category.delete_category');
  String get categoryName => _service.translate('category.category_name');
  String get position => _service.translate('category.position');
  String get saveCategory => _service.translate('category.save_category');
  String get updateCategory => _service.translate('category.update_category');
  String get uploadImage => _service.translate('category.upload_image');
  String get noCategoriesYet => _service.translate('category.no_categories_yet');
  String get categoryAddedSuccess => _service.translate('category.category_added_success');
  String get categoryUpdatedSuccess => _service.translate('category.category_updated_success');
  String get errorAddingCategory => _service.translate('category.error_adding_category');
  String get errorUpdatingCategory => _service.translate('category.error_updating_category');
  String get pleaseEnterCategoryName => _service.translate('category.please_enter_category_name');
  String get pleaseFillAllRequiredFields => _service.translate('category.please_fill_all_required_fields');
  String get addingCategory => _service.translate('category.adding_category');
  String get updatingCategory => _service.translate('category.updating_category');
  String get areYouSureDelete => _service.translate('category.are_you_sure_delete');
  String get thisActionCannotBeUndone => _service.translate('category.this_action_cannot_be_undone');
  String get enterPosition => _service.translate('category.enter_position');
  String get enterCategoryName => _service.translate('category.enter_category_name');
  String get createNewSection => _service.translate('category.create_new_section');
  String get updateNameOfSection => _service.translate('category.update_name_of_section');
  String get removeThisSection => _service.translate('category.remove_this_section');
  String get categoryPlaceholder => _service.translate('category.category_placeholder');

  // Menu Page
  String get addMenuItem => _service.translate('menu.add_menu_item');
  String get editMenuItem => _service.translate('menu.edit_menu_item');
  String get deleteMenuItem => _service.translate('menu.delete_menu_item');
  String get itemImage => _service.translate('menu.item_image');
  String get itemDescription => _service.translate('menu.item_description');
  String get foodType => _service.translate('menu.food_type');
  String get variants => _service.translate('menu.variants');
  String get variantName => _service.translate('menu.variant_name');
  String get addAnotherVariant => _service.translate('menu.add_another_variant');
  String get saveMenuItem => _service.translate('menu.save_menu_item');
  String get updateMenuItem => _service.translate('menu.update_menu_item');
  String get menuItemAddedSuccess => _service.translate('menu.menu_item_added_success');
  String get menuItemUpdatedSuccess => _service.translate('menu.menu_item_updated_success');
  String get menuItemDeletedSuccess => _service.translate('menu.menu_item_deleted_success');
  String get errorAddingMenuItem => _service.translate('menu.error_adding_menu_item');
  String get errorUpdatingMenuItem => _service.translate('menu.error_updating_menu_item');
  String get errorDeletingMenuItem => _service.translate('menu.error_deleting_menu_item');
  String get pleaseEnterItemName => _service.translate('menu.please_enter_item_name');
  String get uploadDishImage => _service.translate('menu.upload_dish_image');
  String get uploadOrChangeDishImage => _service.translate('menu.upload_or_change_dish_image');
  String get dishImageDescription => _service.translate('menu.dish_image_description');
  String get changeImage => _service.translate('menu.change_image');
  String get veg => _service.translate('menu.veg');
  String get nonVeg => _service.translate('menu.non_veg');
  String get noMenuItems => _service.translate('menu.no_menu_items');
  String get noResultsForSearch => _service.translate('menu.no_results_for_search');
  String get searchMenuItems => _service.translate('menu.search_menu_items');
  String get failedToLoadMenu => _service.translate('menu.failed_to_load_menu');
  String get areYouSureDeleteMenuItem => _service.translate('menu.are_you_sure_delete_menu_item');
  String get updateDetailsOfMenuItem => _service.translate('menu.update_details_of_menu_item');
  String get createNewDish => _service.translate('menu.create_new_dish');
  String get enterItemName => _service.translate('menu.enter_item_name');
  String get enterItemDescription => _service.translate('menu.enter_item_description');
  String get selectCategory => _service.translate('menu.select_category');
  String get addingMenuItem => _service.translate('menu.adding_menu_item');
  String get updatingMenuItem => _service.translate('menu.updating_menu_item');
  String get quantity => _service.translate('common.quantity');

  /// Generic key-based lookup — allows widgets to call
  /// AppLocalizations.of(context).translate('some.key')
  String translate(String key) => _service.translate(key);
}

class InheritedLocalizations extends InheritedWidget {
  final LocalizationService service;

  const InheritedLocalizations({super.key,
    required this.service,
    required super.child,
  });

  @override
  bool updateShouldNotify(InheritedLocalizations oldWidget) => true;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => LocalizationService.supportedLocales
      .any((supportedLocale) => supportedLocale.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final service = LocalizationService();
    await service.init();
    return AppLocalizations(service);
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}