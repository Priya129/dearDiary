import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../styles/app_style.dart';
import 'note_editor.dart';
import 'note_reader.dart';

class HomeScreen extends StatefulWidget {
  final String folderId; // Add folderId as a parameter to the constructor

  const HomeScreen({Key? key, required this.folderId}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;
  late User _user; // Initialize a user object
  String searchQuery = ""; // Search query for date or title
  bool isSearching = false; // Track if searching mode is active
  String selectedBackgroundImage = "image1.jpg"; // Default background image
  late String folderId;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  List<String> backgroundImages = [
    "image1.jpg",
    "image2.jpg",
    "image3.jpg",
    "image4.jpg",
    // Add more image names as needed
  ];

  PaletteGenerator? paletteGenerator; // To store the generated palette

  Future<void> _loadPaletteGenerator() async {
    final imageProvider = AssetImage("assets/$selectedBackgroundImage");
    paletteGenerator = await PaletteGenerator.fromImageProvider(imageProvider);
    setState(() {});
  }

  Future<void> _deleteNote(String noteId) async {
    await FirebaseFirestore.instance
        .collection("Users")
        .doc(_user.uid)
        .collection("folders")
        .doc(folderId)
        .collection("Notes")
        .doc(noteId)
        .delete();
  }

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    _loadPaletteGenerator();
    folderId = widget.folderId;
  }

  @override
  Widget build(BuildContext context) {
    Color appBarColor = AppStyle.cardsColor[0];
    if (paletteGenerator != null) {
      appBarColor = paletteGenerator!.dominantColor?.color ?? appBarColor;
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        title: isSearching
            ? TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search by Date or Title",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              )
            : Text("My Diary"),
        centerTitle: true,
        backgroundColor: appBarColor, // Set the app bar color
        foregroundColor: Colors.white,
        actions: [
          isSearching
              ? IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: () {
                    setState(() {
                      isSearching = false;
                      searchQuery = "";
                    });
                  },
                )
              : IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      isSearching = true;
                    });
                  },
                ),
          DropdownButton<String>(
            underline: null,
            value: selectedBackgroundImage,
            items: backgroundImages.map((imageName) {
              return DropdownMenuItem<String>(
                value: imageName,
                child: Row(
                  children: [
                    SizedBox(width: 8), // Add some spacing
                    Text(
                      imageName.split('.').first,
                      style: TextStyle(
                        color: Colors.white, // Change the text color to white
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                if (newValue != null) {
                  selectedBackgroundImage = newValue;
                  _loadPaletteGenerator(); // Load the new palette
                }
              });
            },
            dropdownColor:
                appBarColor, // Change the dropdown background color to pink
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/$selectedBackgroundImage"),
            fit: BoxFit.cover,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("Users")
              .doc(_user.uid)
              .collection("folders")
              .doc(folderId)
              .collection("Notes")
              .orderBy('creation_date', descending: true)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  "There are no Notes",
                  style: GoogleFonts.nunito(
                    color: Colors.black26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }

            final List<QueryDocumentSnapshot> filteredNotes =
                snapshot.data!.docs.where((note) {
              final title = note['note_title'].toLowerCase();
              final date = note['creation_date'].toLowerCase();
              return title.contains(searchQuery.toLowerCase()) ||
                  date.contains(searchQuery.toLowerCase());
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(14.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                ),
                itemCount: filteredNotes.length,
                itemBuilder: (context, index) {
                  final note = filteredNotes[index];
                  final title = note['note_title'];
                  final date = note['creation_date'];
                  final mainContent = note['note_content'];
                  final colorId = note['color_id'];
                  final wordss = title.split(' ');
                  final truncatedContents = wordss.take(2).join(' ');
                  final words = mainContent.split(' ');
                  final truncatedContent = words.take(6).join(' ');

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteReaderScreen(note, _user,  folderId: folderId, ),
                        ),
                      );
                    },
                    child: Card(
                      color: AppStyle.cardsColor[colorId],
                      child: ListTile(
                        title: Text(
                          truncatedContents,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(date),
                            Text(truncatedContent),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.white),
                          onPressed: () {
                            _showDeleteConfirmationDialog(note.id);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(folderId: folderId),
            ),
          );
        },
        label: Text("Add"),
        icon: Icon(Icons.note_alt_outlined),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        elevation: 0.0,
      ),
      drawer: Drawer(
        child: Container(
          color: appBarColor,
          child: ListView(children: [
            Container(
              height: 180,
              child: DrawerHeader(
                child: Column(
                  children: [
                    SizedBox(
                      height: 20,
                    ),
                    Image.asset(
                      'assets/heart.png',
                      width: 50,
                      height: 80,
                      color: Colors.white,
                    ),
                    Text(
                      "Welcome " + user!.email!,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.white),
              title: Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                final user = _auth.currentUser;
                if (user != null) {
                  if (user.providerData
                      .any((userInfo) => userInfo.providerId == "google.com")) {
                    _googleSignIn.signOut();
                  }
                  _auth.signOut();
                  print("User signed out");
                } else {
                  print("User is not signed in.");
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.white),
              title:
                  Text('Delete Account', style: TextStyle(color: Colors.white)),
              onTap: () async {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Confirm Deletion'),
                      content: Text(
                          'Are you sure you want to delete your account? This action is irreversible.'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        TextButton(
                          child: Text('Delete'),
                          onPressed: () {
                            _deleteAccount();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('users').doc(user?.uid).delete();
      await user?.delete();
      await _auth.signOut();
    } catch (e) {
      print("Error deleting account: $e");
    }
  }

  void _showDeleteConfirmationDialog(String noteId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Delete"),
          content: Text("Are you sure you want to delete this note?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteNote(noteId);
              },
            ),
          ],
        );
      },
    );
  }
}
