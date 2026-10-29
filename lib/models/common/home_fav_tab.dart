class HomeFavTab {
  static const int historyId = -1;

  final int id;
  final String title;

  const HomeFavTab({required this.id, required this.title});

  const HomeFavTab.history() : id = historyId, title = '历史记录';

  bool get isHistory => id == historyId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
      };

  factory HomeFavTab.fromJson(Map<String, dynamic> json) => HomeFavTab(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeFavTab &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
