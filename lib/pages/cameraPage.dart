import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  List<CameraDescription> cameras = [];
  CameraDescription? selectedCamera;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      selectedCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        selectedCamera!,
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller.initialize();
      setState(() {});
    } catch (e) {
      print('Error initializing camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera: $e')),
      );
    }
  }

  Future<void> _switchCamera() async {
    try {
      final newCamera = cameras.firstWhere(
            (camera) => camera.lensDirection != selectedCamera?.lensDirection,
      );

      setState(() {
        selectedCamera = newCamera;
      });

      await _controller.dispose();

      _controller = CameraController(
        selectedCamera!,
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller.initialize();
      setState(() {});
    } catch (e) {
      print('Error switching camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error switching camera: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take a Picture'),
      ),
      body: Column(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: FloatingActionButton(
                    onPressed: () async {
                      try {
                        await _initializeControllerFuture;

                        final image = await _controller.takePicture();

                        if (!context.mounted) return;

                        Navigator.pop(context, image.path);
                      } catch (e) {
                        print(e);
                      }
                    },
                    child: const Icon(Icons.camera_alt, size: 32),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: FloatingActionButton(
                    onPressed: _switchCamera,
                    child: const Icon(Icons.flip_camera_ios, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
