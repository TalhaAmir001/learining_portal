import 'package:flutter/material.dart';
import 'package:learining_portal/providers/messages/members_provider.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/widgets/messages/inbox_search_bar.dart';
import 'package:learining_portal/screens/messages/chat.dart';
import 'package:learining_portal/utils/widgets/messages/user_list_item.dart';
import 'package:provider/provider.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Set auth provider when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final membersProvider = Provider.of<MembersProvider>(context, listen: false);
      membersProvider.setAuthProvider(authProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        title: const Text(
          'Select User',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          InboxSearchBar(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),

          // Users List
          Expanded(
            child: Consumer<MembersProvider>(
              builder: (context, membersProvider, child) {
                if (membersProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (membersProvider.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          membersProvider.errorMessage!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => membersProvider.refreshUsers(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final users = _searchQuery.isEmpty
                    ? membersProvider.users
                    : membersProvider.searchUsers(_searchQuery);

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.people_outline
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users found'
                              : 'No users match your search',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, indent: 80, color: Colors.grey[300]),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return UserListItem(
                      user: user,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatScreenWrapper(otherUser: user),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
