import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../models/video_model.dart';
import '../../services/personalization_service.dart';

class WatchScreen extends StatefulWidget{const WatchScreen({super.key,required this.video});final VideoModel video;@override State<WatchScreen> createState()=>_WatchScreenState();}
class _WatchScreenState extends State<WatchScreen> with WidgetsBindingObserver{
  late final VideoPlayerController controller;late final PersonalizationService profile;
  bool playing=false,ready=false,failed=false,saved=false,liked=false;Duration last=Duration.zero;int watched=0;
  Future<void> record(String type,{int seconds=0})=>profile.record(type:type,video:widget.video,seconds:seconds);
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);profile=context.read<PersonalizationService>();record('open');controller=VideoPlayerController.networkUrl(Uri.parse(widget.video.playbackUrl));controller.addListener(track);initialize();}
  void track(){if(!controller.value.isInitialized)return;final pos=controller.value.position,delta=pos-last;if(controller.value.isPlaying&&delta.inSeconds>0&&delta.inSeconds<=5)watched+=delta.inSeconds;last=pos;}
  void flushWatchTime(){final seconds=watched;watched=0;if(seconds>0)record('watch',seconds:seconds);}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.inactive||state==AppLifecycleState.paused||state==AppLifecycleState.detached){track();flushWatchTime();}}
  String? _downloadUrlFor(VideoModel video) {
    final uri = Uri.tryParse(video.playbackUrl);
    const youtubeHosts = {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'www.youtu.be',
    };
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        youtubeHosts.contains(uri.host.toLowerCase())) {
      return uri.toString();
    }
    if (RegExp(r'^[A-Za-z0-9_-]{11}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);track();flushWatchTime();controller.removeListener(track);controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){final v=widget.video;return Scaffold(appBar:AppBar(title:const Text('Watch')),body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    AspectRatio(aspectRatio:ready&&controller.value.aspectRatio>0?controller.value.aspectRatio:16/9,child:Container(color:Colors.black,child:failed?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('This video is hosted on YouTube.',style:TextStyle(color:Colors.white)),FilledButton.icon(onPressed:()async{final u=Uri.tryParse(v.playbackUrl);if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.open_in_new),label:const Text('Open on YouTube'))])):!ready?const Center(child:CircularProgressIndicator()):Stack(alignment:Alignment.center,children:[VideoPlayer(controller),Align(alignment:Alignment.bottomCenter,child:VideoProgressIndicator(controller,allowScrubbing:true,colors:const VideoProgressColors(playedColor:AppColors.primaryStart,bufferedColor:Colors.white54,backgroundColor:Colors.white24))),IconButton.filled(onPressed:()async{if(controller.value.isPlaying){await controller.pause();}else{await controller.play();}if(mounted)setState(()=>playing=controller.value.isPlaying);},icon:Icon(playing?Icons.pause:Icons.play_arrow))]))),
    const SizedBox(height:16),Text(v.title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),Text(v.channelName+' • '+v.views),
    const SizedBox(height:16),Wrap(spacing:8,children:[
      ActionChip(label:Text(liked?'Liked':'Like'),onPressed:()async{final next=!liked;setState(()=>liked=next);await record(next?'like':'unlike');}),
      ActionChip(label:const Text('Share'),onPressed:()=>Share.share(v.title+' — '+v.channelName)),
      ActionChip(
        label: const Text('Add download'),
        onPressed: () {
          final url = _downloadUrlFor(v);
          if (url == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This sample has no downloadable source URL. Add an authorized media link on the next screen.')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Only download media you own or are authorized to save.')),
            );
          }
          context.push('/add-downloads', extra: url);
        },
      ),
      ActionChip(label:Text(saved?'Saved':'Save'),onPressed:()async{setState(()=>saved=!saved);await record(saved?'save':'unsave');}),
      ActionChip(label:const Text('Not interested'),onPressed:()=>record('skip')),
    ]),
    const SizedBox(height:20),const Text('YouTube videos open in the official YouTube app or browser. Watch duration is tracked only for videos played inside Tube Arena.'),
  ])));}
}
).hasMatch(video.id)) {
      return 'https://www.youtube.com/watch?v=${video.id}';
    }
    return null;
  }

  Future<void> initialize() async {
    final uri = Uri.tryParse(widget.video.playbackUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => failed = true);
      return;
    }
    if (_downloadUrlFor(widget.video) != null) {
      if (mounted) setState(() => failed = true);
      return;
    }
    try {
      await controller.initialize();
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);track();flushWatchTime();controller.removeListener(track);controller.dispose();super.dispose();}
  @override Widget build(BuildContext context){final v=widget.video;return Scaffold(appBar:AppBar(title:const Text('Watch')),body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    AspectRatio(aspectRatio:ready&&controller.value.aspectRatio>0?controller.value.aspectRatio:16/9,child:Container(color:Colors.black,child:failed?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('This video is hosted on YouTube.',style:TextStyle(color:Colors.white)),FilledButton.icon(onPressed:()async{final u=Uri.tryParse(v.playbackUrl);if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.open_in_new),label:const Text('Open on YouTube'))])):!ready?const Center(child:CircularProgressIndicator()):Stack(alignment:Alignment.center,children:[VideoPlayer(controller),Align(alignment:Alignment.bottomCenter,child:VideoProgressIndicator(controller,allowScrubbing:true,colors:const VideoProgressColors(playedColor:AppColors.primaryStart,bufferedColor:Colors.white54,backgroundColor:Colors.white24))),IconButton.filled(onPressed:()async{if(controller.value.isPlaying){await controller.pause();}else{await controller.play();}if(mounted)setState(()=>playing=controller.value.isPlaying);},icon:Icon(playing?Icons.pause:Icons.play_arrow))]))),
    const SizedBox(height:16),Text(v.title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700)),Text(v.channelName+' • '+v.views),
    const SizedBox(height:16),Wrap(spacing:8,children:[
      ActionChip(label:Text(liked?'Liked':'Like'),onPressed:()async{final next=!liked;setState(()=>liked=next);await record(next?'like':'unlike');}),
      ActionChip(label:const Text('Share'),onPressed:()=>Share.share(v.title+' — '+v.channelName)),
      ActionChip(label:const Text('Add download'),onPressed:(){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Only download media you own or are authorized to save.')));context.push('/add-downloads');}),
      ActionChip(label:Text(saved?'Saved':'Save'),onPressed:()async{setState(()=>saved=!saved);await record(saved?'save':'unsave');}),
      ActionChip(label:const Text('Not interested'),onPressed:()=>record('skip')),
    ]),
    const SizedBox(height:20),const Text('YouTube videos open in the official YouTube app or browser. Watch duration is tracked only for videos played inside Tube Arena.'),
  ])));}
}
