import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'stufe_bloc.dart';

class StufeCard extends StatelessWidget {
  final Stufe stufe;
  final VoidCallback? onTap;
  final bool isSelected;

  const StufeCard({
    super.key,
    required this.stufe,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 8 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                : null,
          ),
          child: Row(
            children: [
              _buildStufeIcon(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stufe.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stufe.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${stufe.memberCount} Mitglieder',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStufeIcon(BuildContext context) {
    String imagePath;
    switch (stufe.type) {
      case 'biber':
        imagePath = 'assets/images/biber.png';
        break;
      case 'woe':
        imagePath = 'assets/images/woe.png';
        break;
      case 'jufi':
        imagePath = 'assets/images/jufi.png';
        break;
      case 'pfadi':
        imagePath = 'assets/images/pfadi.png';
        break;
      case 'rover':
        imagePath = 'assets/images/rover.png';
        break;
      default:
        imagePath = 'assets/images/dpsg_logo.png';
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: ClipOval(
        child: Image.asset(
          imagePath,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.group, color: Theme.of(context).primaryColor);
          },
        ),
      ),
    );
  }
}

class StufeFilterChips extends StatelessWidget {
  final String? selectedFilter;
  final Function(String?) onFilterChanged;

  const StufeFilterChips({
    super.key,
    this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'label': 'Alle', 'value': null},
      {'label': 'Biber', 'value': 'biber'},
      {'label': 'Wölflinge', 'value': 'woe'},
      {'label': 'Jungpfadfinder', 'value': 'jufi'},
      {'label': 'Pfadfinder', 'value': 'pfadi'},
      {'label': 'Rover', 'value': 'rover'},
    ];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onFilterChanged(filter['value']);
                }
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }
}

class StufeListView extends StatelessWidget {
  const StufeListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StufeBloc, StufeState>(
      builder: (context, state) {
        if (state is StufeLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is StufeError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Fehler',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<StufeBloc>().add(LoadStufen());
                  },
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          );
        }

        if (state is StufeLoaded) {
          final filteredStufen = state.filter != null
              ? state.stufen
                    .where((stufe) => stufe.type == state.filter)
                    .toList()
              : state.stufen;

          if (filteredStufen.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Keine Stufen gefunden', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredStufen.length,
            itemBuilder: (context, index) {
              final stufe = filteredStufen[index];
              final isSelected = state.selectedStufe?.id == stufe.id;

              return StufeCard(
                stufe: stufe,
                isSelected: isSelected,
                onTap: () {
                  context.read<StufeBloc>().add(SelectStufe(stufe.id));
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class StufeStatsWidget extends StatelessWidget {
  const StufeStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StufeBloc, StufeState>(
      builder: (context, state) {
        if (state is! StufeLoaded) {
          return const SizedBox.shrink();
        }

        final totalMembers = state.stufen.fold<int>(
          0,
          (sum, stufe) => sum + stufe.memberCount,
        );

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Übersicht',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      'Stufen',
                      '${state.stufen.length}',
                      Icons.groups,
                    ),
                    _buildStatItem(
                      context,
                      'Mitglieder',
                      '$totalMembers',
                      Icons.people,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
