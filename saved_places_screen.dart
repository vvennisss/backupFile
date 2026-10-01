import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/saved_places_manager.dart';
import 'detail_screen.dart';
import '../widgets/app_image_widget.dart';

class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
          ),
        ),
        title: const Text(
          'Saved Places',
          style: TextStyle(
            color: Color(0xFF303030), // Colors.grey[850]
            fontWeight: FontWeight.bold,
            fontSize: 20, // Clean App Bar Heading size
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<Map<String, String>>>(
        valueListenable: SavedPlacesManager.savedPlacesNotifier,
        builder: (context, savedList, child) {
          if (savedList.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 64,
                      color: AppColors.textGrey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Saved Locations Yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18, // Spec Label: 18px
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDarkNavy,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Search for Penang locations and save them to view them here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12, // Spec Desc: 12px
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: savedList.length,
            itemBuilder: (context, index) {
              final item = savedList[index];
              final title = item['title'] ?? 'Unknown Place';
              final area = item['area'] ?? 'Penang';
              final hours = item['businessHours'] ?? 'Check online';
              final imagePath = item['imagePath'] ?? 'no_image_found';
              final category = item['category'] ?? 'Attraction';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(
                        title: title,
                        area: area,
                        businessHours: hours,
                        description: item['description'] ?? 'No description available.',
                        imagePath: imagePath,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFF1F7FA), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      AppImageWidget(
                        imagePath: imagePath,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 14, // Spec Normal: 14px
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$area • $hours',
                                          style: const TextStyle(
                                            fontSize: 12, // Spec Body/Desc: 12px
                                            color: AppColors.textGrey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentMintTeal.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 10, // Tag: 10px
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondaryRoyalBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  SavedPlacesManager.unsavePlace(title);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.favorite,
                                    color: AppColors.deepOrange,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
