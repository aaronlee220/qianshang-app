import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'platform_mobile.dart'
    if (dart.library.html) 'platform_web.dart';

void main() {
  runApp(const PurchaseApp());
}

class PurchaseApp extends StatelessWidget {
  const PurchaseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '千尚',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F5496)),
        useMaterial3: true,
      ),
      home: const HomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String _baseUrl = 'http://154.51.40.17/api';
  final String _imgUrl = 'http://154.51.40.17/api';

  int _tabIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _searchExpanded = false;

  CalendarFormat _calFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Set<String> _orderDates = {};
  Set<String> _arrivalDates = {};
  Set<String> _shipDates = {};

  List _products = [];
  List _dayProducts = [];
  int _totalCount = 0;
  bool _loading = false;
  bool _showDayProducts = false;

  // 筛选状态
  String _selectedCustomer = '';
  String _selectedCountry = '';
  String _selectedLogistics = '';
  String _selectedArrivalDate = '';
  String _selectedShipDate = '';
  List<String> _availableCustomers = [];
  List<String> _availableCountries = [];
  List<String> _availableLogistics = [];
  bool _showArrivalFilter = false;
  bool _showShipFilter = false;
  DateTime _selectedArrivalDay = DateTime.now();
  DateTime _selectedShipDay = DateTime.now();

  final List<String> _tabs = ['所有商品', '未发货', '已发货'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  String get _tabParam {
    if (_tabIndex == 0) return 'all';
    if (_tabIndex == 1) return 'undelivered';
    return 'delivered';
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_baseUrl/products').replace(queryParameters: {
        'tab': _tabParam,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        if (_selectedCustomer.isNotEmpty) 'customer': _selectedCustomer,
        if (_selectedCountry.isNotEmpty) 'country': _selectedCountry,
        if (_selectedLogistics.isNotEmpty) 'logistics': _selectedLogistics,
        if (_selectedArrivalDate.isNotEmpty) 'arrival_date': _selectedArrivalDate,
        if (_selectedShipDate.isNotEmpty) 'ship_date_filter': _selectedShipDate,
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = json.decode(resp.body);
      setState(() {
        _products = data['products'] as List;
        _totalCount = data['total'] as int;
        _orderDates = (data['order_dates'] as List).cast<String>().toSet();
        _arrivalDates = (data['arrival_dates'] as List?)?.cast<String>().toSet() ?? {};
        _shipDates = (data['ship_dates'] as List?)?.cast<String>().toSet() ?? {};
        _availableCustomers = (data['available_customers'] as List?)?.cast<String>() ?? [];
        _availableCountries = (data['available_countries'] as List?)?.cast<String>() ?? [];
        _availableLogistics = (data['available_logistics'] as List?)?.cast<String>() ?? [];
        _showDayProducts = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadProductsByDate(DateTime day) async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    try {
      final uri = Uri.parse('$_baseUrl/products/date/$dateStr')
          .replace(queryParameters: {
        'tab': _tabParam,
        if (_selectedCustomer.isNotEmpty) 'customer': _selectedCustomer,
        if (_selectedCountry.isNotEmpty) 'country': _selectedCountry,
        if (_selectedLogistics.isNotEmpty) 'logistics': _selectedLogistics,
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = json.decode(resp.body);
      setState(() {
        _dayProducts = data['products'] as List;
        _showDayProducts = true;
        _selectedDay = day;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String val) {
    _searchQuery = val;
    _loadProducts();
  }

  Future<DateTime?> _showCalendarDialog({
    required String title,
    required Set<String> markerDates,
    required Color markerColor,
    required DateTime initialDay,
  }) async {
    DateTime tempDay = initialDay;
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 320,
                        child: TableCalendar(
                          firstDay: DateTime(2024),
                          lastDay: DateTime(2030),
                          focusedDay: tempDay,
                          selectedDayPredicate: (day) => isSameDay(day, tempDay),
                          onDaySelected: (selected, _) {
                            setDlgState(() => tempDay = selected);
                          },
                          locale: 'zh_CN',
                          calendarFormat: CalendarFormat.month,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarStyle: CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          eventLoader: (day) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            return markerDates.contains(key) ? [true] : [];
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              if (events.isEmpty) return const SizedBox();
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final _ in events.take(3))
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: markerColor,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          onPageChanged: (focused) {
                            setDlgState(() => tempDay = focused);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, tempDay),
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked) async {
    final result = await _showCalendarDialog(
      title: '选择下单日期',
      markerDates: _orderDates,
      markerColor: Colors.orange,
      initialDay: _selectedDay,
    );
    if (result != null) {
      onPicked(result);
    }
  }

  Future<void> _pickFilterDate(
    String title,
    Set<String> markerDates,
    Color markerColor,
    ValueChanged<DateTime> onPicked,
  ) async {
    final result = await _showCalendarDialog(
      title: title,
      markerDates: markerDates,
      markerColor: markerColor,
      initialDay: markerDates.isNotEmpty
          ? DateTime.tryParse(markerDates.reduce((a, b) => a.compareTo(b) > 0 ? a : b)) ?? DateTime.now()
          : DateTime.now(),
    );
    if (result != null) {
      onPicked(result);
    }
  }

  // ========== 编辑 / 新增 ==========

  void _showEditDialog({Map? product}) {
    final isNew = product == null;
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final customerCtrl = TextEditingController(text: product?['customer'] ?? '');
    final countryCtrl = TextEditingController(text: product?['country'] ?? '');
    final orderDateCtrl = TextEditingController(text: product?['order_date'] ?? '');
    final piecesCtrl = TextEditingController(text: product?['pieces']?.toString() ?? '');
    final packQtyCtrl = TextEditingController(text: product?['pack_qty']?.toString() ?? '');
    final totalQtyCtrl = TextEditingController(text: product?['total_qty']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: product?['unit_price']?.toString() ?? '');
    final revenueCtrl = TextEditingController(text: product?['revenue']?.toString() ?? '');
    final logisticsCtrl = TextEditingController(text: product?['logistics'] ?? '');
    final notesCtrl = TextEditingController(text: product?['notes'] ?? '');
    final pickupFeeCtrl = TextEditingController(text: product?['pickup_fee']?.toString() ?? '');
    final inlandFeeCtrl = TextEditingController(text: product?['inland_fee']?.toString() ?? '');
    final arrivalDateCtrl = TextEditingController(text: product?['arrival_date'] ?? '');
    final shipDateCtrl = TextEditingController(text: product?['ship_date'] ?? '');
    final trackingCtrl = TextEditingController(text: product?['tracking_no'] ?? '');
    final lengthCtrl = TextEditingController(text: product?['length']?.toString() ?? '');
    final widthCtrl = TextEditingController(text: product?['width']?.toString() ?? '');
    final heightCtrl = TextEditingController(text: product?['height']?.toString() ?? '');
    final weightCtrl = TextEditingController(text: product?['weight']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isNew ? '新增产品' : '编辑产品',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field('品名', nameCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('客户', customerCtrl)),
                    ]),
                    Row(children: [
                      Expanded(child: _field('国家/地区', countryCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('下单日期', orderDateCtrl, hint: '2026-06-15')),
                    ]),
                    Row(children: [
                      Expanded(child: _field('件数', piecesCtrl, num: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('装箱数', packQtyCtrl, num: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('总数', totalQtyCtrl, num: true)),
                    ]),
                    Row(children: [
                      Expanded(child: _field('单价', priceCtrl, num: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('收款', revenueCtrl, num: true)),
                    ]),
                    Row(children: [
                      Expanded(child: _field('物流方式', logisticsCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('单号', trackingCtrl)),
                    ]),
                    Row(children: [
                      Expanded(
                        child: _dateField('到货日期', arrivalDateCtrl, setSheetState),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _dateField('出货日期', shipDateCtrl, setSheetState),
                      ),
                    ]),
                    Row(children: [
                      Expanded(child: _field('长', lengthCtrl, num: true, hint: 'cm')),
                      const SizedBox(width: 8),
                      Expanded(child: _field('宽', widthCtrl, num: true, hint: 'cm')),
                      const SizedBox(width: 8),
                      Expanded(child: _field('高', heightCtrl, num: true, hint: 'cm')),
                    ]),
                    Row(children: [
                      Expanded(child: _field('重量(kg)', weightCtrl, num: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('备注', notesCtrl)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: _field('提货费', pickupFeeCtrl, num: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _field('内陆费', inlandFeeCtrl, num: true)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      if (!isNew) Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteProduct(product!['id']);
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('删除', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      if (!isNew) const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final data = {
                              'name': nameCtrl.text,
                              'customer': customerCtrl.text,
                              'country': countryCtrl.text,
                              'order_date': orderDateCtrl.text,
                              'pieces': int.tryParse(piecesCtrl.text) ?? 0,
                              'pack_qty': int.tryParse(packQtyCtrl.text) ?? 0,
                              'total_qty': int.tryParse(totalQtyCtrl.text) ?? 0,
                              'unit_price': double.tryParse(priceCtrl.text) ?? 0,
                              'revenue': double.tryParse(revenueCtrl.text) ?? 0,
                              'logistics': logisticsCtrl.text,
                              'notes': notesCtrl.text,
                              'arrival_date': arrivalDateCtrl.text,
                              'ship_date': shipDateCtrl.text,
                              'tracking_no': trackingCtrl.text,
                              'length': double.tryParse(lengthCtrl.text),
                              'width': double.tryParse(widthCtrl.text),
                              'height': double.tryParse(heightCtrl.text),
                              'weight': double.tryParse(weightCtrl.text),
                              'pickup_fee': double.tryParse(pickupFeeCtrl.text) ?? 0,
                              'inland_fee': double.tryParse(inlandFeeCtrl.text) ?? 0,
                            };
                            Navigator.pop(ctx);
                            if (isNew) {
                              await _createProduct(data);
                            } else {
                              await _updateProduct(product!['id'], data);
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('保存'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool num = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  Widget _dateField(String label, TextEditingController ctrl, StateSetter setState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final initial = ctrl.text.isNotEmpty
              ? DateTime.tryParse(ctrl.text) ?? now
              : now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            locale: const Locale('zh', 'CN'),
          );
          if (picked != null) {
            final formatted =
                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            ctrl.text = formatted;
            setState(() {});
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(
            ctrl.text.isEmpty ? '点此选择日期' : ctrl.text,
            style: TextStyle(
              color: ctrl.text.isEmpty ? Colors.grey.shade400 : null,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateProduct(int id, Map data) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已更新'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  Future<void> _createProduct(Map data) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/products'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已新增'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个产品吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await http.delete(Uri.parse('$_baseUrl/products/$id'));
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ 已删除'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _markShipped(int id) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await http.put(
        Uri.parse('$_baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ship_date': today}),
      );
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已标记发货'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('标记失败: $e')),
        );
      }
    }
  }

  Future<void> _cancelShipped(int id) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl/products/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ship_date': ''}),
      );
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('↩️ 已取消发货'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
      }
    }
  }

  Future<void> _takeRealPhoto(int productId) async {
    takePhoto((bytes) async {
      try {
        final uri = Uri.parse('$_baseUrl/upload');
        final request = http.MultipartRequest('POST', uri);
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'photo.jpg'));
        final streamedResp = await request.send();
        final resp = await http.Response.fromStream(streamedResp);
        final data = json.decode(resp.body);
        final filename = data['filename'];
        await http.put(
          Uri.parse('$_baseUrl/products/$productId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'real_image': filename}),
        );
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📸 实物图已保存'), duration: Duration(seconds: 1)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $e')),
          );
        }
      }
    });
  }

  Future<void> _pickAlbumPhoto(int productId) async {
    pickFromGallery((bytes) async {
      try {
        final uri = Uri.parse('$_baseUrl/upload');
        final request = http.MultipartRequest('POST', uri);
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'photo.jpg'));
        final streamedResp = await request.send();
        final resp = await http.Response.fromStream(streamedResp);
        final data = json.decode(resp.body);
        final filename = data['filename'];
        await http.put(
          Uri.parse('$_baseUrl/products/$productId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'real_image': filename}),
        );
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🖼️ 相册图片已保存'), duration: Duration(seconds: 1)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $e')),
          );
        }
      }
    });
  }

  Future<void> _importCsv() async {
    pickAndReadFile('.xlsx,.csv', (bytes) async {
      try {
        final base64Str = base64Encode(bytes);
        final uri = Uri.parse('$_baseUrl/import_base64');
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'file': base64Str, 'name': 'import.xlsx'}),
        ).timeout(const Duration(seconds: 30));
        final data = json.decode(resp.body);
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ ${data['message']}'), duration: const Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入失败: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('批发采购助手'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_searchExpanded ? Icons.search : Icons.search),
            onPressed: () => setState(() => _searchExpanded = !_searchExpanded),
            tooltip: '搜索',
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            onPressed: () => openUrl('$_baseUrl/template'),
            tooltip: '下载模板',
          ),
          if (kIsWeb)
            TextButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file, size: 20),
              label: const Text('批量导入'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: '刷新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 可展开搜索栏
          if (_searchExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '按客户、品名搜索...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (_searchCtrl.text == v) _onSearch(v);
                    });
                  },
                ),
              ),
            ),
          // 第一行：下单/到货/出货 日期框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    // 下单日期
                    _dateBox(theme, '下单', _selectedDay, _showDayProducts, () {
                      _pickDate((picked) {
                        setState(() {
                          _selectedDay = picked;
                          _showDayProducts = true;
                        });
                        _showDayProducts ? _loadProductsByDate(_selectedDay) : _loadProducts();
                      });
                    }, () {
                      setState(() => _showDayProducts = false);
                      _loadProducts();
                    }),
                    const SizedBox(width: 6),
                    // 到货日期
                    _dateBox(theme, '到货', _selectedArrivalDay, _showArrivalFilter, () {
                      _pickFilterDate('选择到货日期', _arrivalDates, Colors.blue, (picked) {
                        setState(() {
                          _selectedArrivalDay = picked;
                          _showArrivalFilter = true;
                          _selectedArrivalDate = DateFormat('yyyy-MM-dd').format(picked);
                        });
                        _loadProducts();
                      });
                    }, () {
                      setState(() {
                        _showArrivalFilter = false;
                        _selectedArrivalDate = '';
                      });
                      _loadProducts();
                    }),
                    const SizedBox(width: 6),
                    // 出货日期
                    _dateBox(theme, '出货', _selectedShipDay, _showShipFilter, () {
                      _pickFilterDate('选择出货日期', _shipDates, Colors.green, (picked) {
                        setState(() {
                          _selectedShipDay = picked;
                          _showShipFilter = true;
                          _selectedShipDate = DateFormat('yyyy-MM-dd').format(picked);
                        });
                        _loadProducts();
                      });
                    }, () {
                      setState(() {
                        _showShipFilter = false;
                        _selectedShipDate = '';
                      });
                      _loadProducts();
                    }),
                    const SizedBox(width: 6),
                  ],
                ),
                const SizedBox(height: 6),
                // 第二行：客户 + 国家 + 物流
                Row(
                  children: [
                    Expanded(child: _filterDropdown(
                      value: _selectedCustomer,
                      items: _availableCustomers,
                      hint: '客户',
                      theme: theme,
                      onChanged: (v) {
                        setState(() => _selectedCustomer = v ?? '');
                        _loadProducts();
                      },
                    )),
                    const SizedBox(width: 6),
                    Expanded(child: _filterDropdown(
                      value: _selectedCountry,
                      items: _availableCountries,
                      hint: '国家',
                      theme: theme,
                      onChanged: (v) {
                        setState(() => _selectedCountry = v ?? '');
                        _loadProducts();
                      },
                    )),
                    const SizedBox(width: 6),
                    Expanded(child: _filterDropdown(
                      value: _selectedLogistics,
                      items: _availableLogistics,
                      hint: '物流',
                      theme: theme,
                      onChanged: (v) {
                        setState(() => _selectedLogistics = v ?? '');
                        _loadProducts();
                      },
                    )),
                  ],
                ),
              ],
            ),
          ),

          // 分隔信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  _showDayProducts
                      ? '📅 ${DateFormat('M月d日').format(_selectedDay)} 下单产品'
                      : '📦 共 $_totalCount 个产品',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (_showDayProducts)
                  TextButton(
                    onPressed: () => setState(() => _showDayProducts = false),
                    child: const Text('查看全部'),
                  ),
              ],
            ),
          ),

          // 产品列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildProductList(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() {
            _tabIndex = i;
            _showDayProducts = false;
          });
          _loadProducts();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2), label: '所有商品'),
          NavigationDestination(icon: Icon(Icons.local_shipping), label: '未发货'),
          NavigationDestination(icon: Icon(Icons.check_circle), label: '已发货'),
        ],
      ),
    );
  }

  // ========== 日期小框 ==========

  String _currency(String country) {
    if (country.contains('台湾') || country.contains('台灣')) return 'NT\$';
    if (country.contains('日本') || country.contains('韩国') || country.contains('南韩')) return '₩';
    if (country.contains('美国') || country.contains('美洲') || country.contains('加拿大')) return '\$';
    if (country.contains('德国') || country.contains('法国') || country.contains('意大利') || country.contains('欧洲')) return '€';
    if (country.contains('英国')) return '£';
    if (country.contains('马来西亚')) return 'RM';
    return '¥';
  }

  Widget _dateBox(ThemeData theme, String label, DateTime day, bool isActive,
      VoidCallback onTap, VoidCallback onClear) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isActive ? theme.colorScheme.primary : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isActive ? '' : ''}$label ${DateFormat('M/d').format(day)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? theme.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isActive)
            InkWell(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.close, size: 14, color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  // ========== 下拉筛选 ==========

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required ThemeData theme,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          isExpanded: true,
          isDense: true,
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text('全部', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 13)),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ========== 产品卡片列表 ==========

  Widget _buildProductList() {
    final items = _showDayProducts ? _dayProducts : _products;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              _showDayProducts ? '当日暂无订单' : '暂无数据',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final p = items[i];
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showEditDialog(product: p),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧图片（缩小到80x100）
                        if ((p['image'] as String?)?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        '$_imgUrl/images/${p['image']}',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 80,
                                  height: 100,
                                  child: Image.network(
                                    '$_imgUrl/images/${p['image']}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(),
                                    loadingBuilder: (_, child, progress) =>
                                        progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // 右侧信息（不含图片区域的所有内容）
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 第一行：品名 + 数量
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(p['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if ((num.tryParse(p['pieces']?.toString() ?? '')?.toInt() ?? 0) > 0 || (num.tryParse(p['pack_qty']?.toString() ?? '')?.toInt() ?? 0) > 0 || (num.tryParse(p['total_qty']?.toString() ?? '')?.toInt() ?? 0) > 0)
                                    Text('${p['pieces']}/${p['pack_qty']}/${p['total_qty']}件',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              // 第二行：客户 · 国家（加粗放大）
                              Text(
                                '${p['customer'] ?? ''}${((p['customer'] as String?) ?? '').isNotEmpty && ((p['country'] as String?) ?? '').isNotEmpty ? ' · ' : ''}${p['country'] ?? ''}'
                                style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // 第三行：单价 + 总价（按国家显示货币）
                              if ((num.tryParse(p['unit_price']?.toString() ?? '')?.toDouble() ?? 0) > 0 || (num.tryParse(p['revenue']?.toString() ?? '')?.toDouble() ?? 0) > 0)
                                Row(
                                  children: [
                                    if ((num.tryParse(p['unit_price']?.toString() ?? '')?.toDouble() ?? 0) > 0)
                                      Text('${_currency(p['country'] ?? '')}${p['unit_price']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    if ((num.tryParse(p['unit_price']?.toString() ?? '')?.toDouble() ?? 0) > 0 && (num.tryParse(p['revenue']?.toString() ?? '')?.toDouble() ?? 0) > 0)
                                      Text(' · ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                    if ((num.tryParse(p['revenue']?.toString() ?? '')?.toDouble() ?? 0) > 0)
                                      Text('${_currency(p['country'] ?? '')}${p['revenue']}',
                                        style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              // 第四行：下单日期 + 单号
                              Row(
                                children: [
                                  if (((p['order_date'] as String?) ?? '').isNotEmpty)
                                    Text(p['order_date'] ?? '',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  if (((p['order_date'] as String?) ?? '').isNotEmpty && ((p['tracking_no'] as String?) ?? '').isNotEmpty)
                                    Text('  ', style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
                                  if (((p['tracking_no'] as String?) ?? '').isNotEmpty)
                                    Expanded(
                                      child: Text('单:${p['tracking_no']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              // 第五行：尺寸 + 重量
                              if (((num.tryParse(p['length']?.toString() ?? '')?.toDouble() ?? 0)) > 0 || ((num.tryParse(p['weight']?.toString() ?? '')?.toDouble() ?? 0)) > 0)
                                Row(
                                  children: [
                                    if (((num.tryParse(p['length']?.toString() ?? '')?.toDouble() ?? 0)) > 0)
                                      Text('${p['length']}×${p['width']}×${p['height']}cm',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    if (((num.tryParse(p['length']?.toString() ?? '')?.toDouble() ?? 0)) > 0 && ((num.tryParse(p['weight']?.toString() ?? '')?.toDouble() ?? 0)) > 0)
                                      Text('  ·  ', style: TextStyle(fontSize: 11, color: Colors.grey.shade300)),
                                    if (((num.tryParse(p['weight']?.toString() ?? '')?.toDouble() ?? 0)) > 0)
                                      Text('${p['weight']}kg',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              // 按钮行：发货 + 物流 + 拍照 + 备注
                              Wrap(
                                spacing: 2,
                                runSpacing: 2,
                                children: [
                                  // 发货/取消发货
                                  if (((p['ship_date'] as String?) ?? '').isEmpty)
                                    _smallBtn(Icons.check_circle_outline, '发货',
                                      () => _markShipped(p['id']), Colors.grey.shade600),
                                  if (((p['ship_date'] as String?) ?? '').isNotEmpty)
                                    _smallBtn(Icons.undo, '取消',
                                      () => _cancelShipped(p['id']), Colors.orange.shade600),
                                  // 已出货标签
                                  if (((p['ship_date'] as String?) ?? '').isNotEmpty)
                                    _chip(Icons.check_circle, '已出货 ${p['ship_date']}', color: Colors.blue),
                                  // 物流
                                  if (((p['logistics'] as String?) ?? '').isNotEmpty)
                                    _chip(Icons.local_shipping, p['logistics']),
                                  // 拍照/相册
                                  _smallBtn(Icons.camera_alt, '拍照',
                                    () => _takeRealPhoto(p['id']), Colors.grey.shade600),
                                  _smallBtn(Icons.photo_library, '相册',
                                    () => _pickAlbumPhoto(p['id']), Colors.grey.shade600),
                                  // 备注
                                  if (((p['notes'] as String?) ?? '').isNotEmpty)
                                    _chip(Icons.note, p['notes']),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // 实物图（最右侧）
                        if ((p['real_image'] as String?) != null &&
                            ((p['real_image'] as String?) ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (ctx) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        '$_imgUrl/images/${p['real_image']}',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                child: SizedBox(
                                  width: 70,
                                  height: 90,
                                  child: Image.network(
                                    '$_imgUrl/images/${p['real_image']}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox(),
                                    loadingBuilder: (_, child, progress) =>
                                        progress == null ? child : const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color ?? Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 1),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
