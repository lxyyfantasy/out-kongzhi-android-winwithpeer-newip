import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/account_api.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';

/// 注册/找回密码弹窗，两个分页
Future<void> registerRecoverDialog() async {
  var tab = 0; // 0注册 1找回密码
  var isInProgress = false;
  String? err;

  final uCtrl = TextEditingController();
  final pCtrl = TextEditingController();
  final p2Ctrl = TextEditingController();
  final a1Ctrl = TextEditingController();
  final a2Ctrl = TextEditingController();
  final a3Ctrl = TextEditingController();
  final invCtrl = TextEditingController();
  final npCtrl = TextEditingController();

  await gFFI.dialogManager.show<void>((setState, close, context) {

    onCancel() {
      if (isInProgress) return;
      close();
    }

    Future<void> doRegister() async {
      err = null;
      final u = uCtrl.text.trim();
      final p = pCtrl.text;
      final p2 = p2Ctrl.text;
      final a1 = a1Ctrl.text;
      final a2 = a2Ctrl.text;
      final a3 = a3Ctrl.text;
      final inv = invCtrl.text.trim();
      if (u.isEmpty ||
          p.isEmpty ||
          p2.isEmpty ||
          a1.isEmpty ||
          a2.isEmpty ||
          a3.isEmpty ||
          inv.isEmpty) {
        setState(() => err = translate('所有格子不能为空'));
        return;
      }
      if (p.length < 4) {
        setState(() => err = translate('密码不能少于4位'));
        return;
      }
      if (p != p2) {
        setState(() => err = translate('两次密码不一致'));
        return;
      }
      setState(() => isInProgress = true);
      final r = await AccountApi.register(u, p, a1, a2, a3, inv);
      setState(() => isInProgress = false);
      if (r.isOk) {
        showToast(translate('注册成功'));
        close();
        return;
      }
      if (r.code == 'INVITE_ERROR') {
        setState(() => err = translate('邀请码错误'));
      } else if (r.msg.contains('已存在')) {
        setState(() => err = translate('账号重复'));
      } else {
        setState(() => err = r.msg.isNotEmpty ? r.msg : translate('注册失败'));
      }
    }

    Future<void> doRecover() async {
      err = null;
      final u = uCtrl.text.trim();
      final a1 = a1Ctrl.text;
      final a2 = a2Ctrl.text;
      final a3 = a3Ctrl.text;
      final np = npCtrl.text;
      if (u.isEmpty || a1.isEmpty || a2.isEmpty || a3.isEmpty || np.isEmpty) {
        setState(() => err = translate('所有格子不能为空'));
        return;
      }
      if (np.length < 4) {
        setState(() => err = translate('新密码不能少于4位'));
        return;
      }
      setState(() => isInProgress = true);
      final r = await AccountApi.recoverPassword(u, a1, a2, a3, np);
      setState(() => isInProgress = false);
      if (r.isOk) {
        showToast(translate('密码修改成功'));
        close();
        return;
      }
      setState(() => err = r.msg.isNotEmpty ? r.msg : translate('找回密码失败'));
    }

    final title = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: MyTheme.dialogPadding),
          child: Text(translate(tab == 0 ? '账号注册' : '找回密码')),
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
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: isInProgress
                      ? null
                      : () => setState(() {
                            tab = 0;
                            err = null;
                          }),
                  child: Text(translate('注册'),
                      style: TextStyle(
                          color: tab == 0
                              ? const Color(0xFF2E7D32)
                              : Colors.grey)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: isInProgress
                      ? null
                      : () => setState(() {
                            tab = 1;
                            err = null;
                          }),
                  child: Text(translate('找回密码'),
                      style: TextStyle(
                          color: tab == 1
                              ? const Color(0xFF2E7D32)
                              : Colors.grey)),
                ),
              ),
            ],
          ),
          DialogTextField(
            title: translate('账号'),
            controller: uCtrl,
            prefixIcon: DialogTextField.kUsernameIcon,
          ),
          if (tab == 0) ...[
            PasswordWidget(title: '密码', controller: pCtrl),
            PasswordWidget(title: '验证密码', controller: p2Ctrl),
          ],
          DialogTextField(
              title: translate('小学名称是什么？'), controller: a1Ctrl),
          DialogTextField(
              title: translate('最爱吃的东西是什么？'), controller: a2Ctrl),
          DialogTextField(
              title: translate('最好的朋友是谁？'), controller: a3Ctrl),
          if (tab == 0)
            DialogTextField(title: translate('邀请码'), controller: invCtrl),
          if (tab == 1) PasswordWidget(title: '新密码', controller: npCtrl),
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
              child: Text(translate(tab == 0 ? '提交注册' : '提交修改'),
                  style: const TextStyle(fontSize: 16)),
              onPressed: isInProgress
                  ? null
                  : () {
                      if (tab == 0) {
                        doRegister();
                      } else {
                        doRecover();
                      }
                    },
            ),
          ),
        ],
      ),
      onCancel: onCancel,
    );
  });
}