import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/media.dart';
import 'package:PiliPlus/utils/date_util.dart';
import 'package:PiliPlus/utils/duration_util.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// 收藏视频卡片 - 水平布局
class FavVideoCardH extends StatelessWidget {
  final FavDetailItemModel item;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final VoidCallback? onDelFav;
  final VoidCallback? onViewFav;
  final bool? isSort;

  const FavVideoCardH({
    super.key,
    required this.item,
    this.onDelFav,
    this.onTap,
    this.onLongPress,
    this.onViewFav,
    this.isSort,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: isSort == true
            ? null
            : onTap ??
                  () {
                    if (!const [0, 16].contains(item.attr)) {
                      Get.toNamed('/member?mid=${item.upper?.mid}');
                      return;
                    }

                    // pgc
                    if (item.type == 24) {
                      PageUtils.viewPgc(
                        seasonId: item.ogv!.seasonId,
                        epId: item.id,
                      );
                      return;
                    }

                    onViewFav?.call();
                  },
        onLongPress: isSort == true
            ? null
            : onLongPress ??
                  () => imageSaveDialog(
                    title: item.title,
                    cover: item.cover,
                    bvid: item.bvid,
                  ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleString.safeSpace,
            vertical: 5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: StyleString.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    double maxWidth = boxConstraints.maxWidth;
                    double maxHeight = boxConstraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: item.cover,
                          width: maxWidth,
                          height: maxHeight,
                        ),
                        PBadge(
                          text: DurationUtil.formatDuration(item.duration),
                          right: 6.0,
                          bottom: 6.0,
                          type: PBadgeType.gray,
                        ),
                        PBadge(
                          text: item.ogv?.typeName,
                          top: 6.0,
                          right: 6.0,
                          bottom: null,
                          left: null,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              content(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            spacing: 3,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title!,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.type == 24 && item.intro?.isNotEmpty == true)
                Text(
                  item.intro!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.outline,
                  ),
                ),
              const Spacer(),
              Text(
                '${DateUtil.dateFormat(item.favTime)} ${item.upper?.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  height: 1,
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              if (item.type != 24)
                Row(
                  spacing: 8,
                  children: [
                    StatWidget(
                      type: StatType.play,
                      value: item.cntInfo?.play,
                    ),
                    StatWidget(
                      type: StatType.danmaku,
                      value: item.cntInfo?.danmaku,
                    ),
                  ],
                ),
            ],
          ),
          if (onDelFav != null)
            Positioned(
              right: 0,
              bottom: -8,
              child: iconButton(
                context: context,
                icon: Icons.clear,
                tooltip: '取消收藏',
                iconColor: theme.colorScheme.outline,
                bgColor: Colors.transparent,
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('提示'),
                      content: const Text('要取消收藏吗?'),
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
                            onDelFav!();
                          },
                          child: const Text('确定取消'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
