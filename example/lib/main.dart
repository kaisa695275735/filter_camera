import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:filter_camera/filter_camera.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: CupertinoButton(child: Text('Start'), onPressed: (){
            FilterCamera.startPreview().then((int textureId){
              Navigator.push(context, new MaterialPageRoute(builder: (context) {
                return WillPopScope(child: Scaffold(
                  body: Texture(textureId: textureId),
                ), onWillPop: () {
                  FilterCamera.stopPreview();
                });
              }));

            });
          }),
        ),
      )),
    );
  }
}
