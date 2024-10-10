import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:nami/utilities/app.state.dart';
import 'package:nami/utilities/helper_functions.dart';
import 'package:nami/utilities/hive/mitglied.dart';
import 'package:nami/utilities/hive/settings.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer(
      {super.key,
      this.screenIndex,
      this.iconAnimationController,
      this.callBackIndex});

  final AnimationController? iconAnimationController;
  final DrawerIndex? screenIndex;
  final Function(DrawerIndex)? callBackIndex;

  @override
  HomeDrawerState createState() => HomeDrawerState();
}

class HomeDrawerState extends State<HomeDrawer> {
  final InAppReview inAppReview = InAppReview.instance;
  bool _isReviewAvailable = false;
  List<DrawerList>? drawerList;

  @override
  void initState() {
    setDrawerListArray();
    super.initState();
    _checkReviewAvailability();
  }

  Future<void> _checkReviewAvailability() async {
    final isAvailable = await inAppReview.isAvailable();
    setState(() {
      _isReviewAvailable = isAvailable;
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  void setDrawerListArray() {
    drawerList = <DrawerList>[
      DrawerList(
        index: DrawerIndex.meineStufe,
        labelName: 'Meine Stufe',
        icon: const Icon(Icons.group),
      ),
      DrawerList(
        index: DrawerIndex.mitglieder,
        labelName: 'Mitglieder',
        icon: const Icon(Icons.groups),
      ),
      DrawerList(
        index: DrawerIndex.stats,
        labelName: 'Statistiken',
        icon: const Icon(Icons.analytics),
      ),
      DrawerList(
        index: DrawerIndex.profil,
        labelName: 'Profil',
        icon: const Icon(Icons.person),
      ),
      DrawerList(
        index: DrawerIndex.settings,
        labelName: 'Einstellungen',
        icon: const Icon(Icons.settings),
      ),
    ];
  }

  void _showSupportModal(BuildContext context) {
    bool testDevice = getIsTestDevice();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Entwicklung unterstützen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Deine Unterstützung hilft mir, die App weiter zu verbessern und neue Funktionen zu entwickeln.',
              ),
              const SizedBox(height: 16),
              if (!testDevice)
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text('Paypal Spenden'),
                  onTap: () => _launchURL(
                      'https://www.paypal.com/donate/?hosted_button_id=5YJVWMBN72G3A'),
                ),
              if (!testDevice)
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Github Sponsor'),
                  onTap: () =>
                      _launchURL('https://github.com/sponsors/JanneckLange'),
                ),
              if (_isReviewAvailable)
                ListTile(
                  leading: const Icon(Icons.thumb_up),
                  title: const Text('App bewerten'),
                  onTap: () => inAppReview.requestReview(),
                ),
              ListTile(
                leading: const Icon(Icons.feedback),
                title: const Text('Feedback geben'),
                onTap: () => openWiredash(context, 'Entwickler loben'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int? gruppierung = getGruppierungId();
    Box<Mitglied> memberBox = Hive.box<Mitglied>('members');

    Mitglied? user;
    try {
      user = memberBox.values
          .firstWhere((member) => member.mitgliedsNummer == getNamiLoginId());
    } catch (_) {}

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      '${user?.vorname} ${user?.nachname}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Mitgliedsnummer: ${getNamiLoginId()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Gruppierung: $gruppierung',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(0.0),
              itemCount: drawerList?.length,
              itemBuilder: (BuildContext context, int index) {
                return inkwell(drawerList![index]);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.support),
            title: const Text('Entwicklung unterstützen'),
            onTap: () => _showSupportModal(context),
          ),
          Center(
            child: Text(
              'Entwickelt mit ${Theme.of(context).brightness == Brightness.dark ? '🖤' : '❤️'} in Hamburg',
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
          Column(
            children: <Widget>[
              ListTile(
                title: Text(
                  'Abmelden',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.left,
                ),
                trailing: const Icon(
                  Icons.power_settings_new,
                  color: Colors.red,
                ),
                onTap: () {
                  AppStateHandler().setLoggedOutState();
                },
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget inkwell(DrawerList listData) {
    final itemColor = widget.screenIndex == listData.index
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      splashColor: Colors.grey.withOpacity(0.1),
      highlightColor: Colors.transparent,
      onTap: () {
        navigationtoScreen(listData.index!);
      },
      child: Stack(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 6.0,
                  height: 46.0,
                  // decoration: BoxDecoration(
                  //   color: widget.screenIndex == listData.index
                  //       ? Colors.blue
                  //       : Colors.transparent,
                  //   borderRadius: new BorderRadius.only(
                  //     topLeft: Radius.circular(0),
                  //     topRight: Radius.circular(16),
                  //     bottomLeft: Radius.circular(0),
                  //     bottomRight: Radius.circular(16),
                  //   ),
                  // ),
                ),
                const Padding(
                  padding: EdgeInsets.all(4.0),
                ),
                listData.isAssetsImage
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: Image.asset(
                          listData.imageName,
                          color: itemColor,
                        ),
                      )
                    : Icon(
                        listData.icon?.icon,
                        color: itemColor,
                      ),
                const Padding(padding: EdgeInsets.all(4.0)),
                Text(
                  listData.labelName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: itemColor,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          widget.screenIndex == listData.index
              ? AnimatedBuilder(
                  animation: widget.iconAnimationController!,
                  builder: (BuildContext context, Widget? child) {
                    return Transform(
                      transform: Matrix4.translationValues(
                          (MediaQuery.of(context).size.width * 0.75 - 64) *
                              (1.0 -
                                  widget.iconAnimationController!.value -
                                  1.0),
                          0.0,
                          0.0),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.75 - 64,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(0),
                              topRight: Radius.circular(28),
                              bottomLeft: Radius.circular(0),
                              bottomRight: Radius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const SizedBox()
        ],
      ),
    );
  }

  Future<void> navigationtoScreen(DrawerIndex indexScreen) async {
    widget.callBackIndex!(indexScreen);
  }
}

enum DrawerIndex { meineStufe, mitglieder, stats, settings, profil }

class DrawerList {
  DrawerList({
    this.isAssetsImage = false,
    this.labelName = '',
    this.icon,
    this.index,
    this.imageName = '',
  });

  String labelName;
  Icon? icon;
  bool isAssetsImage;
  String imageName;
  DrawerIndex? index;
}
