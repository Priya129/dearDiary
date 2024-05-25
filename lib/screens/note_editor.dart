import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import '../styles/app_style.dart';
import 'RegisterPage.dart';

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
      width: 200,
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

class NoteEditorScreen extends StatefulWidget {
  final String folderId;

  const NoteEditorScreen({Key? key, required this.folderId}) : super(key: key);

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool isRecording = false;
  bool isPlaying = false;
  late Record audioRecord;
  late AudioPlayer audioPlayer;
  String audioPath = '';
  List<RecordedAudio> recordedAudios = [];
  int color_id = Random().nextInt(AppStyle.cardsColor.length);
  String formattedDate = DateFormat('MMMM d, y h:mm a').format(DateTime.now());
  TextEditingController _titleController = TextEditingController();
  TextEditingController _mainController = TextEditingController();
  // Create a list to store local image paths
  List<String> localImagePaths = [];
  List<VideoPlayerController> _controllers = [];
  final ImagePicker _imagePicker = ImagePicker();
  List<String> videoPaths = [];
  late String folderId;

// Added recording duration variable
  bool isSaving = false; // Track saving state
  bool showLottie = false; // Show/hide Lottie animation

  @override
  void initState() {
    audioPlayer = AudioPlayer();
    audioRecord = Record();
    _checkUserSignIn();
    folderId = widget.folderId;
    super.initState();
  }

  void _checkUserSignIn() {
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    audioRecord.dispose();
    super.dispose();
    for (var controller in _controllers) {
      controller.dispose();
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

  Future<void> playRecording(int index) async {
    try {
      if (recordedAudios[index].isPlaying) {
        await audioPlayer.stop();
        setState(() {
          recordedAudios[index].isPlaying = false;
          recordedAudios[index].isPaused = false;
        });
      } else {
        audio_players.Source urlSource =
            audio_players.UrlSource(recordedAudios[index].path);
        print("URL: $recordedAudios[index].path");
        await audioPlayer.play(urlSource);
        setState(() {
          for (var i = 0; i < recordedAudios.length; i++) {
            if (i == index) {
              recordedAudios[i].isPlaying = true;
              recordedAudios[i].isPaused = false;
            } else {
              recordedAudios[i].isPlaying = false;
              recordedAudios[i].isPaused = false;
            }
          }
        });
      }
    } catch (e) {
      print("Error Play Recording: $e");
    }
  }

  void stopPlayback() async {
    await audioPlayer.stop();
    setState(() {
      for (var audio in recordedAudios) {
        audio.isPlaying = false;
        audio.isPaused = false;
      }
    });
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
                  recordedAudios.add(
                    RecordedAudio(
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
                  localImagePaths.removeAt(index);
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
                  recordedAudios.removeAt(index);
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

  Future<void> saveNote() async {
    if (_user == null) {
      // Show the login screen when the user is not signed in.
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => RegisterPage(
                    showLogInPage: () {},
                  )));
      return;
    }
    if (_titleController.text.isEmpty || _mainController.text.isEmpty) {
      return;
    }

    // Show Lottie animation while saving
    setState(() {
      isSaving = true;
      showLottie = true;
    });

    String noteId = _firestore.collection("Notes").doc().id;
    Map<String, dynamic> noteData = {
      "note_title": _titleController.text,
      "creation_date": formattedDate,
      "note_content": _mainController.text,
      "color_id": color_id,
      "images": [],
      "recorded_audios": [],
      "video": [],
    };

    // Upload local images to Firebase Storage
    for (String localImagePath in localImagePaths) {
      String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference referenceRoot = FirebaseStorage.instance.ref();
      Reference referenceDirImages = referenceRoot.child('images');
      Reference referenceImageToUpload =
          referenceDirImages.child(uniqueFileName);

      try {
        await referenceImageToUpload.putFile(File(localImagePath));
        String imageUrl = await referenceImageToUpload.getDownloadURL();
        noteData["images"].add(imageUrl);
      } catch (error) {
        print('Error uploading image: $error');
      }
    }

    for (String localvideoPath in videoPaths) {
      String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference referenceRoot = FirebaseStorage.instance.ref();
      Reference referenceDirVideos = referenceRoot.child('videos');
      Reference referenceImageToUpload =
          referenceDirVideos.child(uniqueFileName + ".mp4");

      try {
        await referenceImageToUpload.putFile(File(localvideoPath));
        String videoUrl = await referenceImageToUpload.getDownloadURL();
        noteData["video"].add(videoUrl);
      } catch (error) {
        print('Error uploading video: $error');
      }
    }

    // Upload recorded audios to Firebase Storage and save their names, URLs, and durations
    List<Map<String, dynamic>> audioList = [];
    for (var audio in recordedAudios) {
      String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference referenceRoot = FirebaseStorage.instance.ref();
      Reference referenceDirAudios = referenceRoot.child('audios');
      Reference referenceAudioToUpload =
          referenceDirAudios.child(uniqueFileName + ".mp3");

      try {
        final metadata = SettableMetadata(
            contentType: 'audio/mp3'); // Set the content type to audio/mp3
        await referenceAudioToUpload.putFile(File(audio.path), metadata);

        String audioUrl = await referenceAudioToUpload.getDownloadURL();

        // Capture the duration as an integer (milliseconds)

        audioList.add({
          "name": audio.name, // Change the name to the unique file name
          "url": audioUrl,
          // Include the duration here
        });
      } catch (error) {
        print('Error uploading audio: $error');
      }
    }
// Modify other fields in your noteData if needed
    noteData["recorded_audios"] = audioList;

    try {
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(_user!.uid)
          .collection("folders")
          .doc(folderId)
          .collection("Notes")
          .doc(noteId)
          .set(noteData);
      print('Note saved successfully');
      Navigator.pop(context);
    } catch (error) {
      print("Failed to add a new Note due to $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.cardsColor[color_id],
      appBar: AppBar(
        backgroundColor: AppStyle.cardsColor[color_id],
        elevation: 0.0,
        iconTheme: IconThemeData(color: Colors.black),
        title: Text(
          "DearDiary",
          style: TextStyle(color: Colors.black),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Title',
                    ),
                    style: AppStyle.mainContent,
                  ),
                  SizedBox(height: 5.0),
                  Text(formattedDate, style: AppStyle.dateTitle),
                  SizedBox(height: 20.0),
                  TextField(
                    controller: _mainController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Content',
                    ),
                    style: AppStyle.mainTitle,
                  ),
                ],
              ),
            ),
            Visibility(
              visible: recordedAudios.isNotEmpty,
              child: Container(
                height: recordedAudios.length < 3 ? 150 : 300,
                child: ListView.builder(
                  itemCount: recordedAudios.length,
                  itemBuilder: (BuildContext context, int index) {
                    final audio = recordedAudios[index];
                    return Card(
                      elevation: 3.0,
                      color: Colors.white,
                      margin:
                          EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          // Adjust opacity as needed
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                        child: ListTile(
                          title: Text(audio.name),
                          trailing: InkWell(
                            onTap: () {
                              if (audio.isPlaying) {
                                stopPlayback();
                              } else {
                                playRecording(index);
                              }
                            },
                            child: Icon(Icons.multitrack_audio),
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
                          child:
                              MediaWidget(path: localImagePath, isVideo: false),
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
      bottomNavigationBar: Padding(
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
                              color: AppStyle.cardsColor[color_id]),
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
                          color: AppStyle.cardsColor[color_id]),
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
                          color: AppStyle.cardsColor[color_id]),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    saveNote();
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: isSaving
                          ? Lottie.asset(
                              'assets/saving.json',
                              width: 100,
                              height: 100,
                            )
                          : Icon(Icons.save_as,
                              color: AppStyle.cardsColor[color_id]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class RecordedAudio {
  final String path;
  String name;
  bool isPlaying;
  bool isPaused;

  RecordedAudio(this.path, this.name, this.isPlaying, this.isPaused);
}
