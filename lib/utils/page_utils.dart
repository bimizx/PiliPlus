import 'dart:math';

import 'package:PiliPlus/common/widgets/interactiveviewer_gallery/interactiveviewer_gallery.dart';
import 'package:PiliPlus/grpc/im.dart';
import 'package:PiliPlus/http/dynamics.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/models/common/search_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/section.dart';
import 'package:PiliPlus/pages/common/common_intro_controller.dart';
import 'package:PiliPlus/pages/contact/view.dart';
import 'package:PiliPlus/pages/fav_panel/view.dart';
import 'package:PiliPlus/pages/share/view.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/menu_row.dart';
import 'package:PiliPlus/services/shutdown_timer_service.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/url_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:floating/floating.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class PageUtils {
  static Future<void> pmShare(
    BuildContext context, {
    required Map content,
  }) async {
    // if (kDebugMode) debugPrint(content.toString());

    int? selectedIndex;
    List<UserModel> userList = <UserModel>[];

    final shareListRes = await ImGrpc.shareList(size: 3);
    if (shareListRes.isSuccess && shareListRes.data.sessionList.isNotEmpty) {
      userList.addAll(
        shareListRes.data.sessionList
            .map<UserModel>(
              (item) => UserModel(
                mid: item.talkerId.toInt(),
                name: item.talkerUname,
                avatar: item.talkerIcon,
              ),
            )
            .toList(),
      );
    } else if (context.mounted) {
      UserModel? userModel = await Navigator.of(context).push(
        GetPageRoute(page: () => const ContactPage()),
      );
      if (userModel != null) {
        selectedIndex = 0;
        userList.add(userModel);
      }
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SharePanel(
          content: content,
          userList: userList,
          selectedIndex: selectedIndex,
        ),
        useSafeArea: true,
        enableDrag: false,
        isScrollControlled: true,
      );
    }
  }

  static void scheduleExit(
    BuildContext context,
    isFullScreen, [
    bool isLive = false,
  ]) {
    if (!context.mounted) {
      return;
    }
    const List<int> scheduleTimeChoices = [0, 15, 30, 45, 60];
    const TextStyle titleStyle = TextStyle(fontSize: 14);
    if (isLive) {
      shutdownTimerService.waitForPlayingCompleted = false;
    }
    showVideoBottomSheet(
      context,
      isFullScreen: () => isFullScreen,
      child: StatefulBuilder(
        builder: (_, setState) {
          void onTap(int choice) {
            if (choice == -1) {
              showDialog(
                context: context,
                builder: (context) {
                  final ThemeData theme = Theme.of(context);
                  String duration = '';
                  return AlertDialog(
                    title: const Text('自定义时长'),
                    content: TextField(
                      autofocus: true,
                      onChanged: (value) => duration = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(suffixText: 'min'),
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
                          Get.back();
                          int choice = int.tryParse(duration) ?? 0;
                          shutdownTimerService
                            ..scheduledExitInMinutes = choice
                            ..startShutdownTimer();
                          setState(() {});
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  );
                },
              );
            } else {
              Get.back();
              shutdownTimerService.scheduledExitInMinutes = choice;
              shutdownTimerService.startShutdownTimer();
            }
          }

          final ThemeData theme = Theme.of(context);
          return Theme(
            data: theme,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                clipBehavior: Clip.hardEdge,
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  children: [
                    const Center(child: Text('定时关闭', style: titleStyle)),
                    const SizedBox(height: 10),
                    ...[
                      ...[
                        ...scheduleTimeChoices,
                        if (!scheduleTimeChoices.contains(
                          shutdownTimerService.scheduledExitInMinutes,
                        ))
                          shutdownTimerService.scheduledExitInMinutes,
                      ]..sort(),
                      -1,
                    ].map(
                      (choice) => ListTile(
                        dense: true,
                        onTap: () => onTap(choice),
                        title: Text(
                          choice == -1
                              ? '自定义'
                              : choice == 0
                              ? "禁用"
                              : "$choice分钟后",
                          style: titleStyle,
                        ),
                        trailing:
                            shutdownTimerService.scheduledExitInMinutes ==
                                choice
                            ? Icon(
                                size: 20,
                                Icons.done,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                    if (!isLive) ...[
                      Builder(
                        builder: (context) {
                          return ListTile(
                            dense: true,
                            onTap: () {
                              shutdownTimerService.waitForPlayingCompleted =
                                  !shutdownTimerService.waitForPlayingCompleted;
                              (context as Element).markNeedsBuild();
                            },
                            title: const Text("额外等待视频播放完毕", style: titleStyle),
                            trailing: Transform.scale(
                              alignment: Alignment.centerRight,
                              scale: 0.8,
                              child: Switch(
                                thumbIcon:
                                    WidgetStateProperty.resolveWith<Icon?>((
                                      Set<WidgetState> states,
                                    ) {
                                      if (states.isNotEmpty &&
                                          states.first ==
                                              WidgetState.selected) {
                                        return const Icon(Icons.done);
                                      }
                                      return null;
                                    }),
                                value: shutdownTimerService
                                    .waitForPlayingCompleted,
                                onChanged: (value) {
                                  shutdownTimerService.waitForPlayingCompleted =
                                      value;
                                  (context as Element).markNeedsBuild();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        return Row(
                          children: [
                            const SizedBox(width: 18),
                            const Text('倒计时结束:', style: titleStyle),
                            const Spacer(),
                            ActionRowLineItem(
                              onTap: () {
                                shutdownTimerService.exitApp = false;
                                (context as Element).markNeedsBuild();
                              },
                              text: " 暂停视频 ",
                              selectStatus: !shutdownTimerService.exitApp,
                            ),
                            const Spacer(),
                            ActionRowLineItem(
                              onTap: () {
                                shutdownTimerService.exitApp = true;
                                (context as Element).markNeedsBuild();
                              },
                              text: " 退出APP ",
                              selectStatus: shutdownTimerService.exitApp,
                            ),
                            const SizedBox(width: 25),
                          ],
                        );
                      },
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

  static Future<void> pushDynFromId({id, rid, bool off = false}) async {
    SmartDialog.showLoading();
    var res = await DynamicsHttp.dynamicDetail(
      id: id,
      rid: rid,
      type: rid != null ? 2 : null,
    );
    SmartDialog.dismiss();
    if (res['status']) {
      DynamicItemModel data = res['data'];
      if (data.basic?.commentType == 12) {
        toDupNamed(
          '/articlePage',
          parameters: {
            'id': id,
            'type': 'opus',
          },
          off: off,
        );
      } else {
        toDupNamed(
          '/dynamicDetail',
          arguments: {
            'item': res['data'],
          },
          off: off,
        );
      }
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  static void showFavBottomSheet({
    required BuildContext context,
    required CommonIntroController ctr,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: const AnimationStyle(curve: Curves.ease),
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          minChildSize: 0,
          maxChildSize: 1,
          initialChildSize: 0.7,
          snap: true,
          expand: false,
          snapSizes: const [0.7],
          builder: (BuildContext context, ScrollController scrollController) {
            return FavPanel(
              ctr: ctr,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  static void reportVideo(int aid) {
    Get.toNamed(
      '/webview',
      parameters: {'url': 'https://www.bilibili.com/appeal/?avid=$aid'},
    );
  }

  static void enterPip({int? width, int? height}) {
    if (width != null && height != null) {
      Rational aspectRatio = Rational(width, height);
      Floating().enable(
        EnableManual(
          aspectRatio: aspectRatio.fitsInAndroidRequirements
              ? aspectRatio
              : height > width
              ? const Rational.vertical()
              : const Rational.landscape(),
        ),
      );
    } else {
      Floating().enable(const EnableManual());
    }
  }

  static Future<void> pushDynDetail(
    DynamicItemModel item,
    floor, {
    action = 'all',
  }) async {
    feedBack();

    void push() {
      if (item.basic?.commentType == 12) {
        toDupNamed(
          '/articlePage',
          parameters: {
            'id': item.idStr,
            'type': 'opus',
          },
        );
      } else {
        toDupNamed(
          '/dynamicDetail',
          arguments: {
            'item': item,
          },
        );
      }
    }

    /// 点击评论action 直接查看评论
    if (action == 'comment') {
      push();
      return;
    }

    // if (kDebugMode) debugPrint('pushDynDetail: ${item.type}');

    switch (item.type) {
      case 'DYNAMIC_TYPE_AV':
        if (item.modules.moduleDynamic?.major?.archive?.type == 2) {
          if (item.modules.moduleDynamic!.major!.archive!.jumpUrl!.startsWith(
            '//',
          )) {
            item.modules.moduleDynamic!.major!.archive!.jumpUrl =
                'https:${item.modules.moduleDynamic!.major!.archive!.jumpUrl!}';
          }
          String? redirectUrl = await UrlUtils.parseRedirectUrl(
            item.modules.moduleDynamic!.major!.archive!.jumpUrl!,
            false,
          );
          if (redirectUrl != null) {
            viewPgcFromUri(redirectUrl);
            return;
          }
        }

        try {
          String bvid = item.modules.moduleDynamic!.major!.archive!.bvid!;
          String cover = item.modules.moduleDynamic!.major!.archive!.cover!;
          int? cid = await SearchHttp.ab2c(bvid: bvid);
          if (cid != null) {
            toVideoPage(
              'bvid=$bvid&cid=$cid',
              arguments: {
                'pic': cover,
                'heroTag': Utils.makeHeroTag(bvid),
              },
              preventDuplicates: false,
            );
          }
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;

      /// 专栏文章查看
      case 'DYNAMIC_TYPE_ARTICLE':
        toDupNamed(
          '/articlePage',
          parameters: {
            'id': item.idStr,
            'type': 'opus',
          },
        );
        break;
      case 'DYNAMIC_TYPE_PGC':
        if (kDebugMode) debugPrint('番剧');
        SmartDialog.showToast('暂未支持的类型，请联系开发者');
        break;

      case 'DYNAMIC_TYPE_LIVE_RCMD':
        DynamicLiveModel liveRcmd =
            item.modules.moduleDynamic!.major!.liveRcmd!;
        toDupNamed('/liveRoom?roomid=${liveRcmd.roomId}');
        break;

      /// 合集查看
      case 'DYNAMIC_TYPE_UGC_SEASON':
        DynamicArchiveModel ugcSeason =
            item.modules.moduleDynamic!.major!.ugcSeason!;
        int aid = ugcSeason.aid!;
        String bvid = IdUtils.av2bv(aid);
        String cover = ugcSeason.cover!;
        int? cid = await SearchHttp.ab2c(bvid: bvid);
        if (cid != null) {
          toVideoPage(
            'bvid=$bvid&cid=$cid',
            arguments: {
              'pic': cover,
              'heroTag': Utils.makeHeroTag(bvid),
            },
            preventDuplicates: false,
          );
        }
        break;

      /// 番剧查看
      case 'DYNAMIC_TYPE_PGC_UNION':
        if (kDebugMode) debugPrint('DYNAMIC_TYPE_PGC_UNION 番剧');
        DynamicArchiveModel pgc = item.modules.moduleDynamic!.major!.pgc!;
        if (pgc.epid != null) {
          viewPgc(epId: pgc.epid);
        }
        break;
      case 'DYNAMIC_TYPE_MEDIALIST':
        if (item.modules.moduleDynamic?.major?.medialist != null) {
          final String? url =
              item.modules.moduleDynamic!.major!.medialist!.jumpUrl;
          if (url?.contains('medialist/detail/ml') == true) {
            Get.toNamed(
              '/favDetail',
              parameters: {
                'heroTag':
                    '${item.modules.moduleDynamic!.major!.medialist!.cover}',
                'mediaId':
                    '${item.modules.moduleDynamic!.major!.medialist!.id}',
              },
            );
          } else if (url != null) {
            handleWebview(url.http2https);
          }
        }
        break;

      // case 'DYNAMIC_TYPE_COURSES_SEASON':
      // 纯文字动态查看
      // case 'DYNAMIC_TYPE_WORD':
      // # 装扮/剧集点评/普通分享
      // case 'DYNAMIC_TYPE_COMMON_SQUARE':
      // 转发的动态
      // case 'DYNAMIC_TYPE_FORWARD':
      // 图文动态查看
      // case 'DYNAMIC_TYPE_DRAW':
      default:
        push();
        break;
    }
  }

  static void onHorizontalPreview(
    GlobalKey<ScaffoldState> key,
    transitionAnimationController,
    ctr,
    List<String> imgList,
    index,
    onClose,
  ) {
    key.currentState?.showBottomSheet(
      (context) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(ctr),
          child: InteractiveviewerGallery(
            sources: imgList.map((url) => SourceModel(url: url)).toList(),
            initIndex: index,
            setStatusBar: false,
            onClose: onClose,
            quality: GlobalData().imgQuality,
          ),
        );
      },
      enableDrag: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      transitionAnimationController: transitionAnimationController,
      sheetAnimationStyle: const AnimationStyle(duration: Duration.zero),
    );
  }

  static void inAppWebview(
    String url, {
    bool off = false,
  }) {
    if (Pref.openInBrowser) {
      launchURL(url);
    } else {
      if (off) {
        Get.offNamed(
          '/webview',
          parameters: {'url': url},
          arguments: {'inApp': true},
        );
      } else {
        Get.toNamed(
          '/webview',
          parameters: {'url': url},
          arguments: {'inApp': true},
        );
      }
    }
  }

  static Future<void> launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        SmartDialog.showToast('Could not launch $url');
      }
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  static Future<void> handleWebview(
    String url, {
    bool off = false,
    bool inApp = false,
    Map? parameters,
  }) async {
    if (!inApp && Pref.openInBrowser) {
      if (!await PiliScheme.routePushFromUrl(url, selfHandle: true)) {
        launchURL(url);
      }
    } else {
      if (off) {
        Get.offNamed(
          '/webview',
          parameters: {
            'url': url,
            ...?parameters,
          },
        );
      } else {
        PiliScheme.routePushFromUrl(url, parameters: parameters);
      }
    }
  }

  static void showVideoBottomSheet(
    BuildContext context, {
    required Widget child,
    required Function isFullScreen,
    double? padding,
  }) {
    if (!context.mounted) {
      return;
    }
    Get.generalDialog(
      barrierLabel: '',
      barrierDismissible: true,
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return MediaQuery.orientationOf(Get.context!) == Orientation.portrait
            ? SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    Expanded(flex: 7, child: child),
                    if (isFullScreen() && padding != null)
                      SizedBox(height: padding),
                  ],
                ),
              )
            : SafeArea(
                child: Row(
                  children: [
                    const Spacer(),
                    Expanded(child: child),
                  ],
                ),
              );
      },
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin =
            MediaQuery.orientationOf(Get.context!) == Orientation.portrait
            ? const Offset(0.0, 1.0)
            : const Offset(1.0, 0.0);
        var tween = Tween(
          begin: begin,
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      routeSettings: RouteSettings(arguments: Get.arguments),
    );
  }

  static void toVideoPage(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
    bool off = false,
  }) {
    if (off) {
      Get.offNamed(
        '/videoV?$page',
        arguments: arguments,
        id: id,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
      );
    } else {
      Get.toNamed(
        '/videoV?$page',
        arguments: arguments,
        id: id,
        preventDuplicates: preventDuplicates,
        parameters: parameters,
      );
    }
  }

  static final _pgcRegex = RegExp(r'(ep|ss)(\d+)');
  static bool viewPgcFromUri(String uri, {String? progress}) {
    RegExpMatch? match = _pgcRegex.firstMatch(uri);
    if (match != null) {
      bool isSeason = match.group(1) == 'ss';
      String id = match.group(2)!;
      viewPgc(
        seasonId: isSeason ? id : null,
        epId: isSeason ? null : id,
        progress: progress,
      );
      return true;
    }
    return false;
  }

  static Future<void> viewPgc({
    dynamic seasonId,
    dynamic epId,
    String? progress,
  }) async {
    try {
      SmartDialog.showLoading(msg: '资源获取中');
      var result = await SearchHttp.pgcInfo(seasonId: seasonId, epId: epId);
      SmartDialog.dismiss();
      if (result.isSuccess) {
        PgcInfoModel data = result.data;

        // epId episode -> progress episode -> first episode
        EpisodeItem? episode;

        if (epId != null) {
          if (data.episodes?.isNotEmpty == true) {
            episode = data.episodes!.firstWhereOrNull(
              (item) {
                return item.epId.toString() == epId.toString();
              },
            );
          }
          if (episode == null && data.section?.isNotEmpty == true) {
            for (Section item in data.section!) {
              if (item.episodes?.isNotEmpty == true) {
                for (EpisodeItem item in item.episodes!) {
                  if (item.epId.toString() == epId.toString()) {
                    // view as normal video
                    toVideoPage(
                      'bvid=${item.bvid}&cid=${item.cid}&seasonId=${data.seasonId}&epId=${item.epId}',
                      arguments: {
                        'pgcApi': true,
                        'pic': item.cover,
                        'heroTag': Utils.makeHeroTag(item.cid),
                        'videoType': SearchType.video,
                        if (progress != null)
                          'progress': int.tryParse(progress),
                      },
                      preventDuplicates: false,
                    );
                    return;
                  }
                }
              }
            }
          }
        }

        if (data.episodes.isNullOrEmpty) {
          SmartDialog.showToast('资源加载失败');
          return;
        }

        episode ??= data.userStatus?.progress?.lastEpId != null
            ? data.episodes!.firstWhereOrNull(
                    (item) => item.epId == data.userStatus?.progress?.lastEpId,
                  ) ??
                  data.episodes!.first
            : data.episodes!.first;
        toVideoPage(
          'bvid=${episode.bvid}&cid=${episode.cid}&seasonId=${data.seasonId}&epId=${episode.epId}&type=${data.type}',
          arguments: {
            'pic': episode.cover,
            'heroTag': Utils.makeHeroTag(episode.cid),
            'videoType': SearchType.media_bangumi,
            'pgcItem': data,
            if (progress != null) 'progress': int.tryParse(progress),
          },
          preventDuplicates: false,
        );
      } else {
        result.toast();
      }
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('$e');
      if (kDebugMode) debugPrint('$e');
    }
  }

  static void toDupNamed(
    String page, {
    dynamic arguments,
    Map<String, String>? parameters,
    bool off = false,
  }) {
    if (off) {
      Get.offNamed(
        page,
        arguments: arguments,
        parameters: parameters,
        preventDuplicates: false,
      );
    } else {
      Get.toNamed(
        page,
        arguments: arguments,
        parameters: parameters,
        preventDuplicates: false,
      );
    }
  }
}
