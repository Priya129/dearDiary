import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../styles/app_style.dart';

class MediaWidget extends StatelessWidget {
  final String path;
  final bool isVideo;

  MediaWidget({required this.path, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
      child: isVideo ? _buildVideoWidget() : _buildImageWidget(),
    );
  }

  Widget _buildImageWidget() {
    return Image.file(
      File(path),
      alignment: Alignment.centerLeft,
      height: 300,
      width: 300,
      fit: BoxFit.fill,
    );
  }

  Widget _buildVideoWidget() {
    final VideoPlayerController controller =
        VideoPlayerController.file(File(path));

    return GestureDetector(
      onTap: () {
        // Handle video tap (play/pause)
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class NoteReaderScreen extends StatefulWidget {
  final String folderId;
  NoteReaderScreen(this.doc, this._user, {Key? key, required this.folderId})
      : super(key: key);
  final QueryDocumentSnapshot doc;
  final User? _user;
  @override
  State<NoteReaderScreen> createState() => _NoteReaderScreenState();
}

class AudioInfo {
  String name;
  String url;
  bool isPlaying;
  bool isPaused;

  AudioInfo({
    required this.name,
    required this.url,
    this.isPlaying = false,
    this.isPaused = false,
  });
}

class _NoteReaderScreenState extends State<NoteReaderScreen> {
  final player = AudioPlayer();
  List<AudioPlayer> audioPlayers = [];
  bool isRecording = false;
  late Record audioRecord;
  String audioPath = '';
  List<RecordedAudioo> recordedAudioss = [];
  List<String> localImagePaths = [];
  List<String> imageUrls = [];
  TextEditingController _titleController = TextEditingController();
  TextEditingController _mainController = TextEditingController();
  bool _isEditMode = false;
  List<AudioInfo> recordedAudios = [];
  bool isPlaying = false;
  bool isPaused = false;
  String formattedDate = DateFormat('MMMM d, y h:mm a').format(DateTime.now());
  int currentlyPlayingIndex = -1;
  List<String> videoPathss = [];
  List<String> ImagePaths = [];
  List<VideoPlayerController> _controllerss = [];
  List<ChewieController> _chewieControllers = [];
  bool _controllersInitialized = false;
  List<bool> _isControllerInitialized = [];
  bool isPlay = false;
  late String folderId;
  List<VideoPlayerController> _controllers = [];
  final ImagePicker _imagePicker = ImagePicker();
  List<String> videoPaths = [];

  Future<void> _deleteImage(int index) async {
    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete"),
          content: Text("Are you sure you want to delete this?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Fetch the current images
        List<String> currentImages = List<String>.from(widget.doc["images"]);

        // Remove the image at the specified index from the UI
        setState(() {
          currentImages.removeAt(index);
        });

        // Get a reference to the document
        DocumentReference documentReference = FirebaseFirestore.instance
            .collection("Users")
            .doc(widget._user?.uid)
            .collection("folders")
            .doc(folderId)
            .collection("Notes")
            .doc(widget.doc.id);

        // Update the Firestore document
        await documentReference.update({"images": currentImages});

        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image deleted successfully")),
        );
      } catch (error) {
        // Log the error for debugging purposes
        print("Error deleting image: $error");

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting Image. Please try again.")),
        );
      }
    }
  }


  Future<void> _initializeController(String videoPath) async {
    final controller = VideoPlayerController.file(File(videoPath));
    await controller.initialize();
    await controller.setLooping(true);
    setState(() {
      _controllers.add(controller);
    });
  }

  Future<void> _pickVideoFromGallery() async {
    final pickedFile = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final videoPath = pickedFile.path;
      videoPaths.add(videoPath); // Add the video path to the list
      await _initializeController(videoPath);
    }
  }

  Future<void> _recordVideo() async {
    final pickedFile = await _imagePicker.pickVideo(
      source: ImageSource.camera,
    );

    if (pickedFile != null) {
      final videoPath = pickedFile.path;
      videoPaths.add(videoPath); // Add the video path to the list
      await _initializeController(videoPath);
    }
  }

  Future<void> startRecording() async {
    try {
      if (await audioRecord.hasPermission()) {
        await audioRecord.start();
        setState(() {
          isRecording = true;
        });
      }
    } catch (e) {
      print("Error Start Recording: $e");
    }
  }

  Future<void> stopRecording() async {
    try {
      String? path = await audioRecord.stop();
      setState(() {
        isRecording = false;
        audioPath = path!;
      });
      _showRecordingNameDialog(audioPath);
    } catch (e) {
      print("Error Stop Recording: $e");
    }
  }

  void _showVideoSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Video Source"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.video_library),
                title: Text("Gallery"),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _pickVideoFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text("Camera"),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _recordVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRecordingNameDialog(String path) async {
    String recordingName = '';
    final int maxCharacters = 25;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Recording Name'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    onChanged: (name) {
                      setState(() {
                        if (name.length <= maxCharacters) {
                          recordingName = name;
                        } else {
                          recordingName = name.substring(0, maxCharacters);
                        }
                      });
                    },
                    decoration: InputDecoration(labelText: 'Recording Name'),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Maximum $maxCharacters characters',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8.0),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog

                setState(() {
                  recordedAudioss.add(
                    RecordedAudioo(
                      audioPath,
                      recordingName,
                      false,
                      false,
                    ),
                  );
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showDeleteRecordingDialog(int index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Recording'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this recording?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Yes'),
              onPressed: () {
                setState(() {
                  recordedAudioss.removeAt(index);
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> playRecording(int index) async {
    try {
      await player.setFilePath(recordedAudioss[index].path);
      await player.play();
    } catch (e) {
      print("Error Play Recording: $e");
    }
  }

  void stopPlayback() async {
    await player.pause();
    setState(() {
      for (var audio in recordedAudios) {
        audio.isPlaying = false;
        audio.isPaused = false;
      }
    });
  }

  @override
  void initState() {
    if (widget.doc["images"] != null) {
      imageUrls = List<String>.from(widget.doc["images"]);
    }
    if (widget.doc["video"] != null) {
      videoPathss = List<String>.from(widget.doc["video"]);
    }
    audioRecord = Record();
    super.initState();
    _titleController.text = widget.doc["note_title"] ?? "";
    _mainController.text = widget.doc["note_content"] ?? "";
    _initializeRecordedAudios();
    if (!_controllersInitialized) {
      _initializeVideoControllerss();
      _controllersInitialized = true;
      folderId = widget.folderId;
    }
  }

  void _initializeVideoControllerss() {
    _isControllerInitialized =
        List.generate(videoPathss.length, (index) => false);

    for (var i = 0; i < videoPathss.length; i++) {
      VideoPlayerController _controller = VideoPlayerController.network(
        Uri.parse(videoPathss[i]).toString(),
      );
      _controllerss.add(_controller);

      ChewieController chewieController = ChewieController(
        videoPlayerController: _controller,
        autoInitialize: false,
        looping: false,
        autoPlay: false,
      );
      _chewieControllers.add(chewieController);
    }
  }

  Widget _buildVideos() {
    return Container(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true, // Set shrinkWrap to true
        itemCount: videoPathss.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onLongPress: () {
              _deleteVideo(index);
            },
            onTap: () {
              _playPauseVideo(_controllerss[index]);
            },
            child: Container(
              width: 300, // Adjust the width to your preference
              margin: EdgeInsets.all(8.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: videoPathss[index],
                    placeholder: (context, url) => CircularProgressIndicator(),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                  FutureBuilder(
                    future: _initializeControllerss(index),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return Chewie(
                          controller: _chewieControllers[index],
                        );
                      } else {
                        return CircularProgressIndicator();
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteVideo(int index) async {
    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Video"),
          content: Text("Are you sure you want to delete this video?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() async {
        if (index >= 0 && index < _chewieControllers.length) {
          // Dispose of ChewieController before removing it
          _chewieControllers[index].dispose();
          _chewieControllers.removeAt(index);
        }

        if (index >= 0 && index < videoPathss.length) {
          // Delete the video file from Firebase Storage
          String videoUrl = videoPathss[index];
          Reference storageReference =
          FirebaseStorage.instance.refFromURL(videoUrl);

          try {
            await storageReference.delete();
          } catch (e) {
            print("Error deleting video from Firebase Storage: $e");
          }

          // Update the UI by removing the video details
          videoPathss.removeAt(index);

          // Ensure index is within the valid range before accessing the lists
          if (index >= 0 && index < _controllerss.length) {
            _controllerss[index].dispose();
            _controllerss.removeAt(index);
          }
          if (index >= 0 && index < _isControllerInitialized.length) {
            _isControllerInitialized.removeAt(index);
          }
        }

        // Update the videoPaths field in Firestore with the new list.
        await FirebaseFirestore.instance
            .collection("Users")
            .doc(widget._user?.uid)
            .collection("folders")
            .doc(folderId)
            .collection("Notes")
            .doc(widget.doc.id)
            .update({"video": videoPathss});
      });


      // Navigate back after video deletion
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Video deleted successfully")),
      );


    }
  }


  Future<void> _initializeControllerss(int index) async {
    if (!_isControllerInitialized[index]) {
      await _controllerss[index].initialize();
      _chewieControllers[index].enterFullScreen();
      _isControllerInitialized[index] = true;
    }
  }

  void _playPauseVideo(VideoPlayerController controller) {
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _initializeRecordedAudios() {
    List<dynamic>? audioDataList =
        widget.doc["recorded_audios"] as List<dynamic>?;
    if (audioDataList != null) {
      // Initialize audio players for all URLs
      audioPlayers = List.generate(
        audioDataList.length,
        (index) => AudioPlayer(),
      );
      recordedAudios = audioDataList.map((audioData) {
        return AudioInfo(
          name: audioData["name"] ?? "",
          url: audioData["url"] ?? "",
        );
      }).toList();
    }
  }

  @override
  void dispose() {
    audioRecord.dispose();
    _titleController.dispose();
    _mainController.dispose();
    for (var controller in _controllerss) {
      controller.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  Future<void> _updateNote() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading indicator or animation
              CircularProgressIndicator(),
              SizedBox(height: 16.0),
              Text("Updating Note..."),
            ],
          ),
        );
      },
    );

    try {
      String newTitle = _titleController.text;
      String newContent = _mainController.text;

      // Update note details in Firestore
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget._user?.uid)
          .collection("folders")
          .doc(folderId)
          .collection("Notes")
          .doc(widget.doc.id)
          .update({
        "note_title": newTitle,
        "note_content": newContent,
      });

      // Upload new images to Firebase Storage
      List<String> imageUrls = List<String>.from(widget.doc["images"]);

      for (int i = 0; i < localImagePaths.length; i++) {
        File imageFile = File(localImagePaths[i]);
        String imageName = "${widget._user?.uid}_${widget.doc.id}_image_$i.jpg";

        Reference storageReference =
            FirebaseStorage.instance.ref().child("images/$imageName");

        await storageReference.putFile(imageFile);

        String imageUrl = await storageReference.getDownloadURL();

        imageUrls.add(imageUrl);
      }


      // Update the images field in Firestore with the modified array
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget._user?.uid)
          .collection("folders")
          .doc(folderId)
          .collection("Notes")
          .doc(widget.doc.id)
          .update({"images": imageUrls});
      List<String> videoUrls = List<String>.from(widget.doc["video"]);

      for (String localVideoPath in videoPaths) {
        String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference referenceRoot = FirebaseStorage.instance.ref();
        Reference referenceDirVideos = referenceRoot.child('videos');
        Reference referenceVideoToUpload =
        referenceDirVideos.child('$uniqueFileName.mp4');

        try {
          await referenceVideoToUpload.putFile(File(localVideoPath));
          String videoUrl = await referenceVideoToUpload.getDownloadURL();
          videoUrls.add(videoUrl);
        } catch (error) {
          print('Error uploading video: $error');
        }
      }

      // Update the video field in Firestore with the modified array
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget._user?.uid)
          .collection("folders")
          .doc(folderId)
          .collection("Notes")
          .doc(widget.doc.id)
          .update({"video": videoUrls});



      // Upload new recorded audios to Firebase Storage
      List<Map<String, dynamic>> audioDataList =
          List<Map<String, dynamic>>.from(widget.doc["recorded_audios"]);

      for (int i = 0; i < recordedAudioss.length; i++) {
        RecordedAudioo audio = recordedAudioss[i];
        String audioName = "${widget._user?.uid}_${widget.doc.id}_audio_$i.mp3";

        Reference storageReference =
            FirebaseStorage.instance.ref().child("audios/$audioName");

        await storageReference.putFile(File(audio.path));

        String audioUrl = await storageReference.getDownloadURL();

        audioDataList.add({
          "name": audio.name,
          "url": audioUrl,
        });
      }

      // Update the recorded_audios field in Firestore with the modified array
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget._user?.uid)
          .collection("folders")
          .doc(folderId)
          .collection("Notes")
          .doc(widget.doc.id)
          .update({"recorded_audios": audioDataList});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Note updated successfully")),
      );
      _toggleEditMode();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating note: $error")),
      );
    } finally {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _playOrPauseRecording(int index) async {
    try {
      final audioPlayer = audioPlayers[index];
      final url = recordedAudios[index].url;
      await audioPlayer.setUrl(url);
      await audioPlayer.play();
    } catch (e) {
      print("Error Play/Pause Recording: $e");
    }
  }

  Future<void> stop(int index) async {
    try {
      final audioPlayer = audioPlayers[index];
      final url = recordedAudios[index].url;
      await audioPlayer.setUrl(url);
      await audioPlayer.stop();
    } catch (e) {
      print("Error Play/Pause Recording: $e");
    }
  }

  Future<void> _deleteImageOrRecording(int index) async {
    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete"),
          content: Text("Are you sure you want to delete this?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        recordedAudios.removeAt(index);
        // Update the recorded_audios field in Firestore with the new list.
        List<Map<String, dynamic>> audioDataList =
            recordedAudios.map((audioInfo) {
          return {
            "name": audioInfo.name,
            "url": audioInfo.url,
          };
        }).toList();
        FirebaseFirestore.instance
            .collection("Users")
            .doc(widget._user?.uid)
            .collection("folders")
            .doc(folderId)
            .collection("Notes")
            .doc(widget.doc.id)
            .update({"recorded_audios": audioDataList}).then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Recording deleted successfully")),
          );
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting recording: $error")),
          );
        });
      });
    }
  }

  Widget _buildImageOrRecordingList() {
    return Column(
      children: <Widget>[
        for (var i = 0; i < recordedAudios.length; i++)
          Card(
            color: Colors.white,
            elevation: 3.0,
            margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(recordedAudios[i].name),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.multitrack_audio),
                        onPressed: () {
                          _playOrPauseRecording(i);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.stop),
                        onPressed: () {
                          stop(i);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              onLongPress: () {
                _deleteImageOrRecording(i);
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    int colorId = widget.doc['color_id'] ?? 0;
    return Scaffold(
      backgroundColor: AppStyle.cardsColor[colorId],
      appBar: AppBar(
        title: Text("DearDiary"),
        backgroundColor: AppStyle.cardsColor[colorId],
        elevation: 0.0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              setState(() {
                _toggleEditMode();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode)
                TextField(
                  controller: _titleController,
                  style: AppStyle.mainContent,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    widget.doc["note_title"] ?? "",
                    style: AppStyle.mainContent,
                  ),
                ),
              SizedBox(height: 6.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  widget.doc["creation_date"] ?? "",
                  style: AppStyle.dateTitle,
                ),
              ),
              SizedBox(height: 18.0),
              if (_isEditMode)
                TextField(
                  controller: _mainController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: AppStyle.mainTitle,
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    widget.doc["note_content"] ?? "",
                    style: AppStyle.mainTitle,
                  ),
                ),
              SizedBox(height: 12.0),
              if (recordedAudios.isNotEmpty) _buildImageOrRecordingList(),
              SizedBox(height: 12.0),
              if (videoPathss.isNotEmpty) _buildVideos(),
              if (widget.doc["images"] != null)
                Container(
                  height: 300, // Set a reasonable height or use Expanded
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onLongPress: () async {
                            _deleteImage(index);
                          },
                          onDoubleTap: () {
                            _showFullScreenDialog(imageUrls[index]);
                          },
                          child: _buildImage(imageUrls[index]),
                        ),
                      );
                    },
                  ),
                ) ,


              Visibility(
                visible: recordedAudioss.isNotEmpty,
                child: Container(
                  height: recordedAudioss.length < 2 ? 100 : 400,
                  child: ListView.builder(
                    itemCount: recordedAudioss.length,
                    itemBuilder: (BuildContext context, int index) {
                      final audio = recordedAudioss[index];
                      return Card(
                        color: Colors.white,
                        elevation: 3.0,
                        margin: EdgeInsets.symmetric(vertical: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(audio.name),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.multitrack_audio),
                                      onPressed: () {
                                        playRecording(index);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.stop),
                                      onPressed: () {
                                        stopPlayback();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onLongPress: () {
                              showDeleteRecordingDialog(index);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Visibility(
                visible: localImagePaths.isNotEmpty,
                child: Align(
                  alignment: Alignment.centerLeft, // Align to the left
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: localImagePaths.asMap().entries.map((entry) {
                        int index = entry.key;
                        String localImagePath = entry.value;
                        return GestureDetector(
                          onLongPress: () {
                            showDeleteImageDialog(index);
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8.0),
                            child: MediaWidget(
                                path: localImagePath, isVideo: false),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: _controllers.isNotEmpty,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    height: 300,
                    width: MediaQuery.of(context).size.width,
                    child: Center(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _controllers.length,
                        itemBuilder: (BuildContext context, int index) {
                          final controller = _controllers[index];
                          // Ensure the controller is initialized and not null
                          if (controller.value.isInitialized) {
                            return GestureDetector(
                              onTap: () {
                                // Handle video tap (play/pause)
                                if (controller.value.isPlaying) {
                                  controller.pause();
                                } else {
                                  controller.play();
                                }
                              },
                              onLongPress: () {
                                // Show a dialog for confirmation on long press
                                showDeleteDialog(context, index);
                              },
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio,
                                child: Card(child: VideoPlayer(controller)),
                              ),
                            );
                          } else {
                            return SizedBox
                                .shrink(); // Placeholder for non-initialized controllers
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isEditMode
          ? Padding(
              padding: const EdgeInsets.all(15.0),
              child: Card(
                elevation: 5.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            isRecording = !isRecording;
                          });
                          if (isRecording) {
                            startRecording();
                          } else {
                            stopRecording();
                          }
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: isRecording
                                ? Lottie.asset(
                                    'assets/neww.json',
                                    width: 100,
                                    height: 100,
                                  )
                                : Icon(Icons.mic,
                                    color: AppStyle.cardsColor[colorId]),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          captureImage();
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.camera_alt,
                                color: AppStyle.cardsColor[colorId]),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _showVideoSourceDialog();
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(Icons.video_camera_back,
                                color: AppStyle.cardsColor[colorId]),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          _updateNote();
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.save,
                              color: AppStyle.cardsColor[colorId],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      // If imageUrl is not null or empty, display the image
      return Container(
        height: 600,
        width: 300,
        child: Image.network(imageUrl, fit: BoxFit.cover),
      );
    } else {
      // If imageUrl is null or empty, show a no internet icon
      return Icon(
        Icons.signal_wifi_off, // You can use any other appropriate icon
        size: 50,
        color: Colors.red, // You can use any other appropriate color
      );
    }
  }


  Future<void> captureImage() async {
    ImagePicker imagePicker = ImagePicker();

    // Show a dialog to let the user choose between camera and gallery
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text("Choose Image Source"),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context);
                XFile? file =
                    await imagePicker.pickImage(source: ImageSource.camera);
                if (file != null) {
                  setState(() {
                    localImagePaths.add(file.path);
                  });
                }
              },
              child: Text("Camera"),
            ),
            SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(context);
                XFile? file =
                    await imagePicker.pickImage(source: ImageSource.gallery);
                if (file != null) {
                  setState(() {
                    localImagePaths.add(file.path);
                  });
                }
              },
              child: Text("Gallery"),
            ),
          ],
        );
      },
    );
  }
  void _showFullScreenDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop(); // Dismiss the dialog on tap
          },
          child: InteractiveViewer(
            boundaryMargin: EdgeInsets.all(20.0),
            minScale: 0.1,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }





  Future<void> showDeleteImageDialog(int index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Image'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this image?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Yes'),
              onPressed: () {
                setState(() {
                  localImagePaths.removeAt(index); // Remove the deleted image
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showDeleteDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Delete Video"),
          content: Text("Are you sure you want to delete this video?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () {
                // Remove the video from the UI
                setState(() {
                  _controllers.removeAt(index);
                });
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }
}



class RecordedAudioo {
  final String path;
  String name;
  bool isPlaying;
  bool isPaused;

  RecordedAudioo(
    this.path,
    this.name,
    this.isPlaying,
    this.isPaused,
  );
}
