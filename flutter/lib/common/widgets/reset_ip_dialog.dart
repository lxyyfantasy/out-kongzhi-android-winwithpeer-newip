import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/account_api.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';

Future<void> resetIpDialog() async {
  final ipCtrl = TextEditingController();
  var isInProgress = false;
  String? err;

  await gFFI.dialogManager.show<void>((setState, close, context) {
    onCancel() {
      if (isInProgress) return;
      close();
    }

    Future<void> submit() async {
      err = null;
      final ip = ipCtrl.text.trim();
      if (ip.isEmpty) {
        setState(() => err = translate('IP必填'));
        return;
      }
      setState(() => isInProgress = true);
      final ok = await AccountApi.probeServerConfig(ip);
      setState(() => isInProgress = false);
      if (!ok) {
        setState(() => err = translate('该地址不是有效服务器'));
        return;
      }
      await bind.mainSetOption(key: 'external-primary-server', value: ip);
      showToast(translate('重置成功，请重启App生效'));
      close();
    }

    return CustomAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: MyTheme.dialogPadding),
            child: Text(translate('重置IP')),
          ),
          Padding(
            padding: EdgeInsets.only(top: 10, right: 15),
            child: InkWell(
              child: Icon(
                Icons.close,
                size: 22,
                color: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.color
                    ?.withOpacity(0.55),
              ),
              onTap: onCancel,
            ),
          ),
        ],
      ),
      titlePadding: EdgeInsets.fromLTRB(MyTheme.dialogPadding, 0, 0, 0),
      contentBoxConstraints: BoxConstraints(minWidth: 400),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          DialogTextField(
            title: translate('服务器IP'),
            controller: ipCtrl,
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(err!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          if (isInProgress) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            width: 200,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9E9E9E),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text(translate('提交'),
                  style: const TextStyle(fontSize: 16)),
              onPressed: isInProgress ? null : submit,
            ),
          ),
        ],
      ),
      onCancel: onCancel,
    );
  });
}