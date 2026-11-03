import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/account_api.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// 打开修改密码弹窗。返回 true 表示修改成功。
Future<bool?> changePasswordDialog() async {
  final username = gFFI.userModel.userName.value;
  if (username.isEmpty) {
    showToast(translate('请先登录'));
    return false;
  }

  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirm = TextEditingController();

  String? oldMsg;
  String? newMsg;
  String? confirmMsg;
  var isInProgress = false;

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    onCancel() {
      if (isInProgress) return;
      close(false);
    }

    onSubmit() async {
      final o = oldPassword.text;
      final n = newPassword.text;
      final c = confirm.text;

      oldMsg = null;
      newMsg = null;
      confirmMsg = null;

      if (o.isEmpty) {
        setState(() => oldMsg = translate('原密码不能为空'));
        return;
      }
      if (n.isEmpty) {
        setState(() => newMsg = translate('新密码不能为空'));
        return;
      }
      if (n.length < 4) {
        setState(() => newMsg = translate('密码太短'));
        return;
      }
      if (n != c) {
        setState(() => confirmMsg = translate('密码不一致'));
        return;
      }

      setState(() => isInProgress = true);
      try {
        final r = await AccountApi.changePassword(username, o, n);
        if (r.code == 'OK') {
          close(true);
          return;
        }
        if (r.code == 'WRONG_ORIGINAL') {
          setState(() => oldMsg = translate('原密码错误'));
        } else {
          setState(() => newMsg = translate('修改密码失败，请稍后重试'));
        }
      } catch (_) {
        setState(() => newMsg = translate('网络异常，请稍后重试'));
      }
      setState(() => isInProgress = false);
    }

    final title = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: MyTheme.dialogPadding),
          child: Text(translate('修改密码')),
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
    );

    return CustomAlertDialog(
      title: title,
      titlePadding: EdgeInsets.fromLTRB(MyTheme.dialogPadding, 0, 0, 0),
      contentBoxConstraints: BoxConstraints(minWidth: 400),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          DialogTextField(
            title: translate(DialogTextField.kUsernameTitle),
            controller: TextEditingController(text: username),
            prefixIcon: DialogTextField.kUsernameIcon,
            errorText: null,
          ),
          PasswordWidget(
            title: translate('原密码'),
            controller: oldPassword,
            autoFocus: false,
            reRequestFocus: true,
            errorText: oldMsg,
          ),
          PasswordWidget(
            title: translate('新密码'),
            controller: newPassword,
            autoFocus: false,
            reRequestFocus: true,
            errorText: newMsg,
          ),
          PasswordWidget(
            title: translate('确认新密码'),
            controller: confirm,
            autoFocus: false,
            reRequestFocus: true,
            errorText: confirmMsg,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text(translate('确认修改'),
                  style: const TextStyle(fontSize: 16)),
              onPressed: isInProgress ? null : onSubmit,
            ),
          ),
        ],
      ),
      onCancel: onCancel,
      onSubmit: onSubmit,
    );
  });

  if (res == true) {
    showToast(translate('密码修改成功'));
    await gFFI.userModel.logOut();
  }
  return res;
}