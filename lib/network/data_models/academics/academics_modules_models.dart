class AcModuleStatusItem {
  AcModuleStatusItem({
    required this.name,
    required this.shortCode,
    required this.status,
  });

  final String name;
  final String shortCode;
  final bool status;

  factory AcModuleStatusItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    final enabled = rawStatus == true || rawStatus == 1 || rawStatus == '1';
    return AcModuleStatusItem(
      name: (json['name'] ?? '').toString(),
      shortCode: (json['short_code'] ?? '').toString(),
      status: enabled,
    );
  }
}

class AcModuleStatusPayload {
  AcModuleStatusPayload({
    required this.success,
    required this.modules,
    this.error,
  });

  final bool success;
  final List<AcModuleStatusItem> modules;
  final String? error;

  factory AcModuleStatusPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['module_list'] as List?) ?? const [];
    return AcModuleStatusPayload(
      success: json['success'] == true,
      error: json['error']?.toString(),
      modules: list
          .whereType<Map>()
          .map((e) => AcModuleStatusItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

