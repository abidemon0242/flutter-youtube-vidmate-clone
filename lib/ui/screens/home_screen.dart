import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/mock_youtube_repository.dart';
import '../../models/video_model.dart';
import '../../services/personalization_service.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget{const HomeScreen({super.key});@override State<HomeScreen> createState()=>_HomeScreenState();}
class _HomeScreenState extends State<HomeScreen>{
  late final MockYouTubeRepository repository;int selectedCategory=0;bool multiSelectMode=false;String searchQuery='';List<VideoModel> searchResults=[];bool searching=false;String? searchError;final Set<String> selectedIds={};
  @override void initState(){
    super.initState();
    repository=context.read<MockYouTubeRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final profile=context.read<PersonalizationService>();
      if(!mounted||profile.consentDecided)return;
      final accepted=await showDialog<bool>(context:context,barrierDismissible:false,builder:(dialog)=>AlertDialog(
        title:const Text('Personalized recommendations'),
        content:const Text('Tube Arena can use your in-app searches, likes, saves and watch activity to improve recommendations. This activity is stored locally on this device. You can turn personalization off or clear the data at any time.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Not now')),
          FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Agree and continue')),
        ],
      ));
      if(mounted)await profile.setConsent(accepted==true);
    });
  }
  List<VideoModel> videos(PersonalizationService p){
    if(searchQuery.isNotEmpty)return searchResults;
    final map=<String,VideoModel>{};for(final v in [...repository.getTrendingVideos(),...p.playlists.expand((x)=>x.videos)]){map.putIfAbsent(v.id,()=>v);}
    final cats=repository.getCategories(),cat=selectedCategory<cats.length?cats[selectedCategory]:'All';
    return p.rankVideos(cat=='All'?map.values.toList():map.values.where((v)=>v.category==cat).toList());
  }
  void toggle(String id){setState((){if(!selectedIds.add(id))selectedIds.remove(id);multiSelectMode=selectedIds.isNotEmpty;});}
  Future<void> search()async{
    final c=TextEditingController(text:searchQuery);final q=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const Text('Search videos'),content:TextField(controller:c,autofocus:true,onSubmitted:(v)=>Navigator.pop(d,v)),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(d,c.text),child:const Text('Search'))]));c.dispose();
    if(q==null||!mounted)return;if(q.trim().isEmpty){clearSearch();return;}final term=q.trim();
    await context.read<PersonalizationService>().record(type:'search',query:term);
    setState((){searchQuery=term;selectedCategory=0;searching=true;searchError=null;searchResults=[];selectedIds.clear();multiSelectMode=false;});
    try{final found=await repository.searchVideos(term);if(!mounted)return;setState(()=>searchResults=context.read<PersonalizationService>().rankVideos(found));}
    catch(_){if(mounted)setState(()=>searchError='Search is temporarily unavailable. Check your connection.');}
    finally{if(mounted)setState(()=>searching=false);}
  }
  void clearSearch()=>setState((){searchQuery='';searchResults=[];searchError=null;searching=false;selectedIds.clear();multiSelectMode=false;});
  String? _downloadUrlFor(VideoModel video){
    final uri=Uri.tryParse(video.playbackUrl);
    const hosts={'youtube.com','www.youtube.com','m.youtube.com','music.youtube.com','youtu.be','www.youtu.be'};
    if(uri!=null&&(uri.scheme=='http'||uri.scheme=='https')&&hosts.contains(uri.host.toLowerCase()))return uri.toString();
    if(RegExp(r'^[A-Za-z0-9_-]{11}
  @override Widget build(BuildContext context){
    final p=context.watch<PersonalizationService>(),cats=repository.getCategories(),visible=videos(p);
    return Scaffold(appBar:AppBar(automaticallyImplyLeading:false,title:const Text('Tube Arena'),actions:[
      IconButton(tooltip:'Import playlist',onPressed:()=>context.push('/playlists'),icon:const Icon(Icons.playlist_add)),
      IconButton(tooltip:'Personalization & privacy',onPressed:()=>context.push('/personalization'),icon:const Icon(Icons.auto_awesome)),
      if(searchQuery.isNotEmpty)IconButton(onPressed:clearSearch,icon:const Icon(Icons.close)),
      PopupMenuButton<String>(onSelected:(v){if(v=='downloads')context.go('/downloads');if(v=='library')context.go('/library');if(v=='links')context.push('/add-downloads');if(v=='playlists')context.push('/playlists');if(v=='privacy')context.push('/personalization');},itemBuilder:(_)=>const[
        PopupMenuItem(value:'links',child:Text('Add media links')),PopupMenuItem(value:'downloads',child:Text('Downloads')),PopupMenuItem(value:'library',child:Text('Library')),PopupMenuItem(value:'playlists',child:Text('Import playlist')),PopupMenuItem(value:'privacy',child:Text('Personalization & privacy'))]),
      IconButton(onPressed:search,tooltip:'Search',icon:const Icon(Icons.search)),
    ]),
    body:Column(children:[
      SizedBox(height:54,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),itemCount:cats.length,itemBuilder:(c,i)=>ChoiceChip(label:Text(cats[i]),selected:i==selectedCategory,onSelected:(_)=>setState((){selectedCategory=i;searchQuery='';searchResults=[];searchError=null;searching=false;selectedIds.clear();multiSelectMode=false;})),separatorBuilder:(_,__)=>const SizedBox(width:8))),
      Expanded(child:searching?const Center(child:CircularProgressIndicator()):searchError!=null?Center(child:Text(searchError!)):visible.isEmpty?const Center(child:Text('No videos available')):ListView.builder(padding:const EdgeInsets.fromLTRB(16,4,16,80),itemCount:visible.length,itemBuilder:(c,i){final v=visible[i];return VideoCard(video:v,multiSelectMode:multiSelectMode,isSelected:selectedIds.contains(v.id),onLongPress:()=>toggle(v.id),onCheckboxTap:()=>toggle(v.id),onTap:()async{if(multiSelectMode){toggle(v.id);return;}if(context.mounted)context.push('/watch',extra:v);});})),
    ]),
    bottomNavigationBar:BottomNavigationBar(type:BottomNavigationBarType.fixed,backgroundColor:AppColors.background,selectedItemColor:AppColors.primaryStart,unselectedItemColor:AppColors.textSecondary,currentIndex:0,onTap:(i){if(i==1)context.go('/downloads');if(i==2)context.go('/library');},items:const[BottomNavigationBarItem(icon:Icon(Icons.home),label:'Home'),BottomNavigationBarItem(icon:Icon(Icons.download),label:'Downloads'),BottomNavigationBarItem(icon:Icon(Icons.library_books),label:'Library')]),
    floatingActionButton:multiSelectMode?FloatingActionButton.extended(onPressed:()=>_openSelectedDownloads(visible),label:const Text('Download selected'),icon:const Icon(Icons.add_link)):null);
  }
}
).hasMatch(video.id))return 'https://www.youtube.com/watch?v=${video.id}';
    return null;
  }
  void _openSelectedDownloads(List<VideoModel> visible){
    final urls=visible.where((video)=>selectedIds.contains(video.id)).map(_downloadUrlFor).whereType<String>().toList();
    if(urls.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('The selected demo items have no YouTube source URL. Select live search results or add links manually.')));
      return;
    }
    setState(()=>{selectedIds.clear(),multiSelectMode=false});
    context.push('/add-downloads',extra:urls);
  }
  @override Widget build(BuildContext context){
    final p=context.watch<PersonalizationService>(),cats=repository.getCategories(),visible=videos(p);
    return Scaffold(appBar:AppBar(automaticallyImplyLeading:false,title:const Text('Tube Arena'),actions:[
      IconButton(tooltip:'Import playlist',onPressed:()=>context.push('/playlists'),icon:const Icon(Icons.playlist_add)),
      IconButton(tooltip:'Personalization & privacy',onPressed:()=>context.push('/personalization'),icon:const Icon(Icons.auto_awesome)),
      if(searchQuery.isNotEmpty)IconButton(onPressed:clearSearch,icon:const Icon(Icons.close)),
      PopupMenuButton<String>(onSelected:(v){if(v=='downloads')context.go('/downloads');if(v=='library')context.go('/library');if(v=='links')context.push('/add-downloads');if(v=='playlists')context.push('/playlists');if(v=='privacy')context.push('/personalization');},itemBuilder:(_)=>const[
        PopupMenuItem(value:'links',child:Text('Add media links')),PopupMenuItem(value:'downloads',child:Text('Downloads')),PopupMenuItem(value:'library',child:Text('Library')),PopupMenuItem(value:'playlists',child:Text('Import playlist')),PopupMenuItem(value:'privacy',child:Text('Personalization & privacy'))]),
      IconButton(onPressed:search,tooltip:'Search',icon:const Icon(Icons.search)),
    ]),
    body:Column(children:[
      SizedBox(height:54,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),itemCount:cats.length,itemBuilder:(c,i)=>ChoiceChip(label:Text(cats[i]),selected:i==selectedCategory,onSelected:(_)=>setState((){selectedCategory=i;searchQuery='';searchResults=[];searchError=null;searching=false;})),separatorBuilder:(_,__)=>const SizedBox(width:8))),
      Expanded(child:searching?const Center(child:CircularProgressIndicator()):searchError!=null?Center(child:Text(searchError!)):visible.isEmpty?const Center(child:Text('No videos available')):ListView.builder(padding:const EdgeInsets.fromLTRB(16,4,16,80),itemCount:visible.length,itemBuilder:(c,i){final v=visible[i];return VideoCard(video:v,multiSelectMode:multiSelectMode,isSelected:selectedIds.contains(v.id),onLongPress:()=>toggle(v.id),onCheckboxTap:()=>toggle(v.id),onTap:()async{if(multiSelectMode){toggle(v.id);return;}if(context.mounted)context.push('/watch',extra:v);});})),
    ]),
    bottomNavigationBar:BottomNavigationBar(type:BottomNavigationBarType.fixed,backgroundColor:AppColors.background,selectedItemColor:AppColors.primaryStart,unselectedItemColor:AppColors.textSecondary,currentIndex:0,onTap:(i){if(i==1)context.go('/downloads');if(i==2)context.go('/library');},items:const[BottomNavigationBarItem(icon:Icon(Icons.home),label:'Home'),BottomNavigationBarItem(icon:Icon(Icons.download),label:'Downloads'),BottomNavigationBarItem(icon:Icon(Icons.library_books),label:'Library')]),
    floatingActionButton:multiSelectMode?FloatingActionButton.extended(onPressed:()=>context.push('/add-downloads'),label:const Text('Add download links'),icon:const Icon(Icons.add_link)):null);
  }
}
