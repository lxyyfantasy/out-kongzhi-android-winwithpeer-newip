import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/account_api.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';

Future<void> addDeviceDialog() async {
  final username = gFFI.userModel.userName.value;
  if (username.isEmpty) {
    showToast(translate('请先登录'));
    return;
  }

  final codeCtrl = TextEditingController();
  var remain = -1;
  var isInProgress = false;
  String? err;

  await gFFI.dialogManager.show<void>((setState, close, context) {
    if (remain < 0) {
      AccountApi.pendingCount().then((c) {
        if (!context.mounted) return;
        setState(() => remain = c);
      });
    }

    onCancel() {
      if (isInProgress) return;
      close();
    }

    Future<void> submit() async {
      err = null;
      final code = codeCtrl.text.trim();
      if (code.isEmpty) {
        setState(() => err = translate('添加设备码必填'));
        return;
      }
      setState(() => isInProgress = true);
      final r = await AccountApi.addDevice(username, code);
      setState(() => isInProgress = false);
      if (r.isOk) {
        showToast(translate('添加成功'));
        close();
        return;
      }
      if (r.code == 'CODE_ERROR') {
        setState(() => err = translate('添加设备码不对'));
      } else if (r.code == 'EMPTY') {
        setState(() => err = translate('设备库正在补充，请耐心等待'));
      } else {
        setState(() => err = r.msg.isNotEmpty ? r.msg : translate('添加失败'));
      }
    }

    return CustomAlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: MyTheme.dialogPadding),
            child: Text(translate('添加设备')),
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
          Text(
            remain < 0
                ? translate('查询中...')
                : '${translate('剩余')} $remain ${translate('台')}',
            style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 14),
          ),
          const SizedBox(height: 8),
          DialogTextField(
            title: translate('添加设备码'),
            controller: codeCtrl,
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