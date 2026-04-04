import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/support_ticket/support_ticket_data_model.dart';
import 'package:learining_portal/providers/auth_provider.dart';
import 'package:learining_portal/providers/support_tickets_provider.dart';
import 'package:learining_portal/screens/tickets/create_ticket_screen.dart';
import 'package:learining_portal/screens/tickets/ticket_detail_screen.dart';
import 'package:learining_portal/utils/app_colors.dart';
import 'package:provider/provider.dart';

class TicketsListScreen extends StatefulWidget {
  const TicketsListScreen({super.key});

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  /// null = all statuses
  String? _statusFilter;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const List<String> _statusValues = [
    'open',
    'in_progress',
    'pending',
    'resolved',
    'closed',
  ];

  List<SupportTicketModel> _filteredTickets(List<SupportTicketModel> tickets) {
    return tickets.where((t) {
      if (_statusFilter != null && t.status != _statusFilter) {
        return false;
      }
      if (_dateFrom == null && _dateTo == null) return true;
      final raw = t.createdAt;
      if (raw == null || raw.isEmpty) return false;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return false;
      final d = DateTime(parsed.year, parsed.month, parsed.day);
      if (_dateFrom != null) {
        final from =
            DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        if (d.isBefore(from)) return false;
      }
      if (_dateTo != null) {
        final to = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day);
        if (d.isAfter(to)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _statusFilter != null || _dateFrom != null || _dateTo != null;

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _dateFrom = null;
      _dateTo = null;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = (_dateFrom != null && _dateTo != null)
        ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null && mounted) {
      setState(() {
        _dateFrom = range.start;
        _dateTo = range.end;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<SupportTicketsProvider>().loadTickets(auth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryBlue,
              AppColors.secondaryPurple,
              AppColors.backgroundLight,
            ],
            stops: const [0.0, 0.25, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: _buildBody(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Only student, guardian, and teacher can create tickets; hide FAB for admin
          final canCreate = auth.userType == UserType.student ||
              auth.userType == UserType.guardian ||
              auth.userType == UserType.teacher;
          if (!canCreate) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreateTicketScreen()),
              );
              if (created == true && mounted) {
                context.read<SupportTicketsProvider>().loadTickets(
                      context.read<AuthProvider>(),
                    );
              }
            },
            backgroundColor: AppColors.accentTeal,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Ticket'),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support Tickets',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Submit and track your tickets',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<SupportTicketsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingTickets && provider.tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentTeal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading tickets...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.error != null && provider.tickets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () =>
                        provider.loadTickets(context.read<AuthProvider>()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.tickets.isEmpty) {
          final userType = context.watch<AuthProvider>().userType;
          final canCreate = userType == UserType.student ||
              userType == UserType.guardian ||
              userType == UserType.teacher;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No tickets yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canCreate
                        ? 'Tap "New Ticket" to submit a support request.'
                        : 'Tickets submitted by students and parents will appear here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        final filtered = _filteredTickets(provider.tickets);
        if (filtered.isEmpty && _hasActiveFilters) {
          return Column(
            children: [
              _buildFilterBar(context),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_off_rounded,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.45),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tickets match your filters',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all_rounded),
                          label: const Text('Clear filters'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadTickets(context.read<AuthProvider>()),
          color: AppColors.primaryBlue,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: 1 + filtered.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildFilterBar(context);
              }
              final ticket = filtered[index - 1];
              return _TicketListItem(
                ticket: ticket,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TicketDetailScreen(
                        ticketId: ticket.id,
                        ticketSubject: ticket.subject,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) {
                      provider.loadTickets(context.read<AuthProvider>());
                    }
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _statusFilter == null,
                    onSelected: (_) {
                      setState(() => _statusFilter = null);
                    },
                    selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                    checkmarkColor: AppColors.primaryBlue,
                    labelStyle: TextStyle(
                      color: _statusFilter == null
                          ? AppColors.primaryBlue
                          : AppColors.textPrimary,
                      fontWeight: _statusFilter == null
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                ..._statusValues.map((status) {
                  final label = _statusLabelForFilter(status);
                  final selected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _statusFilter = selected ? null : status;
                        });
                      },
                      selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                      checkmarkColor: AppColors.primaryBlue,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.primaryBlue
                            : AppColors.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
                  label: Text(
                    _dateFrom != null && _dateTo != null
                        ? '${_formatShortDate(_dateFrom!)} – ${_formatShortDate(_dateTo!)}'
                        : 'Date range',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(
                      color: AppColors.primaryBlue.withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              if (_dateFrom != null || _dateTo != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear date range',
                  onPressed: () {
                    setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
              if (_hasActiveFilters) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      color: AppColors.accentTeal,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabelForFilter(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In progress';
      case 'pending':
        return 'Pending';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String _formatShortDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _TicketListItem extends StatelessWidget {
  final SupportTicketModel ticket;
  final VoidCallback onTap;

  const _TicketListItem({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(ticket.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(ticket.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.tag_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ticket.ticketId,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (ticket.category != null &&
                      ticket.category!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Text(
                      ticket.category!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ],
                ],
              ),
              if (ticket.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(ticket.createdAt!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.primaryBlue;
      case 'in_progress':
        return AppColors.accentTeal;
      case 'pending':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In progress';
      case 'pending':
        return 'Pending';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
