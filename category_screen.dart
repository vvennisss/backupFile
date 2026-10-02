import 'package:flutter/material.dart';
import '../theme.dart';
import 'detail_screen.dart';
import '../widgets/app_image_widget.dart';

class Destination {
  final String title;
  final String area;
  final String businessHours;
  final String description;
  final String imagePath;
  final String category; // Heritage, Food, Nature, Adventure, Museum

  Destination({
    required this.title,
    required this.area,
    required this.businessHours,
    required this.description,
    required this.imagePath,
    required this.category,
  });
}

// Global list of Top 10 popular destinations (non-food)
// Global list of all Penang destinations
final List<Destination> allDestinations = [
  // --- HERITAGE CATEGORY ---
  Destination(
    title: 'Kek Lok Si Temple',
    area: 'Air Itam',
    businessHours: '8:30 AM - 5:30 PM',
    description: 'Kek Lok Si is the largest Buddhist temple in Malaysia. The temple features a 7-tier pagoda that combines Chinese, Thai, and Burmese architecture, and a giant bronze statue of the Goddess of Mercy (Guanyin).',
    imagePath: 'https://images.unsplash.com/photo-1596402184320-417e7178b2cd?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),
  Destination(
    title: 'George Town Street Art',
    area: 'George Town',
    businessHours: '24 Hours Open',
    description: 'Discover the world-famous street art scattered across the UNESCO Heritage core of George Town. Interactive murals by Ernest Zacharevic, like the kids on a bicycle, bring the walls of historic shophouses to life.',
    imagePath: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),
  Destination(
    title: 'Cheong Fatt Tze (Blue Mansion)',
    area: 'George Town',
    businessHours: '11:00 AM, 2:00 PM, 3:30 PM (Tours)',
    description: 'An iconic indigo-blue heritage mansion featuring 19th-century Chinese-architecture. It was built by merchant Cheong Fatt Tze and has won UNESCO conservation awards, featured in the movie Crazy Rich Asians.',
    imagePath: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),
  Destination(
    title: 'Pinang Peranakan Mansion',
    area: 'George Town',
    businessHours: '9:30 AM - 5:00 PM',
    description: 'A recreation of a rich 19th-century Baba Nyonya home. Filled with over 1,000 antiques, collectibles, and historic jewelry, it highlights the unique Peranakan culture and heritage of Penang.',
    imagePath: 'https://images.unsplash.com/photo-1598977123418-45f04b61b49e?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),
  Destination(
    title: 'Fort Cornwallis',
    area: 'George Town',
    businessHours: '9:00 AM - 10:00 PM',
    description: 'The largest standing fort in Malaysia, built by the British East India Company under Captain Francis Light in 1786. It features old bronze cannons, chapel ruins, and a historic lighthouse.',
    imagePath: 'https://images.unsplash.com/photo-1518684079-3c830dcef090?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),
  Destination(
    title: 'Khoo Kongsi',
    area: 'George Town',
    businessHours: '9:00 AM - 5:00 PM',
    description: 'A spectacular Chinese clan temple featuring intricate stone carvings, gold leaf ornamentation, and detailed roof designs representing the Khoo clan lineage.',
    imagePath: 'https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),
  Destination(
    title: 'Clan Jetties of Penang',
    area: 'George Town',
    businessHours: '9:00 AM - 9:00 PM',
    description: 'Traditional wooden stilt house settlements built over the water by Chinese immigrant clans in the late 19th century, offering a unique glimpse into historic maritime life.',
    imagePath: 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&q=80&w=600',
    category: 'Heritage',
  ),

  // --- FOOD CATEGORY ---
  Destination(
    title: 'Gurney Drive Hawker Centre',
    area: 'George Town',
    businessHours: '4:30 PM - 11:00 PM',
    description: 'One of the most famous food courts in Penang. Try local delicacies like Char Kway Teow, Assam Laksa, Hokkien Mee, Rojak, and Satay by the seaside.',
    imagePath: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
    category: 'Food',
  ),
  Destination(
    title: 'Chulia Street Night Hawkers',
    area: 'George Town',
    businessHours: '6:00 PM - 11:30 PM',
    description: 'A bustling street food spot in the heart of George Town. Famous for its wonton noodles, curry mee, and traditional Penanti styles of local cooking.',
    imagePath: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&q=80&w=600',
    category: 'Food',
  ),
  Destination(
    title: 'Penang Road Teochew Chendul',
    area: 'George Town',
    businessHours: '10:30 AM - 7:00 PM',
    description: 'The legendary stall serving Penang\'s most famous shaved ice dessert with green rice flour jelly, coconut milk, palm sugar, and red beans. Operating since 1936.',
    imagePath: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&q=80&w=600',
    category: 'Food',
  ),
  Destination(
    title: 'New Lane Hawker Centre',
    area: 'George Town',
    businessHours: '4:00 PM - 11:00 PM',
    description: 'A legendary open-air street hawker lane offering a massive variety of Penang specialties including Lor Bak, Popiah, Hokkien Mee, and Fried Oyster Omelettes.',
    imagePath: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&q=80&w=600',
    category: 'Food',
  ),
  Destination(
    title: 'Cecil Street Market Hawkers',
    area: 'George Town',
    businessHours: '7:00 AM - 5:00 PM',
    description: 'A popular local wet market food court known for duck meat koay teow soup, Jawa mee, pasiah, and traditional Nyonya kuih.',
    imagePath: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=600',
    category: 'Food',
  ),
  Destination(
    title: 'Air Itam Assam Laksa',
    area: 'Air Itam',
    businessHours: '10:30 AM - 7:00 PM',
    description: 'Located right next to the wet market, this historic stall serves Penang\'s iconic sour, spicy, fish-broth noodle soup topped with shrimp paste.',
    imagePath: 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?auto=format&fit=crop&q=80&w=600',
    category: 'Food',
  ),

  // --- NATURE CATEGORY ---
  Destination(
    title: 'Penang Hill (Bukit Bendera)',
    area: 'Air Itam',
    businessHours: '6:30 AM - 10:00 PM',
    description: 'Offering panoramic views of George Town, Penang Hill is the oldest colonial hill station in Southeast Asia. The funicular railway climb is a thrilling experience going through the steepest tunnel track in the world.',
    imagePath: 'https://images.unsplash.com/photo-1542856391-010fb87dcfed?auto=format&fit=crop&q=80&w=600',
    category: 'Nature',
  ),
  Destination(
    title: 'Penang Botanic Gardens',
    area: 'George Town',
    businessHours: '5:00 AM - 8:00 PM',
    description: 'Also known as the Waterfall Gardens, this public park was founded in 1884. It features unique flora, green landscapes, walking trails, and cheeky long-tailed macaques in a lush tropical valley.',
    imagePath: 'https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&q=80&w=600',
    category: 'Nature',
  ),
  Destination(
    title: 'Tropical Spice Garden',
    area: 'Batu Ferringhi',
    businessHours: '9:00 AM - 6:00 PM',
    description: 'An award-winning biodiverse bio-reserve featuring over 500 species of tropical herbs, spices, and plants. Walk through landscaped jungle trails, relax on giant swings, or attend a cooking class.',
    imagePath: 'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&q=80&w=600',
    category: 'Nature',
  ),
  Destination(
    title: 'Penang National Park',
    area: 'Teluk Bahang',
    businessHours: '8:00 AM - 5:00 PM',
    description: 'One of the world\'s smallest national parks. Home to pristine beaches like Monkey Beach and Pantai Kerachut, a rare meromictic lake, and coastal hiking trails.',
    imagePath: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=600',
    category: 'Nature',
  ),
  Destination(
    title: 'Teluk Bahang Forest Park',
    area: 'Teluk Bahang',
    businessHours: '9:00 AM - 5:00 PM',
    description: 'A quiet eco-tourism forest offering refreshing natural stream swimming pools, camping grounds, and walking paths in primary rainforest.',
    imagePath: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&q=80&w=600',
    category: 'Nature',
  ),

  // --- OUTDOORS CATEGORY ---
  Destination(
    title: 'ESCAPE Penang',
    area: 'Teluk Bahang',
    businessHours: '10:00 AM - 6:00 PM (Closed Mon)',
    description: 'An outdoor adventure theme park featuring the world\'s longest tube water slide (1,111m) and longest zip coaster. Features rope courses, climbing, water play, and physical challenges in a forest canopy setting.',
    imagePath: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&q=80&w=600',
    category: 'Outdoors',
  ),
  Destination(
    title: 'Entopia by Penang Butterfly Farm',
    area: 'Teluk Bahang',
    businessHours: '9:00 AM - 5:00 PM (Closed Wed)',
    description: 'A giant nature classroom and discovery facility where butterflies and reptiles roam free in a massive outdoor dome. Features interactive educational exhibits, vivariums, and nature learning activities.',
    imagePath: 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?auto=format&fit=crop&q=80&w=600',
    category: 'Outdoors',
  ),
  Destination(
    title: 'The Habitat Penang Hill',
    area: 'Penang Hill',
    businessHours: '9:00 AM - 7:00 PM',
    description: 'An eco-tourism park offering canopy walks, tree-top walks, and ziplines in a 130-million-year-old virgin tropical rainforest.',
    imagePath: 'https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&q=80&w=600',
    category: 'Outdoors',
  ),
  Destination(
    title: 'Youth Park (Taman Perbandaran)',
    area: 'George Town',
    businessHours: '6:00 AM - 6:00 PM',
    description: 'A vibrant public park featuring multiple outdoor swimming pools, skate parks, climbing frames, and walking tracks at the foot of Penang Hill.',
    imagePath: 'https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?auto=format&fit=crop&q=80&w=600',
    category: 'Outdoors',
  ),
  Destination(
    title: 'Batu Ferringhi Watersports',
    area: 'Batu Ferringhi',
    businessHours: '9:00 AM - 7:00 PM',
    description: 'Enjoy outdoor watersports on the main sandy beach strip of Batu Ferringhi, offering parasailing, jet-skiing, banana boats, and windsurfing.',
    imagePath: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&q=80&w=600',
    category: 'Outdoors',
  ),
];

// Re-export old lists filtered from master database for backward compatibility
final List<Destination> popularDestinations = allDestinations.where((d) => d.category != 'Food').toList();
final List<Destination> foodListings = allDestinations.where((d) => d.category == 'Food').toList();

class CategoryScreen extends StatefulWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final List<Destination> _items;
  final Set<String> _favoritedTitles = {};

  @override
  void initState() {
    super.initState();
    // Gather matching destinations
    if (widget.categoryName == 'Food') {
      _items = foodListings;
    } else {
      _items = popularDestinations
          .where((d) => d.category == widget.categoryName)
          .toList();
    }
  }

  // Gets the background header asset depending on category
  String _getCategoryHeaderAsset() {
    switch (widget.categoryName) {
      case 'Adventure':
      case 'Outdoors':
        return 'assets/images/adventure_tab1.png';
      case 'Food':
        return 'assets/images/food_tab1.png';
      case 'Heritage':
        return 'assets/images/heritage_tab1.png';
      case 'Museum':
        return 'assets/images/museum_tab1.png';
      case 'Nature':
        return 'assets/images/nature_tab1.png';
      default:
        return 'assets/images/penang_tab1.png';
    }
  }

  String _getCategoryLabel() {
    switch (widget.categoryName) {
      case 'Heritage':
        return 'Heritage & Cultural';
      case 'Food':
        return 'Food Discovery';
      case 'Nature':
        return 'Nature & Parks';
      case 'Adventure':
        return 'Adventure & Fun';
      case 'Outdoors':
        return 'Outdoors & Adventure';
      case 'Museum':
        return 'Museum & History';
      default:
        return widget.categoryName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // 1. Header image with title and back button
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_getCategoryHeaderAsset()),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Black overlay for text readability
              Container(
                height: 250,
                width: double.infinity,
                color: Colors.black.withOpacity(0.3),
              ),
              // Title text
              Positioned(
                bottom: 24,
                left: 24,
                child: Text(
                  _getCategoryLabel(),
                  style: const TextStyle(
                    fontFamily: 'Georgia', // using standard system font for premium cursive-like look
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              // Circular Back Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.black,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. Control bar (sort/layout)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.swap_vert, size: 28, color: AppColors.black),
                  onPressed: () {
                    setState(() {
                      _items.shuffle(); // basic sort simulation
                    });
                  },
                ),
              ],
            ),
          ),

          // 3. List of items matching category
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('No destinations found for this category.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length + 1, // add 1 for footer card
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        // Footer card: "Swipe left to view other activities"
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "Swipe left to view other activities",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey,
                            ),
                          ),
                        );
                      }

                      final item = _items[index];
                      final isFav = _favoritedTitles.contains(item.title);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailScreen(
                                title: item.title,
                                area: item.area,
                                businessHours: item.businessHours,
                                description: item.description,
                                imagePath: item.imagePath,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Left: image with fallback
                              AppImageWidget(
                                imagePath: item.imagePath,
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                              // Right: title & description
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.black,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.description,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textGrey,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      // Heart icon at bottom-right
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isFav) {
                                                _favoritedTitles.remove(item.title);
                                              } else {
                                                _favoritedTitles.add(item.title);
                                              }
                                            });
                                          },
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isFav
                                                  ? AppColors.deepOrange.withOpacity(0.1)
                                                  : AppColors.grey.withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isFav ? Icons.favorite : Icons.favorite_border,
                                              color: isFav ? AppColors.deepOrange : AppColors.white,
                                              size: 18,
                                            ),
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
                  ),
          ),
        ],
      ),
    );
  }
}
