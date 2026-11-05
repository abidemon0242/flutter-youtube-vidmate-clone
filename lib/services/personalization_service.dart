import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_model.dart';

class ActivityRecord {
  const ActivityRecord(this.type,this.time,{this.title='',this.category='',this.query='',this.seconds=0});
  final String type,title,category,query;
  final DateTime time;
  final int seconds;
  Map<String,dynamic> toJson()=>{'type':type,'time':time.toUtc().toIso8601String(),'title':title,'category':category,'query':query,'seconds':seconds};
  factory ActivityRecord.fromJson(Map<String,dynamic> j)=>ActivityRecord(j['type'] as String? ?? 'unknown',DateTime.tryParse(j['time'] as String? ?? '')?.toLocal() ?? DateTime.now(),title:j['title'] as String? ?? '',category:j['category'] as String? ?? '',query:j['query'] as String? ?? '',seconds:(j['seconds'] as num?)?.toInt() ?? 0);
}
class ImportedPlaylist {
  const ImportedPlaylist(this.id,this.title,this.channel,this.videos);
  final String id,title,channel;
  final List<VideoModel> videos;
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'channel':channel,'videos':videos.map((v)=>{'id':v.id,'title':v.title,'channelName':v.channelName,'views':v.views,'duration':v.duration,'thumbnailUrl':v.thumbnailUrl,'channelAvatar':v.channelAvatar,'isVerified':v.isVerified,'category':v.category,'playbackUrl':v.playbackUrl}).toList()};
  factory ImportedPlaylist.fromJson(Map<String,dynamic> j)=>ImportedPlaylist(j['id'] as String,j['title'] as String? ?? 'Playlist',j['channel'] as String? ?? '',(j['videos'] as List? ?? const []).whereType<Map<String,dynamic>>().map((v)=>VideoModel(id:v['id'] as String,title:v['title'] as String? ?? 'Video',channelName:v['channelName'] as String? ?? '',views:v['views'] as String? ?? '',duration:v['duration'] as String? ?? '—',thumbnailUrl:v['thumbnailUrl'] as String? ?? '',channelAvatar:v['channelAvatar'] as String? ?? '',isVerified:v['isVerified'] as bool? ?? false,category:'Imported playlist',playbackUrl:v['playbackUrl'] as String? ?? 'https://www.youtube.com/watch?v='+(v['id'] as String))).toList());
}
class PlaylistImportException implements Exception {
  const PlaylistImportException(this.message);
  final String message;
  @override String toString()=>message;
}
class PersonalizationService extends ChangeNotifier {
  PersonalizationService({Future<Directory> Function()? directoryResolver,String? apiKey}):_directoryResolver=directoryResolver??getApplicationDocumentsDirectory,_apiKey=apiKey??const String.fromEnvironment('YOUTUBE_DATA_API_KEY');
  final Future<Directory> Function() _directoryResolver;
  final String _apiKey;
  final List<ActivityRecord> _events=[];
  final List<ImportedPlaylist> _playlists=[];
  bool _ready=false;
  bool _consentDecided=false;
  bool _personalizationEnabled=false;
  Future<void> _queue=Future<void>.value();
  List<ActivityRecord> get activity=>List.unmodifiable(_events);
  List<ImportedPlaylist> get playlists=>List.unmodifiable(_playlists);
  int get activityCount=>_events.length;
  bool get consentDecided=>_consentDecided;
  bool get personalizationEnabled=>_personalizationEnabled;
  Future<File> _file() async {final d=await _directoryResolver();final folder=Directory(d.path+'/TubeArena');await folder.create(recursive:true);return File(folder.path+'/personalization.json');}
  Future<void> initialize() async {
    if(_ready)return;
    try{final f=await _file();if(await f.exists()){final j=jsonDecode(await f.readAsString());if(j is Map<String,dynamic>){_consentDecided=j['consentDecided'] as bool? ?? false;_personalizationEnabled=j['personalizationEnabled'] as bool? ?? false;if(j['activity'] is List)_events.addAll((j['activity'] as List).whereType<Map<String,dynamic>>().map(ActivityRecord.fromJson));if(j['playlists'] is List)_playlists.addAll((j['playlists'] as List).whereType<Map<String,dynamic>>().map(ImportedPlaylist.fromJson));}}}catch(e){debugPrint('Personalization restore: $e');}
    _ready=true;notifyListeners();
  }
  Future<void> record({required String type,VideoModel? video,String query='',int seconds=0}) async {
    if(!_ready)await initialize();
    if(!_personalizationEnabled)return;
    if(type=='search'&&query.trim().isEmpty)return;
    _events.insert(0,ActivityRecord(type,DateTime.now(),title:video?.title??'',category:video?.category??'',query:query.trim(),seconds:seconds.clamp(0,86400)));
    if(_events.length>2000)_events.removeRange(2000,_events.length);
    notifyListeners();await _persist();
  }
  Future<ImportedPlaylist> importPlaylist(String input) async {
    if(!_ready)await initialize();
    if(!_personalizationEnabled)throw const PlaylistImportException('Enable personalization in the privacy settings before importing a playlist.');
    final u=Uri.tryParse(input.trim().startsWith('http')?input.trim():'https://'+input.trim());
    const hosts={'youtube.com','www.youtube.com','m.youtube.com','music.youtube.com'};
    final id=u!=null&&hosts.contains(u.host.toLowerCase())?u.queryParameters['list']:null;
    if(id==null||!RegExp(r'^[A-Za-z0-9_-]{10,}$').hasMatch(id))throw const PlaylistImportException('Enter a valid YouTube playlist URL.');
    if(_apiKey.isEmpty)throw const PlaylistImportException('Playlist link recognized. Public playlist lookup requires a restricted YouTube Data API key supplied at build time.');
    final meta=await _get(Uri.https('youtube.googleapis.com','/youtube/v3/playlists',{'part':'snippet','id':id,'key':_apiKey}));
    final rows=meta['items'];if(rows is! List||rows.isEmpty)throw const PlaylistImportException('Playlist not found or not publicly accessible.');
    final s=(rows.first as Map<String,dynamic>)['snippet'] as Map<String,dynamic>? ?? const {};
    final title=s['title'] as String? ?? 'YouTube playlist',channel=s['channelTitle'] as String? ?? '';
    final videos=<VideoModel>[];String? token;
    do{
      final q=<String,String>{'part':'snippet,contentDetails','playlistId':id,'maxResults':'50','key':_apiKey};if(token!=null)q['pageToken']=token;
      final page=await _get(Uri.https('youtube.googleapis.com','/youtube/v3/playlistItems',q));
      if(page['items'] is List)for(final item in (page['items'] as List).whereType<Map<String,dynamic>>()){
        final sn=item['snippet'] as Map<String,dynamic>? ?? const {},cd=item['contentDetails'] as Map<String,dynamic>? ?? const {},r=sn['resourceId'] as Map<String,dynamic>? ?? const {};
        final vid=(cd['videoId']??r['videoId']) as String?;if(vid==null||vid.isEmpty)continue;
        final ts=sn['thumbnails'] as Map<String,dynamic>? ?? const {},th=(ts['high']??ts['medium']??ts['default']) as Map<String,dynamic>? ?? const {},img=th['url'] as String? ?? 'https://i.ytimg.com/vi/'+vid+'/hqdefault.jpg';
        videos.add(VideoModel(id:vid,title:sn['title'] as String? ?? 'Video',channelName:sn['videoOwnerChannelTitle'] as String? ?? sn['channelTitle'] as String? ?? channel,views:'Playlist',duration:'—',thumbnailUrl:img,channelAvatar:img,isVerified:false,category:'Imported playlist',playbackUrl:'https://www.youtube.com/watch?v='+vid));
      }
      token=page['nextPageToken'] as String?;
    }while(token!=null&&videos.length<500);
    final p=ImportedPlaylist(id,title,channel,videos);_playlists.removeWhere((x)=>x.id==id);_playlists.insert(0,p);
    await record(type:'playlist_import',query:title);await _persist();notifyListeners();return p;
  }
  Future<Map<String,dynamic>> _get(Uri uri) async {
    final c=HttpClient()..connectionTimeout=const Duration(seconds:15);
    try{final req=await c.getUrl(uri);req.headers.set(HttpHeaders.acceptHeader,'application/json');final res=await req.close().timeout(const Duration(seconds:20));final body=await res.transform(utf8.decoder).join();
      if(res.statusCode<200||res.statusCode>=300){var msg='YouTube API error '+res.statusCode.toString();try{msg=((jsonDecode(body) as Map<String,dynamic>)['error'] as Map<String,dynamic>)['message'] as String? ?? msg;}catch(_){}throw PlaylistImportException(msg);}
      final data=jsonDecode(body);if(data is! Map<String,dynamic>)throw const PlaylistImportException('Unexpected YouTube response.');return data;
    }on SocketException{throw const PlaylistImportException('Network error. Check your connection.');}finally{c.close(force:true);}
  }
  Map<String,double> get interestProfile {
    if(!_personalizationEnabled)return const {};
    final out=<String,double>{},now=DateTime.now();
    for(final e in _events){final days=now.difference(e.time).inDays,recency=days<=1?1.0:days<=7?0.8:days<=30?0.55:0.25;
      final weight=(switch(e.type){'like'=>4.0,'watch'=>e.seconds>=120?2.8:1.5,'open'=>.7,'save'=>3.0,'search'=>1.7,'playlist_import'=>2.0,'skip'=>-1.2,'dislike'=>-3.5,_=>0.0})*recency;
      for(final t in _tokens((e.title+' '+e.category+' '+e.query).toLowerCase())){out[t]=(out[t]??0)+weight;}
      if(e.category.isNotEmpty){final k='category:'+e.category.toLowerCase();out[k]=(out[k]??0)+weight;}
    }
    for(final p in _playlists)for(final v in p.videos)for(final t in _tokens(v.title.toLowerCase())){out[t]=(out[t]??0)+.65;}
    return Map.unmodifiable(out);
  }
  List<VideoModel> rankVideos(List<VideoModel> list){
    final profile=interestProfile;if(profile.isEmpty)return List.unmodifiable(list);
    final ranked=list.map((v){var score=0.0;for(final t in _tokens((v.title+' '+v.channelName+' '+v.category).toLowerCase()))score+=profile[t]??0;score+=profile['category:'+v.category.toLowerCase()]??0;return (video:v,score:score);}).toList()
      ..sort((a,b)=>b.score.compareTo(a.score));
    return ranked.map((x)=>x.video).toList(growable:false);
  }
  Set<String> _tokens(String s){const stop={'the','and','for','with','from','that','this','your','you','how','what','when','where','why','are','was','into','about','video','videos','youtube','official','full','new','best','top','এবং','কেন','কী','কিভাবে','করে','থেকে','জন্য','আমার','আপনার','ভিডিও'};return s.split(RegExp(r'[^a-z0-9\u0980-\u09FF]+')).where((x)=>x.length>=2&&!stop.contains(x)).toSet();}
  Future<void> setConsent(bool enabled) async{_consentDecided=true;_personalizationEnabled=enabled;if(!enabled){_events.clear();_playlists.clear();}notifyListeners();await _persist();}
  Future<void> removePlaylist(String id) async{_playlists.removeWhere((p)=>p.id==id);await _persist();notifyListeners();}
  Future<void> clearActivity() async{_events.clear();_playlists.clear();notifyListeners();await _persist();}
  Future<void> _persist(){_queue=_queue.then((_)async{try{final f=await _file();await f.writeAsString(jsonEncode({'consentDecided':_consentDecided,'personalizationEnabled':_personalizationEnabled,'activity':_events.map((e)=>e.toJson()).toList(),'playlists':_playlists.map((p)=>p.toJson()).toList()}),flush:true);}catch(e){debugPrint('Personalization save: $e');}});return _queue;}
}
