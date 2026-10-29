import 'dart:math';

import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/common/home_fav_tab.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/data.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/models_new/sub/sub/list.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class _HomeTabSelectItem {
  final int id;
  final String title;
  final String subtitle;
  final IconData icon;
  bool selected;

  _HomeTabSelectItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
  });
}

Future<void> showSelectHomeFavDialog(BuildContext context) async {
  if (!Accounts.main.isLogin) {
    SmartDialog.showToast('请先登录');
    Get.toNamed('/loginPage');
    return;
  }

  SmartDialog.showLoading(msg: '加载中...');
  List<FavFolderInfo> allFolders = [];

  try {
    final res = await FavHttp.allFavFolders(Accounts.main.mid);
    if (res case Success(:final response)) {
      if (response.list != null) {
        allFolders.addAll(response.list!);
      }
    }

    final subRes = await UserHttp.userSubFolder(
      mid: Accounts.main.mid,
      pn: 1,
      ps: 50,
    );
    if (subRes case Success(:final response)) {
      for (final sub in response.list ?? <SubItemModel>[]) {
        if (sub.id != null && (sub.type == 11 || sub.type == 21)) {
          if (!allFolders.any((f) => f.id == sub.id)) {
            allFolders.add(
              FavFolderInfo(
                id: sub.id!,
                title: sub.title ?? '',
                mediaCount: sub.mediaCount ?? 0,
              ),
            );
          }
        }
      }
    }
  } catch (e) {
    SmartDialog.dismiss();
    SmartDialog.showToast('获取收藏夹异常: $e');
    return;
  }

  SmartDialog.dismiss();

  final homeController = Get.find<HomeController>();
  final currentTabs = homeController.tabs.toList();
  final currentSelectedIds = currentTabs.map((e) => e.id).toSet();

  List<_HomeTabSelectItem> items = [];
  for (final tab in currentTabs) {
    if (tab.isHistory) {
      items.add(
        _HomeTabSelectItem(
          id: HomeFavTab.historyId,
          title: '历史记录',
          subtitle: '展示近期观看的视频历史记录',
          icon: Icons.history_rounded,
          selected: true,
        ),
      );
    } else {
      final match = allFolders.firstWhereOrNull((f) => f.id == tab.id);
      items.add(
        _HomeTabSelectItem(
          id: match?.id ?? tab.id,
          title: match?.title ?? tab.title,
          subtitle: '收藏夹 · 共 ${match?.mediaCount ?? 0} 条内容',
          icon: Icons.folder_special_outlined,
          selected: true,
        ),
      );
    }
  }

  if (!currentSelectedIds.contains(HomeFavTab.historyId)) {
    items.add(
      _HomeTabSelectItem(
        id: HomeFavTab.historyId,
        title: '历史记录',
        subtitle: '展示近期观看的视频历史记录',
        icon: Icons.history_rounded,
        selected: false,
      ),
    );
  }

  for (final folder in allFolders) {
    if (!currentSelectedIds.contains(folder.id)) {
      items.add(
        _HomeTabSelectItem(
          id: folder.id,
          title: folder.title,
          subtitle: '收藏夹 · 共 ${folder.mediaCount} 条内容',
          icon: Icons.folder_special_outlined,
          selected: false,
        ),
      );
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) => _SelectHomeFavDialog(
      items: items,
      onConfirm: (selected) {
        final newTabs = selected
            .map((e) => HomeFavTab(id: e.id, title: e.title))
            .toList();
        homeController.setFolders(newTabs);
      },
    ),
  );
}

class _SelectHomeFavDialog extends StatefulWidget {
  final List<_HomeTabSelectItem> items;
  final ValueChanged<List<_HomeTabSelectItem>> onConfirm;

  const _SelectHomeFavDialog({
    required this.items,
    required this.onConfirm,
  });

  @override
  State<_SelectHomeFavDialog> createState() => _SelectHomeFavDialogState();
}

class _SelectHomeFavDialogState extends State<_SelectHomeFavDialog> {
  late final List<_HomeTabSelectItem> items;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('配置首页内容'),
          Text(
            '*可拖动排序',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.only(top: 12, bottom: 8),
      content: SizedBox(
        width: min(400, size.width * 0.9),
        height: min(420, size.height * 0.6),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final item = items.removeAt(oldIndex);
              items.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final item = items[index];
            final isHistory = item.id == HomeFavTab.historyId;
            return CheckboxListTile(
              key: ValueKey(item.id),
              value: item.selected,
              title: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 18,
                    color: isHistory
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Text(item.subtitle),
              secondary: const Icon(Icons.drag_indicator_rounded),
              onChanged: (val) {
                setState(() {
                  item.selected = val ?? false;
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () {
            final selected = items.where((e) => e.selected).toList();
            widget.onConfirm(selected);
            Get.back();
            SmartDialog.showToast('设置成功');
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
