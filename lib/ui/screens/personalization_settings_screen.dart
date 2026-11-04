import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/personalization_service.dart';

class PersonalizationSettingsScreen extends StatelessWidget{
  const PersonalizationSettingsScreen({super.key});
  @override Widget build(BuildContext context){final p=context.watch<PersonalizationService>();final interests=p.interestProfile.entries.where((e)=>e.value>.5&&!e.key.startsWith('category:')).toList()..sort((a,b)=>b.value.compareTo(a.value));
    return Scaffold(appBar:AppBar(title:const Text('Personalization & privacy')),body:ListView(padding:const EdgeInsets.all(16),children:[
      Text('Your activity stays on this device',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),const Text('Tube Arena uses in-app searches, likes, saves, watch activity and imported public playlist metadata to rank recommendations. This prototype stores personalization data locally.'),
      const SizedBox(height:20),Card(child:ListTile(leading:const Icon(Icons.insights),title:const Text('Activity records'),trailing:Text(p.activityCount.toString()))),
      Card(child:ListTile(leading:const Icon(Icons.playlist_play),title:const Text('Imported playlists'),trailing:Text(p.playlists.length.toString()))),
      const SizedBox(height:20),Text('Detected interests',style:Theme.of(context).textTheme.titleMedium),
      if(interests.isEmpty)const Text('Use Tube Arena to build your interest profile.')else Wrap(spacing:8,children:interests.take(20).map((e)=>Chip(label:Text(e.key))).toList()),
      const SizedBox(height:24),OutlinedButton.icon(onPressed:p.activityCount==0&&p.playlists.isEmpty?null:()async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Clear personalization data?'),content:const Text('This removes locally stored activity and imported playlists.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Clear'))]));if(ok==true&&context.mounted)await context.read<PersonalizationService>().clearActivity();},icon:const Icon(Icons.delete_sweep),label:const Text('Clear activity and imported data')),
    ]));}
}
