import 'package:flutter/material.dart';
import 'package:learining_portal/providers/messages/inbox_provider.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/utils/widgets/messages/inbox_chat_item.dart';
import 'package:learining_portal/utils/widgets/messages/inbox_search_bar.dart';
import 'package:learining_portal/screens/messages/members.dart';
import 'package:provider/provider.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Set auth provider when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final inboxProvider = Provider.of<InboxProvider>(context, listen: false);
      inboxProvider.setAuthProvider(authProvider);
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
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // TODO: Show options menu
            },
          ),
        ],
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

          // Chats List
          Expanded(
            child: Consumer<InboxProvider>(
              builder: (context, inboxProvider, child) {
                if (inboxProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (inboxProvider.errorMessage != null) {
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
                          inboxProvider.errorMessage!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => inboxProvider.refreshChats(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final chats = _searchQuery.isEmpty
                    ? inboxProvider.chats
                    : inboxProvider.searchChats(_searchQuery);

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.chat_bubble_outline
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No conversations yet'
                              : 'No conversations match your search',
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
                  itemCount: chats.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, indent: 80, color: Colors.grey[300]),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return ChatListItem(chat: chat);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MembersScreen()),
          );
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
