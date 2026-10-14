import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Service powering Penny's location-specific interactive cultural & heritage Q&A
class PennyPlaceQAService {
  static final PennyPlaceQAService instance = PennyPlaceQAService._internal();
  PennyPlaceQAService._internal();

  String? _workingOllamaHost;

  /// Ask Penny a question regarding a specific visited Penang landmark
  Future<String> askPenny({
    required String placeName,
    required String userQuestion,
    String? area,
    String modelPreference = 'gemma4:cloud', // Fixed default to gemma4:cloud
    String language = 'en', // 'en' or 'zh'
  }) async {
    final cleanPlace = placeName.trim();
    final cleanArea = (area == null || area.isEmpty) ? 'Penang' : area.trim();
    final isZh = language.toLowerCase().startsWith('zh');

    final systemPrompt = isZh
        ? "你是'小粉'（Penny 🌸），马来西亚槟城热情活泼、见多识广的粉色小鸟吉祥物！"
            "游客目前正置身于马来西亚槟城的知名地标：'$cleanPlace'（位于 $cleanArea 区域）。"
            "你的任务是直接回答游客的具体问题：'$userQuestion'。"
            "语言要求（极其严格）：必须全篇使用地道、优美、亲切自然的简体中文（Simplified Chinese）回答！绝对不要出现英文句子。"
            "语气风格：热情可爱、活泼伴游、对槟城多元文化与世界遗产充满自豪，包含2-3个生动表情符号（如 🌸, 🏛️, 📸, 🏮, ✨）。"
            "篇幅与字数限制（极严格）：回答内容必须严格控制在 80 到 120 个字之间（包含标点符号，严格在 80-120 字范围，不可过长或少于80字）。"
        : "You are 'Penny' (小粉), the enthusiastic, witty, and deeply knowledgeable pink bird mascot (🌸) of Penang, Malaysia. "
            "The traveler is currently standing right at: '$cleanPlace' in $cleanArea, Penang, Malaysia. "
            "Your mission is to directly answer the traveler's specific question: '$userQuestion'. "
            "LANGUAGE REQUIREMENT (CRITICAL): You MUST write your ENTIRE response in natural, engaging English. "
            "Tone guidelines: "
            "- Warm, companionable, conversational, and proud of Penang's UNESCO heritage. "
            "- Include 2-3 lively emojis (e.g. 🌸, 🏛️, 📸, 🏮, ✨). "
            "- LENGTH REQUIREMENT (STRICT): Your response MUST be around 80 to 120 words (do not write fewer than 80 words, and do not exceed 120 words).";

    final prompt = isZh
        ? "当前地点：马来西亚槟城 $cleanPlace（$cleanArea）\n"
            "游客提问：$userQuestion\n"
            "小粉（Penny）的纯中文精彩回答（字数严格在80到120字左右）："
        : "Current Landmark: $cleanPlace ($cleanArea, Penang, Malaysia)\n"
            "Traveler's Specific Question: $userQuestion\n"
            "Penny's direct response in English (strictly around 80 to 120 words):";

    // 1. Query Ollama exclusively using gemma4:cloud
    const targetModel = 'gemma4:cloud';
    final candidateHosts = [
      ?_workingOllamaHost,
      AppConfig.ollamaBaseUrl,
      'http://10.0.2.2:11434',
      'http://127.0.0.1:11434',
      'http://localhost:11434',
    ];

    for (final host in candidateHosts) {
      try {
        final ollamaUrl = Uri.parse('$host/api/generate');
        final response = await http.post(
          ollamaUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'model': targetModel,
            'system': systemPrompt,
            'prompt': prompt,
            'stream': false,
            'options': {
              'temperature': 0.7,
              'num_predict': 250,
            },
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final res = (data['response'] as String?)?.trim();
          if (res != null && res.isNotEmpty) {
            _workingOllamaHost = host;
            debugPrint('🌸 [PENNY AI] Answered live via Ollama ($host - $targetModel) in $language for: "$userQuestion"');
            return res;
          }
        }
      } catch (e) {
        // Try next host
      }
    }

    // 2. Fallback to rich question-tailored cultural & heritage knowledge base
    return _getLocalHeritageFallback(cleanPlace, userQuestion, isZh: isZh);
  }

  /// Rich, question-tailored localized Penang cultural narratives for offline reliability
  String _getLocalHeritageFallback(String place, String question, {required bool isZh}) {
    final placeLower = place.toLowerCase();
    final qLower = question.toLowerCase();

    // Categorize traveler question intent
    final isPhoto = qLower.contains('photo') ||
        qLower.contains('photograph') ||
        qLower.contains('camera') ||
        qLower.contains('instagram') ||
        qLower.contains('spot') ||
        qLower.contains('shoot') ||
        qLower.contains('picture') ||
        qLower.contains('拍照') ||
        qLower.contains('拍摄') ||
        qLower.contains('打卡') ||
        qLower.contains('摄影') ||
        qLower.contains('照片');

    final isCulture = qLower.contains('tradition') ||
        qLower.contains('meaning') ||
        qLower.contains('culture') ||
        qLower.contains('worship') ||
        qLower.contains('temple') ||
        qLower.contains('ceremony') ||
        qLower.contains('heritage') ||
        qLower.contains('文化') ||
        qLower.contains('传统') ||
        qLower.contains('习俗') ||
        qLower.contains('拜祭') ||
        qLower.contains('寓意');

    final isFolklore = qLower.contains('folklore') ||
        qLower.contains('secret') ||
        qLower.contains('legend') ||
        qLower.contains('myth') ||
        qLower.contains('mystery') ||
        qLower.contains('rumor') ||
        qLower.contains('story') ||
        qLower.contains('传说') ||
        qLower.contains('秘密') ||
        qLower.contains('故事') ||
        qLower.contains('八卦');

    final isFood = qLower.contains('food') ||
        qLower.contains('eat') ||
        qLower.contains('snack') ||
        qLower.contains('restaurant') ||
        qLower.contains('hawker') ||
        qLower.contains('cafe') ||
        qLower.contains('dish') ||
        qLower.contains('delicious') ||
        qLower.contains('吃') ||
        qLower.contains('美食') ||
        qLower.contains('小吃') ||
        qLower.contains('好吃');

    final isTips = qLower.contains('tip') ||
        qLower.contains('rule') ||
        qLower.contains('etiquette') ||
        qLower.contains('hour') ||
        qLower.contains('time') ||
        qLower.contains('open') ||
        qLower.contains('close') ||
        qLower.contains('ticket') ||
        qLower.contains('fee') ||
        qLower.contains('注意') ||
        qLower.contains('时间') ||
        qLower.contains('门票') ||
        qLower.contains('规则') ||
        qLower.contains('游览');

    // 1. Chew Clan Jetty (姓周桥)
    if (placeLower.contains('chew jetty') || placeLower.contains('姓周桥') || placeLower.contains('chew clan')) {
      if (isPhoto) {
        return isZh
            ? '🌸 姓周桥（Chew Jetty）的最佳摄影打卡机位推荐给你！📸\n\n'
                '1. **木栈道尽头观景台**：一直走到最外侧的海上木平台，栈道延伸向槟城海峡，背景有传统木舢板渔船与开阔海天，经典明信片机位！\n'
                '2. **低角度老木屋回廊**：在木栈道正中央低角度仰拍，两侧错落有致的高脚木屋挂满红灯笼与渔网，充满岁月纵深感。\n'
                '3. **桥头退潮木桩倒影**：在入口处拍摄矗立在泥滩与海水中的红树木桩倒影。\n\n'
                '✨ 最佳时段：傍晚 6:30 - 7:15 PM 黄金日落时刻，海面泛着金光最出片！'
            : '🌸 Best photography spots at Chew Clan Jetty (姓周桥)! 📸\n\n'
                '1. **The Pier Tip Over the Strait**: Walk to the very end of the main wooden boardwalk. The wooden pier jutting into the sea with moored fishing boats and the open horizon creates an iconic postcard shot!\n'
                '2. **Rustic Wooden Stilt Boardwalk**: Shoot from a low angle along the timber walkway to capture weathered stilt houses, glowing red lanterns, and fishing nets.\n'
                '3. **Tidal Stilts & Reflection**: Near the entrance temple during mid-tide, capture the water reflections under the timber stilts.\n\n'
                '✨ Best Time: 6:30 PM - 7:15 PM for golden hour and twilight colors over the water!';
      }
      if (isCulture) {
        return isZh
            ? '🌸 姓周桥深厚的宗族文化与水上民间信仰！🏮\n\n'
                '1. **正月初九拜天公（天公诞）**：全槟城最壮观的新年庆典！整座木栈道会摆满百尺超长供桌，摆满烧猪、甘蔗、发糕与清香，万人朝拜极其震撼！\n'
                '2. **朝阳阁／海珠屿大伯公庙**：桥头供奉海神大伯公与水尾圣娘，护佑出海宗亲出入平安、顺风顺水。\n'
                '3. **宗亲凝聚力**：过去非周姓宗亲不得在桥上置业或泊船，宗族同心协力渡过了百年风浪。'
            : '🌸 Cultural traditions & spiritual meaning of Chew Clan Jetty! 🏮\n\n'
                '1. **Pai Ti Kong (Jade Emperor Worship)**: On the 8th night / 9th morning of Chinese New Year, Chew Jetty hosts Penang\'s grandest festival. A 100-foot-long altar table stretches across the pier, laden with roast pigs, sugarcanes, and incense!\n'
                '2. **Qian Hai Temple (海珠屿大伯公庙)**: Safeguarding the pier entrance, dedicated to the Ocean God and Tudigong to bless maritime workers with calm seas.\n'
                '3. **Clan Kinship**: Historically, every resident belonged to the Chew kinship lineage from Tong\'an, Fujian, creating an unbroken community that shared fishing nets and boats.';
      }
      if (isFolklore) {
        return isZh
            ? '🌸 姓周桥的本地传说与神秘秘密！✨\n\n'
                '1. **木板脚步声暗号**：老桥民说，早年夜间没有路灯，哪家邻居踩在木板上的轻重缓急，整条街75户人家一听便知！若有外来陌生人脚步声，全桥瞬间警觉！\n'
                '2. **海墘码头商战争霸**：19世纪英商货轮抵港，姓周桥、姓林桥、姓陈桥之间曾爆发激烈的码头搬运货源竞争，直到后来划定码头势力界限。\n'
                '3. **水下百年铁木桩**：支撑整座高脚村落的木桩采用坚硬沉重的坤甸铁木（Belian），浸泡在海水中反而越泡越结实，历经百余年风暴海浪依然稳固！'
            : '🌸 Local folklore & secrets of Chew Clan Jetty! ✨\n\n'
                '1. **The Creaking Plank Alarm**: Clan elders recount that in early colonial times, residents recognized each other purely by footfalls on the timber planks; any outsider walking at night instantly alerted all 75 households!\n'
                '2. **Quay Clan Rivalries**: In the 19th century, fierce commercial rivalries erupted between Chew Jetty and neighboring Tan / Lim jetties over unloading rights for British and merchant steamships at Weld Quay.\n'
                '3. **The Ironwood Foundation**: The stilts are crafted from Belian ironwood and mangrove trunks that harden underwater, withstanding tropical waves for over 150 years!';
      }
      if (isFood) {
        return isZh
            ? '🌸 姓周桥周边不可错过的地道南洋美食！🍜\n\n'
                '1. **大碗公面（Chew Jetty Big Bowl Noodles）**：超大碗的手工弹牙面条，配上海鲜与炸肉，份量十足！\n'
                '2. **猫山王榴莲雪糕**：木栈道上的原只椰壳纯榴莲果肉冰淇淋，浓郁冰凉解暑。\n'
                '3. **路口现炸尖不辣（Cempedak）与炸香蕉**：金黄酥脆、果香四溢。\n'
                '4. **海墘茶室（Kedai Kopi Weld Quay）**：马路对面就是正宗海南烤面包、半熟蛋与地道白咖啡！'
            : '🌸 Must-try bites right at Chew Jetty entrance and Weld Quay! 🍜\n\n'
                '1. **Chew Jetty Big Bowl Noodles (大碗公面)**: Gigantic bowls packed with springy noodles, seafood, and rich broth.\n'
                '2. **Musang King Durian Ice Cream**: Fresh durian ice cream served in real coconut husks along the main boardwalk.\n'
                '3. **Crispy Fried Cempedak & Banana**: Freshly fried golden fruit fritters right by the entrance roadside.\n'
                '4. **Kedai Kopi Weld Quay**: Right across the road for authentic Hainanese iced white coffee and char koay teow!';
      }
      if (isTips) {
        return isZh
            ? '🌸 游览姓周桥的重要温馨贴士！💡\n\n'
                '1. **尊重居民生活**：姓周桥是真实居住的民俗村落，请勿随意将镜头伸入敞开的私人客厅或卧室门窗内。\n'
                '2. **留意脚下木板**：木栈道偶有潮湿或木隙，建议穿着平底舒适的防滑鞋。\n'
                '3. **开放时间与门票**：全天免费开放（推荐白天至晚上9点前游览）。\n'
                '4. **支持在地小摊**：可以尝尝桥上居民自家经营的传统饮料、手工文创与南洋小吃！'
            : '🌸 Essential visiting tips for Chew Clan Jetty! 💡\n\n'
                '1. **Respect Living Residents**: This is an active residential village where multi-generational families live. Please do not peer into private windows or take photos inside living rooms.\n'
                '2. **Watch Your Step**: Timber planks can be uneven or slippery when damp; wear flat, comfortable walking shoes.\n'
                '3. **Hours & Admission**: Open daily (recommended 9:00 AM - 9:00 PM). Entry is completely free!\n'
                '4. **Support Locals**: Enjoy refreshing drinks and handmade souvenirs from the family stalls along the pier.';
      }
      // Default / History
      return isZh
          ? '🌸 你现在正踩在百年活历史的姓周桥（Chew Jetty）木板上！🌊\n\n'
              '这里始建于19世纪中叶，由来自中国福建同安县的周姓宗亲移民共同建立。当时英国殖民政府对陆地征收地税，而海上搭建的高脚屋不受市政地税管辖，于是同安渔民便在海墘街沿海搭建水上木屋集群！\n\n'
              '桥民昔日主要在海墘码头从事驳船装卸、拉网捕鱼与驳运劳作。如今，姓周桥是乔治市现存六座姓氏桥中规模最大、保存最完好的水上聚落！'
          : '🌸 You are walking on living history at Chew Jetty (姓周桥)! Built in the mid-19th century by immigrants from Tong\'an, Fujian, these wooden stilt houses were built over water because river and coastal settlements were exempt from municipal land taxes by British colonial authorities! 🌊\n\n'
              'Every family residing here historically belonged to the Chew clan and worked as barge lightermen, stevedores, and fishermen unloading cargo from ships anchored off Weld Quay. Today, it remains the largest and most intact of George Town\'s six surviving heritage clan jetties!';
    }

    // 2. Kek Lok Si (极乐寺)
    if (placeLower.contains('kek lok si') || placeLower.contains('极乐寺')) {
      if (isPhoto) {
        return isZh
            ? '🌸 极乐寺（Kek Lok Si）三大绝佳拍照打卡机位！📸\n\n'
                '1. **30.2米青铜观音圣像八角亭**：在开阔的观音广场仰拍，八角庄严亭阁与蓝天相衬极其巍峨！\n'
                '2. **万佛宝塔（拉玛六世佛塔）**：在庭院中拍摄七层宝塔，底部中国八角形、中部泰国风情、顶部缅甸金顶完美融合。\n'
                '3. **半山俯瞰全景平台**：晴天时可俯瞰亚依淡城镇与乔治市天际线。\n\n'
                '✨ 建议早上 9:00 前往，光线柔和清爽！'
            : '🌸 Best photo spots at Kek Lok Si Temple (极乐寺)! 📸\n\n'
                '1. **Colossal 30.2m Bronze Guan Yin Pavilion**: Stand in the open plaza framed by the ornate octagonal pavilion pillars against the blue sky.\n'
                '2. **Pagoda of Rama VI (Ban Pho Thar)**: Capture the 7-tier pagoda from the mid-level courtyard showing the Chinese base, Thai center, and Burmese spiral crown.\n'
                '3. **Panoramic Mountain Terrace**: A sweeping panoramic view overlooking Air Itam valley and George Town.\n\n'
                '✨ Best Time: Morning 9:00 AM for clear mountain skies and gentle sunlight!';
      }
      if (isFood) {
        return isZh
            ? '🌸 极乐寺山脚下亚依淡必吃美食！🍜\n\n'
                '1. **亚依淡巴刹亚参叻沙（Air Itam Asam Laksa）**：浓郁鲜辣的鲭鱼酸辣汤底，搭配薄荷与虾膏，名扬海外！\n'
                '2. **两姐妹咖喱面**：炭火烹煮数十年的老字号，配鱿鱼与特制辣椒酱！\n'
                '3. **传统咖啡店海南烤面包与生熟蛋**。'
            : '🌸 Iconic food spots right below Kek Lok Si in Air Itam! 🍜\n\n'
                '1. **Air Itam Asam Laksa**: Right beside the wet market—world-famous tangy tamarind fish broth with thick rice noodles!\n'
                '2. **Sister Curry Mee (两姐妹咖喱面)**: Legendary charcoal-cooked curry noodles with cuttlefish and tofu puffs.\n'
                '3. **Air Itam Duck Rice & Toast**: Crisp roasted duck and kaya butter toast at nearby vintage kopitiams.';
      }
      return isZh
          ? '🌸 极乐寺（Kek Lok Si）建于1890年，由妙莲法师开山，是马来西亚最大的佛教寺庙！🏮 依山而建，气势恢宏，每逢农历新年更有超过20万盏明灯照耀整座山头，蔚为壮观！'
          : '🌸 Kek Lok Si (极乐寺 / Temple of Supreme Bliss) was founded in 1890 by Venerable Beow Lean with support from prominent Penang Chinese leaders including Cheong Fatt Tze. It is the largest Buddhist temple in Malaysia, standing majestically on the slopes of Air Itam!';
    }

    // 3. Generic / Other Penang Landmarks
    if (isPhoto) {
      return isZh
          ? '🌸 $place 的绝佳拍照建议！📸 留意南洋骑楼的复古线条、色彩斑斓的街头壁画以及傍晚 6:30 左右的落日暖光。配合穿行的三轮车或老洋房百叶窗，能拍出最具槟城味道的照片！'
          : '🌸 Great photography tips for $place! 📸 Look for unique heritage textures, architectural symmetry, vibrant street murals, and warm golden hour light (around 6:30 PM). Frame with passing trishaws or overhead red lanterns for authentic Penang charm!';
    } else if (isFood) {
      return isZh
          ? '🌸 $place 附近的槟城地道美味！🍜 寻访周边的老咖啡店，必尝炒粿条（鸭蛋与鲜蛤）、正宗槟城亚参叻沙、香浓煎蕊（Chendol）与纯正白咖啡！'
          : '🌸 Delicious Penang food nearby $place! 🍜 Seek out nearby traditional kopitiams for Char Koay Teow (fried with duck egg & cockles), Penang Asam Laksa, Chendol with fresh gula melaka, and aromatic White Coffee!';
    } else if (isCulture || isFolklore) {
      return isZh
          ? '🌸 $place 的文化底蕴！🏮 槟城乔治市被联合国列为世界文化遗产，华人宗祠、马来聚落、印度香料街与英殖民建筑共存，构成了这里多元包容的人文风貌。'
          : '🌸 Cultural richness of $place! 🏮 George Town\'s UNESCO World Heritage status stems from its harmonious co-existence of Chinese clan guilds, Malay kampungs, Indian Muslim spice traders, and British colonial history living side by side.';
    } else {
      return isZh
          ? '🌸 欢迎来到 $place！这是槟城非常特别的一处精彩地标。不妨放慢脚步欣赏这里的建筑与人文，随时向我提问关于这里的历史、拍照机位或美食哦！'
          : '🌸 Welcome to $place! As one of Penang\'s treasured highlights, this landmark is steeped in George Town\'s vibrant multicultural tapestry. Feel free to ask me about history, photo spots, or food nearby!';
    }
  }
}
