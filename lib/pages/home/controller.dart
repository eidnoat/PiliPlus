import 'dart:async';

import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/home_fav_tab.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:PiliPlus/pages/fav_detail/controller.dart';
import 'package:PiliPlus/pages/history/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class HomeController extends GetxController
    with GetTickerProviderStateMixin, ScrollOrRefreshMixin {
  final RxList<HomeFavTab> tabs = <HomeFavTab>[].obs;
  TabController? tabController;

  RxBool? showTopBar;
  late final bool hideTopBar;

  bool enableSearchWord = false;
  late final RxString defaultSearch = ''.obs;
  late int lateCheckSearchAt = 0;

  final ScrollController _fallbackScrollController = ScrollController();

  ScrollOrRefreshMixin? get controller {
    if (tabs.isEmpty || tabController == null) return null;
    final index = tabController!.index;
    if (index < 0 || index >= tabs.length) return null;
    final tab = tabs[index];
    try {
      if (tab.isHistory) {
        return Get.find<HistoryController>(tag: 'home_history');
      }
      return Get.find<FavDetailController>(tag: 'home_fav_${tab.id}');
    } catch (_) {
      return null;
    }
  }

  @override
  ScrollController get scrollController =>
      controller?.scrollController ?? _fallbackScrollController;

  AccountService accountService = Get.find<AccountService>();

  @override
  void onInit() {
    super.onInit();

    hideTopBar = !Pref.useSideBar && Pref.hideTopBar;
    if (hideTopBar) {
      final mainCtr = Get.find<MainController>();
      switch (mainCtr.barHideType) {
        case .instant:
          showTopBar = RxBool(true);
        case .sync:
          mainCtr.barOffset ??= RxDouble(0.0);
      }
    }

    if (enableSearchWord) {
      lateCheckSearchAt = DateTime.now().millisecondsSinceEpoch;
      querySearchDefault();
    }

    setTabConfig();

    ever(accountService.isLogin, (bool isLogin) {
      if (isLogin && tabs.isEmpty) {
        _tryLoadDefaultFavFolder();
      }
    });
  }

  @override
  Future<void> onRefresh() {
    return controller?.onRefresh().catchError((e) {
      if (kDebugMode) debugPrint(e.toString());
    }) ?? Future.value();
  }

  void setTabConfig() {
    final cached = GStorage.setting.get(SettingBoxKey.homeFavFolderList) as List?;
    if (cached != null && cached.isNotEmpty) {
      tabs.assignAll(
        cached
            .map(
              (e) => HomeFavTab.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
      _initTabController();
    } else {
      tabs.clear();
      _initTabController();
      _tryLoadDefaultFavFolder();
    }
  }

  void _initTabController() {
    tabController?.dispose();
    if (tabs.isNotEmpty) {
      tabController = TabController(
        length: tabs.length,
        vsync: this,
      );
    } else {
      tabController = null;
    }
    update();
  }

  void setFolders(List<HomeFavTab> newTabs) {
    GStorage.setting.put(
      SettingBoxKey.homeFavFolderList,
      newTabs.map((e) => e.toJson()).toList(),
    );
    tabs.assignAll(newTabs);
    _initTabController();
  }

  Future<void> _tryLoadDefaultFavFolder() async {
    if (Accounts.main.isLogin) {
      final res = await FavHttp.allFavFolders(Accounts.main.mid);
      if (res case Success(:final response)) {
        final list = response.list;
        if (list != null && list.isNotEmpty && tabs.isEmpty) {
          final defaultFolder = list.first;
          final newTabs = [
            HomeFavTab(id: defaultFolder.id, title: defaultFolder.title),
          ];
          setFolders(newTabs);
        }
      }
    }
  }

  @override
  void dispose() {
    _fallbackScrollController.dispose();
    tabController?.dispose();
    super.dispose();
  }

  Future<void> querySearchDefault() async {
    try {
      final res = await Request().get(
        Api.searchDefault,
        queryParameters: await WbiSign.makSign({'web_location': 333.1365}),
      );
      if (res.data['code'] == 0) {
        defaultSearch.value = res.data['data']?['name'] ?? '';
      }
    } catch (_) {}
  }
}
