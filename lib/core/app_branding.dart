import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Nome visível da app (launcher, notificação, título Material).
const String kAppDisplayName = 'Vision';

/// Meta-data no AndroidManifest que aponta para @drawable/ic_notification.
const String kNotificationIconMetaName =
    'br.com.vision.vision_app.NOTIFICATION_ICON';

const NotificationIcon kForegroundNotificationIcon = NotificationIcon(
  metaDataName: kNotificationIconMetaName,
  backgroundColor: Color(0xFF1E40AF),
);
