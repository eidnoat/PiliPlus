import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/home_fav_tab.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/fav_detail/controller.dart';
import 'package:PiliPlus/pages/fav_detail/widget/fav_video_card.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/home/widgets/select_fav_dialog.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      Widget tabBar;
      if (_homeController.tabs.length > 1 &&
          _homeController.tabController != null) {
        tabBar = Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            height: 42,
            width: double.infinity,
            child: TabBar(
              controller: _homeController.tabController,
              tabs: _homeController.tabs
                  .map((e) => Tab(text: e.title))
                  .toList(),
              isScrollable: true,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              splashBorderRadius: Style.mdRadius,
              tabAlignment: TabAlignment.center,
              onTap: (_) {
                feedBack();
                if (!_homeController.tabController!.indexIsChanging) {
                  _homeController.animateToTop();
                }
              },
            ),
          ),
        );
        if (_homeController.hideTopBar &&
            _mainController.barHideType == .instant) {
          tabBar = Material(
            color: _colorScheme.surface,
            child: tabBar,
          );
        }
      } else {
        tabBar = const SizedBox(height: 6);
      }

      Widget content;
      if (_homeController.tabs.isEmpty) {
        content = _buildEmptyView();
      } else if (_homeController.tabs.length == 1) {
        content = HomeFavFolderView(
          key: ValueKey(_homeController.tabs.first.id),
          tab: _homeController.tabs.first,
        );
      } else {
        content = tabBarView(
          controller: _homeController.tabController!,
          children: _homeController.tabs
              .map(
                (tab) => HomeFavFolderView(
                  key: ValueKey(tab.id),
                  tab: tab,
                ),
              )
              .toList(),
        );
      }

      return Column(
        children: [
          if (!_mainController.useSideBar &&
              MediaQuery.sizeOf(context).isPortrait)
            customAppBar(),
          tabBar,
          Expanded(
            child: onBuild(content),
          ),
        ],
      );
    });
  }

  Widget _buildEmptyView() {
    final isLogin = _mainController.accountService.isLogin.value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLogin ? Icons.bookmarks_outlined : Icons.account_circle_outlined,
              size: 64,
              color: _colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isLogin ? '首页暂无收藏夹' : '未登录',
              style: TextStyle(
                fontSize: 16,
                color: _colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLogin ? '点击下方按钮选择要在首页展示的收藏夹' : '请先登录后选择收藏夹展示在首页',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                if (isLogin) {
                  showSelectHomeFavDialog(context);
                } else {
                  Get.toNamed('/login');
                }
              },
              icon: Icon(isLogin ? Icons.add : Icons.login),
              label: Text(isLogin ? '选择收藏夹' : '前往登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget customAppBar() {
    const padding = EdgeInsets.fromLTRB(14, 6, 14, 0);
    final child = Row(
      children: [
        searchBar(),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '选择首页收藏夹',
          icon: const Icon(Icons.bookmarks_outlined),
          onPressed: () => showSelectHomeFavDialog(context),
        ),
        const SizedBox(width: 4),
        userAvatar(colorScheme: _colorScheme, mainController: _mainController),
      ],
    );
    if (_homeController.hideTopBar) {
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () {
            final offset = barOffset.value;
            return CustomHeightWidget(
              offset: Offset(0, -offset),
              height: Style.topBarHeight - offset,
              child: Padding(
                padding: padding,
                child: child,
              ),
            );
          },
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(() {
          final showSearchBar = showTopBar.value;
          return AnimatedOpacity(
            opacity: showSearchBar ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedContainer(
              curve: Curves.easeInOutCubicEmphasized,
              duration: const Duration(milliseconds: 500),
              height: showSearchBar ? Style.topBarHeight : 0,
              padding: padding,
              child: child,
            ),
          );
        });
      }
    }
    return Container(
      height: Style.topBarHeight,
      padding: padding,
      child: child,
    );
  }

  Widget searchBar() {
    const borderRadius = BorderRadius.all(Radius.circular(25));
    return Expanded(
      child: SizedBox(
        height: 44,
        child: Material(
          borderRadius: borderRadius,
          color: _colorScheme.onSecondaryContainer.withValues(alpha: 0.05),
          child: InkWell(
            borderRadius: borderRadius,
            splashColor: _colorScheme.primaryContainer.withValues(
              alpha: 0.3,
            ),
            onTap: () => Get.toNamed('/search'),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_outlined,
                  color: _colorScheme.onSecondaryContainer,
                  semanticLabel: '搜索',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '搜索',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _colorScheme.outline),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeFavFolderView extends StatefulWidget {
  final HomeFavTab tab;
  const HomeFavFolderView({super.key, required this.tab});

  @override
  State<HomeFavFolderView> createState() => _HomeFavFolderViewState();
}

class _HomeFavFolderViewState extends State<HomeFavFolderView>
    with AutomaticKeepAliveClientMixin, GridMixin {
  late final FavDetailController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      FavDetailController(initialMediaId: widget.tab.id),
      tag: 'home_fav_${widget.tab.id}',
    );
  }

  @override
  void dispose() {
    Get.delete<FavDetailController>(tag: 'home_fav_${widget.tab.id}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return refreshIndicator(
      onRefresh: controller.onRefresh,
      child: CustomScrollView(
        controller: controller.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(
              left: Style.safeSpace,
              right: Style.safeSpace,
              top: Style.cardSpace,
              bottom: 100,
            ),
            sliver: Obx(
              () => _buildBody(theme, controller.loadingState.value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    LoadingState<List<FavDetailItemModel>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => gridSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length) {
                    controller.onLoadMore();
                    return Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: Text(
                        controller.isEnd ? '没有更多了' : '加载中...',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  final item = response[index];
                  return FavVideoCardH(
                    item: item,
                    index: index,
                    ctr: controller,
                  );
                },
                itemCount: response.length + 1,
              )
            : HttpError(
                errMsg: '收藏夹为空',
                onReload: controller.onReload,
              ),
      Error(:final errMsg) => HttpError(
          errMsg: errMsg,
          onReload: controller.onReload,
        ),
    };
  }
}

Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
}) {
  return Semantics(
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                width: 34,
                height: 34,
                src: mainController.accountService.face.value,
              ),
              Positioned.fill(
                child: Material(
                  type: .transparency,
                  child: InkWell(
                    onTap: mainController.toMinePage,
                    splashColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Obx(
                  () => MineController.anonymity.value
                      ? IgnorePointer(
                          child: Container(
                            padding: const .all(2),
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              size: 14,
                              MdiIcons.incognito,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}

Widget msgBadge(MainController mainController) {
  return Obx(
    () {
      if (mainController.accountService.isLogin.value) {
        final count = mainController.msgUnReadCount.value;
        final isNumBadge = mainController.msgBadgeMode == .number;
        return IconButton(
          tooltip: '消息',
          onPressed: () {
            mainController
              ..clearUnreadMsg()
              ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
            Get.toNamed('/whisper');
          },
          icon: Badge(
            isLabelVisible:
                mainController.msgBadgeMode != .hidden && count != null,
            alignment: isNumBadge
                ? const Alignment(0.0, -0.85)
                : const Alignment(1.0, -0.85),
            label: isNumBadge && count != null ? Text(count) : null,
            child: const Icon(Icons.notifications_none),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
