import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:pos/models/sale.dart';
import 'package:pos/models/table.dart';
import 'package:pos/models/user.dart';
import 'package:pos/providers/auth_provider.dart';
import 'package:pos/providers/sale_provider.dart';
import 'package:pos/providers/table_provider.dart';
import 'package:pos/routes/app_router.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _soft = Color(0xFFF8FAFC);
const _burgundy = Color(0xFF7A1026);
const _orange = Color(0xFFF59E0B);
const _green = Color(0xFF059669);

class RestaurantDashboardScreenV2 extends StatefulWidget {
  const RestaurantDashboardScreenV2({super.key});
  @override
  State<RestaurantDashboardScreenV2> createState() => _RestaurantDashboardScreenV2State();
}

class _RestaurantDashboardScreenV2State extends State<RestaurantDashboardScreenV2> {
  static const defaults = <String>['sales','receipts','tables','kot','payments','pra','activity','leakage','expenses','store','branches','cameras'];
  static const labels = <String,String>{
    'sales': "Today's Sales", 'receipts': "Today's Receipts", 'tables': 'Live Tables', 'kot': 'Live KOT',
    'payments': 'Payments', 'pra': 'PRA Monitor', 'activity': 'Live Activity', 'leakage': 'Leakage & Theft',
    'expenses': 'Expenses', 'store': 'Store', 'branches': 'Branches', 'cameras': 'Cameras'
  };
  static const permissions = <String,String>{
    'kot': UserModel.viewKotWidgetPermission, 'payments': UserModel.viewPaymentsWidgetPermission,
    'pra': UserModel.viewPraWidgetPermission, 'leakage': UserModel.viewLeakageWidgetPermission,
    'expenses': UserModel.viewAccountsWidgetPermission, 'store': UserModel.viewStoreWidgetPermission,
    'branches': UserModel.viewBranchesWidgetPermission, 'cameras': UserModel.viewCamerasWidgetPermission,
  };

  bool _started = false;
  bool _prefsLoaded = false;
  List<String> order = List.from(defaults);
  Set<String> visible = Set.from(defaults);
  Set<String> minimized = {};
  Set<String> favorites = {};
  String? maximized;

  DocumentReference<Map<String,dynamic>>? get _prefsRef {
    final u = context.read<AuthProvider>().currentUser;
    if (u == null) return null;
    return FirebaseFirestore.instance.collection('vendors').doc(u.id).collection('dashboardPreferences').doc(u.authUid.replaceAll('/','_'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final u = context.read<AuthProvider>().currentUser;
      if (u != null) {
        context.read<TableProvider>().loadTables();
        context.read<SaleProvider>().fetchSales(u.id);
      }
    }
    if (!_prefsLoaded) { _prefsLoaded = true; _loadPrefs(); }
  }

  List<String> _allowed(UserModel u) => defaults.where((id) => u.isAdmin || permissions[id] == null || u.hasPermission(permissions[id]!)).toList();

  Future<void> _loadPrefs() async {
    try {
      final x = (await _prefsRef?.get())?.data();
      if (x == null || !mounted) return;
      final savedOrder = (x['order'] as List?)?.map((e)=>e.toString()).where(labels.containsKey).toList() ?? <String>[];
      final savedVisible = (x['visible'] as List?)?.map((e)=>e.toString()).where(labels.containsKey).toSet() ?? <String>{};
      final savedMin = (x['minimized'] as List?)?.map((e)=>e.toString()).where(labels.containsKey).toSet() ?? <String>{};
      final savedFav = (x['favoriteWidgets'] as List?)?.map((e)=>e.toString()).where(labels.containsKey).toSet() ?? <String>{};
      setState(() {
        order = [...savedOrder, ...defaults.where((e)=>!savedOrder.contains(e))];
        visible = savedVisible.isEmpty ? Set.from(defaults) : savedVisible;
        minimized = savedMin;
        favorites = savedFav;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await _prefsRef?.set({'order':order,'visible':visible.toList(),'minimized':minimized.toList(),'favoriteWidgets':favorites.toList(),'updatedAt':FieldValue.serverTimestamp()}, SetOptions(merge:true));
    } catch (_) {}
  }

  void _toggleFavorite(String id) { setState(()=>favorites.contains(id)?favorites.remove(id):favorites.add(id)); _save(); }
  void _toggleMin(String id) { setState(() { minimized.contains(id)?minimized.remove(id):minimized.add(id); if(minimized.contains(id)&&maximized==id)maximized=null; }); _save(); }
  void _toggleMax(String id) => setState(() { minimized.remove(id); maximized=maximized==id?null:id; });
  void _hide(String id) { setState(() { visible.remove(id); minimized.remove(id); favorites.remove(id); if(maximized==id)maximized=null; }); _save(); }
  void _move(String from,String to){if(from==to)return;final a=order.indexOf(from),b=order.indexOf(to);if(a<0||b<0)return;setState((){final x=order.removeAt(a);order.insert(b,x);});_save();}

  Future<void> _customize(UserModel u) async {
    if (!u.canAddWidgets) return;
    final allowed=_allowed(u); final selected=Set<String>.from(visible.intersection(allowed.toSet()));
    final result=await showDialog<Set<String>>(context:context,builder:(c)=>StatefulBuilder(builder:(_,setModal)=>AlertDialog(backgroundColor:Colors.white,title:const Text('Add Dashboard Widgets'),content:SizedBox(width:500,child:SingleChildScrollView(child:Column(children:allowed.map((id)=>CheckboxListTile(dense:true,value:selected.contains(id),title:Text(labels[id]!),secondary:Icon(_icon(id),size:19),onChanged:(v)=>setModal(()=>v==true?selected.add(id):selected.remove(id)))).toList()))),actions:[TextButton(onPressed:()=>setModal(()=>selected..clear()..addAll(allowed)),child:const Text('Add all')),TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,selected),child:const Text('Save'))])));
    if(result!=null&&mounted){setState(()=>visible=result);_save();}
  }

  bool _today(DateTime d){final n=DateTime.now();return d.year==n.year&&d.month==n.month&&d.day==n.day;}

  @override
  Widget build(BuildContext context) {
    final u=context.watch<AuthProvider>().currentUser;
    if(u==null)return const Center(child:CircularProgressIndicator());
    final tables=context.watch<TableProvider>().tables;
    final sales=context.watch<SaleProvider>().sales;
    final today=sales.where((s)=>_today(s.createdAt)).toList();
    final revenue=today.fold<double>(0,(a,b)=>a+b.total);
    final vendor=FirebaseFirestore.instance.collection('vendors').doc(u.id);
    final allowed=_allowed(u).toSet();

    return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:vendor.collection('tableOrders').snapshots(),
      builder:(context,snap){
        final tableOrders=snap.data?.docs??const<QueryDocumentSnapshot<Map<String,dynamic>>>[];
        final ids=order.where((e)=>visible.contains(e)&&allowed.contains(e)).toList()
          ..sort((a,b){final af=favorites.contains(a),bf=favorites.contains(b);if(af==bf)return 0;return af?-1:1;});
        final minis=ids.where(minimized.contains).toList();
        final normal=ids.where((e)=>!minimized.contains(e)&&e!=maximized).toList();
        return ColoredBox(color:Colors.white,child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            if((u.restaurantLogoUrl??'').isNotEmpty)...[ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network(u.restaurantLogoUrl!,width:46,height:46,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.storefront_outlined,size:34))),const SizedBox(width:10)],
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(u.restaurantName.isEmpty?'Restaurant Dashboard':u.restaurantName,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:_ink)),const SizedBox(height:3),const Row(children:[Icon(Icons.circle,size:8,color:_green),SizedBox(width:6),Text('LIVE • Updates automatically',style:TextStyle(fontSize:11,color:_muted))])])),
            if(u.canAddWidgets)OutlinedButton.icon(onPressed:()=>_customize(u),icon:const Icon(Icons.add_rounded,size:17),label:const Text('Add Widgets')),
          ]),
          if(minis.isNotEmpty)...[const SizedBox(height:14),Wrap(spacing:8,runSpacing:8,children:minis.map((id)=>ActionChip(avatar:Icon(_icon(id),size:15),label:Text(labels[id]!),onPressed:()=>_toggleMin(id))).toList())],
          if(maximized!=null&&ids.contains(maximized))...[const SizedBox(height:14),_widget(maximized!,u,revenue,today,tables,tableOrders,true)],
          const SizedBox(height:14),
          LayoutBuilder(builder:(_,c){final cols=c.maxWidth>1180?3:c.maxWidth>720?2:1;final w=(c.maxWidth-(cols-1)*12)/cols;return Wrap(spacing:12,runSpacing:12,children:normal.map((id)=>DragTarget<String>(onWillAcceptWithDetails:(d)=>d.data!=id,onAcceptWithDetails:(d)=>_move(d.data,id),builder:(_,__,___)=>LongPressDraggable<String>(data:id,feedback:Material(color:Colors.transparent,child:SizedBox(width:w,child:_widget(id,u,revenue,today,tables,tableOrders,false))),child:SizedBox(width:w,child:_widget(id,u,revenue,today,tables,tableOrders,false))))).toList());}),
        ])));
      },
    );
  }

  Widget _widget(String id,UserModel u,double revenue,List<Sale> today,List<RestaurantTable> tables,List<QueryDocumentSnapshot<Map<String,dynamic>>> orders,bool max){
    final active=tables.where((t)=>t.status!=TableStatus.empty).length;
    final making=orders.where((d)=>['making','open','sent'].contains((d.data()['status']??'').toString().toLowerCase())).length;
    final ready=orders.where((d)=>(d.data()['status']??'').toString().toLowerCase()=='ready').length;
    final pra=today.where((s)=>(s.praInvoiceNo??'').isNotEmpty).length;
    final reprints=today.where((s)=>s.receiptPrintCount>1).length;
    final data=switch(id){
      'sales'=>("Today's Sales",'Realtime',_metric('Rs ${revenue.toStringAsFixed(0)}',Icons.account_balance_wallet_outlined),AppRouter.sales),
      'receipts'=>("Today's Receipts",'${today.length} completed',_metric('${today.length}',Icons.receipt_long_outlined),AppRouter.sales),
      'tables'=>('Live Tables','$active in service • ${tables.length-active} available',_tableList(tables),AppRouter.tables),
      'kot'=>('Live KOT','$making making • $ready ready',_kotList(orders),AppRouter.orders),
      'payments'=>('Payments','Completed receipts',_paymentList(today),AppRouter.sales),
      'pra'=>('PRA Monitor','$pra / ${today.length} fiscalized',_metric('$pra / ${today.length}',Icons.verified_user_outlined),AppRouter.praSettings),
      'activity'=>('Live Activity','Latest operations',_activity(orders,today),AppRouter.orders),
      'leakage'=>('Leakage & Theft','$reprints reprint alerts',_metric('$reprints alerts',Icons.security_outlined),AppRouter.sales),
      'expenses'=>('Expenses','Operating costs',_metric('Open Expenses',Icons.payments_outlined),AppRouter.expenses),
      'store'=>('Store','Stock movement',_metric('Open Store',Icons.storefront_outlined),AppRouter.storeOut),
      'branches'=>('Branches','Multi-branch control',_metric('Open Branches',Icons.account_tree_outlined),AppRouter.branches),
      _=>('Cameras','CCTV / NVR monitoring',_metric('Configure Cameras',Icons.videocam_outlined),AppRouter.settings),
    };
    return _DashboardCard(title:data.$1,subtitle:data.$2,favorite:favorites.contains(id),maximized:max,onFavorite:()=>_toggleFavorite(id),onMin:()=>_toggleMin(id),onMax:()=>_toggleMax(id),onClose:()=>_hide(id),onOpen:()=>context.go(data.$4),child:data.$3);
  }

  Widget _metric(String value,IconData icon)=>Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:const Color(0xFFFBECEF),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:_burgundy)),const SizedBox(width:12),Expanded(child:Text(value,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:_ink)))]);
  Widget _tableList(List<RestaurantTable> list)=>ListView(children:list.take(6).map((t)=>_row('Table ${t.tableNumber}',t.statusString.toUpperCase(),t.status==TableStatus.empty?_green:_orange)).toList());
  Widget _kotList(List<QueryDocumentSnapshot<Map<String,dynamic>>> list)=>ListView(children:list.take(6).map((d){final a=d.data();final table=(a['tableNumber']??'').toString();final kot=(a['kotNumber']??'').toString();final name=table.isNotEmpty?'Table $table':kot.isNotEmpty?'KOT $kot':'Kitchen order';return _row(name,(a['status']??'OPEN').toString().toUpperCase(),_orange);}).toList());
  Widget _paymentList(List<Sale> list)=>ListView(children:list.take(6).map((s)=>_row('Receipt ${s.id}','Rs ${s.total.toStringAsFixed(0)} • ${s.paymentMethod}',_green)).toList());
  Widget _activity(List<QueryDocumentSnapshot<Map<String,dynamic>>> orders,List<Sale> sales)=>ListView(children:[...orders.take(4).map((d){final a=d.data();return _row((a['tableNumber']??'Order').toString(),(a['status']??'').toString().toUpperCase(),_orange);}),...sales.take(2).map((s)=>_row('Receipt ${s.id}','PAID ${s.paymentMethod}',_green))]);
  Widget _row(String a,String b,Color color)=>Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),decoration:BoxDecoration(color:_soft,borderRadius:BorderRadius.circular(8)),child:Row(children:[Expanded(child:Text(a,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.8,fontWeight:FontWeight.w800))),Text(b,style:TextStyle(fontSize:9,fontWeight:FontWeight.w900,color:color))]));

  IconData _icon(String id)=>switch(id){'sales'=>Icons.account_balance_wallet_outlined,'receipts'=>Icons.receipt_long_outlined,'tables'=>Icons.table_restaurant_outlined,'kot'=>Icons.soup_kitchen_outlined,'payments'=>Icons.payments_outlined,'pra'=>Icons.verified_user_outlined,'activity'=>Icons.timeline_outlined,'leakage'=>Icons.security_outlined,'expenses'=>Icons.money_off_csred_outlined,'store'=>Icons.storefront_outlined,'branches'=>Icons.account_tree_outlined,_=>Icons.videocam_outlined};
}

class _DashboardCard extends StatelessWidget {
  final String title,subtitle;
  final Widget child;
  final bool favorite,maximized;
  final VoidCallback onFavorite,onMin,onMax,onClose,onOpen;
  const _DashboardCard({required this.title,required this.subtitle,required this.child,required this.favorite,required this.maximized,required this.onFavorite,required this.onMin,required this.onMax,required this.onClose,required this.onOpen});
  @override
  Widget build(BuildContext context)=>Container(height:maximized?560:320,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:_line),boxShadow:const[BoxShadow(color:Color(0x080F172A),blurRadius:12,offset:Offset(0,4))]),child:Column(children:[
    Row(children:[Expanded(child:InkWell(onTap:onOpen,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900,color:_ink)),const SizedBox(height:2),Text(subtitle,style:const TextStyle(fontSize:10,color:_muted))]))),IconButton(tooltip:'Favorite',onPressed:onFavorite,icon:Icon(favorite?Icons.star_rounded:Icons.star_border_rounded,size:17,color:favorite?const Color(0xFFF59E0B):_muted)),IconButton(tooltip:'Minimize',onPressed:onMin,icon:const Icon(Icons.remove_rounded,size:17)),IconButton(tooltip:maximized?'Restore':'Maximize',onPressed:onMax,icon:Icon(maximized?Icons.close_fullscreen_rounded:Icons.open_in_full_rounded,size:16)),IconButton(tooltip:'Remove widget',onPressed:onClose,icon:const Icon(Icons.close_rounded,size:17))]),
    const SizedBox(height:10),Expanded(child:InkWell(onTap:onOpen,child:child)),
  ]));
}
