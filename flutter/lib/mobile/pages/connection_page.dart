import 'dart:async';

import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/connection_page_title.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import '../../common.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import '../../models/ab_model.dart';  // ← 加这行
import 'home_page.dart';
import '../../common/widgets/login.dart';
import '../../common/widgets/change_password_dialog.dart';
import '../../common/widgets/account_api.dart';
import '../../common/widgets/register_dialog.dart';
import '../../common/widgets/add_device_dialog.dart';
import '../../common/widgets/reset_ip_dialog.dart';

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget implements PageShape {
  ConnectionPage({Key? key, required this.appBarActions}) : super(key: key);

  @override
  final icon = const Icon(Icons.connected_tv);

  @override
  final title = "";

  @override
  final List<Widget> appBarActions;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage> {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();
  final RxBool _idEmpty = true.obs;

  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();

  final AllPeersLoader _allPeersLoader = AllPeersLoader();

  StreamSubscription? _uniLinksSubscription;

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];
  
  late final Future<String> _myIdFuture = bind.mainGetMyId();   // ← 加这行
  int _hostExpire = 0;
  bool _ledgerLoaded = false;

  _ConnectionPageState() {
    if (!isWeb) _uniLinksSubscription = listenUniLinks();
    _idController.addListener(() {
      _idEmpty.value = _idController.text.isEmpty;
    });
    Get.put<IDTextEditingController>(_idController);
  }

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  Future<void> _refreshAll() async {
    if (isAndroid) await _loadLedgerInfo();
    await gFFI.abModel.pullAb(
        force: ForcePullAb.listAndCurrent, quiet: false);
    ledgerRefreshTick.value++;
  }

  Future<void> _loadLedgerInfo() async {
    final id = await bind.mainGetMyId();
    if (id.isEmpty) return;
    final info = await AccountApi.deviceInfo(id);
    if (mounted) {
      setState(() {
        _hostExpire = info?.hostExpire ?? 0;
        _ledgerLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<FfiModel>(context);
    return Column(
      children: [
        if (!bind.isDisableAccount())
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: null,
              title: Obx(() {
                final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
                if (!loggedIn) {
                  return Text(
                    translate('Login'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${translate('Logout')} (${gFFI.userModel.accountLabelWithHandle})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: _myIdFuture,
                      builder: (context, snapshot) {
                        final id = snapshot.data ?? '';
                        if (id.isEmpty) return const SizedBox.shrink();
                        return Text(
                          id,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                );
              }),
              trailing: Obx(() {
                if (gFFI.userModel.userName.value.isEmpty) {
                  return TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => registerRecoverDialog(),
                    child: Text(translate('注册'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black)),
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: translate('刷新'),
                      icon: const Icon(Icons.refresh,
                          color: Color(0xFF2E7D32)),
                      onPressed: _refreshAll,
                    ),
                    const SizedBox(width: 8),
                    // 更多菜单
                    PopupMenuButton<String>(
                      tooltip: translate('更多'),
                      icon: const Icon(Icons.more_vert,
                          color: Color(0xFF2E7D32)),
                      onSelected: (value) {
                        if (value == 'change_password') {
                          changePasswordDialog();
                        } else if (value == 'add_device') {
                          addDeviceDialog();
                        } else if (value == 'reset_ip') {
                          resetIpDialog();
                        } else if (value == 'about') {
                          _showAboutDialog(context);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'change_password',
                          child: Text(translate('修改密码')),
                        ),
                        PopupMenuItem(
                          value: 'add_device',
                          child: Text(translate('添加设备')),
                        ),
                        PopupMenuItem(
                          value: 'reset_ip',
                          child: Text(translate('重置IP')),
                        ),
                        PopupMenuItem(
                          value: 'about',
                          child: Text(translate('关于')),
                        ),
                      ],
                    ),
                  ],
                );
              }),
              onTap: () {
                if (gFFI.userModel.userName.value.isEmpty) {
                  loginDialog();
                } else {
                  logOutConfirmDialog();
                }
              },
            ),
          ),
        if (gFFI.userModel.userName.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '请不要对外提供任何个人信息和密码；开通不在有效期ID留存3天后清除、空账号留存7天后销户；普通密码界面显示，重要密码界面会导致黑屏不显示，多次按回退键可退出，重要密码请在自己设备登录使用；控制端连接设备时为唯一操作端，不支持多端并行。',
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.black54,
              ),
            ),
          ),
        Expanded(child: PeerTabPage()),
      ],
    );
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  void onConnect() async {
      var id = _idController.id;
      
      // 连接前验证登录状态
      if (gFFI.userModel.isLogin) {
          try {
              await gFFI.abModel.pullAb(force: ForcePullAb.current, quiet: false);
              if (!gFFI.userModel.isLogin) {
                  showToast(translate("账号已被禁用"));
                  return;
              }
          } catch (e) {
              if (!gFFI.userModel.isLogin) {
                  showToast(translate("账号已被禁用"));
                  return;
              }
          }
      }
      
      connect(context, id);
  }

  void onFocusChanged() {
    _idEmpty.value = _idEditingController.text.isEmpty;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection =
          TextSelection(baseOffset: 0, extentOffset: textLength);
    }
  }

  /// UI for software update.
  /// If _updateUrl] is not empty, shows a button to update the software.
  Widget _buildUpdateUI(String updateUrl) {
    return updateUrl.isEmpty
        ? const SizedBox(height: 0)
        : InkWell(
            onTap: () async {
              final url = 'https://rustdesk.com/download';
              // https://pub.dev/packages/url_launcher#configuration
              // https://developer.android.com/training/package-visibility/use-cases#open-urls-custom-tabs
              //
              // `await launchUrl(Uri.parse(url))` can also run if skip
              // 1. The following check
              // 2. `<action android:name="android.support.customtabs.action.CustomTabsService" />` in AndroidManifest.xml
              //
              // But it is better to add the check.
              await launchUrl(Uri.parse(url));
            },
            child: Container(
                alignment: AlignmentDirectional.center,
                width: double.infinity,
                color: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(translate('Download new version'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))));
  }

  /// UI for the remote ID TextField.
  /// Search for a peer and connect to it if the id exists.
  Widget _buildRemoteIDTextField() {
    final w = SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.all(Radius.circular(13)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: RawAutocomplete<Peer>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        _autocompleteOpts = const Iterable<Peer>.empty();
                      } else if (_allPeersLoader.peers.isEmpty &&
                          !_allPeersLoader.isPeersLoaded) {
                        Peer emptyPeer = Peer(
                          id: '',
                          username: '',
                          hostname: '',
                          alias: '',
                          platform: '',
                          tags: [],
                          hash: '',
                          password: '',
                          forceAlwaysRelay: false,
                          rdpPort: '',
                          rdpUsername: '',
                          loginName: '',
                          device_group_name: '',
                          note: '',
                        );
                        _autocompleteOpts = [emptyPeer];
                      } else {
                        String textWithoutSpaces =
                            textEditingValue.text.replaceAll(" ", "");
                        if (int.tryParse(textWithoutSpaces) != null) {
                          textEditingValue = TextEditingValue(
                            text: textWithoutSpaces,
                            selection: textEditingValue.selection,
                          );
                        }
                        String textToFind = textEditingValue.text.toLowerCase();

                        _autocompleteOpts = _allPeersLoader.peers
                            .where((peer) =>
                                peer.id.toLowerCase().contains(textToFind) ||
                                peer.username
                                    .toLowerCase()
                                    .contains(textToFind) ||
                                peer.hostname
                                    .toLowerCase()
                                    .contains(textToFind) ||
                                peer.alias.toLowerCase().contains(textToFind))
                            .toList();
                      }
                      return _autocompleteOpts;
                    },
                    focusNode: _idFocusNode,
                    textEditingController: _idEditingController,
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController fieldTextEditingController,
                        FocusNode fieldFocusNode,
                        VoidCallback onFieldSubmitted) {
                      updateTextAndPreserveSelection(
                          fieldTextEditingController, _idController.text);
                      return AutoSizeTextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        minFontSize: 18,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        // keyboardType: TextInputType.number,
                        onChanged: (String text) {
                          _idController.id = text;
                        },
                        style: const TextStyle(
                          fontFamily: 'WorkSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                          color: MyTheme.idColor,
                        ),
                        decoration: InputDecoration(
                          labelText: translate('Remote ID'),
                          // hintText: 'Enter your remote ID',
                          border: InputBorder.none,
                          helperStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: MyTheme.darkGray,
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.2,
                            color: MyTheme.darkGray,
                          ),
                        ),
                        inputFormatters: [IDTextInputFormatter()],
                        onSubmitted: (_) {
                          onConnect();
                        },
                      );
                    },
                    onSelected: (option) {
                      setState(() {
                        _idController.id = option.id;
                        FocusScope.of(context).unfocus();
                      });
                    },
                    optionsViewBuilder: (BuildContext context,
                        AutocompleteOnSelected<Peer> onSelected,
                        Iterable<Peer> options) {
                      options = _autocompleteOpts;
                      double maxHeight = options.length * 50;
                      if (options.length == 1) {
                        maxHeight = 52;
                      } else if (options.length == 3) {
                        maxHeight = 146;
                      } else if (options.length == 4) {
                        maxHeight = 193;
                      }
                      maxHeight = maxHeight.clamp(0, 200);
                      return Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Material(
                                      elevation: 4,
                                      child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: maxHeight,
                                            maxWidth: 320,
                                          ),
                                          child: _allPeersLoader
                                                      .peers.isEmpty &&
                                                  !_allPeersLoader.isPeersLoaded
                                              ? Container(
                                                  height: 80,
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  )))
                                              : ListView(
                                                  padding:
                                                      EdgeInsets.only(top: 5),
                                                  children: options
                                                      .map((peer) =>
                                                          AutocompletePeerTile(
                                                              onSelect: () =>
                                                                  onSelected(
                                                                      peer),
                                                              peer: peer))
                                                      .toList(),
                                                ))))));
                    },
                  ),
                ),
              ),
              Obx(() => Offstage(
                    offstage: _idEmpty.value,
                    child: IconButton(
                        onPressed: () {
                          setState(() {
                            _idController.clear();
                          });
                        },
                        icon: Icon(Icons.clear, color: MyTheme.darkGray)),
                  )),
              SizedBox(
                width: 60,
                height: 60,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward,
                      color: MyTheme.darkGray, size: 45),
                  onPressed: onConnect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final child = Column(children: [
      if (isWebDesktop)
        getConnectionPageTitle(context, true)
            .marginOnly(bottom: 10, top: 15, left: 12),
      w
    ]);
    return Align(
        alignment: Alignment.topCenter,
        child: Container(constraints: kMobilePageConstraints, child: child));
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    _idController.dispose();
    _idFocusNode.removeListener(onFocusChanged);
    _allPeersLoader.clear();
    _idFocusNode.dispose();
    _idEditingController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }
  
  void _showAboutDialog(BuildContext parentContext) {
    gFFI.dialogManager.show((setState, close, context) {
      const commonStyle = TextStyle(fontSize: 14, height: 1.6, color: Colors.black);
      return CustomAlertDialog(
        title: Text(translate('关于')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              SelectableText(
                '本软件基于 RustDesk 开源项目修改，遵循 AGPL-3.0 许可证。',
                style: commonStyle,
              ),
              SizedBox(height: 8),
              SelectableText(
                '源代码地址：https://codeberg.org/openshow/openshow.git',
                style: commonStyle,
              ),
              SizedBox(height: 8),
              SelectableText(
                'AGPL-3.0 许可证全文：https://www.gnu.org/licenses/agpl-3.0.html',
                style: commonStyle,
              ),
            ],
          ),
        ),
        actions: [
          dialogButton('OK', onPressed: close),
        ],
        onSubmit: close,
        onCancel: close,
      );
    });
  }
}
