
import 'package:deardiary_myjournal/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  TextEditingController nameController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  bool _isSaving = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String searchQuery = "";
  bool isSearching = false;

  @override
  void initState() {
    _checkUserSignIn();
    _user = FirebaseAuth.instance.currentUser!;
    super.initState();
  }

  void _checkUserSignIn() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        setState(() {
          _user = user;
        });
      }
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      floatingActionButton: _buildFloatingActionButton(),
      drawer: _buildDrawer(),
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: _buildFolderList(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: isSearching
          ? _buildSearchTextField()
          : Text("DearDiary"),
      centerTitle: true,
      backgroundColor: Colors.deepPurple.shade100,
      foregroundColor: Colors.white,
      actions: [
        isSearching
            ? _buildCancelSearchButton()
            : _buildSearchButton(),
      ],
    );
  }

  Widget _buildSearchTextField() {
    return TextField(
      controller: searchController,
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
    );
  }

  IconButton _buildSearchButton() {
    return IconButton(
      icon: Icon(Icons.search),
      onPressed: () {
        setState(() {
          isSearching = true;
        });
      },
    );
  }

  IconButton _buildCancelSearchButton() {
    return IconButton(
      icon: Icon(Icons.cancel),
      onPressed: () {
        setState(() {
          isSearching = false;
          searchQuery = "";
          searchController.clear();
        });
      },
    );
  }

  FloatingActionButton _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        _showAddFolderDialog(context);
      },
      label: Text('Create Folder'),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.deepPurple.shade100,
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
                    "Welcome " + _user!.email!,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(Icons.exit_to_app, 'Sign Out', _signOut),
          _buildDrawerItem(Icons.delete, 'Delete Account', _showDeleteAccountDialog),
        ]),
      ),
    );
  }

  ListTile _buildDrawerItem(IconData icon, String title, Function onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(color: Colors.white),
      ),
      onTap: () {
        onTap();
      },
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/image2.jpg'),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildFolderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("Users")
          .doc(_user!.uid)
          .collection('folders')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildBackgroundImage();
        }

        List<DocumentSnapshot> filteredFolders = snapshot.data!.docs
            .where((folder) =>
        folder['name']
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            folder['timestamp']
                .toDate()
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
            .toList();

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 40.0,
              mainAxisSpacing: 40.0,
            ),
            itemCount: filteredFolders.length,
            itemBuilder: (context, index) {
              var folderId = filteredFolders[index].id;
              var folderName = filteredFolders[index]['name'];
              var timestamp = filteredFolders[index]['timestamp'];
              return _buildFolderItem(context, folderId, folderName, timestamp);
            },
          ),
        );
      },
    );
  }

  Widget _buildFolderItem(
      BuildContext context, String folderId, String folderName, Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(folderId: folderId),
          ),
        );
      },
      child: Card(
        color: Colors.deepPurple.shade50,
        elevation: 5.0,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 10.0),
              Image.asset(
                'assets/heart.png',
                width: 20.0,
                height: 20.0,
                color: Colors.white,
              ),
              SizedBox(height: 10.0),
              Text(
                folderName,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5.0),
              Text(
                '${dateTime.day}/${dateTime.month}/${dateTime.year}',
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 5.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildDeleteIconButton(() {
                    _showDeleteFolderDialog(context, folderId, folderName);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteIconButton(Function onPressed) {
    return IconButton(
      icon: Icon(Icons.delete, color: Colors.white),
      onPressed: () {
        onPressed();
      },
    );
  }

  Widget _buildBackgroundImage() {
    return Container(
      decoration: _buildBackgroundDecoration(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(),
    );
  }

  Future<void> _showAddFolderDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Container(
            width: 200.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Folder'),
                SizedBox(height: 16.0),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Folder Name'),
                ),
              ],
            ),
          ),
          actions: [
            _buildTextButton('Cancel', () {
              Navigator.of(context).pop();
            }),
            _buildTextButton('Add', () async {
              await _saveFolderToFirebase(nameController.text);
              nameController.clear();
              Navigator.of(context).pop();
            }),
          ],
        );
      },
    );
  }

  Future<void> _saveFolderToFirebase(String folderName) async {
    try {
      CollectionReference folders = FirebaseFirestore.instance
          .collection("Users")
          .doc(_user!.uid)
          .collection('folders');
      await folders.add({
        'name': folderName,
        'timestamp': Timestamp.now(),
      });

      print('Folder added to Firebase: $folderName');
    } catch (e) {
      print('Error adding folder to Firebase: $e');
    }
  }

  Future<void> _showDeleteFolderDialog(
      BuildContext context, String folderId, String folderName) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Folder'),
          content:
          Text('Are you sure you want to delete the folder "$folderName"?'),
          actions: [
            _buildTextButton('No', () {
              Navigator.of(context).pop();
            }),
            _buildTextButton('Yes', () async {
              await _deleteFolderFromFirebase(folderName);
              Navigator.of(context).pop();
            }),
          ],
        );
      },
    );
  }

  Future<void> _deleteFolderFromFirebase(String folderName) async {
    try {
      CollectionReference folders = FirebaseFirestore.instance
          .collection("Users")
          .doc(_user!.uid)
          .collection('folders');

      // Find the document with the specified folder name
      QuerySnapshot snapshot =
      await folders.where('name', isEqualTo: folderName).get();

      // Delete the first document found (there should be at most one)
      if (snapshot.docs.isNotEmpty) {
        await folders.doc(snapshot.docs.first.id).delete();
        print('Folder deleted from Firebase: $folderName');
      } else {
        print('Folder not found: $folderName');
      }
    } catch (e) {
      print('Error deleting folder from Firebase: $e');
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text(
              'Are you sure you want to delete your account? This action is irreversible.'),
          actions: [
            _buildTextButton('Cancel', () {
              Navigator.pop(context);
            }),
            _buildTextButton('Delete', () {
              _deleteAccount();
              Navigator.pop(context);
            }),
          ],
        );
      },
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

  void _signOut() {
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
  }

  TextButton _buildTextButton(String text, Function onPressed) {
    return TextButton(
      onPressed: () {
        onPressed();
      },
      child: Text(text),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: HomePage(),
  ));
}
