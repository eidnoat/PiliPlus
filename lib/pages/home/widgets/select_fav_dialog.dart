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

class _FavFolderSelectItem {
  final FavFolderInfo folder;
  bool selected;

  _FavFolderSelectItem({required this.folder, required this.selected});
}

Future<void> showSelectHomeFavDialog(BuildContext context) async {
  if (!Accounts.main.isLogin) {
    SmartDialog.showToast('请先登录');
    return;
  }

  SmartDialog.showLoading(msg: '加载收藏夹中...');
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

  if (allFolders.isEmpty) {
    SmartDialog.showToast('未找到收藏夹');
    return;
  }

  final homeController = Get.find<HomeController>();
  final currentTabs = homeController.tabs.toList();
  final currentSelectedIds = currentTabs.map((e) => e.id).toSet();

  List<_FavFolderSelectItem> items = [];
  for (final tab in currentTabs) {
    final match = allFolders.firstWhereOrNull((f) => f.id == tab.id);
    if (match != null) {
      items.add(_FavFolderSelectItem(folder: match, selected: true));
    } else {
      items.add(
        _FavFolderSelectItem(
          folder: FavFolderInfo(id: tab.id, title: tab.title),
          selected: true,
        ),
      );
    }
  }

  for (final folder in allFolders) {
    if (!currentSelectedIds.contains(folder.id)) {
      items.add(_FavFolderSelectItem(folder: folder, selected: false));
    }
  }

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) => _SelectHomeFavDialog(
      items: items,
      onConfirm: (selected) {
        final newTabs = selected
            .map((e) => HomeFavTab(id: e.folder.id, title: e.folder.title))
            .toList();
        homeController.setFolders(newTabs);
      },
    ),
  );
}

class _SelectHomeFavDialog extends StatefulWidget {
  final List<_FavFolderSelectItem> items;
  final ValueChanged<List<_FavFolderSelectItem>> onConfirm;

  const _SelectHomeFavDialog({
    required this.items,
    required this.onConfirm,
  });

  @override
  State<_SelectHomeFavDialog> createState() => _SelectHomeFavDialogState();
}

class _SelectHomeFavDialogState extends State<_SelectHomeFavDialog> {
  late final List<_FavFolderSelectItem> items;

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
          const Text('选择首页收藏夹'),
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
            return CheckboxListTile(
              key: ValueKey(item.folder.id),
              value: item.selected,
              title: Text(
                item.folder.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('共 ${item.folder.mediaCount} 条内容'),
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
