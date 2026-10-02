// file: services/birdPersonaEngine.js
const mongoose = require('mongoose');
const PlaceNew = require('../models/PlaceNew');
const fetch = require('node-fetch');

const OLLAMA_CHAT_URL = process.env.OLLAMA_CHAT_URL || 'http://127.0.0.1:11434/api/chat';
const OLLAMA_GEN_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434/api/generate';
const DEFAULT_MODEL = process.env.OLLAMA_MODEL || 'gemma4:cloud';

// Known Penang Areas for Geo-Awareness
const PENANG_AREAS = [
    'Batu Ferringhi', 'George Town', 'Georgetown', 'Air Itam', 'Ayer Itam',
    'Bayan Lepas', 'Bayan Baru', 'Tanjung Bungah', 'Tanjung Tokong', 'Gurney',
    'Pulau Tikus', 'Gelugor', 'Balik Pulau', 'Teluk Bahang', 'Butterworth',
    'Bukit Mertajam', 'Seberang Perai', 'Nibong Tebal', 'Kepala Batas',
    '乔治市', '亚依淡', '峇都丁宜', '峇六拜', '浮罗山背', '直落巴巷', '丹绒武雅', '丹绒道光', '新关仔角', '北海', '大山脚'
];

const CATEGORY_KEYWORDS = {
    'clan houses': ['clan house', 'kongsi', 'ancestral hall', 'chinese clan', '宗祠', '会馆', '公祠', '宗祠会馆'],
    'clan jetty': ['clan jetty', 'clan jetties', 'chew jetty', 'tan jetty', 'lee jetty', 'water village', '姓氏桥', '姓周桥', '姓陈桥', '姓李桥', '姓林桥'],
    'beaches': ['beach', 'beaches', 'pantai', 'coast', 'seaside', 'sea', 'shore', 'bay', 'sunset', '海滩', '沙滩', '海边', '海景'],
    'nature & parks': ['nature', 'park', 'botanical', 'hill', 'garden', 'forest', 'hiking', 'waterfall', '公园', '自然', '植物园', '升旗山', '徒步', '瀑布', '生态'],
    'Cafes': ['cafe', 'cafes', 'coffee', 'kopi', 'tea', 'matcha', 'latte', 'brunch', 'cake', 'cakes', 'bakery', 'pastry', '咖啡', '咖啡馆', '咖啡店', '下午茶', '探店'],
    'Dessert and Pastry': ['dessert', 'pastry', 'cake', 'cakes', 'bakery', 'bakeries', 'patisserie', 'bakes', 'waffle', 'ice cream', 'cendol', 'ais kacang', 'sweet', 'sweets', 'sugar', '蛋糕', '蛋糕店', '甜品', '甜点', '糕点', '烘焙', '烘焙坊', '面包', '面包店', '糖水', '糖水铺', '冰品', '红豆冰', '煎豆', '珍多冰'],
    'Hawker Centres & Food Courts': ['hawker', 'food court', 'stall', 'medan selera', 'kopitiam', 'street food', 'char kway teow', 'laksa', 'durian', '小贩中心', '熟食中心', '茶室', '大排档', '街头小吃', '炒粿条', '叻沙', '福建面', '榴莲'],
    'food & beverages': ['food', 'makan', 'restaurant', 'dinner', 'lunch', 'breakfast', 'noodle', 'rice', 'seafood', 'durian', '美食', '餐厅', '餐馆', '好吃', '吃', '午餐', '晚餐', '早餐', '海鲜', '炒面', '特色美食', '榴莲'],
    'durian & farm': ['durian', 'durians', 'durian farm', 'durian stall', 'durian shop', 'nutmeg', 'orchard', 'farm', 'farms', 'agro', '榴莲', '榴莲园', '榴莲摊', '果园', '农场', '豆蔻'],
    'Halal restaurant': ['halal', 'muslim', 'nasi kandar', 'roti canai', 'mee goreng', '清真', '清真餐', '印度煎饼', '扁担饭'],
    'Street Art & Murals': ['street art', 'mural', 'wall art', 'armenian street art', 'graffiti', '壁画', '街头壁画', '街头艺术', '铁塑壁画'],
    'Museums & Galleries': ['museum', 'gallery', 'art exhibition', 'peranakan', 'wonderfood', '博物馆', '美术馆', '展览馆', '娘惹博物馆'],
    'places of worship': ['temple', 'mosque', 'church', 'shrine', 'pagoda', 'kek lok si', 'kapitan keling', '庙', '寺', '极乐寺', '教堂', '清真寺', '观音亭'],
    'cultural & heritage': ['heritage', 'history', 'historic', 'historical sites', 'monuments', 'fort', 'unesco', 'place to visit', 'places to visit', 'thing to do', 'things to do', 'what to see', 'sightseeing', 'attraction', 'attractions', 'highlights', 'landmark', 'landmarks', 'visit', '古迹', '历史', '文化', '景点', '观光', '必去', '旅游景点', '名胜'],
    'Accommodations & Hotels': ['hotel', 'stay', 'resort', 'homestay', 'hostel', '酒店', '住宿', '民宿', '度假村'],
    'Night Markets (Pasar Malam)': ['night market', 'pasar malam', 'evening market', '夜市'],
    'shopping & malls': [
        'shopping', 'mall', 'malls', 'shopping mall', 'shopping malls', 'shopping center', 'shopping centers',
        'shopping centre', 'shopping centres', 'supermarket', 'hypermarket', 'pasar', 'market', 'store',
        'plaza', 'all seasons', 'sunshine', 'queensbay', 'gurney plaza', 'gurney paragon', '1st avenue',
        'straits quay', 'department store', 'farlim market', 'night market', 'pasar malam',
        '购物', '商场', '百货', '购物中心', '超级市场', '夜市', '市场'
    ],
    'Indoor & Sanctuaries': [
        'indoor', 'indoor discovery', 'indoor attraction', 'indoor attractions', 'rain', 'rainy',
        'aircon', 'air-conditioned', 'air conditioned', 'shelter', '室内', '避雨', '空调', '冷气', '下雨'
    ],
    'Digital Stamps & Landmarks': [
        'digital stamp', 'stamp hunt', 'stamp', 'heritage stamp', '印章', '打卡', '集章'
    ],
    'Shopping & Markets': [
        'shopping', 'mall', 'malls', 'shopping mall', 'shopping malls', 'shopping center', 'shopping centers',
        'shopping centre', 'shopping centres', 'supermarket', 'hypermarket', 'pasar', 'market', 'store',
        'plaza', 'all seasons', 'sunshine', 'queensbay', 'gurney plaza', 'gurney paragon', '1st avenue',
        'straits quay', 'department store', 'farlim market', 'night market', 'pasar malam',
        '购物', '商场', '百货', '购物中心', '超级市场', '夜市', '市场'
    ]
};

// Map any detected category string or keyword to MongoDB places_new collections & categories
function mapCategoryToMongo(categories = [], userKeywords = []) {
    const mongoCategories = new Set();
    const subCategories = new Set();
    const searchTerms = new Set((userKeywords || []).map(k => k.toLowerCase().trim()).filter(Boolean));

    for (const rawCat of categories) {
        const cat = rawCat.toLowerCase();
        if (cat.includes('indoor') || cat.includes('aircon') || cat.includes('rain') || cat.includes('室内') || cat.includes('避雨')) {
            mongoCategories.add('Heritage & Culture');
            mongoCategories.add('Museums & Galleries');
            mongoCategories.add('Cafes');
            mongoCategories.add('Arts & Workshops');
            mongoCategories.add('Shopping & Markets');
        } else if (cat.includes('stamp') || cat.includes('印章') || cat.includes('打卡')) {
            mongoCategories.add('Heritage & Culture');
            mongoCategories.add('Museums & Galleries');
            mongoCategories.add('Religious Sites');
        } else if (cat.includes('shop') || cat.includes('mall') || cat.includes('market') || cat.includes('supermarket') || cat.includes('store') || cat.includes('百货') || cat.includes('商场') || cat.includes('集市')) {
            mongoCategories.add('Shopping & Markets');
            subCategories.add('Shopping & Markets');
            subCategories.add('Mall');
            subCategories.add('Supermarket');
            subCategories.add('Market');
        } else if (cat.includes('cafe') || cat.includes('coffee') || cat.includes('kopi') || cat.includes('brunch') || cat.includes('咖啡') || cat.includes('cake') || cat.includes('bakery') || cat.includes('pastry') || cat.includes('dessert') || cat.includes('甜品') || cat.includes('面包')) {
            mongoCategories.add('Cafes');
            mongoCategories.add('Food & Dining');
        } else if (cat.includes('food') || cat.includes('hawker') || cat.includes('restaurant') || cat.includes('dining') || cat.includes('halal') || cat.includes('makan') || cat.includes('noodle') || cat.includes('laksa') || cat.includes('美食') || cat.includes('餐厅')) {
            mongoCategories.add('Food & Dining');
            mongoCategories.add('Cafes');
        } else if (cat.includes('worship') || cat.includes('temple') || cat.includes('mosque') || cat.includes('church') || cat.includes('shrine') || cat.includes('庙') || cat.includes('寺') || cat.includes('极乐寺')) {
            mongoCategories.add('Religious Sites');
            mongoCategories.add('Heritage & Culture');
        } else if (cat.includes('nature') || cat.includes('park') || cat.includes('beach') || cat.includes('hill') || cat.includes('hiking') || cat.includes('botanical') || cat.includes('garden') || cat.includes('海滩') || cat.includes('公园')) {
            mongoCategories.add('Nature & Parks');
        } else if (cat.includes('heritage') || cat.includes('culture') || cat.includes('museum') || cat.includes('gallery') || cat.includes('historic') || cat.includes('clan') || cat.includes('monument') || cat.includes('古迹') || cat.includes('博物馆')) {
            mongoCategories.add('Heritage & Culture');
            mongoCategories.add('Arts & Workshops');
        } else if (cat.includes('art') || cat.includes('mural') || cat.includes('workshop') || cat.includes('craft') || cat.includes('壁画')) {
            mongoCategories.add('Arts & Workshops');
            mongoCategories.add('Heritage & Culture');
        } else if (cat.includes('adventure') || cat.includes('theme park') || cat.includes('escape') || cat.includes('entopia')) {
            mongoCategories.add('Family & Adventure');
        } else if (cat.includes('hotel') || cat.includes('stay') || cat.includes('resort') || cat.includes('homestay') || cat.includes('住宿') || cat.includes('酒店')) {
            mongoCategories.add('Boutique Stays');
        } else if (cat.includes('bar') || cat.includes('nightlife') || cat.includes('bistro') || cat.includes('pub') || cat.includes('speakeasy')) {
            mongoCategories.add('Nightlife & Speakeasies');
        } else if (cat.includes('spa') || cat.includes('wellness') || cat.includes('massage')) {
            mongoCategories.add('Wellness & Spa');
        } else if (cat.includes('souvenir') || cat.includes('gift') || cat.includes('nutmeg') || cat.includes('biscuit') || cat.includes('特产') || cat.includes('手信')) {
            mongoCategories.add('Local Souvenirs');
            mongoCategories.add('Shopping & Markets');
        }
    }

    return {
        primaryCategories: Array.from(mongoCategories),
        subCategories: Array.from(subCategories),
        searchTerms: Array.from(searchTerms)
    };
}

// Verified Penang Attraction Factual Knowledge (for accurate Opening Hours, Entrance Fees, Address)
const KNOWN_PENANG_FACTS = [
    {
        name: 'Pinang Peranakan Mansion',
        aliases: ['pinang peranakan mansion', 'penang peranakan mansion', 'peranakan mansion', 'pinang peranakan', 'emerald green mansion', 'baba nyonya mansion', '侨生博物馆', '娘惹博物馆', '峇峇娘惹博物馆'],
        opening_hours: 'Daily from 9:30 AM to 5:00 PM.',
        entrance_fee: 'Yes, admission fee is required: RM 25 for adults, RM 12 for children (aged 6-12), and free for children below 6.',
        address: '29, Church Street, George Town, 10200 George Town, Penang.',
        tip: 'Tour the emerald-green mansion to discover authentic Baba Nyonya antiques!'
    },
    {
        name: 'Indian Heritage Gallery & Cultural Centre',
        aliases: ['indian heritage gallery', 'indian heritage', 'cultural centre', 'penang indian heritage', '印度遗产馆', '印度文化馆'],
        opening_hours: 'Monday to Friday from 10:00 AM to 5:00 PM (Closed on weekends and public holidays).',
        entrance_fee: 'Admission is free!',
        address: 'Jalan Macalister, George Town, 10400 George Town, Penang.',
        tip: 'Explore Penang’s rich Indian cultural traditions and historical artifacts!'
    },
    {
        name: 'Kek Lok Si Temple',
        aliases: ['kek lok si', 'air itam temple', 'kek lok temple', 'kek lok si temple', '极乐寺', '槟城极乐寺'],
        opening_hours: 'Daily from 8:30 AM to 5:30 PM.',
        entrance_fee: 'Admission to the main temple grounds is free. Small fees apply for the Pagoda (RM 2) and inclined lift to the Kuan Yin statue (RM 3 to RM 6).',
        address: '11500 Air Itam, Penang.',
        phone: '+60 4-828 3317',
        website: 'https://kekloksitemple.com/',
        tip: 'Visit during sunset or festive periods to see the temple aglow with lights!'
    },
    {
        name: 'Penang Hill (Bukit Bendera)',
        aliases: ['penang hill', 'penang hills', 'bukit bendera', 'hills', '升旗山', '槟榔山'],
        opening_hours: 'Funicular railway operates daily from 6:30 AM to 10:00 PM.',
        entrance_fee: 'Standard return funicular ticket is RM 12 for adult MyKad holders (RM 6 for kids) and RM 30 for standard adult tourists (RM 15 for kids).',
        address: 'Jalan Stesen Bukit Bendera, 11500 Air Itam, Penang.',
        phone: '+60 4-828 8880',
        website: 'https://www.penanghill.gov.my/',
        tip: 'Head up early in the morning for crisp breezes and panoramic island views!'
    },
    {
        name: 'The Habitat Penang Hill',
        aliases: ['the habitat', 'habitat penang', 'the habitat penang hill', '生态公园'],
        opening_hours: 'Daily from 9:00 AM to 7:00 PM (Last entry at 5:30 PM).',
        entrance_fee: 'Standard adult ticket is RM 60, children and seniors RM 40.',
        address: 'Penang Hill, Bukit Bendera, 11300 Penang.',
        phone: '+60 19-645 7741',
        website: 'http://thehabitat.my/',
        tip: 'Walk the Curtis Crest Tree Top Walk for 360-degree views of Penang!'
    },
    {
        name: 'Cheong Fatt Tze - The Blue Mansion',
        aliases: ['cheong fatt tze - the blue mansion', 'cheong fatt tze mansion', 'the blue mansion', 'blue mansion', 'cheong fatt tze', '张弼士故居', '蓝屋'],
        opening_hours: 'Daily guided heritage tours at 11:00 AM and 2:00 PM.',
        entrance_fee: 'Yes, guided heritage tour tickets are RM 25 for adults and RM 12.50 for children under 12.',
        address: '14, Leith Street, George Town, 10200 George Town, Penang.',
        phone: '+60 4-262 0006',
        website: 'https://www.cheongfatttzemansion.com/',
        tip: 'Pre-book online to ensure a spot on the daily architectural guided tour!'
    },
    {
        name: 'Khoo Kongsi',
        aliases: ['khoo kongsi', 'leong san tong khoo kongsi', 'leong san tong', '邱公司', '龙山堂邱公司'],
        opening_hours: 'Daily from 9:00 AM to 5:00 PM.',
        entrance_fee: 'Yes, admission is RM 15 for adults and RM 5 for children under 12.',
        address: '18, Cannon Square, George Town, 10200 George Town, Penang.',
        phone: '+60 4-261 4609',
        website: 'http://www.khookongsi.com.my/',
        tip: 'Admire the intricate clan dragon pillars and golden wood carvings!'
    },
    {
        name: 'Chew Jetty',
        aliases: ['chew jetty', 'clan jetty', 'clan jetties', '姓周桥', '姓氏桥'],
        opening_hours: 'Daily from 9:00 AM to 9:00 PM.',
        entrance_fee: 'Admission is completely free!',
        address: 'Weld Quay, George Town, 10300 George Town, Penang.',
        tip: 'Stroll along the historic wooden stilt walkway and sample local snacks!'
    },
    {
        name: 'Fort Cornwallis',
        aliases: ['fort cornwallis', '康华利斯堡', '康华利斯要塞'],
        opening_hours: 'Daily from 9:00 AM to 10:00 PM.',
        entrance_fee: 'MyKad: RM 10 for adults, RM 5 for kids. Standard tourist: RM 20 for adults, RM 10 for kids.',
        address: 'Jalan Tun Syed Sheh Barakbah, 10200 George Town, Penang.',
        tip: 'Check out the historic Seri Rambai bronze cannon facing the Malacca Strait!'
    },
    {
        name: 'Wonderfood Museum',
        aliases: ['wonderfood museum', 'wonderfood', '食物狂想馆', '美食博物馆'],
        opening_hours: 'Daily from 9:00 AM to 6:00 PM.',
        entrance_fee: 'MyKad: RM 18 for adults, RM 10 for kids. Standard tourist: RM 28 for adults, RM 18 for kids.',
        address: '49, Lebuh Pantai, George Town, 10200 George Town, Penang.',
        tip: 'Pose with the giant replicas of iconic Malaysian hawker dishes!'
    },
    {
        name: 'ESCAPE Penang',
        aliases: ['escape penang', 'escape theme park', 'escape', '世外逃园', '逃生冒险游乐主题公园'],
        opening_hours: 'Tuesday to Sunday from 10:00 AM to 6:00 PM (Closed on Mondays).',
        entrance_fee: 'Dynamic online ticket pricing, usually from RM 110 to RM 180 depending on booking date.',
        address: '828, Jalan Teluk Bahang, 11050 Teluk Bahang, Penang.',
        tip: 'Wear comfortable athletic attire and book early for the Guinness World Record water slide!'
    },
    {
        name: 'Entopia by Penang Butterfly Farm',
        aliases: ['entopia', 'penang butterfly farm', 'butterfly farm', '蝴蝶公园', '槟城蝴蝶公园'],
        opening_hours: 'Thursday to Tuesday from 9:00 AM to 5:00 PM (Closed on Wednesdays).',
        entrance_fee: 'MyKad: RM 59 for adults, RM 39 for kids. Standard tourist: RM 79 for adults, RM 59 for kids.',
        address: '830, Jalan Teluk Bahang, 11050 Teluk Bahang, Penang.',
        tip: 'Explore the glass aviary with thousands of free-flying tropical butterflies!'
    },
    {
        name: 'The TOP Penang',
        aliases: ['the top', 'the top penang', 'rainbow skywalk', 'komtar skywalk', '光大顶楼', '彩虹天空步道'],
        opening_hours: 'Daily from 10:00 AM to 10:00 PM (Closed on Tuesdays for certain indoor attractions).',
        entrance_fee: 'Rainbow Skywalk & Observatory Deck: RM 68 for adults, RM 48 for kids (discounted with MyKad).',
        address: '1, Jalan Penang, George Town, 10000 George Town, Penang.',
        tip: 'Step out onto the open-air glass walkway on level 68 for thrilling views!'
    },
    {
        name: 'Snake Temple (Cheng Hoon Giam)',
        aliases: ['snake temple', 'ban an gong', 'cheng hoon giam', '蛇庙', '万寿宫'],
        opening_hours: 'Daily from 9:00 AM to 5:00 PM.',
        entrance_fee: 'Admission is free!',
        address: 'Jalan Sultan Azlan Shah, Bayan Lepas Industrial Park, 11900 Bayan Lepas, Penang.',
        tip: 'Observe harmless temple pit vipers coiled serenely around trees and shrines!'
    },
    {
        name: 'Penang War Museum',
        aliases: ['penang war museum', 'war museum', 'bukit batu maung fortress', '战争博物馆', '槟城战争博物馆'],
        opening_hours: 'Daily from 9:00 AM to 6:00 PM.',
        entrance_fee: 'MyKad: RM 22 for adults, RM 12 for kids. Standard tourist: RM 38 for adults, RM 20 for kids.',
        address: 'Lot 1335, Mukim 12, Daerah Barat Daya, 11960 Batu Maung, Bayan Lepas, Penang.',
        tip: 'Tour the subterranean bunkers, gun emplacements, and WWII barracks!'
    },
    {
        name: 'Queensbay Mall',
        aliases: ['queensbay mall', 'queensbay', 'queensbay plaza', '皇后湾广场', '皇后湾商场', '皇后湾'],
        opening_hours: 'Daily from 10:30 AM to 10:30 PM.',
        entrance_fee: 'Admission is free!',
        address: '100, Persiaran Bayan Indah, 11900 Bayan Lepas, Penang.',
        tip: 'Shop at Penang’s largest waterfront retail and dining mall overlooking Jerejak Island!'
    },
    {
        name: 'Batu Ferringhi Beach',
        aliases: ['batu ferringhi beach', 'ferringhi beach', 'pantai batu ferringhi', '峇都丁宜海滩', '巴都丁宜海滩'],
        opening_hours: 'Open 24 hours daily.',
        entrance_fee: 'Admission is completely free!',
        address: 'Jalan Batu Ferringhi, 11100 Batu Ferringhi, Penang.',
        tip: 'Enjoy water sports, stroll along the sunset coastline, and explore the night market!'
    }
];

// 🔍 Helper to retrieve previous user input(s) from conversation history
function getPreviousUserInput(history = []) {
    if (!Array.isArray(history) || history.length === 0) return null;
    for (let i = history.length - 1; i >= 0; i--) {
        const h = history[i];
        if (h && (h.role === 'user' || h.sender === 'user' || (!h.role && !h.sender && (h.content || h.text)))) {
            const str = (h.content || h.text || '').trim();
            if (str.length > 0) return str;
        }
    }
    return null;
}

function getAllPreviousUserInputs(history = []) {
    if (!Array.isArray(history) || history.length === 0) return [];
    const list = [];
    for (let i = history.length - 1; i >= 0; i--) {
        const h = history[i];
        if (h && (h.role === 'user' || h.sender === 'user' || (!h.role && !h.sender && (h.content || h.text)))) {
            const str = (h.content || h.text || '').trim();
            if (str.length > 0) list.push(str);
        }
    }
    return list;
}

// 🎯 INTENT CLASSIFIER (判断: Factual Inquiry vs. Recommendation vs. Itinerary Action)
// 规则: 优先根据当前 user input 判断；若缺少明确意图，才看回上一个 user input 来执行
function classifyUserIntent(text, history = []) {
    if (!text || typeof text !== 'string') return 'FACTUAL_INQUIRY';
    const lower = text.toLowerCase().trim();

    // 1. Itinerary Actions (e.g. Add, Remove, Save, Plan)
    const isAddAction = /(?:help\s+me\s+|please\s+|can\s+you\s+|could\s+you\s+)?(?:add|insert|include|put)\b/i.test(lower) ||
        /(?:add|insert|include|put)\s+.*?\s+(?:to|into|in)\s+(?:my\s+|the\s+)?(?:plan|itinerary|trip|list)/i.test(lower) ||
        lower.includes('add to plan') || lower.includes('add to my plan') || lower.includes('add to itinerary') ||
        lower.includes('add to trip') || lower.includes('add to list') ||
        lower.includes('add this') || lower.includes('add option') || lower.includes('add both') ||
        lower.includes('帮我加') || lower.includes('加入行程') || lower.includes('加进行程') || lower.includes('加入计划') ||
        lower.includes('加进计划') || lower.includes('加到行程');

    const isAction = isAddAction ||
        /^(?:add|insert|include|put|delete|remove|clear|save|lock)\b/i.test(lower) ||
        lower.includes('save and plan') || lower.includes('save my trip') ||
        lower.includes('lock trip') || lower.includes('lock itinerary');
    if (isAction) {
        return 'ITINERARY_ACTION';
    }

    // 2. Explicit Recommendation Requests
    const recTriggers = [
        'recommend', 'recommendation', 'recommendations', 'suggest', 'suggestion', 'suggestions',
        'where to go', 'where should i go', 'what to visit', 'places to visit', 'place to visit',
        'where to visit', 'spots to visit', 'spots to see', 'places to go', 'place to go',
        'where can i go', 'where can i visit', 'what should i visit', 'what can i visit',
        'where to eat', 'what to eat', 'places to eat', 'place to eat', 'where can i eat',
        'what can i do in', 'what to do in', 'what should i do in', 'things to do in',
        'any place recommended', 'any places recommended', 'any place to recommend', 'any places to recommend',
        'any good cafe', 'any cafes in', 'any food in', 'any good food', 'show me places',
        'give me places', 'give me options', 'give me some options', 'introduce some',
        'hidden gem', 'hidden gems', 'must visit', 'must-visit', 'must eat',
        'what are the best places', 'what are some good places', 'top places', 'top spots',
        'special', 'what is special', 'anything special', 'what special', 'whats special',
        'highlights', 'highlight', 'famous', 'what is famous', 'famous for', 'famous place',
        'popular', 'best of penang', 'must see', 'must do', 'what to do', 'what is good',
        'anything good', 'good places', 'good spots', 'attractions in penang', 'spots in penang',
        'places in penang', 'what has penang', 'what is there',
        'nearby', 'near', 'around', 'close to', 'what is nearby', 'what are nearby', 'what is near',
        'what to visit', 'to visit', 'nearby to visit', 'near to visit', 'places nearby', 'spots nearby',
        'food nearby', 'attractions nearby', 'restaurants nearby', 'cafes nearby', 'what to see nearby',
        'more', 'give more', 'other options', 'another option', 'different', 'else', 'anything else',
        '推荐', '介绍', '有什么好去处', '有什么去处', '去哪里玩', '去哪玩', '去哪好玩',
        '有什么好玩的', '好玩的', '好玩的地方', '有什么好吃的', '好吃的', '去哪里吃',
        '去哪吃', '有什么景点', '有什么地方可以去', '有什么地方推荐', '推荐一些',
        '推荐几个', '安排一些地方', '有什么餐厅', '有什么咖啡厅', '有什么夜市',
        '有什么特别', '特别', '特色', '著名', '著名景点', '必看', '必去', '有什么好', '好去处',
        '附近的', '附近', '周边', '附近有什么', '附近好玩', '附近好吃', '还有吗', '换一个', '更多'
    ];
    if (recTriggers.some(t => lower.includes(t))) {
        return 'RECOMMENDATION_REQUEST';
    }

    // 3. Factual & Informational Inquiry Indicators
    const factualTriggers = [
        'what is', 'what are', 'what does', 'what can', 'what people', 'what should i bring',
        'why is', 'why are', 'why does', 'why do',
        'how to', 'how do', 'how can', 'how does', 'how much', 'how long', 'how far',
        'when is', 'when does', 'when are', 'when can',
        'who is', 'who built', 'who was',
        'which area', 'what area', 'which part', 'where is', 'where are', 'where does',
        'can i', 'can we', 'can people', 'can someone', 'can pregnant', 'can children',
        'cannot eat', 'can not eat', 'should not eat', 'should avoid', 'not allowed',
        'is it', 'are there', 'is there', 'do i need', 'does it have', 'do they have',
        'tell me about', 'explain', 'meaning of', 'history of', 'difference between',
        'entrance fee', 'opening hour', 'ticket price', 'business hour', 'contact number',
        'safe to', 'weather like', 'take bus', 'take ferry', 'grab',
        '为什么', '怎么', '如何', '可不可以', '能不能', '是不是', '有没有', '多少', '什么是',
        '介绍一下...的历史', '背景', '注意什么', '禁忌', '不能吃', '可以吃吗', '门票', '营业时间',
        '在哪个区', '在哪里', '怎么去', '要多久', '有多远', '安全吗', '天气'
    ];
    const isFactualTrigger = factualTriggers.some(t => lower.includes(t));
    const hasQuestionMark = lower.includes('?') || lower.includes('？') || lower.endsWith('吗') || lower.endsWith('么') || lower.endsWith('呢');

    if (isFactualTrigger || hasQuestionMark) {
        return 'FACTUAL_INQUIRY';
    }

    // 4. 当前输入缺少明确意图，看回上一个 user input 来执行
    const prevUserText = getPreviousUserInput(history);
    if (prevUserText && prevUserText.trim().length > 0) {
        return classifyUserIntent(prevUserText);
    }

    return 'RECOMMENDATION_REQUEST';
}

// Identify if a user query is a Factual Inquiry (Opening Hours, Entrance Fees, Address & Location, or Entity Clarification)
// 规则: 优先根据当前 user input 判断；若缺少，才看回上一个 user input 来执行
function detectFactualInquiry(text, history = []) {
    if (!text || typeof text !== 'string') return null;
    const lower = text.toLowerCase().trim();

    // If query is an explicit recommendation or itinerary action, it is NOT a factual inquiry!
    if (typeof classifyUserIntent === 'function') {
        const intent = classifyUserIntent(text);
        if (intent === 'RECOMMENDATION_REQUEST' || intent === 'ITINERARY_ACTION') {
            return null;
        }
    }

    if (lower.includes('nearby') || lower.includes('near to') || lower.includes('around here') || lower.includes('recommend') || lower.includes('suggest') || lower.includes('to visit')) {
        return null;
    }

    const isHours = lower.includes('opening hour') ||
        lower.includes('business hour') ||
        lower.includes('operating hour') ||
        lower.includes('operation hour') ||
        lower.includes('hours of operation') ||
        lower.includes('closing time') ||
        lower.includes('opening time') ||
        lower.includes('open time') ||
        lower.includes('close time') ||
        /what\s+time\b.*?\b(?:open|close|start|end)/i.test(lower) ||
        /when\b.*?\b(?:open|close)/i.test(lower) ||
        /what\s+hour\b.*?\b(?:open|close)/i.test(lower) ||
        /hours?\s+(?:of|for|at)\b/i.test(lower) ||
        lower.includes('what time open') ||
        lower.includes('what time close') ||
        lower.includes('what time does it open') ||
        lower.includes('what time does it close') ||
        lower.includes('when does it open') ||
        lower.includes('when does it close') ||
        lower.includes('when is it open') ||
        lower.includes('is it open today') ||
        lower.includes('is it open tomorrow') ||
        lower.includes('is it open on') ||
        lower.includes('open on sunday') ||
        lower.includes('open on monday') ||
        lower.includes('几点开') ||
        lower.includes('几点关') ||
        lower.includes('营业时间') ||
        lower.includes('开放时间') ||
        lower.includes('开门时间') ||
        lower.includes('关门时间') ||
        lower.includes('今天有开吗') ||
        lower.includes('明天有开吗') ||
        lower.includes('周末有开吗');

    const isFee = lower.includes('price level') ||
        lower.includes('price range') ||
        lower.includes('ticket price') ||
        lower.includes('ticket fee') ||
        lower.includes('ticket rate') ||
        lower.includes('entrance fee') ||
        lower.includes('admission fee') ||
        lower.includes('entry fee') ||
        lower.includes('entrance rate') ||
        lower.includes('admission rate') ||
        lower.includes('entrance rates') ||
        lower.includes('entrance price') ||
        lower.includes('admission price') ||
        lower.includes('need to pay') ||
        lower.includes('do i need to pay') ||
        lower.includes('how much to enter') ||
        lower.includes('how much is the ticket') ||
        lower.includes('how much does it cost') ||
        lower.includes('how much is') ||
        lower.includes('how much for') ||
        lower.includes('cost to enter') ||
        lower.includes('pay to enter') ||
        lower.includes('is it free') ||
        lower.includes('free entry') ||
        lower.includes('pricing') ||
        /\bprice\b/i.test(lower) ||
        /\bcost\b/i.test(lower) ||
        /\brates?\b/i.test(lower) ||
        /\bfares?\b/i.test(lower) ||
        /\bcharges?\b/i.test(lower) ||
        lower.includes('门票') ||
        lower.includes('票价') ||
        lower.includes('价格') ||
        lower.includes('价位') ||
        lower.includes('消费') ||
        lower.includes('费用') ||
        lower.includes('收费') ||
        lower.includes('收费吗') ||
        lower.includes('多少钱') ||
        lower.includes('要门票吗') ||
        lower.includes('需要门票吗') ||
        lower.includes('免费吗') ||
        lower.includes('门票价格') ||
        lower.includes('门票费');

    const isLocation = lower.includes('which area') ||
        lower.includes('what area') ||
        lower.includes('in which area') ||
        lower.includes('in what area') ||
        lower.includes('which part') ||
        lower.includes('what part') ||
        lower.includes('where is it located') ||
        lower.includes('where is it') ||
        lower.includes('where are they located') ||
        lower.includes('where are they') ||
        lower.includes('where are these') ||
        lower.startsWith('where is ') ||
        lower.startsWith('where are ') ||
        lower.includes('what is the address') ||
        lower.includes('location of') ||
        lower.includes('address of') ||
        lower.includes('exact address') ||
        lower.includes('how to get to') ||
        lower.includes('how to go to') ||
        lower.includes('where can i find') ||
        (lower.includes('address') && (lower.includes('what') || lower.includes('give') || lower.includes('tell') || lower.includes('?'))) ||
        lower.includes('在哪个区') ||
        lower.includes('在什么区') ||
        lower.includes('在哪个地方') ||
        lower.includes('什么位置') ||
        lower.includes('具体位置') ||
        lower.includes('具体地址') ||
        lower.includes('在哪里') ||
        lower.includes('在哪') ||
        lower.includes('在何处') ||
        lower.includes('位于哪里') ||
        lower.includes('属于哪个区') ||
        lower.includes('地址是什么') ||
        lower.includes('地址在哪') ||
        lower.includes('怎么去');

    const isComparisonOrEntityCheck = 
        lower.includes('is the same as') ||
        lower.includes('is it the same') ||
        lower.includes('are they the same') ||
        lower.includes('are these the same') ||
        lower.includes('different from') ||
        lower.includes('difference between') ||
        lower.includes('difference') ||
        lower.includes('the same') ||
        /(?:is|are)\s+.*?\s+(?:the\s+same|different|same\s+as)/i.test(lower) ||
        lower.includes('是一样吗') ||
        lower.includes('是同一个吗') ||
        lower.includes('有什么区别') ||
        lower.includes('有什么不同');

    const isCategory = 
        lower.includes('category') ||
        lower.includes('categories') ||
        lower.includes('what kind of') ||
        lower.includes('what type of') ||
        lower.includes('type of place') ||
        lower.includes('is it a cafe') ||
        lower.includes('is it a temple') ||
        lower.includes('is it a museum') ||
        lower.includes('is it a mosque') ||
        lower.includes('is it a heritage') ||
        lower.includes('what sort of') ||
        lower.includes('classification') ||
        lower.includes('分类') ||
        lower.includes('类别') ||
        lower.includes('种类') ||
        lower.includes('类型') ||
        lower.includes('属于什么分类') ||
        lower.includes('属于哪种分类') ||
        lower.includes('是什么分类') ||
        lower.includes('属于哪种') ||
        lower.includes('是什么店') ||
        lower.includes('是什么景点') ||
        lower.includes('属于什么') ||
        lower.includes('是什么类型');

    const isContact =
        lower.includes('phone number') ||
        lower.includes('contact number') ||
        lower.includes('telephone') ||
        lower.includes('phone') ||
        lower.includes('hotline') ||
        lower.includes('tel') ||
        lower.includes('official website') ||
        lower.includes('website') ||
        lower.includes('web site') ||
        lower.includes('home page') ||
        lower.includes('homepage') ||
        lower.includes('webpage') ||
        lower.includes('contact info') ||
        lower.includes('contact details') ||
        lower.includes('how to contact') ||
        lower.includes('contact them') ||
        lower.includes('电话号码') ||
        lower.includes('联系电话') ||
        lower.includes('电话') ||
        lower.includes('手机号') ||
        lower.includes('官网') ||
        lower.includes('官方网站') ||
        lower.includes('主页') ||
        lower.includes('网站') ||
        lower.includes('网址') ||
        lower.includes('联系方式');

    const isSummary =
        lower.includes('tell me about') ||
        lower.includes('history of') ||
        lower.includes('background of') ||
        lower.includes('who built') ||
        lower.includes('what is the story') ||
        lower.includes('介绍一下') ||
        lower.includes('历史背景') ||
        lower.includes('有什么来历') ||
        lower.includes('有什么故事') ||
        lower.includes('简介');

    const isPlanInquiry =
        lower.includes('in my draft') ||
        lower.includes('in my plan') ||
        lower.includes('in my itinerary') ||
        lower.includes('what is in my') ||
        lower.includes('what do i have') ||
        lower.includes('show my plan') ||
        lower.includes('show my draft') ||
        lower.includes('check my draft') ||
        lower.includes('check my plan') ||
        lower.includes('view my draft') ||
        lower.includes('view my plan') ||
        lower.includes('what spots do i have') ||
        lower.includes('what spots are in') ||
        lower.includes('how many stops') ||
        lower.includes('how many places') ||
        lower.includes('what have i planned') ||
        lower.includes('current draft') ||
        lower.includes('current plan') ||
        lower.includes('my draft plan') ||
        lower.includes('我的行程') ||
        lower.includes('我的草稿') ||
        lower.includes('计划里有') ||
        lower.includes('草稿里有');

    if (isPlanInquiry) return 'plan_inquiry';
    if (isHours) return 'opening_hours';
    if (isFee) return 'entrance_fee';
    if (isCategory) return 'category';
    if (isLocation) return 'address_location';
    if (isContact) return 'contact_info';
    if (isSummary) return 'place_summary';
    if (isComparisonOrEntityCheck) return 'comparison_query';

    // 若当前输入缺少事实查询类型，看回上一个 user input 来执行
    const prevUserText = getPreviousUserInput(history);
    if (prevUserText && prevUserText.trim().length > 0) {
        return detectFactualInquiry(prevUserText);
    }

    return null;
}

// Helper: Format business hours object into readable string
function formatBusinessHours(hours) {
    if (!hours) return null;
    if (typeof hours === 'string' && hours.trim().length > 0) return hours;
    if (typeof hours === 'object') {
        const entries = Object.entries(hours);
        if (entries.length === 0) return null;
        return entries.map(([day, time]) => `${day.charAt(0).toUpperCase() + day.slice(1)}: ${time}`).join(', ');
    }
    return null;
}

// Format opening hours strictly from PlaceNew document
function formatOpeningHoursInfo(doc) {
    if (!doc) return 'No Information in database (check before visiting)';
    if (doc.raw_hours_text && typeof doc.raw_hours_text === 'string' && doc.raw_hours_text.trim()) {
        return doc.raw_hours_text.trim();
    }
    if (doc.opening_hours && doc.opening_hours.is_24_hours) {
        return 'Open 24 hours';
    }
    if (doc.place_business_hours) {
        const formatted = formatBusinessHours(doc.place_business_hours);
        if (formatted) return formatted;
    }
    if (doc.opening_hours && typeof doc.opening_hours === 'object') {
        const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        const dayEntries = [];
        for (const day of days) {
            const sch = doc.opening_hours[day];
            if (sch) {
                if (sch.is_closed) dayEntries.push(`${day.charAt(0).toUpperCase() + day.slice(1)}: Closed`);
                else if (sch.open && sch.close) dayEntries.push(`${day.charAt(0).toUpperCase() + day.slice(1)}: ${sch.open}–${sch.close}`);
            }
        }
        if (dayEntries.length > 0) return dayEntries.join(', ');
    }
    return 'No Information in database (check before visiting)';
}

// Format price / ticket / admission fee strictly from PlaceNew document
function formatPriceInfo(doc) {
    if (!doc) return 'N/A';
    const placeInfoPrice = doc.place_information?.price_level;
    if (placeInfoPrice && typeof placeInfoPrice === 'string' && placeInfoPrice.trim() && placeInfoPrice.trim() !== 'N/A') {
        return placeInfoPrice.trim();
    }
    if (typeof doc.price_level === 'string' && doc.price_level.trim() && doc.price_level.trim() !== 'N/A') {
        return doc.price_level.trim();
    }
    if (typeof doc.ticket_fee === 'object' && doc.ticket_fee !== null) {
        if (doc.ticket_fee.is_free) return 'Free admission';
        if (doc.ticket_fee.amount_myr && doc.ticket_fee.amount_myr > 0) return `RM ${doc.ticket_fee.amount_myr}`;
    }
    if (doc.price_level === 0 || doc.place_information?.price_level === 'Free') {
        return 'Free admission';
    }
    return 'Free admission or rates not listed in database';
}

// Helper: Build diacritic-tolerant regex string (e.g. "Helena Cafe" -> matches "Helena Café")
function buildDiacriticRegex(str) {
    if (!str || typeof str !== 'string') return '';
    const diacriticMap = {
        'a': '[aàáâãäåā]',
        'e': '[eèéêëē]',
        'i': '[iìíîïī]',
        'o': '[oòóôõöō]',
        'u': '[uùúûüū]',
        'c': '[cç]',
        'n': '[nñ]'
    };
    return str.split('').map(ch => {
        const lower = ch.toLowerCase();
        if (diacriticMap[lower]) return diacriticMap[lower];
        return ch.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    }).join('');
}

// Helper: Extract candidate place name mentioned by user in factual queries
function extractTargetPlaceNameFromText(text) {
    if (!text || typeof text !== 'string') return null;
    const trimmed = text.trim();

    // 1. Chinese patterns:
    // Pattern 1a: [Place]的(营业时间|门票|电话|官网|...)
    const zhPropKeywords = '(?:营业时间|开放时间|开门时间|关门时间|门票|票价|价格|费用|收费|多少钱|电话号码|联系电话|电话|手机号|官网|官方网站|主页|网站|网址|联系方式|地址|具体位置|在哪个区|在哪里)';
    const zhPropRegex = new RegExp('(?:请问|想问|帮我查一下|查一下)?\\s*(.+?)\\s*(?:的)?\\s*' + zhPropKeywords, 'i');
    const zhPropMatch = trimmed.match(zhPropRegex);
    if (zhPropMatch && zhPropMatch[1]) {
        let p = zhPropMatch[1].trim();
        p = p.replace(/^(?:请问|想问|帮我查一下|查一下|请帮我查|请教一下)\s*/i, '');
        p = p.replace(/[\?\,\.\!\:\;\'\"\(\)]+/g, '').trim();
        if (p.length >= 2) return p;
    }

    // 2. English patterns:
    // Pattern 2a: (hours|price|price level|website|phone|contact) of/for/about/at [Place]
    const enOfMatch = trimmed.match(/(?:opening hours?|business hours?|operating hours?|hours?|price level|price range|ticket prices?|ticket fees?|entrance fees?|admission fees?|admission prices?|rates?|fees?|costs?|pricing|prices?|websites?|official website|phone numbers?|contact numbers?|contact info|contact details|phone|telephone|hotlines?|address|location|details)\s+(?:of|for|about|at)\s+([A-Za-z0-9\s'&.-]+?)(?:\?|$|\s+in\s+penang)/i);
    if (enOfMatch && enOfMatch[1] && enOfMatch[1].trim().length >= 2) {
        let p = enOfMatch[1].trim().replace(/^the\s+/i, '');
        p = p.replace(/[\?\,\.\!\:\;\'\"]+/g, '').trim();
        if (p.length >= 2) return p;
    }

    // Pattern 2b: what is [Place]'s (hours|price|...) OR what is [Place] (hours|price|...)
    const enWhatIsMatch = trimmed.match(/(?:what\s+is|what\s+are|tell\s+me|give\s+me|show\s+me|check)\s+(?:the\s+)?([A-Za-z0-9\s'&.-]+?)(?:'s|\s+)(?:opening hours?|business hours?|operating hours?|hours?|price level|price range|ticket price|ticket fee|tickets?|entrance fee|admission|rates?|fees?|cost|pricing|price|website|official website|phone number|contact number|contact info|contact details|phone|telephone|address|location)(?:\?|$)/i);
    if (enWhatIsMatch && enWhatIsMatch[1] && enWhatIsMatch[1].trim().length >= 2) {
        let p = enWhatIsMatch[1].trim().replace(/^the\s+/i, '');
        p = p.replace(/[\?\,\.\!\:\;\'\"]+/g, '').trim();
        if (p.length >= 2) return p;
    }

    // Pattern 2c: is [Place] open/free/paid
    const enIsOpenMatch = trimmed.match(/is\s+([A-Za-z0-9\s'&.-]+?)\s+(?:open|closed|free|operating)/i);
    if (enIsOpenMatch && enIsOpenMatch[1] && enIsOpenMatch[1].trim().length >= 2) {
        let p = enIsOpenMatch[1].trim().replace(/^the\s+/i, '');
        p = p.replace(/[\?\,\.\!\:\;\'\"]+/g, '').trim();
        if (p.length >= 2) return p;
    }

    return null;
}

// Format a PlaceNew document into a verified RAG grounding object
function formatFactualGroundingDoc(doc) {
    if (!doc) return null;
    return {
        name: doc.name,
        local_name_zh: doc.local_names?.zh || '',
        primary_category: doc.primary_category || 'Heritage & Culture',
        sub_categories: Array.isArray(doc.sub_categories) ? doc.sub_categories : [],
        opening_hours_text: formatOpeningHoursInfo(doc),
        price_level: formatPriceInfo(doc),
        address: doc.address || `${doc.name}, Penang, Malaysia`,
        area: doc.area || 'Penang',
        phone: doc.place_information?.phone || '',
        website: doc.place_information?.website || '',
        rating: doc.rating || doc.place_information?.rating || null,
        summary: doc.summary || doc.description || '',
        source: 'MongoDB (places_new collection)'
    };
}

// 🏛️ Specialized RAG resolver: Retrieve verified facts for target place from MongoDB (places_new)
async function findFactualGroundingFromMongo(text, history = [], context = {}, inquiryType = null, trace = null) {
    if (!text || typeof text !== 'string') return null;
    const lower = text.toLowerCase().trim();

    // 1. Direct alias match in known landmarks
    const sortedAliases = typeof getSortedKnownAliases === 'function' ? getSortedKnownAliases() : [];
    for (const item of sortedAliases) {
        if (lower.includes(item.alias)) {
            try {
                const cleanName = item.place.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                const factFilter = {
                    status: 'active',
                    name: { $regex: cleanName, $options: 'i' }
                };
                if (typeof formatMongoFilterForTerminal === 'function') {
                    console.log(`\n\x1b[36m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\x1b[0m`);
                    console.log(`\x1b[36m┃ 🔍 [MongoDB places_new Factual Filter - Alias Match: ${item.place.name}]\x1b[0m`);
                    console.log(`\x1b[36m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\x1b[0m`);
                    console.log(`\x1b[33m${formatMongoFilterForTerminal(factFilter)}\x1b[0m\n`);
                }
                if (trace) {
                    trace.mongoQueryFilters = trace.mongoQueryFilters || [];
                    trace.mongoQueryFilters.push({ label: `Factual Alias Match: ${item.place.name}`, filter: factFilter });
                }
                const dbDoc = await PlaceNew.findOne(factFilter).lean();
                if (dbDoc) {
                    const formatted = formatFactualGroundingDoc(dbDoc);
                    if (formatted.opening_hours_text.includes('No Information') && item.place.opening_hours) {
                        formatted.opening_hours_text = item.place.opening_hours;
                    }
                    if (formatted.price_level === 'N/A' && item.place.entrance_fee) {
                        formatted.price_level = item.place.entrance_fee;
                    }
                    if (!formatted.phone && item.place.phone) {
                        formatted.phone = item.place.phone;
                    }
                    if (!formatted.website && item.place.website) {
                        formatted.website = item.place.website;
                    }
                    return formatted;
                }
            } catch (_) {}
            return {
                name: item.place.name,
                local_name_zh: '',
                primary_category: item.place.category || 'Heritage & Culture',
                sub_categories: [item.place.category || 'Heritage & Culture'],
                opening_hours_text: item.place.opening_hours || 'No Information in database',
                price_level: item.place.entrance_fee || 'N/A',
                address: item.place.address || 'Penang',
                area: 'Penang',
                phone: item.place.phone || '',
                website: item.place.website || '',
                rating: null,
                summary: item.place.tip || '',
                source: 'Known Penang Landmarks Knowledge Base'
            };
        }
    }

    // 2. High-precision extraction of candidate place name from query
    let candidate = extractTargetPlaceNameFromText(text);

    // Fallback stop-word cleaning if regex extraction didn't yield a candidate
    if (!candidate || candidate.length < 2) {
        const questionStopWords = /\b(?:what|when|where|which|who|how|is|are|the|of|for|about|at|in|does|do|can|tell|me|give|time|hours?|opening|business|operating|closed?|open|entrance|admission|ticket|fees?|prices?|rates?|category|categories|type|address|location|phone|website|contact|penang|malaysia|level|range|much|cost|pricing|information|details)\b|[\?\,\.\!\:\;\'\"]+/gi;
        const chineseStopWords = /(?:营业时间|开放时间|开门时间|关门时间|门票|票价|价格|费用|收费|多少钱|在哪个区|在哪里|在何处|地址|位置|分类|类别|类型|属于|是什么|有开吗|好玩吗|介绍|历史|背景|电话号码|联系电话|电话|官网|网站|网址|联系方式|请问|想问|帮我查)/g;
        candidate = text.replace(questionStopWords, ' ').replace(chineseStopWords, ' ').trim();
        candidate = candidate.replace(/\s+/g, ' ').trim();
    }

    // Search MongoDB places_new with candidate regex
    if (candidate && candidate.length >= 2) {
        try {
            const diacriticRegex = buildDiacriticRegex(candidate);
            const cleanEscaped = candidate.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

            // Try exact name match first
            let doc = await PlaceNew.findOne({
                status: 'active',
                name: { $regex: `^${diacriticRegex}$`, $options: 'i' }
            }).lean();

            // Try substring name, local_names.zh, or search_keywords
            if (!doc) {
                doc = await PlaceNew.findOne({
                    status: 'active',
                    $or: [
                        { name: { $regex: diacriticRegex, $options: 'i' } },
                        { 'local_names.zh': { $regex: cleanEscaped, $options: 'i' } },
                        { search_keywords: candidate.toLowerCase() }
                    ]
                }).lean();
            }

            // Try token matching if candidate has multiple words
            if (!doc && candidate.includes(' ')) {
                const tokens = candidate.split(/\s+/).filter(t => t.length > 2);
                if (tokens.length >= 2) {
                    doc = await PlaceNew.findOne({
                        status: 'active',
                        $and: tokens.map(t => ({
                            name: { $regex: buildDiacriticRegex(t), $options: 'i' }
                        }))
                    }).lean();
                }
            }

            if (doc) {
                if (trace) {
                    trace.mongoQueryFilters = trace.mongoQueryFilters || [];
                    trace.mongoQueryFilters.push({ label: `Factual Name Match: ${doc.name}`, filter: { name: candidate } });
                }
                return formatFactualGroundingDoc(doc);
            }
        } catch (e) {
            console.warn('findFactualGroundingFromMongo search error:', e.message);
        }
    }

    // 3. Contextual Reference Resolution:
    // User refers to Option A, Option B, or pronoun ("its hours", "它的门票", "这个地方")
    const isRefOptionA = lower.includes('option a') || lower.includes('option 1');
    const isRefOptionB = lower.includes('option b') || lower.includes('option 2');
    const isPronounRef = lower.includes('it ') || lower.includes('its ') || lower.includes('this place') || lower.includes('它') || lower.includes('这个地方') || lower.includes('这里');

    if (isRefOptionA || isRefOptionB || isPronounRef || !candidate || candidate.length < 2) {
        if (Array.isArray(history) && history.length > 0) {
            for (let i = history.length - 1; i >= 0; i--) {
                const h = history[i];
                const content = h.content || h.text || '';
                const opts = typeof extractOptionsFromText === 'function' ? extractOptionsFromText(content) : {};
                let targetName = null;
                if (isRefOptionA && opts.optionA) targetName = opts.optionA;
                else if (isRefOptionB && opts.optionB) targetName = opts.optionB;
                else if (opts.optionA) targetName = opts.optionA;
                else if (Array.isArray(h.suggestedPlaces) && h.suggestedPlaces.length > 0) {
                    const first = h.suggestedPlaces[0];
                    targetName = typeof first === 'string' ? first : (first.name || first.placeName);
                }

                if (targetName) {
                    try {
                        const cleanEscaped = targetName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                        const doc = await PlaceNew.findOne({
                            status: 'active',
                            name: { $regex: cleanEscaped, $options: 'i' }
                        }).lean();
                        if (doc) return formatFactualGroundingDoc(doc);
                    } catch (_) {}
                }
            }
        }

        // Draft plan stops fallback
        if (context?.draftPlan?.stops?.length > 0) {
            const lastStop = context.draftPlan.stops[context.draftPlan.stops.length - 1];
            const stopName = lastStop.placeName || lastStop.name;
            if (stopName) {
                try {
                    const cleanEscaped = stopName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    const doc = await PlaceNew.findOne({
                        status: 'active',
                        name: { $regex: cleanEscaped, $options: 'i' }
                    }).lean();
                    if (doc) return formatFactualGroundingDoc(doc);
                } catch (_) {}
            }
        }
    }

    return null;
}


// Helper: Robustly parse and extract clean message, action, and payload from raw model response
// Prevents raw JSON, Markdown fences, schema keys, or truncated JSON from ever leaking into chat bubbles
function extractCleanMessageAndPayload(rawText) {
    if (!rawText || typeof rawText !== 'string') {
        return { message: '', action: 'none', payload: {}, parsedSuccessfully: false };
    }

    const trimmed = rawText.trim();
    const jsonCandidates = [];

    // 1. Markdown code fences: ```json ... ``` or ``` ... ```
    const fenceMatches = [...trimmed.matchAll(/```(?:json)?\s*([\s\S]*?)\s*```/gi)];
    for (const m of fenceMatches) {
        if (m[1]) jsonCandidates.push(m[1].trim());
    }

    // 2. Outermost balanced or boundary { ... }
    const firstBrace = trimmed.indexOf('{');
    const lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace > firstBrace) {
        jsonCandidates.push(trimmed.slice(firstBrace, lastBrace + 1).trim());
    }

    if (trimmed.startsWith('{')) {
        jsonCandidates.push(trimmed);
    }

    // Attempt standard JSON parsing on candidates
    for (const cand of jsonCandidates) {
        try {
            const parsed = JSON.parse(cand);
            if (parsed && typeof parsed === 'object') {
                const msg = (parsed.message || parsed.reply || '').toString().trim();
                const action = parsed.action || 'none';
                const payload = (parsed.payload && typeof parsed.payload === 'object') ? parsed.payload : {};
                if (msg) {
                    return {
                        message: msg,
                        action,
                        payload,
                        parsedSuccessfully: true
                    };
                }
            }
        } catch (_) {
            // Keep trying next candidate
        }
    }

    // 3. Fallback Regex Extraction for Truncated JSON / Incomplete Stream
    // In case model hits token limit or timeout and truncates before closing braces
    let extractedMessage = '';
    const msgMatch = trimmed.match(/"message"\s*:\s*"((?:[^"\\]|\\.)*)"/s);
    if (msgMatch && msgMatch[1]) {
        try {
            extractedMessage = JSON.parse(`"${msgMatch[1]}"`).trim();
        } catch (_) {
            extractedMessage = msgMatch[1]
                .replace(/\\"/g, '"')
                .replace(/\\n/g, '\n')
                .replace(/\\r/g, '')
                .replace(/\\t/g, '\t')
                .trim();
        }
    }

    let extractedAction = 'none';
    const actionMatch = trimmed.match(/"action"\s*:\s*"([a-zA-Z_]+)"/);
    if (actionMatch && actionMatch[1]) {
        extractedAction = actionMatch[1];
    }

    const extractedSuggestedPlaces = [];
    const placeRegex = /"placeName"\s*:\s*"((?:[^"\\]|\\.)*)"/g;
    let pMatch;
    while ((pMatch = placeRegex.exec(trimmed)) !== null) {
        if (pMatch[1]) {
            extractedSuggestedPlaces.push({
                placeName: pMatch[1].replace(/\\"/g, '"').trim(),
                category: 'Attraction'
            });
        }
    }

    let extractedTargetSeqs = [];
    const seqMatch = trimmed.match(/"targetSequences"\s*:\s*\[([\d,\s]+)\]/);
    if (seqMatch && seqMatch[1]) {
        extractedTargetSeqs = seqMatch[1].split(',').map(s => parseInt(s.trim(), 10)).filter(n => !isNaN(n));
    }
    if (extractedTargetSeqs.length === 0 && extractedMessage) {
        const textSeq = extractedMessage.match(/removed\s+(?:stop\s+|spot\s+|#)?(\d+)/i);
        if (textSeq && textSeq[1]) {
            extractedTargetSeqs = [parseInt(textSeq[1], 10)];
            if (extractedAction === 'none') {
                extractedAction = 'remove_spots';
            }
        }
    }

    if (extractedMessage) {
        return {
            message: extractedMessage,
            action: extractedAction,
            payload: {
                suggestedPlaces: extractedSuggestedPlaces,
                targetSequences: extractedTargetSeqs
            },
            parsedSuccessfully: true
        };
    }

    // 4. If string still contains JSON keys or code fence, sanitize aggressively
    let sanitizedText = trimmed
        .replace(/^```(?:json)?\s*/i, '')
        .replace(/\s*```$/i, '')
        .trim();

    // If it starts with { and has "message": "something without closing quote
    const unclosedMsgMatch = sanitizedText.match(/"message"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)$/s);
    if (unclosedMsgMatch && unclosedMsgMatch[1]) {
        return {
            message: unclosedMsgMatch[1].replace(/\\"/g, '"').replace(/\\n/g, '\n').trim(),
            action: extractedAction,
            payload: {},
            parsedSuccessfully: true
        };
    }

    return {
        message: sanitizedText,
        action: 'none',
        payload: {},
        parsedSuccessfully: false
    };
}

// Helper: Get all known aliases sorted by length descending so longer, specific names match first
function getSortedKnownAliases() {
    const allKnown = [];
    for (const p of KNOWN_PENANG_FACTS) {
        for (const alias of p.aliases) {
            allKnown.push({ alias: alias.toLowerCase(), place: p });
        }
    }
    allKnown.sort((a, b) => b.alias.length - a.alias.length);
    return allKnown;
}

// Helper: Find all mentioned verified places in user input and conversation history
function findMentionedKnownFacts(text, history = [], context = {}) {
    const historyText = Array.isArray(history) && history.length > 0
        ? history.slice(-4).map(h => h.content || h.text || '').join(' ')
        : '';
    const draftStopsText = (context?.draftPlan?.stops || []).map(s => s.placeName || s.name || '').join(' ');
    const corpus = `${text} ${historyText} ${draftStopsText}`.toLowerCase();

    const sortedAliases = getSortedKnownAliases();
    const matched = [];
    const seen = new Set();

    for (const item of sortedAliases) {
        if (corpus.includes(item.alias)) {
            if (!seen.has(item.place.name)) {
                seen.add(item.place.name);
                matched.push(item.place);
            }
        }
    }
    return matched;
}

// Resolve target place name for factual inquiries (from prompt or previous dialogue)
async function resolveTargetPlaceForInquiry(text, history = [], context = {}) {
    const lower = text.toLowerCase().trim();
    const sortedAliases = getSortedKnownAliases();

    // 1. Direct match in query text against known facts (longest alias checked first)
    for (const item of sortedAliases) {
        if (lower.includes(item.alias)) {
            return { source: 'known', data: item.place, name: item.place.name };
        }
    }

    // 2. Direct match in query text against MongoDB PlaceNew
    const rawWords = text.replace(/[^\w\s]/g, ' ').split(/\s+/).filter(w => w.length > 2);
    const ignoreWords = new Set(['what', 'where', 'when', 'help', 'want', 'please', 'plan', 'trip', 'this', 'that', 'with', 'about', 'some', 'good', 'best', 'option', 'asking', 'business', 'hour', 'hours', 'time', 'which', 'other', 'another', 'need', 'pay', 'entrance', 'fee', 'ticket', 'cost', 'entry', 'admission', 'free', 'open', 'close', 'closed', 'opening', 'closing', 'operating', 'address', 'location', 'enter', 'rate', 'rates', 'charges']);
    const keywords = rawWords.filter(w => !ignoreWords.has(w.toLowerCase()));
    if (keywords.length > 0) {
        try {
            const dbMatch = await PlaceNew.findOne({
                status: 'active',
                name: { $regex: keywords.join(' '), $options: 'i' }
            });
            if (dbMatch) {
                return { source: 'mongo', data: dbMatch, name: dbMatch.name };
            }
        } catch (_) {}
    }

    // 3. Fallback to conversation history (look backwards for mentioned place - active focus)
    if (Array.isArray(history) && history.length > 0) {
        for (let i = history.length - 1; i >= 0; i--) {
            const h = history[i];
            const textContent = h.content || h.text || '';
            const opts = extractOptionsFromText(textContent);
            const candidateNames = [opts.optionB, opts.optionA].filter(Boolean);
            if (Array.isArray(h.suggestedPlaces)) {
                h.suggestedPlaces.forEach(p => {
                    const nm = typeof p === 'string' ? p : (p.name || p.placeName);
                    if (nm) candidateNames.push(nm);
                });
            }

            for (const cand of candidateNames) {
                const lowCand = cand.toLowerCase();
                for (const item of sortedAliases) {
                    if (lowCand === item.alias || lowCand.includes(item.alias)) {
                        return { source: 'known', data: item.place, name: item.place.name };
                    }
                }
                try {
                    const dbMatch = await PlaceNew.findOne({
                        status: 'active',
                        name: { $regex: cand.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' }
                    });
                    if (dbMatch) return { source: 'mongo', data: dbMatch, name: dbMatch.name };
                } catch (_) {}
                return { source: 'unknown', data: null, name: cand };
            }
        }
    }

    // 4. Fallback to context: draft plan last stop
    if (context && context.draftPlan && Array.isArray(context.draftPlan.stops) && context.draftPlan.stops.length > 0) {
        const lastStop = context.draftPlan.stops[context.draftPlan.stops.length - 1];
        const stopName = (lastStop.placeName || lastStop.name || '').trim();
        if (stopName) {
            const lowStop = stopName.toLowerCase();
            for (const item of sortedAliases) {
                if (lowStop === item.alias || lowStop.includes(item.alias)) {
                    return { source: 'known', data: item.place, name: item.place.name };
                }
            }
            try {
                const dbMatch = await PlaceNew.findOne({
                    status: 'active',
                    name: { $regex: stopName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' }
                });
                if (dbMatch) return { source: 'mongo', data: dbMatch, name: dbMatch.name };
            } catch (_) {}
            return { source: 'unknown', data: null, name: stopName };
        }
    }

    return null;
}

// Fallback Rule-Based Factual Responder (Used when LLM fails or times out)
async function generateRuleBasedFactualReply(message, history = [], context = {}, inquiryType = null) {
    const isChinese = /[\u4e00-\u9fa5]/.test(message);
    const grounding = await findFactualGroundingFromMongo(message, history, context, inquiryType);
    let factualReply = '';

    if (grounding) {
        const placeName = grounding.name;
        if (inquiryType === 'opening_hours') {
            const hours = grounding.opening_hours_text;
            factualReply = isChinese 
                ? `**${placeName}** 的营业时间为：${hours}。建议出行前确认最新开放状态！`
                : `**${placeName}** opening hours: ${hours}. Jom plan your visit!`;
        } else if (inquiryType === 'entrance_fee') {
            const fee = grounding.price_level;
            factualReply = isChinese
                ? `关于 **${placeName}** 的门票与费用：${fee}。祝你游玩愉快！`
                : `Regarding entrance fees for **${placeName}**: ${fee}. Jom explore!`;
        } else if (inquiryType === 'category') {
            const cat = grounding.primary_category;
            const sub = (grounding.sub_categories && grounding.sub_categories.length > 0) ? grounding.sub_categories.join(', ') : '';
            const catDisplay = sub ? `${cat}（细分类别：${sub}）` : cat;
            const catDisplayEn = sub ? `${cat} (Sub-categories: ${sub})` : cat;
            factualReply = isChinese
                ? `**${placeName}** 属于 **${catDisplay}** 分类。`
                : `**${placeName}** is categorized under **${catDisplayEn}**.`;
        } else if (inquiryType === 'address_location') {
            const addr = grounding.address;
            factualReply = isChinese
                ? `**${placeName}** 位于 ${addr}（区域：${grounding.area}）。欢迎前往探索！`
                : `**${placeName}** is located at ${addr} (${grounding.area}). Jom visit!`;
        } else if (inquiryType === 'contact_info') {
            const phone = grounding.phone || (isChinese ? '暂无记录' : 'Not listed');
            const website = grounding.website || (isChinese ? '暂无记录' : 'Not listed');
            factualReply = isChinese
                ? `**${placeName}** 的联系电话：${phone}，官方网址：${website}。`
                : `**${placeName}** contact info: Phone: ${phone}, Website: ${website}.`;
        } else if (inquiryType === 'place_summary' || inquiryType === 'comparison_query') {
            const desc = grounding.summary || (isChinese ? '槟城著名历史文化地点。' : 'Notable Penang attraction.');
            factualReply = isChinese
                ? `关于 **${placeName}**：${desc} 位于 ${grounding.address}。`
                : `About **${placeName}**: ${desc} Located at ${grounding.address}.`;
        }
    }

    if (!factualReply) {
        factualReply = isChinese
            ? `*Flap flap!* 抱歉，我们在官方数据库中未能检索到该地点的确切资料。关于景点的开放时间与门票，建议查阅官网或致电确认！`
            : `*Flap flap!* I couldn't find verified records for that place in our official Penang database. Please check their official page or Google Maps before visiting!`;
    }

    return factualReply;
}

// System Action Blacklist & Checker
const SYSTEM_ACTIONS = [
    'save & optimize', 'save and optimize', 'save & plan', 'save and plan',
    'save trip', 'save plan', 'save the trip', 'save and plan trip for me now',
    'keep exploring', 'keep planning', 'select dates', 'lock trip',
    'optimize trip', 'require dates', 'i still want to plan', 'add more places',
    'add more', 'select dates 📅', 'keep planning 🗺️'
];

function isSystemAction(str) {
    if (!str || typeof str !== 'string') return false;
    const lower = str.toLowerCase();
    if (lower.includes('save and plan') ||
        lower.includes('save & plan') ||
        lower.includes('save trip') ||
        lower.includes('save plan') ||
        lower.includes('save the trip') ||
        lower.includes('lock trip') ||
        lower.includes('add more places') ||
        lower.includes('add more') ||
        lower.includes('keep exploring') ||
        lower.includes('keep planning') ||
        lower.includes('select dates') ||
        lower.includes('require dates') ||
        lower.includes('保存并规划') ||
        lower.includes('保存行程') ||
        lower.includes('锁定行程') ||
        lower.includes('添加更多') ||
        lower.includes('选择日期')) {
        return true;
    }
    const clean = str
        .replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*/i, '')
        .replace(/[^a-zA-Z0-9\u4e00-\u9fa5\s]/gu, ' ')
        .replace(/\s+/g, ' ')
        .trim()
        .toLowerCase();
    return SYSTEM_ACTIONS.some(k => clean === k || clean.includes(k) || k.includes(clean));
}

// 1. Base Persona
const BASE_PERSONA = `You are Kia-Kia, a friendly, warm, and highly knowledgeable local bird companion guiding travelers through Penang, Malaysia.

- Tone & Vocabulary (STRICT):
  * Attitude: Cheerful, welcoming, authentic, culturally insightful, and concise.
  * FORBIDDEN PARTICLES: Never use sentence-ending particles like 'lah', 'leh', 'lor', or 'gok'. Keep sentence endings clean and natural.
  * ALLOWED LOCAL SLANG (Use contextually & max 1 per response):
    - "Jom": Use as an inviting call-to-action ("Jom explore...", "Jom feast!").
    - "Ho chiak": Use strictly when highlighting delicious food, hawker stalls, or snacks.
    - "Alamak": Use exclusively for unexpected or disappointing scenarios (closed shops, sudden rain, missing dates). Never use it in neutral or positive statements.
    - Cultural Terms: Use authentic local terms where appropriate (e.g., Kopitiam, Tapao, Kopi Peng, Char Koay Teow, Asam Laksa).

- Length & Mobile Formatting:
  * Factual inquiries (hours, price, location): Clean and direct (under 35 words). State the requested fact first, plus at most one short action/highlight tip (<= 12 words). Never mention "Option A" or "Option B" for pure factual lookups.
  * Recommendations / comparisons: Keep descriptions vivid yet brief (under 80 words total).
  * Design every response to fit comfortably in a single mobile chat bubble without excessive scrolling.

- Core Knowledge:
  * Deep familiarity with Penang's diverse regions (George Town, Batu Ferringhi, Bayan Lepas, Bayan Baru, Balik Pulau, Air Itam, Teluk Bahang, Butterworth, etc.).
  * Heritage, Straits Chinese/Baba Nyonya traditions, hawker food culture, and tropical rain/sun patterns.

- Guardrails:
  1. ACCURACY FIRST: Ground all facts strictly on the provided Grounding Data. Never hallucinate opening hours, ticket prices, rest days, or travel times.
  2. ALWAYS TWO OPTIONS FOR SUGGESTIONS & SPECIFIC PLACE NAMES:
     - Whenever recommending places, suggesting spots, or providing choices, you MUST ALWAYS provide EXACTLY two options formatted explicitly as [Option A] and [Option B], matching Grounding Option A and Grounding Option B.
     - NEVER provide only one option when giving suggestions, and NEVER suggest a third place or mention "Option C". You MUST ALWAYS provide two distinct choices!
     - You MUST put the EXACT, SPECIFIC VENUE, STALL, OR PLACE NAME immediately after [Option A]: and [Option B]:, followed by " - " and a short highlight.
     - NEVER use generic areas or plural categories as option names (e.g., NEVER write "[Option A]: George Town Hawker Centres for char koay teow"). ALWAYS specify the actual stall or venue name (e.g. "[Option A]: Chulia Street Hawker Food - Known for smoky Char Koay Teow", "[Option B]: Penang Air Itam Laksa - Legendary stall in Air Itam serving rich Asam Laksa").
     - NO TRAVEL DATES OR WEATHER GUARD DURING SPOT SELECTION: When presenting [Option A] and [Option B] recommendations, you MUST NOT ask for travel dates or mention Weather Guard. Focus strictly on helping the user discover and choose between the two spots!
  3. CONVERSATIONAL MEMORY & RESOLUTION: Always inspect the recent conversation history. When the user says "add this", "add Option B", "let's go with the second one", or "add this pasar malam", accurately resolve the exact place referenced from previous turns.
  4. LANGUAGE MATCHING: Always respond in the same language as the user's input. If the user writes in Chinese (Simplified or Traditional), reply warmly in natural Chinese with [Option A] and [Option B] adhering to the same persona and facts. If the user writes in English, reply in English.
  5. FACTUAL INQUIRIES & QUESTIONS (ZERO OPTIONS):
     - When the user asks a factual question, inquiry, food/health precaution (e.g. "what people cannot eat or drink buah pala?"), rules, opening hours, entrance fees, weather, or history, answer directly, warmly, and helpfully.
     - NEVER present [Option A] or [Option B] choices and NEVER suggest new places when the user is only asking a factual question.
  6. GEOGRAPHIC CLUSTERING & AREA CONSISTENCY:
     - STRICT LOCAL AREA ANCHOR: You MUST strictly respond based on the user's added places area (e.g., if user has added places in Balik Pulau, ALL your suggestions MUST be in Balik Pulau).
     - ZERO MAINLAND CROSSING: NEVER suggest POIs in Bukit Mertajam, Butterworth, or Seberang Perai when user has added places in Balik Pulau or on Penang Island. Both [Option A] and [Option B] MUST stay strictly within the user's active area.
     - Avoid drafting plans that require users to cross bridges or travel across mountains between distant parts of Penang.
  7. TRIP CONTROL INTENTS: Append exact protocol tags when appropriate:
     - [INTENT: REQUIRE_DATES] ONLY when the user explicitly requests to lock, save, or finalize their trip schedule, but travel dates are missing. NEVER trigger this or ask for travel dates/Weather Guard when presenting [Option A] and [Option B] spot choices.
     - [INTENT: LOCK_TRIP] when the itinerary is finalized and dates are confirmed.
     - [INTENT: CANCEL_TRIP] when the user explicitly requests to stop or reset their active trip.`;

// 2. Mode-Specific Prompt Builder
function buildModeInstruction(mode, context) {
    if (mode === 'draft_modifier') {
        return `
MODE: draft_modifier
Objective: Help user assemble, refine, prune, and explain their drafted itinerary.
Response Format: ALWAYS output a valid JSON object matching the DraftActionPayload schema:
{
  "message": "Friendly, short message explaining your reasoning (strictly under 60 words)",
  "action": "add_spot" | "remove_spots" | "suggest_spots" | "explain_times" | "require_confirmation" | "none",
  "payload": {
    "suggestedPlaces": [
      {
        "placeName": "Name of Place",
        "category": "heritage" | "nature" | "dining" | "cultural",
        "reason": "Why this place fits"
      }
    ],
    "targetSequences": [1, 2],
    "confirmationType": "remove_ambiguous" | "schedule_conflict" | "replace_spot" | "proactive_save_nudge",
    "pendingData": {},
    "quickReplies": ["🚀 Save and Plan Trip for Me Now", "➕ Add More Places"]
  }
}

Special Rules for draft_modifier:
1. "Add spot / add this to my plan / Option A / Option B":
   - ONLY when user explicitly says "Add [Place]", "Add [Place] into my plan", "帮我加 [Place]", or selects an option ("Option A" / "Option B" / "Add this"), set action: "add_spot", provide ONLY that single placeName in payload.suggestedPlaces, and cheerfully confirm adding ONLY that place.
   - CRITICAL RULE FOR "I want to visit [Place]": If the user says "I want to visit [Place]", "I would like to see [Place]", "我想去 [Place]", or expresses desire to visit without the explicit word "add": DO NOT set action: "add_spot"! Instead, set action: "suggest_spots", present [Option A] as that place and [Option B] as a complementary nearby place so the user can choose to add it themselves!
   - If the user asks to "Add new spot" in general, proactively suggest at most 2 nearby places (Option A and Option B, NEVER more than 2) with action: "suggest_spots".
2. "Proactive Save Milestone (>= 3 spots drafted)":
   - When suggesting spots ([Option A] and [Option B]), DO NOT mention travel dates or Weather Guard. Focus strictly on introducing the two options.
   - ONLY when user explicitly asks to finalize or save their itinerary without dates:
     * Suggest locking dates to activate Weather Guard routing.
     * Set action: "require_confirmation" with confirmationType: "proactive_save_nudge".
     * Set payload.quickReplies: ["🚀 Save and Plan Trip for Me Now", "➕ Add More Places"].
3. "Remove spot":
   - State the current list: "Spot 1 is [Name], Spot 2 is [Name]..."
   - Accept numbers or sequence keywords and map to payload.targetSequences with action: "remove_spots".
   - Ambiguity: If user says "Remove the market" and there are multiple or fuzzy matches, set action: "require_confirmation", confirmationType: "remove_ambiguous", and provide at most 2 quickReplies: ["Option A: Remove Spot 1 (Name)", "Option B: Remove Spot 2 (Name)"].
4. "Why suggest this arrival time?":
   - Analyze context.draftPlan. Set action: "explain_times". Explain sequence reasoning stop-by-stop based on Weather Guard forecast logic: indoor sanctuaries during midday heat (11 AM - 3 PM) or rain windows, and open outdoor breezes/hills in the morning or sunset.
5. Strict Option Caps:
   - When offering choices, comparisons, or confirmations, ALWAYS provide at most 2 items: payload.quickReplies: ["Option A: ...", "Option B: ..."]. NEVER include Option C or more.
   - Keep natural language "message" under 60 words, strictly avoiding "lah", "leh", "lor", "gok", and using "ho chiak" only for food.
`;
    } else if (mode === 'in_trip_assistant') {
        return `
MODE: in_trip_assistant
Objective: On-the-ground live companion reacting to location, itinerary progression, and weather.
Response Format: Ultra-concise mobile text (maximum 2-3 short sentences, under 45 words) + immediate action suggestions.
Rules:
1. Dynamic Weather Guard Rerouting:
   - If liveWeather.precipitationProbability > 50% or sudden rain is flagged, proactively suggest swapping the upcoming outdoor spot with an immediate indoor alternative.
   - Use 'Alamak' exclusively for sudden weather disruptions or unexpected closures (e.g., "Alamak, rain is heading towards George Town!").
2. Hyper-Local Context & Heritage Gamification:
   - Guide users to nearby open hawker stalls, Kopitiams (use terms like Kopi Peng, Teh Tarik naturally), and authentic eats (use 'ho chiak' contextually).
   - Alert the user to collect digital heritage stamps when geofencing confirms proximity to supported landmarks.
3. Mobile Constraints:
   - No sentence-ending particles like 'lah', 'leh', 'lor', or 'gok'.
   - If suggesting an emergency route change or stop swap, provide strictly at most 2 options: Option A and Option B.
`;
    } else {
        // Default: global_explorer
        return `
MODE: global_explorer
Objective: Broad travel brainstorming, local trivia/factual Q&A, and scratch itinerary creation.
Date Conflict Safeguard:
- If the user specifies travel dates, check against context.existingTripDates. If an overlap is detected, warn the user politely and clarify if they intend to plan a separate overlapping itinerary.

Tone & Length Rules (Strict Mobile Optimization):
- Factual Queries (hours, price, location, open status):
  * State the core answer in sentence 1. Add at most one action tip (<= 12 words).
  * Hard limit: under 35 words total.
  * NEVER mention "Option A" or "Option B" for pure factual queries.
- Recommendations / Comparisons:
  * Present strictly 2 choices aligned with Grounding: "[Option A]: [Place/Area 1]" vs "[Option B]: [Place/Area 2]". NEVER include a third option.
  * Highlight the vibe, culinary specialty, or setting of each.
  * Hard limit: under 70 words total.
  * NEVER ask for travel dates or mention Weather Guard when presenting [Option A] and [Option B] spot choices.
- Vocabulary Guardrails:
  * FORBIDDEN: 'lah', 'leh', 'lor', 'gok'.
  * 'ho chiak': strictly for delicious food and hawker stalls.
  * 'Alamak': strictly for closures, rain, or missing information.
  * Max 1 local slang expression per response.

Trip Control Intents:
- Only when user explicitly asks to save, lock, or finalize their trip and dates are missing: append [INTENT: REQUIRE_DATES].
- When dates are set and sequence is ready: append [INTENT: LOCK_TRIP].
- When user asks to stop/cancel the journey: append [INTENT: CANCEL_TRIP].
`;
    }
}

// 3. Context Injection Builder
function buildContextInjection(context, dbPlaces = [], excludedPlaces = new Set(), mentionedFacts = []) {
    let ctxStr = "\n=== CURRENT APP CONTEXT INJECTION ===\n";

    if (context.userId) {
        ctxStr += `- User ID: ${context.userId}\n`;
    }

    if (Array.isArray(context.existingTripDates) && context.existingTripDates.length > 0) {
        ctxStr += `- Existing Trip Dates: ${JSON.stringify(context.existingTripDates)}\n`;
    }

    if (context.draftPlan) {
        const dp = context.draftPlan;
        ctxStr += `- Draft Plan Schedule Date: ${dp.scheduleDate || 'Not specified'}\n`;
        if (Array.isArray(dp.weatherAlerts) && dp.weatherAlerts.length > 0) {
            ctxStr += `- Weather Alerts: ${JSON.stringify(dp.weatherAlerts)}\n`;
        }
        if (Array.isArray(dp.stops) && dp.stops.length > 0) {
            ctxStr += `- Draft Plan Stops (${dp.stops.length} total):\n`;
            dp.stops.forEach(s => {
                ctxStr += `  * Stop ${s.sequence}: "${s.placeName}" (Category: ${s.category}, Arrival: ${s.suggestedArrivalWindow || 'Flexible'}, Stay: ${s.durationMinutes || 60}m, WeatherTag: ${s.weatherTag || 'None'})\n`;
            });
        } else {
            ctxStr += `- Draft Plan Stops: (Currently Empty)\n`;
        }
    }

    if (context.activeTrip) {
        const at = context.activeTrip;
        ctxStr += `- Active Trip ID: ${at.tripId}\n`;
        ctxStr += `- Current Stop Index: ${at.currentStopIndex}\n`;
        if (at.currentCoordinates) {
            ctxStr += `- Current Coordinates: [${at.currentCoordinates.lat}, ${at.currentCoordinates.lng}]\n`;
        }
        if (at.liveWeather) {
            ctxStr += `- Live Weather: ${at.liveWeather.condition}, ${at.liveWeather.temperature}°C, Rain Prob: ${at.liveWeather.precipitationProbability}%\n`;
        }
        if (Array.isArray(at.remainingStops)) {
            ctxStr += `- Remaining Stops: ${at.remainingStops.map(s => `#${s.sequence} ${s.placeName} (Indoor: ${s.isIndoor})`).join(', ')}\n`;
        }
    }

    if (excludedPlaces && excludedPlaces.size > 0) {
        const excludedList = Array.from(excludedPlaces).slice(0, 15).map(p => `"${p}"`).join(', ');
        ctxStr += `\n=== FORBIDDEN / PREVIOUSLY SUGGESTED OR DRAFTED PLACES ===\n`;
        ctxStr += `STRICT RULE: The user already has or has recently seen these places: [${excludedList}]. You MUST NOT suggest, recommend, or mention any of these places as Option A or Option B. You MUST suggest completely fresh alternatives!\n`;
    }

    if (Array.isArray(dbPlaces) && dbPlaces.length > 0) {
        const top2Places = dbPlaces.slice(0, 2);
        const anchorArea = top2Places[0] ? (extractArea(top2Places[0]) || top2Places[0].area || 'Penang') : 'Penang';
        ctxStr += `\n=== REAL PENANG GROUNDING DATA (${top2Places.length} places found in ${anchorArea}) ===\n`;
        ctxStr += `CRITICAL MANDATORY RULES:
1. ALWAYS PROVIDE TWO CHOICES: You MUST ALWAYS provide EXACTLY two options formatted as [Option A] and [Option B]! Never provide only one option.
2. STRICT LOCAL AREA ANCHOR: The user is planning / exploring in ${anchorArea}. Both [Option A] and [Option B] MUST strictly be located in ${anchorArea}! DO NOT suggest places from other areas (e.g. do not suggest George Town or Air Itam spots when user is exploring ${anchorArea}).
3. ZERO MAINLAND CROSSING: NEVER suggest places in Bukit Mertajam, Butterworth, or Seberang Perai when user is in ${anchorArea} or on Penang Island!
4. STRICT MANDATORY USE OF GROUNDING VENUES: You MUST use the two Grounding venues provided below as your [Option A] and [Option B]. DO NOT substitute them with different places from your general memory or previous turns!\n\n`;
        top2Places.forEach((p, idx) => {
            const optLabel = idx === 0 ? 'Option A' : 'Option B';
            const placeName = p.name || p.place_name || 'Penang Spot';
            const area = extractArea(p) || p.area || anchorArea;
            const cat = p.primary_category || p.place_category || 'General';
            const addr = p.address || p.place_address || 'Penang';
            const summ = p.summary || p.place_summary || '';
            const hoursStr = typeof p.place_business_hours === 'object' ? JSON.stringify(p.place_business_hours) : (p.place_business_hours || p.raw_hours_text || 'Opening hours not listed');
            ctxStr += `[${optLabel} Grounding - "${placeName}"]:\n`;
            ctxStr += `  - Name: "${placeName}"\n`;
            ctxStr += `  - Area: "${area}"\n`;
            ctxStr += `  - Category: "${cat}"\n`;
            ctxStr += `  - Address: "${addr}"\n`;
            ctxStr += `  - Business Hours: ${hoursStr}\n`;
            ctxStr += `  - Summary: "${summ}"\n\n`;
        });
    }

    if (Array.isArray(mentionedFacts) && mentionedFacts.length > 0) {
        ctxStr += `\n=== VERIFIED PENANG ATTRACTION FACTS ===\n`;
        mentionedFacts.forEach(p => {
            ctxStr += `- "${p.name}":\n`;
            if (p.entrance_fee) ctxStr += `  * Entrance Fee: ${p.entrance_fee}\n`;
            if (p.opening_hours) ctxStr += `  * Opening Hours: ${p.opening_hours}\n`;
            if (p.address) ctxStr += `  * Address: ${p.address}\n`;
            if (p.tip) ctxStr += `  * Highlights/Tip: ${p.tip}\n`;
        });
    }

    ctxStr += "=====================================\n";
    return ctxStr;
}

function normalizeAreaName(area) {
    if (!area) return area;
    const lower = area.toLowerCase().trim();
    if (lower === 'georgetown' || lower === 'george town' || lower === '乔治市' || lower === 'weld quay' || lower === 'pengkalan weld') return 'George Town';
    if (lower === 'ayer itam' || lower === 'air itam' || lower === '亚依淡') return 'Air Itam';
    if (lower === 'batu ferringhi' || lower === 'batu feringghi' || lower === '峇都丁宜') return 'Batu Ferringhi';
    if (lower === 'bayan lepas' || lower === 'bayan baru' || lower === '峇六拜' || lower === '峇央峇鲁') return 'Bayan Lepas';
    if (lower === 'balik pulau' || lower === '浮罗山背') return 'Balik Pulau';
    if (lower === 'teluk bahang' || lower === '直落巴巷') return 'Teluk Bahang';
    if (lower === 'tanjung bungah' || lower === '丹绒武雅') return 'Tanjung Bungah';
    if (lower === 'tanjung tokong' || lower === '丹绒道光') return 'Tanjung Tokong';
    if (lower === 'gurney' || lower === '新关仔角') return 'Gurney';
    if (lower === 'pulau tikus') return 'Pulau Tikus';
    if (lower === 'butterworth' || lower === '北海') return 'Butterworth';
    if (lower === 'bukit mertajam' || lower === '大山脚') return 'Bukit Mertajam';
    return area;
}

function getAreaDefaultCoordinates(area) {
    const norm = normalizeAreaName(area);
    switch (norm) {
        case 'Bayan Lepas': return { lat: 5.2950, lng: 100.2650 };
        case 'Air Itam': return { lat: 5.4010, lng: 100.2780 };
        case 'Batu Ferringhi': return { lat: 5.4740, lng: 100.2480 };
        case 'Teluk Bahang': return { lat: 5.4570, lng: 100.2180 };
        case 'Balik Pulau': return { lat: 5.3520, lng: 100.2370 };
        case 'Tanjung Bungah': return { lat: 5.4620, lng: 100.2830 };
        case 'Tanjung Tokong': return { lat: 5.4520, lng: 100.3070 };
        case 'Pulau Tikus': return { lat: 5.4300, lng: 100.3120 };
        case 'Gurney': return { lat: 5.4370, lng: 100.3095 };
        case 'Butterworth': return { lat: 5.4100, lng: 100.3700 };
        case 'Bukit Mertajam': return { lat: 5.3630, lng: 100.4610 };
        case 'George Town':
        default:
            return { lat: 5.4141, lng: 100.3288 };
    }
}

function detectMatchedAreas(text) {
    const lower = text.toLowerCase();
    const matches = [];
    const seen = new Set();

    for (const area of PENANG_AREAS) {
        const norm = normalizeAreaName(area);
        const idx = lower.indexOf(area.toLowerCase());
        if (idx !== -1 && !seen.has(norm.toLowerCase())) {
            seen.add(norm.toLowerCase());
            matches.push({ area: norm, index: idx });
        }
    }

    matches.sort((a, b) => a.index - b.index);
    return matches.map(m => m.area);
}

// 🎯 Resolve Target Area across Current Query, History Turns, Context, Draft Plan, and Active Trip
// 规则: 优先根据当前 user input 判断；若缺少，才看回上一个 user input 来执行
function resolveTargetArea(text, history = [], context = {}) {
    // 1. Explicitly mentioned area in current query (Highest priority)
    const matched = detectMatchedAreas(text);
    if (matched.length > 0) return matched[0];

    // 1.5. Explicit postcode or known landmark in current query (Highest priority)
    const textPc = extractPostcode(text);
    if (textPc) {
        const pcArea = getAreaForPostcode(textPc);
        if (pcArea) return pcArea;
    }
    const lowText = text ? text.toLowerCase() : '';
    if (lowText) {
        for (const fact of KNOWN_PENANG_FACTS) {
            if (fact.aliases.some(alias => lowText.includes(alias.toLowerCase()))) {
                const factArea = extractArea(fact) || (fact.address ? extractArea({ address: fact.address }) : null);
                if (factArea && factArea !== 'Penang') return normalizeAreaName(factArea);
            }
        }
        for (const [curArea, pois] of Object.entries(CURATED_AREA_POIS)) {
            if (pois.some(p => lowText.includes(p.name.toLowerCase()))) {
                return curArea;
            }
        }
    }

    // 2. Direct context targetArea / userLocation (Explicitly passed by frontend session or location service)
    if (context) {
        if (context.targetArea && typeof context.targetArea === 'string' && context.targetArea !== 'Penang') {
            const norm = normalizeAreaName(context.targetArea);
            if (norm) return norm;
        }
        if (context.userLocation && context.userLocation.area && context.userLocation.area !== 'Penang') {
            const norm = normalizeAreaName(context.userLocation.area);
            if (norm) return norm;
        }
        if (context.area && typeof context.area === 'string' && context.area !== 'Penang') {
            const norm = normalizeAreaName(context.area);
            if (norm) return norm;
        }
    }

    // 2.5. 若当前输入缺少 area，看回历史输入与助手推荐消息来执行
    const prevUserInputs = getAllPreviousUserInputs(history);
    for (const prevText of prevUserInputs) {
        const pMatched = detectMatchedAreas(prevText);
        if (pMatched.length > 0) return pMatched[0];

        const pPc = extractPostcode(prevText);
        if (pPc) {
            const pcArea = getAreaForPostcode(pPc);
            if (pcArea) return pcArea;
        }

        const pLow = prevText.toLowerCase();
        for (const fact of KNOWN_PENANG_FACTS) {
            if (fact.aliases.some(alias => pLow.includes(alias.toLowerCase()))) {
                const factArea = extractArea(fact) || (fact.address ? extractArea({ address: fact.address }) : null);
                if (factArea && factArea !== 'Penang') return normalizeAreaName(factArea);
            }
        }
        for (const [curArea, pois] of Object.entries(CURATED_AREA_POIS)) {
            if (pois.some(p => pLow.includes(p.name.toLowerCase()))) {
                return curArea;
            }
        }
    }

    // Scan recent assistant messages in history (e.g. AI recently recommended places in Balik Pulau)
    if (Array.isArray(history)) {
        for (let i = history.length - 1; i >= 0; i--) {
            const h = history[i];
            const hText = (h.content || h.text || '').toString();
            if (hText) {
                const hMatched = detectMatchedAreas(hText);
                if (hMatched.length > 0) return hMatched[0];
            }
        }
    }

    // 3. Fallback: Draft plan stops area (Scan from most recently added stop backwards!)
    if (context && context.draftPlan && Array.isArray(context.draftPlan.stops) && context.draftPlan.stops.length > 0) {
        for (let i = context.draftPlan.stops.length - 1; i >= 0; i--) {
            const stop = context.draftPlan.stops[i];
            const extArea = extractArea(stop);
            if (extArea && extArea !== 'Penang') return normalizeAreaName(extArea);
            if (stop.area && stop.area !== 'Penang') return normalizeAreaName(stop.area);
            const pc = extractPostcode(stop.address || stop.place_address || stop.description || '');
            if (pc) {
                const area = getAreaForPostcode(pc);
                if (area) return area;
            }
            const stopStr = `${stop.placeName || stop.name || ''} ${stop.place_address || stop.address || ''} ${stop.description || ''}`;
            const stopAreas = detectMatchedAreas(stopStr);
            if (stopAreas.length > 0) return stopAreas[0];
            const lowStop = (stop.placeName || stop.name || '').toLowerCase();
            for (const fact of KNOWN_PENANG_FACTS) {
                if (fact.aliases.some(alias => lowStop.includes(alias.toLowerCase()))) {
                    const factArea = extractArea(fact) || (fact.address ? extractArea({ address: fact.address }) : null);
                    if (factArea && factArea !== 'Penang') return normalizeAreaName(factArea);
                }
            }
        }
    }

    // 4. Fallback: Active trip stops area (Scan current & remaining stops)
    if (context && context.activeTrip) {
        if (context.activeTrip.currentArea && context.activeTrip.currentArea !== 'Penang') {
            return normalizeAreaName(context.activeTrip.currentArea);
        }
        if (Array.isArray(context.activeTrip.remainingStops) && context.activeTrip.remainingStops.length > 0) {
            for (let i = context.activeTrip.remainingStops.length - 1; i >= 0; i--) {
                const stop = context.activeTrip.remainingStops[i];
                const extArea = extractArea(stop);
                if (extArea && extArea !== 'Penang') return normalizeAreaName(extArea);
                const stopStr = `${stop.placeName || stop.name || ''} ${stop.place_address || stop.address || ''}`;
                const stopAreas = detectMatchedAreas(stopStr);
                if (stopAreas.length > 0) return stopAreas[0];
            }
        }
    }

    // 5. Fallback: Direct context targetArea / area
    if (context) {
        if (context.targetArea && typeof context.targetArea === 'string' && context.targetArea !== 'Penang') {
            const norm = normalizeAreaName(context.targetArea);
            if (norm) return norm;
        }
        if (context.area && typeof context.area === 'string' && context.area !== 'Penang') {
            const norm = normalizeAreaName(context.area);
            if (norm) return norm;
        }
    }

    return null;
}

// 🎯 Resolve Target Category:
// 规则: 优先根据当前 user input 判断；若缺少，才看回上一个 user input 来执行
function resolveTargetCategory(text, history = []) {
    // 1. Explicitly matched category in current text
    const directCats = detectMatchedCategories(text);
    if (directCats.length > 0) return directCats;

    // 2. 若当前输入缺少类别，看回上一个 user input 来执行
    const prevUserInputs = getAllPreviousUserInputs(history);
    for (const prevText of prevUserInputs) {
        const histCats = detectMatchedCategories(prevText);
        if (histCats.length > 0) return histCats;
    }

    return [];
}

// 🎯 Resolve Target Keywords:
// 规则: 优先根据当前 user input 判断；若缺少，才看回上一个 user input 来执行
function resolveTargetKeywords(text, history = []) {
    const rawWords = text.replace(/[^\w\s]/g, ' ').split(/\s+/).filter(w => w.length > 2);
    const ignoreWords = new Set([
        // Actions & Commands
        'add', 'adding', 'added', 'insert', 'include', 'put', 'remove', 'delete', 'clear',
        'want', 'wants', 'wanted', 'wish', 'like', 'likes', 'love', 'prefer', 'need', 'needs',
        'help', 'helps', 'helping', 'please', 'give', 'gives', 'giving', 'bring', 'brings',
        'show', 'shows', 'showing', 'find', 'finds', 'finding', 'look', 'looking', 'looks',
        'suggest', 'suggests', 'suggesting', 'suggestion', 'suggestions',
        'recommend', 'recommends', 'recommending', 'recommendation', 'recommendations',
        'choose', 'choosing', 'chose', 'chosen', 'pick', 'picks', 'picking',
        'select', 'selects', 'selecting', 'decide', 'decides', 'deciding',
        'plan', 'plans', 'planning', 'planned', 'trip', 'trips', 'itinerary', 'itineraries',
        'schedule', 'schedules', 'scheduling',
        'visit', 'visits', 'visiting', 'visited', 'see', 'sees', 'seeing', 'saw', 'seen',
        'go', 'goes', 'going', 'went', 'gone', 'come', 'comes', 'coming', 'came',
        'try', 'tries', 'trying', 'tried', 'check', 'checks', 'checking',
        'tell', 'tells', 'telling', 'told', 'know', 'knows', 'knowing', 'knew',
        'think', 'thinks', 'thinking', 'thought',

        // Auxiliaries & Modals
        'can', 'could', 'would', 'should', 'will', 'shall', 'may', 'might', 'must',
        'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'having',
        'do', 'does', 'did', 'doing', 'done',

        // Pronouns & Demonstratives & Alternatives
        'this', 'that', 'these', 'those', 'them', 'they', 'their', 'theirs',
        'you', 'your', 'yours', 'yourself', 'yourselves',
        'we', 'our', 'ours', 'ourselves', 'us',
        'me', 'my', 'mine', 'myself', 'him', 'his', 'her', 'hers', 'its',
        'else', 'anything', 'something', 'everything', 'nothing',
        'anyone', 'someone', 'everyone', 'anybody', 'somebody', 'nobody',
        'besides', 'apart', 'instead', 'alternatives', 'alternative',
        'additional', 'extra', 'others', 'further',

        // Prepositions & Connectors
        'for', 'with', 'about', 'from', 'into', 'onto', 'upon', 'over', 'under',
        'and', 'but', 'nor', 'yet', 'because', 'since', 'until', 'while',

        // Question Words
        'what', 'where', 'when', 'which', 'who', 'whom', 'whose', 'why', 'how',

        // Qualifiers & Quantifiers
        'good', 'best', 'better', 'great', 'nice', 'fine', 'awesome', 'amazing', 'wonderful',
        'some', 'any', 'many', 'much', 'more', 'most', 'less', 'least', 'all', 'both', 'each',
        'every', 'other', 'another', 'different', 'same', 'such', 'only', 'own',
        'very', 'really', 'quite', 'just', 'also', 'too', 'even', 'ever', 'never', 'always',
        'still', 'already', 'again', 'then', 'than', 'now', 'soon', 'later', 'today', 'tomorrow',

        // Spatial / Proximity
        'near', 'nearby', 'around', 'close', 'closer', 'closest', 'here', 'there',
        'area', 'vicinity', 'neighborhood', 'region',

        // Generic Place Fillers
        'place', 'places', 'spot', 'spots', 'shop', 'shops', 'stall', 'stalls',
        'store', 'stores', 'center', 'centers', 'centre', 'centres', 'venue', 'venues',
        'attraction', 'attractions', 'location', 'locations', 'stop', 'stops',
        'option', 'options', 'choice', 'choices', 'item', 'items', 'thing', 'things',
        'asking', 'business', 'hour', 'hours', 'time', 'timing',

        // Penang Area Names
        'penang', 'george', 'town', 'georgetown', 'air', 'itam', 'ayer', 'bayan', 'lepas',
        'baru', 'batu', 'ferringhi', 'balik', 'pulau', 'teluk', 'bahang', 'tanjung', 'bungah',
        'tokong', 'tikus', 'butterworth', 'seberang', 'perai', 'bukit', 'mertajam',
        'island', 'famous', 'popular'
    ]);
    const directKeywords = rawWords.filter(w => !ignoreWords.has(w.toLowerCase()));
    if (directKeywords.length > 0) return directKeywords;

    // 若当前输入缺少关键词，看回上一个 user input
    const prevUserInputs = getAllPreviousUserInputs(history);
    for (const prevText of prevUserInputs) {
        const hWords = prevText.replace(/[^\w\s]/g, ' ').split(/\s+/).filter(w => w.length > 2);
        const hKeywords = hWords.filter(w => !ignoreWords.has(w.toLowerCase()));
        if (hKeywords.length > 0) return hKeywords;
    }

    return [];
}

function detectMatchedCategories(text) {
    const lower = text.toLowerCase();
    const matches = [];
    const seen = new Set();

    for (const [cat, kws] of Object.entries(CATEGORY_KEYWORDS)) {
        for (const kw of kws) {
            const isAscii = /^[a-zA-Z0-9\s]+$/.test(kw);
            let matched = false;
            let matchIndex = -1;
            if (isAscii) {
                const reg = new RegExp(`\\b${kw}\\b`, 'i');
                const m = lower.match(reg);
                if (m) {
                    matched = true;
                    matchIndex = m.index;
                }
            } else {
                const idx = lower.indexOf(kw.toLowerCase());
                if (idx !== -1) {
                    matched = true;
                    matchIndex = idx;
                }
            }
            if (matched && !seen.has(cat)) {
                seen.add(cat);
                matches.push({ category: cat, index: matchIndex });
                break;
            }
        }
    }

    matches.sort((a, b) => a.index - b.index);
    return matches.map(m => m.category);
}

const MAINLAND_REGEX = 'Bukit Mertajam|Butterworth|Seberang Perai|Seberang Jaya|Nibong Tebal|Kepala Batas|Simpang Ampat|Juru|Perai|14000|13000|14100|14200|14300|大山脚|北海';

const JUNK_NAMES_REGEX = /^(air itam|ayer itam|george town|georgetown|batu ferringhi|balik pulau|bayan lepas|tanjung bungah|tanjung tokong|pulau tikus|butterworth|penang)$|^.*(?:roundabout|traffic circle|junction|flyover|interchange|highway).*$/i;

const MAINLAND_FILTER = {
    $and: [
        {
            $or: [
                { address: { $not: { $regex: MAINLAND_REGEX, $options: 'i' } } },
                { place_address: { $not: { $regex: MAINLAND_REGEX, $options: 'i' } } }
            ]
        },
        {
            $or: [
                { name: { $not: { $regex: 'Bukit Mertajam|Butterworth|Seberang Perai|大山脚|北海', $options: 'i' } } },
                { place_name: { $not: { $regex: 'Bukit Mertajam|Butterworth|Seberang Perai|大山脚|北海', $options: 'i' } } }
            ]
        }
    ]
};

const CURATED_AREA_POIS = {
    'Balik Pulau': [
        { name: 'Audi Dream Farm', category: 'Attraction / Agro-Tourism', description: 'Scenic countryside farm with friendly petting animals, birds, and lush plantation gardens in Balik Pulau.' },
        { name: 'Bao Sheng Durian Farm', category: 'Attraction / Agro-Tourism', description: 'Famous hillside durian orchard with breathtaking mountain views and authentic durian experiences in Balik Pulau.' },
        { name: 'Saanen Dairy Goat Farm', category: 'Attraction / Agro-Tourism', description: 'Charming family-run goat farm offering fresh goat milk, dairy treats, and animal feeding in Balik Pulau.' },
        { name: 'Countryside Stables Penang', category: 'Attraction / Agro-Tourism', description: 'Picturesque equestrian park offering horseback riding and guided countryside carriage rides in Balik Pulau.' },
        { name: 'Kim Laksa Balik Pulau', category: 'Hawker Centres & Food Courts', description: 'Legendary coffee shop stall celebrated for rich asam laksa and fragrant siam laksa in Balik Pulau town.' },
        { name: 'Ghee Hup Nutmeg Factory', category: 'cultural & heritage', description: 'Historic traditional nutmeg factory producing pure nutmeg oil, candied slices, and authentic local spices.' },
        { name: 'Balik Pulau Paddy Field (Kampung Terang)', category: 'nature & parks', description: 'Idyllic open countryside paddy fields perfect for cycling and sunset photography in Balik Pulau.' },
        { name: 'SpedaHub - The All Wheels Cafe', category: 'Cafes', description: 'Cozy bicycle cafe and cycling rest stop in Balik Pulau offering refreshing coffee, cakes, and trail advice.' }
    ],
    'George Town': [
        { name: 'Cheong Fatt Tze - The Blue Mansion', category: 'cultural & heritage', description: 'World-renowned indigo-blue Chinese courtyard mansion showcasing UNESCO-awarded heritage architecture.' },
        { name: 'Pinang Peranakan Mansion', category: 'cultural & heritage', description: 'Opulent Baba Nyonya heritage residence filled with antiques and Straits Chinese cultural treasures.' },
        { name: 'Chulia Street Hawker Food', category: 'Hawker Centres & Food Courts', description: 'Vibrant evening street food hub famous for Char Koay Teow, Curry Mee, and Wonton Noodles.' },
        { name: 'Chew Jetty', category: 'cultural & heritage', description: 'Historic 19th-century wooden stilt clan settlement built over the waters of Weld Quay.' }
    ],
    'Air Itam': [
        { name: 'Kek Lok Si Temple', category: 'places of worship', description: 'Magnificent sprawling Buddhist temple with towering pagoda and grand bronze statue of Kuan Yin.' },
        { name: 'Penang Hill (Bukit Bendera)', category: 'nature & parks', description: 'Iconic hill retreat reached via funicular railway with cool breezes and sweeping island panoramas.' },
        { name: 'Air Itam Sister Curry Mee', category: 'Hawker Centres & Food Courts', description: 'Famous heritage roadside stall serving charcoal-boiled curry noodles in Air Itam.' }
    ],
    'Batu Ferringhi': [
        { name: 'Batu Ferringhi Beach', category: 'beaches', description: 'Penang’s famous stretch of golden sand beach featuring water sports, beach bars, and spectacular sunsets.' },
        { name: 'Batu Ferringhi Night Market', category: 'shopping & malls', description: 'Lively beachfront night bazaar lined with handicrafts, souvenirs, and local street eats.' }
    ],
    'Teluk Bahang': [
        { name: 'ESCAPE Penang', category: 'nature & parks', description: 'Premier outdoor adventure theme park featuring the world’s longest water slide and ziplines.' },
        { name: 'Entopia by Penang Butterfly Farm', category: 'nature & parks', description: 'Enchanting indoor ecological sanctuary with thousands of free-flying butterflies and nature exhibits.' }
    ],
    'Bayan Lepas': [
        { name: 'Snake Temple (Cheng Hoon Giam)', category: 'places of worship', description: 'Historic 1805 Taoist temple renowned for live pit vipers resting peacefully on altars.' },
        { name: 'Penang War Museum', category: 'cultural & heritage', description: 'Vast outdoor historical fortress museum atop Bukit Batu Maung featuring WWII military relics.' }
    ]
};

function getAreaCuratedPair(area, excludedSet = new Set()) {
    const norm = normalizeAreaName(area);
    const candidates = CURATED_AREA_POIS[norm] || CURATED_AREA_POIS['Balik Pulau'] || CURATED_AREA_POIS['George Town'];
    const filtered = candidates.filter(p => !isPlaceExcluded(p.name, excludedSet));
    if (filtered.length >= 2) return filtered.slice(0, 2);
    if (filtered.length === 1) {
        const other = candidates.find(c => c.name.toLowerCase() !== filtered[0].name.toLowerCase());
        return other ? [filtered[0], other] : [filtered[0], filtered[0]];
    }
    return candidates.slice(0, 2);
}

// 🎯 Area to 5-digit postcode mapping in Penang
const AREA_POSTCODES = {
    'Balik Pulau': ['11000', '11010', '11020'],
    'Teluk Bahang': ['11050'],
    'Batu Ferringhi': ['11100'],
    'Tanjung Bungah': ['11200'],
    'Tanjung Tokong': ['10470', '11200'],
    'Pulau Tikus': ['10350'],
    'George Town': ['10000', '10050', '10100', '10150', '10200', '10250', '10300', '10400', '10450'],
    'Air Itam': ['11500'],
    'Jelutong': ['11600'],
    'Gelugor': ['11700'],
    'Bayan Lepas': ['11900', '11920', '11950'],
    'Batu Maung': ['11960'],
    'Butterworth': ['12000', '12100', '12200', '12300', '13000'],
    'Bukit Mertajam': ['14000', '14020'],
    'Perai': ['13600', '13700'],
    'Nibong Tebal': ['14300'],
    'Kepala Batas': ['13200']
};

function extractPostcode(str) {
    if (!str || typeof str !== 'string') return null;
    const m = str.match(/\b(1\d{4})\b/);
    return m ? m[1] : null;
}

// 🎯 Resolve Target 5-digit Postcode across Current Query, History Turns, Context, Draft Plan, and Active Trip
async function resolveTargetPostcode(text, history = [], context = {}) {
    // 1. Explicit 5-digit postcode in current text (Highest priority)
    const textPostcode = extractPostcode(text);
    if (textPostcode) return textPostcode;

    // 2. Explicit area mentioned in current text (HIGHEST PRIORITY OVER HISTORICAL/CONTEXT POSTCODE!)
    const currentTextAreas = detectMatchedAreas(text);
    if (currentTextAreas.length > 0) {
        const matchedArea = currentTextAreas[0];
        if (AREA_POSTCODES[matchedArea] && AREA_POSTCODES[matchedArea].length > 0) {
            return AREA_POSTCODES[matchedArea][0];
        }
    }

    // 3. Known landmark or curated POI mentioned in current text
    const lowText = text ? text.toLowerCase() : '';
    if (lowText) {
        for (const fact of KNOWN_PENANG_FACTS) {
            if (fact.aliases.some(alias => lowText.includes(alias.toLowerCase()))) {
                const factPc = extractPostcode(fact.address || '');
                if (factPc) return factPc;
                const factArea = extractArea(fact);
                if (factArea && AREA_POSTCODES[factArea] && AREA_POSTCODES[factArea].length > 0) {
                    return AREA_POSTCODES[factArea][0];
                }
            }
        }
        for (const [curArea, pois] of Object.entries(CURATED_AREA_POIS)) {
            if (pois.some(p => lowText.includes(p.name.toLowerCase()))) {
                if (AREA_POSTCODES[curArea] && AREA_POSTCODES[curArea].length > 0) {
                    return AREA_POSTCODES[curArea][0];
                }
            }
        }
    }

    // 3.5 Direct context targetPostcode / userLocation / targetArea (Passed explicitly by frontend session)
    if (context) {
        if (context.targetPostcode) {
            const pc = extractPostcode(context.targetPostcode.toString());
            if (pc) return pc;
        }
        if (context.userLocation?.postcode) {
            const pc = extractPostcode(context.userLocation.postcode.toString());
            if (pc) return pc;
        }
        if (context.targetArea && AREA_POSTCODES[context.targetArea] && AREA_POSTCODES[context.targetArea].length > 0) {
            return AREA_POSTCODES[context.targetArea][0];
        }
        if (context.userLocation?.area && AREA_POSTCODES[context.userLocation.area] && AREA_POSTCODES[context.userLocation.area].length > 0) {
            return AREA_POSTCODES[context.userLocation.area][0];
        }
    }

    // 4. 若当前输入缺少 postcode，看回上一个 user input 来执行 (只看 role === 'user' 的输入，绝不从 assistant 回复中泄露)
    const prevUserInputs = getAllPreviousUserInputs(history);
    for (const prevText of prevUserInputs) {
        const pPc = extractPostcode(prevText);
        if (pPc) return pPc;

        const pAreas = detectMatchedAreas(prevText);
        if (pAreas.length > 0 && AREA_POSTCODES[pAreas[0]] && AREA_POSTCODES[pAreas[0]].length > 0) {
            return AREA_POSTCODES[pAreas[0]][0];
        }

        const pLow = prevText.toLowerCase();
        for (const fact of KNOWN_PENANG_FACTS) {
            if (fact.aliases.some(alias => pLow.includes(alias.toLowerCase()))) {
                const factPc = extractPostcode(fact.address || '');
                if (factPc) return factPc;
                const factArea = extractArea(fact);
                if (factArea && AREA_POSTCODES[factArea] && AREA_POSTCODES[factArea].length > 0) {
                    return AREA_POSTCODES[factArea][0];
                }
            }
        }
        for (const [curArea, pois] of Object.entries(CURATED_AREA_POIS)) {
            if (pois.some(p => pLow.includes(p.name.toLowerCase()))) {
                if (AREA_POSTCODES[curArea] && AREA_POSTCODES[curArea].length > 0) {
                    return AREA_POSTCODES[curArea][0];
                }
            }
        }
    }

    // 5. Fallback: Draft plan stops (Scan backwards from most recently added stop)
    if (context && context.draftPlan && Array.isArray(context.draftPlan.stops) && context.draftPlan.stops.length > 0) {
        for (let i = context.draftPlan.stops.length - 1; i >= 0; i--) {
            const stop = context.draftPlan.stops[i];
            const addr = stop.address || stop.place_address || stop.description || '';
            let pc = extractPostcode(addr);
            if (pc) return pc;
            if (stop.area && AREA_POSTCODES[stop.area] && AREA_POSTCODES[stop.area].length > 0) {
                return AREA_POSTCODES[stop.area][0];
            }
            const stopName = stop.name || stop.placeName || '';
            if (stopName) {
                try {
                    const dbStop = await PlaceNew.findOne({ name: { $regex: stopName, $options: 'i' } }).select('address area').maxTimeMS(800);
                    if (dbStop) {
                        if (dbStop.address) {
                            pc = extractPostcode(dbStop.address);
                            if (pc) return pc;
                        }
                        if (dbStop.area && AREA_POSTCODES[dbStop.area] && AREA_POSTCODES[dbStop.area].length > 0) {
                            return AREA_POSTCODES[dbStop.area][0];
                        }
                    }
                } catch (_) {}
            }
        }
    }

    // 6. Fallback: Active trip stops (Scan backwards)
    if (context && context.activeTrip && Array.isArray(context.activeTrip.remainingStops) && context.activeTrip.remainingStops.length > 0) {
        for (let i = context.activeTrip.remainingStops.length - 1; i >= 0; i--) {
            const stop = context.activeTrip.remainingStops[i];
            const addr = stop.address || stop.place_address || '';
            let pc = extractPostcode(addr);
            if (pc) return pc;
            if (stop.area && AREA_POSTCODES[stop.area] && AREA_POSTCODES[stop.area].length > 0) {
                return AREA_POSTCODES[stop.area][0];
            }
            const stopName = stop.name || stop.placeName || '';
            if (stopName) {
                try {
                    const dbStop = await PlaceNew.findOne({ name: { $regex: stopName, $options: 'i' } }).select('address area').maxTimeMS(800);
                    if (dbStop) {
                        if (dbStop.address) {
                            pc = extractPostcode(dbStop.address);
                            if (pc) return pc;
                        }
                        if (dbStop.area && AREA_POSTCODES[dbStop.area] && AREA_POSTCODES[dbStop.area].length > 0) {
                            return AREA_POSTCODES[dbStop.area][0];
                        }
                    }
                } catch (_) {}
            }
        }
    }

    // 7. Direct context targetPostcode / postcode / targetArea (if explicitly specified in API call)
    if (context) {
        if (context.targetPostcode) {
            const pc = extractPostcode(context.targetPostcode.toString());
            if (pc) return pc;
        }
        if (context.postcode) {
            const pc = extractPostcode(context.postcode.toString());
            if (pc) return pc;
        }
        if (context.targetArea && AREA_POSTCODES[context.targetArea] && AREA_POSTCODES[context.targetArea].length > 0) {
            return AREA_POSTCODES[context.targetArea][0];
        }
        if (context.area && AREA_POSTCODES[context.area] && AREA_POSTCODES[context.area].length > 0) {
            return AREA_POSTCODES[context.area][0];
        }
    }

    // 8. If no postcode directly extracted, but targetArea is known, check AREA_POSTCODES
    const area = resolveTargetArea(text, history, context);
    if (area && AREA_POSTCODES[area] && AREA_POSTCODES[area].length > 0) {
        return AREA_POSTCODES[area][0];
    }

    return null;
}

function getAreaForPostcode(postcode) {
    if (!postcode) return null;
    const cleanPc = postcode.toString().trim();
    for (const [area, pcs] of Object.entries(AREA_POSTCODES)) {
        if (pcs.includes(cleanPc)) return area;
    }
    return null;
}

// 🎯 Strict Consistency Guard: Guarantees Target Postcode and Target Area are fully aligned without conflict
// 规则: 优先根据当前 user input 判断；若缺少，才看回上一个 user input 来执行
function reconcileAreaAndPostcode(targetArea, targetPostcode, text = '', history = []) {
    let resolvedArea = targetArea;
    let resolvedPostcode = targetPostcode;

    // 1. Explicit area in current text always takes precedence as ground truth
    const textAreas = detectMatchedAreas(text);
    if (textAreas.length > 0) {
        resolvedArea = textAreas[0];
        if (AREA_POSTCODES[resolvedArea] && AREA_POSTCODES[resolvedArea].length > 0) {
            resolvedPostcode = AREA_POSTCODES[resolvedArea][0];
        }
        return { targetArea: resolvedArea, targetPostcode: resolvedPostcode };
    }

    // 2. Explicit 5-digit postcode in current text takes precedence
    const textPc = extractPostcode(text);
    if (textPc) {
        resolvedPostcode = textPc;
        resolvedArea = getAreaForPostcode(textPc) || resolvedArea;
        return { targetArea: resolvedArea, targetPostcode: resolvedPostcode };
    }

    // 3. 若当前未提供明确地区或邮编，看回上一个 user input
    if ((!resolvedArea || resolvedArea === 'Penang') && !resolvedPostcode && Array.isArray(history) && history.length > 0) {
        const prevUserInputs = getAllPreviousUserInputs(history);
        for (const prevText of prevUserInputs) {
            const pAreas = detectMatchedAreas(prevText);
            if (pAreas.length > 0) {
                resolvedArea = pAreas[0];
                if (AREA_POSTCODES[resolvedArea] && AREA_POSTCODES[resolvedArea].length > 0) {
                    resolvedPostcode = AREA_POSTCODES[resolvedArea][0];
                }
                break;
            }
            const pPc = extractPostcode(prevText);
            if (pPc) {
                resolvedPostcode = pPc;
                resolvedArea = getAreaForPostcode(pPc) || resolvedArea;
                break;
            }
        }
    }

    // 4. Consistency alignment: if area is specified (not generic Penang) but postcode belongs to another area
    if (resolvedArea && resolvedArea !== 'Penang') {
        const pcArea = getAreaForPostcode(resolvedPostcode);
        if (!resolvedPostcode || (pcArea && pcArea !== resolvedArea)) {
            if (AREA_POSTCODES[resolvedArea] && AREA_POSTCODES[resolvedArea].length > 0) {
                resolvedPostcode = AREA_POSTCODES[resolvedArea][0];
            }
        }
    } else if (resolvedPostcode && (!resolvedArea || resolvedArea === 'Penang')) {
        resolvedArea = getAreaForPostcode(resolvedPostcode) || resolvedArea;
    }

    return { targetArea: resolvedArea, targetPostcode: resolvedPostcode };
}

// 🔍 Helper to format MongoDB Query Filters for clean, readable terminal debugging
function formatMongoFilterForTerminal(filter) {
    if (!filter) return '{}';
    try {
        return JSON.stringify(filter, (key, value) => {
            if (value instanceof RegExp) {
                return value.toString();
            }
            return value;
        }, 2);
    } catch (_) {
        return String(filter);
    }
}

function buildPostcodeQuery(postcode) {
    if (!postcode) return null;
    const cleanPc = postcode.toString().trim();
    if (!/^\d{5}$/.test(cleanPc)) return null;
    const isMainland = /^(12|13|14)/.test(cleanPc);
    const pcRegex = new RegExp(`\\b${cleanPc}\\b`, 'i');
    const pcMatch = {
        $or: [
            { address: pcRegex },
            { place_address: pcRegex }
        ]
    };
    if (!isMainland) {
        return {
            $and: [
                pcMatch,
                MAINLAND_FILTER
            ]
        };
    }
    return pcMatch;
}

function buildAreaQuery(area) {
    if (!area) return MAINLAND_FILTER;
    const norm = area.toLowerCase().trim();
    if (norm === 'penang' || norm === 'penang island' || norm === 'pulau pinang') return MAINLAND_FILTER;

    const areaRegex = new RegExp(area.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    const conflictingAreas = ['Air Itam', 'Ayer Itam', 'Bayan Lepas', 'Batu Ferringhi', 'George Town', 'Teluk Bahang', 'Tanjung Bungah', 'Tanjung Tokong', 'Pulau Tikus'].filter(a => a.toLowerCase() !== norm);

    const areaMatch = {
        $or: [
            { area: areaRegex },
            {
                $and: [
                    { address: areaRegex },
                    { area: { $nin: conflictingAreas } }
                ]
            },
            {
                $and: [
                    { place_address: areaRegex },
                    { area: { $nin: conflictingAreas } }
                ]
            }
        ]
    };
    const isMainlandTarget = norm.includes('bukit mertajam') || norm.includes('butterworth') || norm.includes('seberang');
    if (isMainlandTarget) {
        return areaMatch;
    }
    return {
        $and: [
            areaMatch,
            MAINLAND_FILTER
        ]
    };
}

// 🎯 Safe Area Verification Guard
function isPlaceInTargetArea(place, targetArea) {
    if (!place || !targetArea) return true;
    const targetNorm = targetArea.toLowerCase().trim();
    if (targetNorm === 'penang' || targetNorm === 'penang island' || targetNorm === 'pulau pinang') return true;

    const pArea = (place.area || '').toLowerCase().trim();
    const pAddr = (place.address || place.place_address || '').toLowerCase();
    const pName = (place.name || place.place_name || '').toLowerCase();

    const knownAreas = [
        'balik pulau', 'bayan lepas', 'batu ferringhi', 'george town', 'air itam',
        'ayer itam', 'teluk bahang', 'tanjung bungah', 'tanjung tokong', 'pulau tikus',
        'butterworth', 'bukit mertajam', 'seberang perai', 'perai', 'nibong tebal',
        'kepala batas', 'jelutong', 'gelugor', 'batu maung', 'gurney'
    ];

    // 1. Direct positive area match
    if (pArea) {
        if (pArea === targetNorm || pArea.includes(targetNorm) || targetNorm.includes(pArea)) {
            return true;
        }
        const isAirItamEquiv = (targetNorm === 'air itam' && pArea === 'ayer itam') || (targetNorm === 'ayer itam' && pArea === 'air itam');
        if (isAirItamEquiv) return true;

        if (pArea !== 'penang' && pArea !== 'pulau pinang') {
            const conflictingArea = knownAreas.find(a => {
                if (a === targetNorm) return false;
                if ((targetNorm === 'air itam' || targetNorm === 'ayer itam') && (a === 'air itam' || a === 'ayer itam')) return false;
                return pArea === a || pArea.includes(a);
            });
            if (conflictingArea) {
                return false;
            }
        }
    }

    // 2. Check address and name
    if (pAddr.includes(targetNorm) || pName.includes(targetNorm)) {
        if (targetNorm === 'balik pulau') {
            if (pAddr.includes('11500') || pAddr.includes('air itam') || pAddr.includes('ayer itam')) return false;
            if (pAddr.includes('bayan lepas') && !pAddr.includes('balik pulau')) return false;
            if (pAddr.includes('batu ferringhi')) return false;
        }
        if (targetNorm === 'air itam' || targetNorm === 'ayer itam') {
            if (pAddr.includes('11000') || pAddr.includes('11010') || (pAddr.includes('balik pulau') && !pAddr.includes('11500'))) return false;
        }
        return true;
    }

    // 3. Postcode check if place has a recognized postcode
    const pc = extractPostcode(pAddr);
    if (pc && AREA_POSTCODES[targetArea] && AREA_POSTCODES[targetArea].includes(pc)) {
        if (targetNorm === 'balik pulau' && pAddr.includes('bayan lepas')) {
            return false;
        }
        return true;
    }

    return false;
}

// 🎯 Unified Search for Search Suggestions:
// 1. If target area is known, strictly searches within that area, never leaking into unrelated areas
// 2. If postcode is provided, prioritizes places matching both area and postcode, with safe area fallback
// 3. Query PlaceNew as primary collection, filter out non-place junks & roundabouts
async function searchPlacesWithPostcodeAndAreaFallback({
    queryFilter = {},
    postcode = null,
    targetPostcode = null,
    area = null,
    targetArea = null,
    limit = 30,
    excludedPlaces = new Set(),
    trace = null
}) {
    area = area || targetArea;
    postcode = postcode || targetPostcode;
    // 🛡️ Postcode & Area Consistency Guard inside search execution
    if (area && postcode) {
        const pcArea = getAreaForPostcode(postcode);
        if (pcArea && pcArea !== area && AREA_POSTCODES[area] && AREA_POSTCODES[area].length > 0) {
            postcode = AREA_POSTCODES[area][0];
        }
    }
    if (!area && postcode) {
        area = getAreaForPostcode(postcode);
    }

    async function execQuery(filter, label = '') {
        try {
            const finalFilter = {
                status: 'active',
                name: { $not: JUNK_NAMES_REGEX },
                ...filter
            };

            const formattedFilter = formatMongoFilterForTerminal(finalFilter);
            console.log(`\n\x1b[36m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\x1b[0m`);
            console.log(`\x1b[36m┃ 🔍 [MongoDB places_new Query Filter${label ? ` - ${label}` : ''}]\x1b[0m`);
            console.log(`\x1b[36m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\x1b[0m`);
            console.log(`\x1b[33m${formattedFilter}\x1b[0m`);

            if (trace) {
                trace.mongoQueryFilters = trace.mongoQueryFilters || [];
                trace.mongoQueryFilters.push({ label, filter: finalFilter, formatted: formattedFilter });
            }

            let matches = await PlaceNew.find(finalFilter)
                .sort({ popularity_score: -1, review_count: -1, rating: -1 })
                .limit(limit)
                .maxTimeMS(2500);
            let fresh = matches.filter(p => {
                const pName = p.name || p.place_name || '';
                const inTargetArea = !area || area === 'Penang' || isPlaceInTargetArea(p, area);
                return !JUNK_NAMES_REGEX.test(pName) && !isPlaceExcluded(pName, excludedPlaces) && inTargetArea;
            });
            console.log(`\x1b[32m✔ [MongoDB Result${label ? ` - ${label}` : ''}]: Found ${matches.length} records (${fresh.length} fresh after exclusions & area guard)\x1b[0m\n`);
            return fresh;
        } catch (err) {
            console.warn('execQuery error in search suggestion:', err.message);
            return [];
        }
    }

    // Case A: Specific Area is Targeted (e.g. Balik Pulau, Bayan Lepas, Batu Ferringhi, Air Itam)
    if (area && area !== 'Penang' && area !== 'Penang Island' && area !== 'Pulau Pinang') {
        const areaQuery = buildAreaQuery(area);
        let freshMatches = [];

        // 1. Try exact area + specific postcode (if postcode provided)
        if (postcode) {
            const pcQuery = buildPostcodeQuery(postcode);
            if (pcQuery) {
                const fullPcQuery = Object.keys(queryFilter).length > 0
                    ? { $and: [queryFilter, areaQuery, pcQuery] }
                    : { $and: [areaQuery, pcQuery] };
                freshMatches = await execQuery(fullPcQuery, `${area} (Postcode: ${postcode})`);
                if (freshMatches.length >= 2) return freshMatches;
            }
        }

        // 2. Search across entire target area (covering all postcodes of the area)
        const fullAreaQuery = Object.keys(queryFilter).length > 0
            ? { $and: [queryFilter, areaQuery] }
            : areaQuery;
        const areaMatches = await execQuery(fullAreaQuery, `Area: ${area}`);
        for (const am of areaMatches) {
            if (!freshMatches.some(fm => (fm.name || fm.place_name) === (am.name || am.place_name))) {
                freshMatches.push(am);
                if (freshMatches.length >= 2) break;
            }
        }
        if (freshMatches.length >= 2) return freshMatches;

        // 3. Broader category search within target area
        const attractionCats = [
            'Heritage & Culture', 'Nature & Parks', 'Religious Sites',
            'Arts & Workshops', 'Family & Adventure', 'Food & Dining', 'Cafes', 'Shopping & Markets'
        ];
        const broadAreaFilter = {
            $and: [
                {
                    $or: [
                        { primary_category: { $in: attractionCats } },
                        { sub_categories: { $in: attractionCats } }
                    ]
                },
                areaQuery
            ]
        };
        const broadMatches = await execQuery(broadAreaFilter, `${area} (Top Attractions)`);
        for (const bm of broadMatches) {
            if (!freshMatches.some(fm => (fm.name || fm.place_name) === (bm.name || bm.place_name))) {
                freshMatches.push(bm);
                if (freshMatches.length >= 2) break;
            }
        }
        if (freshMatches.length >= 2) return freshMatches;

        // 4. Strict Curated Fallback for THIS area
        const curated = getAreaCuratedPair(area, excludedPlaces);
        for (const c of curated) {
            if (!freshMatches.some(fm => (fm.name || fm.place_name) === (c.name || c.place_name))) {
                freshMatches.push(c);
                if (freshMatches.length >= 2) break;
            }
        }
        if (freshMatches.length > 0) return freshMatches;
    }

    // Case B: General Query (No specific area requested, or Island-wide)
    if (postcode) {
        const pcQuery = buildPostcodeQuery(postcode);
        if (pcQuery) {
            const fullPcQuery = Object.keys(queryFilter).length > 0
                ? { $and: [queryFilter, pcQuery] }
                : pcQuery;
            const freshPc = await execQuery(fullPcQuery, `Postcode: ${postcode}`);
            if (freshPc.length >= 2) return freshPc;
            if (freshPc.length === 1) return freshPc;
        }
    }

    const fallbackQuery = Object.keys(queryFilter).length > 0
        ? { $and: [queryFilter, MAINLAND_FILTER] }
        : MAINLAND_FILTER;
    const generalMatches = await execQuery(fallbackQuery, 'General Island Fallback');
    return generalMatches;
}

function extractArea(place) {
    if (!place) return 'Penang';
    if (place.area && typeof place.area === 'string' && place.area.trim().length > 0 && place.area !== 'Penang' && place.area !== 'Pulau Pinang') {
        return place.area.trim();
    }
    const addr = (place.place_address || place.address || place.description || '').toLowerCase();
    const name = (place.place_name || place.name || place.placeName || '').toLowerCase();
    const full = `${name} ${addr}`;

    // 1. Specific landmarks and postcodes for outer regions (MUST precede generic "George Town")
    if (full.includes('air itam') || full.includes('ayer itam') || full.includes('kek lok si') || full.includes('penang hill') || full.includes('bukit bendera') || full.includes('11500') || full.includes('亚依淡') || full.includes('升旗山') || full.includes('极乐寺') || (name.includes('dam') && full.includes('balik pulau'))) {
        return 'Air Itam';
    }
    if (full.includes('teluk bahang') || full.includes('taman negara') || full.includes('national park') || full.includes('escape') || full.includes('entopia') || full.includes('tropical spice') || full.includes('11050') || full.includes('直落巴巷')) {
        return 'Teluk Bahang';
    }
    if (full.includes('batu ferringhi') || full.includes('batu feringghi') || full.includes('11100') || full.includes('峇都丁宜')) {
        return 'Batu Ferringhi';
    }
    if (full.includes('balik pulau') || full.includes('audi dream') || full.includes('saanen') || full.includes('bao sheng') || full.includes('countryside stables') || full.includes('spedahub') || full.includes('karuna hill') || full.includes('kim laksa') || full.includes('ghee hup') || full.includes('11010') || full.includes('11020') || full.includes('浮罗山背') || (full.includes('11000') && !full.includes('bayan lepas'))) {
        return 'Balik Pulau';
    }
    if (full.includes('bayan lepas') || full.includes('bayan baru') || full.includes('snake temple') || full.includes('spice') || full.includes('11900') || full.includes('11950') || full.includes('峇六拜') || full.includes('teluk kumbar') || full.includes('gertak sanggul')) {
        return 'Bayan Lepas';
    }
    if (full.includes('tanjung bungah') || full.includes('floating mosque') || full.includes('11200') || full.includes('丹绒武雅')) {
        return 'Tanjung Bungah';
    }
    if (full.includes('tanjung tokong') || full.includes('straits quay') || full.includes('丹绒道光')) {
        return 'Tanjung Tokong';
    }
    if (full.includes('pulau tikus') || full.includes('chayamangkalaram') || full.includes('dhammikarama') || full.includes('taman belia') || full.includes('taman bandar')) {
        return 'Pulau Tikus';
    }
    if (full.includes('gurney drive') || full.includes('gurney plaza') || full.includes('gurney bay') || full.includes('新关仔角')) {
        return 'Gurney';
    }
    if (full.includes('butterworth') || full.includes('12000') || full.includes('13000') || full.includes('北海')) {
        return 'Butterworth';
    }
    if (full.includes('bukit mertajam') || full.includes('14000') || full.includes('大山脚')) {
        return 'Bukit Mertajam';
    }
    if (full.includes('seberang perai') || full.includes('seberang jaya') || full.includes('nibong tebal') || full.includes('kepala batas')) {
        return 'Seberang Perai';
    }
    if (full.includes('jelutong') || full.includes('11600')) {
        return 'Jelutong';
    }
    if (full.includes('gelugor') || full.includes('11700')) {
        return 'Gelugor';
    }

    // 2. George Town (inner city postcodes 10000 - 10450 or explicit street names)
    if (full.includes('george town') || full.includes('georgetown') || full.includes('乔治市') ||
        /\b10[0-4]\d{2}\b/.test(addr) ||
        full.includes('leith') || full.includes('chulia') || full.includes('armenian') || full.includes('beach st') || full.includes('penang rd') || full.includes('weld quay') || full.includes('love lane')) {
        return 'George Town';
    }

    return 'Penang';
}

// Helper: Clean raw extracted option string and separate place name from description
function cleanOptionCandidate(str) {
    if (!str || typeof str !== 'string') return null;
    let clean = str.trim();

    // 1. Separate place name from trailing descriptions or explanations
    // Stops at: " - ", " – ", " — ", " : ", " ： ", " for ", " to ", " offers ", " features ", " where ", " is a ", "。", "，", or newline
    const sepMatch = clean.match(/^(.*?)(?:\s+[-–—]{1,2}\s+|\s*[:：]\s+|\s+(?:for|to|offers?|features?|where|is\s+a|is\s+the|is)\s+|[。，\r\n])/i);
    if (sepMatch && sepMatch[1] && sepMatch[1].trim().length > 1) {
        clean = sepMatch[1].trim();
    }

    // 2. Strip leading actions, markdown tags, quotes, trailing dots/commas
    clean = clean
        .replace(/^(?:add|visit|choose|pick)\s+/i, '')
        .replace(/[\*\_\[\]"]/g, '')
        .replace(/[,\.，。]$/, '')
        .trim();

    if (isSystemAction(clean)) return null;
    return clean.length >= 2 ? clean : null;
}

// 3.5 Extract Option A & Option B Place Names from Markdown Text
function extractOptionsFromText(text) {
    if (!text || typeof text !== 'string') return { optionA: null, optionB: null, rawA: null, rawB: null };
    
    let optionA = null;
    let optionB = null;
    let rawA = null;
    let rawB = null;

    const optAPatterns = [
        /###\s*\[?Option\s*A\]?\s*[:：]\s*([^\n\r#\。]+)/i,
        /###\s*\[?Option\s*1\]?\s*[:：]\s*([^\n\r#\。]+)/i,
        /\*\*\[?Option\s*A\]?\s*[:：]\*\*\s*([^\n\r\。]+)/i,
        /\*\*\[?Option\s*1\]?\s*[:：]\*\*\s*([^\n\r\。]+)/i,
        /\[Option\s*A\]\s*[:：]\s*([^\n\r\。]+)/i,
        /\[Option\s*1\]\s*[:：]\s*([^\n\r\。]+)/i,
        /Option\s*A\s*[:：]\s*([^\n\r\。]+)/i,
        /Option\s*1\s*[:：]\s*([^\n\r\。]+)/i,
        /Option\s*A\s*is\s*(?:the\s*)?([^\n\r\。]+)/i
    ];

    const optBPatterns = [
        /###\s*\[?Option\s*B\]?\s*[:：]\s*([^\n\r#\。]+)/i,
        /###\s*\[?Option\s*2\]?\s*[:：]\s*([^\n\r#\。]+)/i,
        /\*\*\[?Option\s*B\]?\s*[:：]\*\*\s*([^\n\r\。]+)/i,
        /\*\*\[?Option\s*2\]?\s*[:：]\*\*\s*([^\n\r\。]+)/i,
        /\[Option\s*B\]\s*[:：]\s*([^\n\r\。]+)/i,
        /\[Option\s*2\]\s*[:：]\s*([^\n\r\。]+)/i,
        /Option\s*B\s*[:：]\s*([^\n\r\。]+)/i,
        /Option\s*2\s*[:：]\s*([^\n\r\。]+)/i,
        /Option\s*B\s*is\s*(?:the\s*)?([^\n\r\。]+)/i
    ];

    for (const pat of optAPatterns) {
        const match = text.match(pat);
        if (match && match[1]) {
            rawA = match[1].trim();
            optionA = cleanOptionCandidate(match[1]);
            if (optionA) break;
        }
    }

    for (const pat of optBPatterns) {
        const match = text.match(pat);
        if (match && match[1]) {
            rawB = match[1].trim();
            optionB = cleanOptionCandidate(match[1]);
            if (optionB) break;
        }
    }

    return { optionA, optionB, rawA, rawB };
}

// Helper: Strip conflicting date/weather prompts when presenting spot options
function stripPrematureDateAndWeatherPrompts(text) {
    if (!text || typeof text !== 'string') return text;
    let res = text
        .replace(/(?:To\s+activate\s+(?:my\s+|our\s+)?Weather\s+Guard[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:(?:To\s+get|For)\s+the\s+perfect\s+timing[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:I\s+(?:just\s+)?need\s+your\s+travel\s+dates[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:Please\s+(?:provide|select|lock\s+in)\s+your\s+travel\s+dates[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:为了激活(?:我的|我们的)?(?:Weather\s+Guard|天气防护)[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:我只需要你的出行日期[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:请提供你的出行日期[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/(?:锁定出行日期以激活[^.!?\n]*[.!?\n]*)/gi, '')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
    return res;
}

// 3.6 Ensure Both Option A & Option B Place Names and Descriptions are Present in Chat Bubble Message
function ensureBothOptionsInMessage(cleanMessage, p1, p2) {
    if (!cleanMessage || !p1 || !p2) return cleanMessage;

    const p1Name = (p1.name || p1.place_name || '').trim();
    const p2Name = (p2.name || p2.place_name || '').trim();
    if (!p1Name || !p2Name) return cleanMessage;

    const p1Desc = p1.description || 'Historic and cultural landmark nearby to explore';
    const p2Desc = p2.description || 'Great spot nearby to explore';

    const p1Lower = p1Name.toLowerCase();
    const p2Lower = p2Name.toLowerCase();
    const msgLower = cleanMessage.toLowerCase();

    // Check if the expected places p1 and p2 are actually mentioned in the message
    const hasP1Name = p1Lower.length > 2 && msgLower.includes(p1Lower);
    const hasP2Name = p2Lower.length > 2 && msgLower.includes(p2Lower);

    // If both correct place names are already mentioned in the message, sanitize and keep it!
    if (hasP1Name && hasP2Name) {
        return stripPrematureDateAndWeatherPrompts(cleanMessage);
    }

    // Check if the message contains explicit option headers
    const hasExplicitOptionA = /\[?Option\s*(?:A|1)\]?/i.test(cleanMessage);
    const hasExplicitOptionB = /\[?Option\s*(?:B|2)\]?/i.test(cleanMessage);

    if (hasExplicitOptionA || hasExplicitOptionB) {
        // Model outputted Option headers, but with wrong/out-of-area place names!
        // Keep the introductory text before the first Option tag and inject the verified grounded places
        const firstOptIndex = cleanMessage.search(/(?:###\s*)?\[?Option\s*(?:A|1)\]?/i);
        let introText = cleanMessage;
        if (firstOptIndex !== -1) {
            introText = cleanMessage.slice(0, firstOptIndex).trim();
        }
        introText = stripPrematureDateAndWeatherPrompts(introText);
        if (!introText || introText.length < 5) {
            introText = "Jom explore! Here are two recommended spots for you:";
        }
        return `${introText}\n\n[Option A]: **${p1Name}** - ${p1Desc}\n\n[Option B]: **${p2Name}** - ${p2Desc}\n\nWhich of these two options would you prefer? 🦜`;
    }

    // Neither Option A nor Option B is labeled in message
    const sanitizedBase = stripPrematureDateAndWeatherPrompts(cleanMessage);
    return sanitizedBase.trim() + 
        `\n\n[Option A]: **${p1Name}** - ${p1Desc}\n\n[Option B]: **${p2Name}** - ${p2Desc}\n\nWhich of these two options would you prefer? 🦜`;
}

// 3.7 Hydrate or Synthesize Places from Quick Replies when structured places are missing
async function hydratePlacesFromQuickReplies(rawQuickReplies, existingPlaces = [], activeArea = 'George Town') {
    if (!Array.isArray(rawQuickReplies) || rawQuickReplies.length < 2) return existingPlaces;
    const rawNameA = rawQuickReplies[0].replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*/i, '').trim();
    const rawNameB = rawQuickReplies[1].replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*/i, '').trim();
    if (!rawNameA || !rawNameB) return existingPlaces;

    const names = [rawNameA, rawNameB];
    const defaultCoords = getAreaDefaultCoordinates(activeArea);
    const result = [];

    for (let i = 0; i < 2; i++) {
        const name = names[i];
        if (isSystemAction(name)) continue;
        let matched = (existingPlaces || []).find(p => (p.name || p.place_name || '').toLowerCase() === name.toLowerCase());
        if (!matched) {
            matched = await resolvePlaceByName(name, activeArea);
        }
        if (matched && activeArea && activeArea !== 'Penang') {
            const mArea = normalizeAreaName(matched.area || extractArea(matched));
            if (mArea && mArea !== 'Penang' && mArea.toLowerCase() !== activeArea.toLowerCase()) {
                console.warn(`[AREA FILTER] hydratePlacesFromQuickReplies rejected ${matched.name} (${mArea}) for activeArea ${activeArea}`);
                matched = null;
            }
        }
        if (!matched) {
            matched = {
                id: `sug_${Date.now()}_${i}`,
                name: name,
                area: activeArea,
                category: 'Attraction',
                description: `${name} in ${activeArea}, Penang.`,
                lat: defaultCoords.lat,
                lng: defaultCoords.lng
            };
        }
        result.push(matched);
    }
    return result;
}

const GENERIC_EXCLUDE_WORDS = new Set([
    'penang', 'cafe', 'coffee', 'food', 'restaurant', 'beach', 'hotel', 'park',
    'market', 'stall', 'centre', 'center', 'shop', 'road', 'street', 'lorong',
    'jalan', 'pulau', 'george', 'town', 'bayan', 'lepas', 'malaysia', 'the',
    'pasar', 'malam', 'hill', 'heritage', 'temple', 'museum'
]);

function normalizePlaceNameForComparison(name) {
    if (!name || typeof name !== 'string') return '';
    return name
        .toLowerCase()
        // remove text in parentheses e.g. (PICAF), (Penang)
        .replace(/\([^)]*\)/g, ' ')
        // replace punctuation like - / , : . with spaces
        .replace(/[,\-_/:|•·]/g, ' ')
        // collapse spaces
        .replace(/\s+/g, ' ')
        .trim();
}

function getBasePlaceName(name) {
    if (!name || typeof name !== 'string') return '';
    const base = name.split(/\s*[-–—|@,]\s*/)[0];
    return normalizePlaceNameForComparison(base);
}

function addPlaceToExcluded(set, rawName) {
    if (!rawName || typeof rawName !== 'string') return;
    const lower = rawName.toLowerCase().trim();
    if (lower.length >= 2) {
        set.add(lower);
    }
    const norm = normalizePlaceNameForComparison(rawName);
    if (norm && norm.length >= 2) {
        set.add(norm);
    }
    const base = getBasePlaceName(rawName);
    if (base && base.length >= 3 && !GENERIC_EXCLUDE_WORDS.has(base)) {
        set.add(base);
    }
}

// Extract only draft plan and active trip place names from context
function extractDraftPlanPlaceNames(context = {}) {
    const draftNames = new Set();
    if (!context || typeof context !== 'object') return draftNames;

    const stopSources = [];
    if (Array.isArray(context.draftPlan?.stops)) stopSources.push(context.draftPlan.stops);
    if (Array.isArray(context.draftPlan)) stopSources.push(context.draftPlan);
    if (Array.isArray(context.draftItinerary)) stopSources.push(context.draftItinerary);
    if (Array.isArray(context.stops)) stopSources.push(context.stops);
    if (Array.isArray(context.activeTrip?.remainingStops)) stopSources.push(context.activeTrip.remainingStops);
    if (Array.isArray(context.activeTrip?.stops)) stopSources.push(context.activeTrip.stops);
    if (Array.isArray(context.timeline)) stopSources.push(context.timeline);

    for (const source of stopSources) {
        for (const item of source) {
            const rawName = typeof item === 'string' ? item : (item.placeName || item.name || item.place_name || item.title || '');
            if (rawName) {
                addPlaceToExcluded(draftNames, rawName);
            }
        }
    }

    if (Array.isArray(context.excludedPlaces)) {
        context.excludedPlaces.forEach(ep => addPlaceToExcluded(draftNames, ep));
    } else if (context.excludedPlaces instanceof Set) {
        context.excludedPlaces.forEach(ep => addPlaceToExcluded(draftNames, ep));
    }

    return draftNames;
}

// Helper: Check if place is in user's draft plan
function isPlaceInDraftPlan(placeName, context = {}) {
    if (!placeName) return false;
    const draftSet = extractDraftPlanPlaceNames(context);
    return isPlaceExcluded(placeName, draftSet);
}

// Helper: Check if place is excluded by exact match, base match, or substantial substring
function isPlaceExcluded(placeName, excludedSet) {
    if (!placeName || !excludedSet || excludedSet.size === 0) return false;
    const lower = placeName.toLowerCase().trim();
    if (excludedSet.has(lower)) return true;

    const normCandidate = normalizePlaceNameForComparison(placeName);
    if (normCandidate && excludedSet.has(normCandidate)) return true;

    const baseCandidate = getBasePlaceName(placeName);
    if (baseCandidate && baseCandidate.length > 3 && !GENERIC_EXCLUDE_WORDS.has(baseCandidate)) {
        if (excludedSet.has(baseCandidate)) return true;
    }

    for (const ex of excludedSet) {
        if (!ex || typeof ex !== 'string') continue;
        const normEx = normalizePlaceNameForComparison(ex);
        if (!normEx || normEx.length <= 3) continue;
        if (GENERIC_EXCLUDE_WORDS.has(normEx)) continue;

        // Substring check
        if (normCandidate && (normCandidate.includes(normEx) || normEx.includes(normCandidate))) {
            return true;
        }

        // Base candidate check against normEx
        if (baseCandidate && baseCandidate.length > 4 && (normEx.includes(baseCandidate) || baseCandidate.includes(normEx))) {
            return true;
        }

        // Substantial token overlap: check if non-generic words match
        const candTokens = normCandidate.split(' ').filter(t => t.length > 3 && !GENERIC_EXCLUDE_WORDS.has(t));
        const exTokens = normEx.split(' ').filter(t => t.length > 3 && !GENERIC_EXCLUDE_WORDS.has(t));
        if (candTokens.length >= 2 && exTokens.length >= 2) {
            const overlap = candTokens.filter(t => exTokens.includes(t));
            if (overlap.length >= 2 && overlap.length >= Math.min(candTokens.length, exTokens.length) * 0.7) {
                return true;
            }
        }
    }

    return false;
}

// Extract previously suggested and added place names from conversation history and draft plan
function extractHistoryMentionedPlaces(history = [], context = {}) {
    const mentioned = new Set();

    // 1. Ingest all draft plan & active trip stops first
    const draftStops = extractDraftPlanPlaceNames(context);
    draftStops.forEach(s => mentioned.add(s));

    // 2. History extraction
    if (Array.isArray(history)) {
        history.forEach(h => {
            const text = h.content || h.text || '';
            if (text) {
                const opts = extractOptionsFromText(text);
                if (opts.optionA) addPlaceToExcluded(mentioned, opts.optionA);
                if (opts.optionB) addPlaceToExcluded(mentioned, opts.optionB);

                const boldMatches = text.match(/\*\*([^*]+)\*\*/g);
                if (boldMatches) {
                    boldMatches.forEach(b => {
                        const clean = b.replace(/\*\*/g, '').trim();
                        if (clean.length > 2) addPlaceToExcluded(mentioned, clean);
                    });
                }
            }

            if (Array.isArray(h.quickReplies)) {
                h.quickReplies.forEach(qr => {
                    const clean = qr.replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*/i, '').trim();
                    if (clean.length > 2) addPlaceToExcluded(mentioned, clean);
                });
            }

            if (Array.isArray(h.suggestedPlaces)) {
                h.suggestedPlaces.forEach(p => {
                    const name = (p.name || p.placeName || '').trim();
                    if (name.length > 2) addPlaceToExcluded(mentioned, name);
                });
            }
        });
    }

    return mentioned;
}

// Helper: Check if query contains proximity terms ('nearby', 'near', 'around', '附近', etc.)
function containsNearbyTerms(text) {
    if (!text || typeof text !== 'string') return false;
    const lower = text.toLowerCase().trim();
    const englishProximity = /\b(?:nearby|near\s*by|near\s+here|around\s+here|close\s+by|close\s+to\s+here|in\s+the\s+vicinity|around|near|vicinity)\b/i.test(lower);
    const chineseProximity = /(?:附近|周边|周围|这附近|这周边|就近)/.test(lower);
    return englishProximity || chineseProximity;
}

const GENERIC_ANCHOR_TERMS = new Set([
    'food', 'foods', 'eat', 'eating', 'makan', 'places', 'place', 'spot', 'spots', 'attraction', 'attractions',
    'cafe', 'cafes', 'coffee', 'kopi', 'drink', 'drinks', 'restaurant', 'restaurants', 'hawker', 'stall', 'stalls',
    'things to do', 'thing to do', 'what to do', 'what to see', 'what to visit', 'to visit', 'to see', 'to eat',
    'anything', 'something', 'good', 'best', 'here', 'there', 'me', 'us', 'i', 'we', 'you',
    'what', 'what is', 'what are', 'where', 'which', 'recommend', 'recommendation', 'suggest', 'suggestion',
    'option', 'options', 'visit', 'see', 'go', 'penang', 'malaysia', 'island', 'travel', 'trip',
    '好吃的', '好吃', '美食', '好玩', '好玩的', '景点', '地方', '去处', '好去处', '咖啡', '咖啡厅', '咖啡馆',
    '餐厅', '餐馆', '小吃', '排档', '小贩中心', '这里', '这', '那', '推荐', '介绍', '有什么', '吃什么', '玩什么'
]);

// 4. Smart Place Retrieval from MongoDB with Multi-Turn Context & Exclusions
async function findRelevantPlaces(text, history = [], context = {}, trace = null) {
    try {
        if (!mongoose.connection || mongoose.connection.readyState !== 1) {
            return [];
        }

        const lowerText = text.toLowerCase().trim();
        const isOtherSuggestion = lowerText.includes('other') ||
            lowerText.includes('another') ||
            lowerText.includes('more') ||
            lowerText.includes('different') ||
            lowerText.includes('else') ||
            lowerText.includes('alternat') ||
            lowerText.includes('other suggestion');

        // Collect search terms from current message + previous user inputs only (never assistant responses!)
        let searchCorpus = text;
        const prevUserInputs = getAllPreviousUserInputs(history);
        const recentUserTexts = prevUserInputs.slice(0, 3).join(' ');
        if (recentUserTexts) {
            searchCorpus = `${text} ${recentUserTexts}`;
        }
        const lowerCorpus = searchCorpus.toLowerCase();

        // 🎯 1. Resolve Target Postcode (5-digit) & Target Area
        let targetPostcode = await resolveTargetPostcode(text, history, context);
        let targetArea = resolveTargetArea(text, history, context);
        const reconciled = reconcileAreaAndPostcode(targetArea, targetPostcode, text, history);
        targetArea = reconciled.targetArea;
        targetPostcode = reconciled.targetPostcode;

        if (trace) {
            trace.targetArea = targetArea;
            trace.targetPostcode = targetPostcode;
        }

        let matchedAreas = targetArea ? [targetArea] : [];
        const detectedTextAreas = detectMatchedAreas(text);
        if (detectedTextAreas.length >= 2) {
            matchedAreas = detectedTextAreas;
        } else if (matchedAreas.length === 0) {
            for (const prevUser of prevUserInputs) {
                const prevAreas = detectMatchedAreas(prevUser);
                if (prevAreas.length > 0) {
                    matchedAreas = prevAreas;
                    break;
                }
            }
        }

        let matchedCategories = resolveTargetCategory(text, history);
        let keywords = resolveTargetKeywords(text, history);

        // Collect previously mentioned/added places to exclude for fresh recommendations
        const excludedPlaces = extractHistoryMentionedPlaces(history, context);

        // CASE 0.0: USER EXPRESSED DESIRE TO VISIT A SPECIFIC PLACE (e.g. "I want to visit Kek Lok Si", "wanna go to Entopia", "我想去升旗山")
        // Rule: DO NOT directly add to plan! Provide requested spot as Option A, and a complementary spot nearby as Option B so user can add it themselves!
        const spotDesire = detectExpressedSpotDesire(text);
        if (spotDesire) {
            let requestedPlace = await resolvePlaceByName(spotDesire, targetArea, trace);
            if (requestedPlace && !isSystemAction(requestedPlace.name)) {
                const requestedArea = extractArea(requestedPlace) || targetArea || 'Penang';
                const areaComplements = getAreaCuratedPair(requestedArea, excludedPlaces);
                const reqNameLower = (requestedPlace.name || requestedPlace.place_name || '').toLowerCase().trim();
                const optionB = areaComplements.find(c => {
                    const cName = (c.name || c.place_name || '').toLowerCase().trim();
                    return cName && cName !== reqNameLower && !isPlaceExcluded(cName, excludedPlaces);
                });

                if (optionB) {
                    return [requestedPlace, optionB];
                }
                return [requestedPlace];
            }
        }

        // CASE 0: NEARBY PLACES QUERY
        // Handles both:
        // A) Explicit named anchor (e.g. "places near Entopia", "food around Kek Lok Si")
        // B) Relative nearby query (e.g. "nearby", "food nearby", "what is nearby", "spots nearby", "附近有什么好吃的", "附近的咖啡馆")
        //    -> STRICTLY retrieves from target postcode/area in the history turns (context) / chat history!
        const isNearby = containsNearbyTerms(text);

        if (isNearby) {
            let anchorPlace = null;
            let knownAnchor = null;
            let rawAnchor = null;

            // Check if user explicitly mentioned a specific named anchor place
            const anchorMatch = text.match(/(?:any\s+)?(?:places?|spots?|attractions?|food|things?\s+to\s+do)?\s*(?:nearby|near|around|close\s+to)\s+([a-zA-Z0-9\s'&-]+)/i) ||
                                text.match(/([a-zA-Z0-9\s'&-]+)\s+(?:nearby|near\s*by|around)/i);

            if (anchorMatch && anchorMatch[1]) {
                const candAnchor = anchorMatch[1].replace(/[?!.,]/g, '').trim().replace(/\s+(?:please|lah|lor|can\s+recommend)$/i, '').trim();
                const candLower = candAnchor.toLowerCase();

                if (candLower.length > 2 && !GENERIC_ANCHOR_TERMS.has(candLower)) {
                    knownAnchor = KNOWN_PENANG_FACTS.find(k => k.aliases.some(a => a.toLowerCase() === candLower || candLower.includes(a.toLowerCase())));
                    const cleanAnchor = (knownAnchor ? knownAnchor.name : candAnchor).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

                    anchorPlace = await PlaceNew.findOne({
                        status: 'active',
                        $or: [
                            { name: { $regex: cleanAnchor, $options: 'i' } },
                            { summary: { $regex: cleanAnchor, $options: 'i' } }
                        ]
                    }).maxTimeMS(1500);

                    if (anchorPlace || knownAnchor) {
                        rawAnchor = candAnchor;
                    }
                }
            }

            if (anchorPlace || knownAnchor) {
                // A) Explicit anchor POI search
                const anchorArea = anchorPlace ? (anchorPlace.area || extractArea(anchorPlace)) : (knownAnchor.address ? extractArea({ address: knownAnchor.address }) : 'Teluk Bahang');
                const nearbyExcluded = new Set(excludedPlaces);
                if (anchorPlace) nearbyExcluded.add(anchorPlace.name.toLowerCase().trim());
                if (knownAnchor) nearbyExcluded.add(knownAnchor.name.toLowerCase().trim());
                if (rawAnchor) nearbyExcluded.add(rawAnchor.toLowerCase().trim());

                let anchorPostcode = null;
                if (anchorPlace && anchorPlace.address) {
                    anchorPostcode = extractPostcode(anchorPlace.address);
                } else if (knownAnchor && knownAnchor.address) {
                    anchorPostcode = extractPostcode(knownAnchor.address);
                }

                let nearbyCatFilter = null;
                const mapped = mapCategoryToMongo(matchedCategories, keywords);
                if (mapped.primaryCategories.length > 0) {
                    nearbyCatFilter = {
                        $or: [
                            { primary_category: { $in: mapped.primaryCategories } },
                            { sub_categories: { $in: mapped.primaryCategories } }
                        ]
                    };
                } else {
                    const defaultNearbyCats = [
                        'Heritage & Culture', 'Nature & Parks', 'Religious Sites',
                        'Arts & Workshops', 'Family & Adventure', 'Food & Dining', 'Cafes', 'Shopping & Markets'
                    ];
                    nearbyCatFilter = {
                        $or: [
                            { primary_category: { $in: defaultNearbyCats } },
                            { sub_categories: { $in: defaultNearbyCats } }
                        ]
                    };
                }

                const nearbyPlaces = await searchPlacesWithPostcodeAndAreaFallback({
                    queryFilter: nearbyCatFilter,
                    postcode: anchorPostcode,
                    area: anchorArea,
                    limit: 30,
                    excludedPlaces: nearbyExcluded,
                    trace
                });

                if (nearbyPlaces.length >= 2) return nearbyPlaces.slice(0, 2);
                if (nearbyPlaces.length === 1) {
                    const curated = getAreaCuratedPair(anchorArea, nearbyExcluded);
                    const extraCurated = curated.find(c => c.name.toLowerCase() !== (nearbyPlaces[0].name || '').toLowerCase());
                    if (extraCurated) return [nearbyPlaces[0], extraCurated];
                    return [nearbyPlaces[0]];
                }
            } else {
                // B) Relative nearby query without anchor POI (e.g. "any food nearby", "what is nearby", "spots nearby", "cafes nearby")
                // -> STRICTLY RETRIEVE FROM TARGET POSTCODE / AREA IN THE HISTORY TURNS (CONTEXT) / CHAT HISTORY!
                const nearbyArea = targetArea || (targetPostcode ? getAreaForPostcode(targetPostcode) : null) || 'George Town';
                const nearbyPostcode = targetPostcode || (nearbyArea && AREA_POSTCODES[nearbyArea] ? AREA_POSTCODES[nearbyArea][0] : null);

                let nearbyCatFilter = null;
                const mapped = mapCategoryToMongo(matchedCategories, keywords);
                if (mapped.primaryCategories.length > 0) {
                    nearbyCatFilter = {
                        $or: [
                            { primary_category: { $in: mapped.primaryCategories } },
                            { sub_categories: { $in: mapped.primaryCategories } }
                        ]
                    };
                } else if (keywords.length > 0) {
                    const kwPattern = keywords.join('|');
                    nearbyCatFilter = {
                        $or: [
                            { name: { $regex: kwPattern, $options: 'i' } },
                            { summary: { $regex: kwPattern, $options: 'i' } },
                            { search_keywords: { $in: keywords } }
                        ]
                    };
                } else {
                    const defaultNearbyCats = [
                        'Heritage & Culture', 'Nature & Parks', 'Religious Sites',
                        'Arts & Workshops', 'Family & Adventure', 'Food & Dining', 'Cafes', 'Shopping & Markets'
                    ];
                    nearbyCatFilter = {
                        $or: [
                            { primary_category: { $in: defaultNearbyCats } },
                            { sub_categories: { $in: defaultNearbyCats } }
                        ]
                    };
                }

                const nearbyPlaces = await searchPlacesWithPostcodeAndAreaFallback({
                    queryFilter: nearbyCatFilter,
                    postcode: nearbyPostcode,
                    area: nearbyArea,
                    limit: 30,
                    excludedPlaces,
                    trace
                });

                if (nearbyPlaces.length >= 2) return nearbyPlaces.slice(0, 2);
                if (nearbyPlaces.length === 1) {
                    const curated = getAreaCuratedPair(nearbyArea, excludedPlaces);
                    const extraCurated = curated.find(c => c.name.toLowerCase() !== (nearbyPlaces[0].name || '').toLowerCase());
                    if (extraCurated) return [nearbyPlaces[0], extraCurated];
                    return [nearbyPlaces[0]];
                }
                if (nearbyArea) {
                    const curated = getAreaCuratedPair(nearbyArea, excludedPlaces);
                    if (curated.length >= 2) return curated.slice(0, 2);
                }
            }
        }

        // CASE 1: MULTI-AREA COMPARISON (e.g. "Bayan Lepas or Balik Pulau", "George Town vs Batu Ferringhi")
        if (matchedAreas.length >= 2 && !isOtherSuggestion) {
            const area1 = matchedAreas[0];
            const area2 = matchedAreas[1];
            const pc1 = AREA_POSTCODES[area1] ? AREA_POSTCODES[area1][0] : null;
            const pc2 = AREA_POSTCODES[area2] ? AREA_POSTCODES[area2][0] : null;

            const places1 = await searchPlacesWithPostcodeAndAreaFallback({
                postcode: pc1,
                area: area1,
                limit: 10,
                excludedPlaces,
                trace
            });
            const places2 = await searchPlacesWithPostcodeAndAreaFallback({
                postcode: pc2,
                area: area2,
                limit: 10,
                excludedPlaces,
                trace
            });

            const place1 = places1.find(p => !isPlaceExcluded(p.place_name, excludedPlaces)) || places1[0];
            const place2 = places2.find(p => !isPlaceExcluded(p.place_name, excludedPlaces)) || places2[0];

            const results = [];
            if (place1) results.push(place1);
            if (place2) results.push(place2);
            if (results.length > 0) return results;
        }

        // CASE 2: MULTI-CATEGORY COMPARISON (e.g. "beaches or museums")
        if (matchedCategories.length >= 2 && matchedAreas.length <= 1 && !isOtherSuggestion) {
            const cat1 = matchedCategories[0];
            const cat2 = matchedCategories[1];

            const places1 = await searchPlacesWithPostcodeAndAreaFallback({
                queryFilter: { place_category: { $regex: cat1, $options: 'i' } },
                postcode: targetPostcode,
                area: targetArea,
                limit: 10,
                excludedPlaces,
                trace
            });
            const places2 = await searchPlacesWithPostcodeAndAreaFallback({
                queryFilter: { place_category: { $regex: cat2, $options: 'i' } },
                postcode: targetPostcode,
                area: targetArea,
                limit: 10,
                excludedPlaces,
                trace
            });

            const place1 = places1.find(p => !isPlaceExcluded(p.place_name, excludedPlaces)) || places1[0];
            const place2 = places2.find(p => !isPlaceExcluded(p.place_name, excludedPlaces)) || places2[0];

            const results = [];
            if (place1) results.push(place1);
            if (place2) results.push(place2);
            if (results.length > 0) return results;
        }

        // CASE 2.5: SPECIALIZED BAKERY, CAKE, & PASTRY SEARCH
        // Note: Strictly DO NOT query place_name in search suggestion!
        const cakeRegex = /cake|cakes|bakery|bakeries|pastry|pastries|patisserie|蛋糕|甜品|甜点|糕点|烘焙|面包|糖水/i;
        let isBakeryOrCakeQuery = cakeRegex.test(lowerText);
        if (!isBakeryOrCakeQuery && matchedCategories.length === 0 && (keywords.length === 0 || keywords.every(k => ['other', 'more', 'option', 'options', 'different', 'else', 'another'].includes(k.toLowerCase())))) {
            const lastUserText = getPreviousUserInput(history);
            if (lastUserText && cakeRegex.test(lastUserText)) {
                isBakeryOrCakeQuery = true;
            }
        }
        if (isBakeryOrCakeQuery && !isOtherSuggestion) {
            const cakeRegex = /cake|bakery|pastry|patisserie|dessert|tiramisu|tart|dessert|sweet|bakes|蛋糕|甜品|甜点|糕点|烘焙|面包|糖水/i;
            const cakeQuery = {
                $or: [
                    { place_summary: { $regex: 'cake|bakery|pastry|patisserie|tiramisu|tart|dessert|sweet|bakes|蛋糕|甜品|甜点|糕点|烘焙|面包|糖水', $options: 'i' } },
                    { place_category: { $in: ['Dessert and Pastry', 'bakery', 'Cafes'] } }
                ]
            };

            let freshCakes = await searchPlacesWithPostcodeAndAreaFallback({
                queryFilter: cakeQuery,
                postcode: targetPostcode,
                area: targetArea,
                limit: 30,
                excludedPlaces,
                trace
            });

            freshCakes.sort((a, b) => {
                const aSumm = cakeRegex.test(a.place_summary || '');
                const bSumm = cakeRegex.test(b.place_summary || '');
                if (aSumm && !bSumm) return -1;
                if (!aSumm && bSumm) return 1;
                return 0;
            });

            if (freshCakes.length >= 2) {
                return freshCakes.slice(0, 2);
            }

            // Fallback to Photon OpenStreetMap if fewer than 2 cake places in MongoDB
            const osmArea = targetArea || (targetPostcode ? getAreaForPostcode(targetPostcode) : 'George Town');
            const osmQuery = `cake bakery ${osmArea}`;
            const osmCakes = await searchPlacesFromPhoton(osmQuery, 4);
            const freshOsm = osmCakes.filter(p => !isPlaceExcluded(p.name, excludedPlaces));

            if (freshCakes.length === 1 && freshOsm.length > 0) {
                return [freshCakes[0], freshOsm[0]];
            }
            if (freshOsm.length >= 2) {
                return freshOsm.slice(0, 2);
            }
            if (freshCakes.length > 0) {
                return freshCakes.slice(0, 2);
            }
        }

        // CASE 3: CATEGORY OR KEYWORD SEARCH (TARGETS places_new WITH POSTCODE & AREA FALLBACK)
        // 1. Search 5-digit postcode in address
        // 2. Fallback to area name in area/address
        // 3. Always provide 2 options matching requested keyword / category
        if (!keywords || keywords.length === 0) {
            keywords = resolveTargetKeywords(text, history);
        }

        let suggestionFilter = null;
        const mapped = mapCategoryToMongo(matchedCategories, keywords);

        if (mapped.primaryCategories.length > 0) {
            suggestionFilter = {
                $or: [
                    { primary_category: { $in: mapped.primaryCategories } },
                    { sub_categories: { $in: mapped.primaryCategories } }
                ]
            };
        } else if (keywords.length > 0) {
            const kwPattern = keywords.join('|');
            suggestionFilter = {
                $or: [
                    { name: { $regex: kwPattern, $options: 'i' } },
                    { summary: { $regex: kwPattern, $options: 'i' } },
                    { search_keywords: { $in: keywords } }
                ]
            };
        }

        if (suggestionFilter) {
            let candidateMatches = await searchPlacesWithPostcodeAndAreaFallback({
                queryFilter: suggestionFilter,
                postcode: targetPostcode,
                area: targetArea,
                limit: 30,
                excludedPlaces,
                trace
            });

            // Specific keyword relevance boost (e.g. prioritize places with "mall" or "shopping" in name/summary)
            if (candidateMatches.length > 0) {
                const mallBoost = /mall|shopping\s*centre|shopping\s*center|plaza/i.test(lowerText);
                if (mallBoost) {
                    const mallNameRegex = /mall|shopping\s*centre|shopping\s*center|plaza|hypermarket|sunshine|all seasons|komtar|queensbay|gurney/i;
                    candidateMatches.sort((a, b) => {
                        const aName = a.name || a.place_name || '';
                        const bName = b.name || b.place_name || '';
                        const aNameMatch = mallNameRegex.test(aName);
                        const bNameMatch = mallNameRegex.test(bName);
                        if (aNameMatch && !bNameMatch) return -1;
                        if (!aNameMatch && bNameMatch) return 1;
                        return (b.popularity_score || 0) - (a.popularity_score || 0);
                    });
                } else if (keywords.length > 0) {
                    const kwBoostRegex = new RegExp(keywords.join('|'), 'i');
                    candidateMatches.sort((a, b) => {
                        const aName = a.name || a.place_name || '';
                        const bName = b.name || b.place_name || '';
                        const aScore = (kwBoostRegex.test(aName) ? 10 : 0) + (kwBoostRegex.test(a.summary || a.place_summary || '') ? 5 : 0);
                        const bScore = (kwBoostRegex.test(bName) ? 10 : 0) + (kwBoostRegex.test(b.summary || b.place_summary || '') ? 5 : 0);
                        if (aScore !== bScore) return bScore - aScore;
                        return (b.popularity_score || 0) - (a.popularity_score || 0);
                    });
                }
            }

            if (candidateMatches.length >= 2) {
                return candidateMatches.slice(0, 2);
            }

            // If fewer than 2 matches found in exact postcode, search broader area for the SAME category
            if (candidateMatches.length < 2 && (matchedCategories.length > 0 || keywords.length > 0)) {
                const broaderAreaMatches = await searchPlacesWithPostcodeAndAreaFallback({
                    queryFilter: suggestionFilter,
                    postcode: null,
                    area: targetArea || 'George Town',
                    limit: 30,
                    excludedPlaces,
                    trace
                });
                for (const bm of broaderAreaMatches) {
                    const bmName = bm.name || bm.place_name;
                    if (!candidateMatches.some(cm => (cm.name || cm.place_name) === bmName)) {
                        candidateMatches.push(bm);
                        if (candidateMatches.length >= 2) break;
                    }
                }
            }

            if (candidateMatches.length >= 2) {
                return candidateMatches.slice(0, 2);
            }

            // If only 1 match found, find a sibling place in the SAME postcode / area
            if (candidateMatches.length === 1) {
                const siblingFilter = {
                    $or: [
                        { primary_category: { $in: ['Shopping & Markets', 'Food & Dining', 'Cafes', 'Heritage & Culture', 'Nature & Parks', 'Religious Sites'] } },
                        { place_category: { $regex: 'shopping|market|cultural|heritage|museum|nature|park|attraction|farm|food|cafe|hawker|dessert|worship', $options: 'i' } }
                    ]
                };
                const siblings = await searchPlacesWithPostcodeAndAreaFallback({
                    queryFilter: siblingFilter,
                    postcode: targetPostcode,
                    area: targetArea,
                    limit: 30,
                    excludedPlaces: new Set([...excludedPlaces, (candidateMatches[0].name || candidateMatches[0].place_name || '').toLowerCase().trim()]),
                    trace
                });
                const extraSibling = siblings.find(p => (p._id?.toString() || p.id) !== (candidateMatches[0]._id?.toString() || candidateMatches[0].id));
                if (extraSibling) {
                    return [candidateMatches[0], extraSibling];
                }

                if (targetArea) {
                    const curated = getAreaCuratedPair(targetArea, excludedPlaces);
                    const extraCurated = curated.find(c => c.name.toLowerCase() !== (candidateMatches[0].name || candidateMatches[0].place_name || '').toLowerCase());
                    if (extraCurated) return [candidateMatches[0], extraCurated];
                }
            }
        }

        // CASE 4: AREA TOP ATTRACTIONS / GENERAL FALLBACK
        // Always search 5-digit postcode first, fallback to area name, strictly NO place_name query!
        const attractionCats = [
            'Heritage & Culture', 'Nature & Parks', 'Religious Sites',
            'Arts & Workshops', 'Family & Adventure', 'Food & Dining', 'Cafes', 'Shopping & Markets'
        ];
        const topAttractionFilter = {
            $or: [
                { primary_category: { $in: attractionCats } },
                { sub_categories: { $in: attractionCats } },
                { place_category: { $regex: 'cultural|heritage|museum|historical|monument|clan|art|worship|nature|park|tourist|cafe|food|farm|attraction', $options: 'i' } }
            ]
        };
        let topAreaMatches = await searchPlacesWithPostcodeAndAreaFallback({
            queryFilter: topAttractionFilter,
            postcode: targetPostcode,
            area: targetArea,
            limit: 30,
            excludedPlaces,
            trace
        });
        if (topAreaMatches.length >= 2) return topAreaMatches.slice(0, 2);

        // General places in postcode / area
        let areaMatches = await searchPlacesWithPostcodeAndAreaFallback({
            queryFilter: {},
            postcode: targetPostcode,
            area: targetArea,
            limit: 50,
            excludedPlaces,
            trace
        });
        if (areaMatches.length >= 2) return areaMatches.slice(0, 2);

        // Target area curated POIs fallback (prevents leaking spots from completely different areas like Air Itam)
        if (targetArea) {
            const curated = getAreaCuratedPair(targetArea, excludedPlaces);
            const basePlace = areaMatches[0] || topAreaMatches[0];
            if (basePlace) {
                const extraCurated = curated.find(c => c.name.toLowerCase() !== (basePlace.name || basePlace.place_name || '').toLowerCase());
                if (extraCurated) return [basePlace, extraCurated];
            }
            if (curated.length >= 2) return curated.slice(0, 2);
        }

        // OpenStreetMap Photon fallback in targetArea
        const searchArea = targetArea || (targetPostcode ? getAreaForPostcode(targetPostcode) : 'George Town');
        const basePlace = areaMatches[0] || topAreaMatches[0];
        const osmCandidates = await searchPlacesFromPhoton(`${searchArea} penang`, 6);
        const freshOsm = osmCandidates.filter(p => !isPlaceExcluded(p.name, excludedPlaces) && (!basePlace || p.name.toLowerCase() !== (basePlace.place_name || '').toLowerCase()));

        if (basePlace && freshOsm.length > 0) {
            return [basePlace, freshOsm[0]];
        }
        if (freshOsm.length >= 2) {
            return freshOsm.slice(0, 2);
        }

        // If specific target area is requested, strictly fall back to curated POIs for that area
        if (targetArea && targetArea !== 'Penang' && targetArea !== 'Penang Island' && targetArea !== 'Pulau Pinang') {
            const curated = getAreaCuratedPair(targetArea, excludedPlaces);
            if (curated.length > 0) return curated.slice(0, 2);
        }

        // Ultimate fallback: General Penang Island places (only for island-wide queries)
        const islandMatches = await PlaceNew.find({
            status: 'active',
            name: { $not: JUNK_NAMES_REGEX },
            $and: [
                topAttractionFilter,
                MAINLAND_FILTER
            ]
        }).sort({ popularity_score: -1, review_count: -1, rating: -1 }).limit(20).maxTimeMS(1500);
        const freshIsland = islandMatches.filter(p => !isPlaceExcluded(p.name, excludedPlaces));
        if (freshIsland.length >= 2) return freshIsland.slice(0, 2);
        if (freshIsland.length === 1) {
            const curated = getAreaCuratedPair('George Town', excludedPlaces);
            return [freshIsland[0], curated[0]];
        }
        return getAreaCuratedPair('George Town', excludedPlaces).slice(0, 2);
    } catch (err) {
        console.error('Error finding relevant places in MongoDB:', err.message);
        return getAreaCuratedPair('George Town').slice(0, 2);
    }
}

// 5. Main Prompt Builder Function
function buildPrompt(mode, context, dbPlaces, excludedPlaces = new Set(), isFactualQuery = false, mentionedFacts = [], factualGrounding = null, inquiryType = null) {
    const basePrompt = BASE_PERSONA;
    const modePrompt = buildModeInstruction(mode, context);
    const contextPrompt = buildContextInjection(context, dbPlaces, excludedPlaces, mentionedFacts);
    let prompt = `${basePrompt}\n\n${modePrompt}\n\n${contextPrompt}`;
    if (isFactualQuery) {
        if (factualGrounding) {
            prompt += `\n\n=== 🏛️ VERIFIED MONGODB GROUNDING DATA (RAG FACT SHEET) ===
[DATA SOURCE: Official MongoDB places_new Database - GROUND TRUTH]
• Place Name: "${factualGrounding.name}" ${factualGrounding.local_name_zh ? `(${factualGrounding.local_name_zh})` : ''}
• Primary Category: "${factualGrounding.primary_category}"
• Sub-Categories: [${(factualGrounding.sub_categories || []).join(', ')}]
• Opening / Business Hours: "${factualGrounding.opening_hours_text}"
• Ticket Price / Entrance Fee / Rates: "${factualGrounding.price_level}"
• Address: "${factualGrounding.address}" (Area: "${factualGrounding.area}")
• Contact / Website: Phone: "${factualGrounding.phone || 'N/A'}", Website: "${factualGrounding.website || 'N/A'}"
• Verified Summary / Description: "${factualGrounding.summary}"
===========================================================

=== 🛡️ CRITICAL FACTUAL GROUNDING DIRECTIVES (STRICT ZERO HALLUCINATION) ===
The user is asking a factual question regarding opening hours, entrance fees/tickets, price level, contact numbers/phone, official website, categories, or location/address.
You MUST obey the following strict rules:
1. MANDATORY RAG GROUNDING: For all questions regarding:
   - 营业时间 / Opening Hours & Business Hours
   - 门票 & 消费 / Ticket Prices, Price Level & Entrance Fees
   - 电话 & 联系方式 / Contact Phone Numbers & Hotlines
   - 官网 & 网址 / Official Website URLs
   - 分类 / Category (Primary Category & Sub-categories)
   - 地址 / Address & Location
   You MUST strictly base your answer ONLY on the data in the "VERIFIED MONGODB GROUNDING DATA" section above!
2. ABSOLUTE PROHIBITION ON GUESSING OR FABRICATION:
   - State the verified phone number ("${factualGrounding.phone || 'N/A'}") and website ("${factualGrounding.website || 'N/A'}") accurately if asked.
   - DO NOT invent, extrapolate, or hallucinate opening hours (e.g. NEVER guess "09:00 - 18:00" if the database says "No Information").
   - DO NOT invent ticket prices or price levels if the database has no fee listed.
   - If MongoDB says "No Information", "N/A", or lacks the specific detail, inform the user truthfully that the verified record currently does not list that specific field and advise checking official channels.
3. CATEGORY FIDELITY:
   - Always quote the exact Primary Category and Sub-categories from MongoDB ("${factualGrounding.primary_category}"). Do NOT fabricate alternative categories.
4. NO RECOMMENDATION OPTIONS:
   - DO NOT provide Option A or Option B recommendations when answering a pure factual question. Answer directly, accurately, and crisply.
5. TONE & BILINGUAL SUPPORT:
   - Keep your charming Kia-Kia Penang bird mascot persona (friendly, enthusiastic, warm, light Manglish like Jom, lah).
   - Answer in the user's language (Chinese if asked in Chinese, English if asked in English).`;
        } else {
            prompt += `\n\n=== ⚠️ MONGODB RAG GROUNDING: NO VERIFIED PLACE FOUND IN DATABASE ===
The user asked a factual question about a specific place or detail, but no verified matching record was found in the official MongoDB places_new database.
CRITICAL DIRECTIVE: You MUST inform the user that this place/information is not available in the Kia-Kia Penang verified database.
DO NOT invent or guess opening hours, ticket prices, categories, contact numbers, or addresses!`;
        }
    }
    return prompt;
}

// 6. Pretty JS Console Logger
function logBirdInteraction({ mode, message, history, context, systemPrompt, messagesSent = [], rawModelResponse = '', finalResponse = {}, trace = null }) {
    const hr = '═'.repeat(78);
    const subHr = '─'.repeat(78);

    console.log(`\n╔${hr}╗`);
    console.log(`║ 📥 [BIRD AI CHAT REQUEST RECEIVED]`);
    console.log(`║ Mode: \x1b[33m${mode}\x1b[0m`);
    console.log(`║ User Input: "\x1b[32m${message}\x1b[0m"`);
    console.log(`║ History Turns: ${Array.isArray(history) ? history.length : 0} messages`);
    if (context?.draftPlan) {
        console.log(`║ Draft Plan Stops: ${context.draftPlan.stops?.length || 0} stops`);
    }
    if (context?.activeTrip) {
        console.log(`║ Active Trip: ${context.activeTrip.tripId} (Stop #${context.activeTrip.currentStopIndex})`);
    }

    // ─────────────────────────────────────────────────────────────
    // 🔍 INTENT & KEYWORD EXTRACTION PIPELINE
    // ─────────────────────────────────────────────────────────────
    console.log(`╠${subHr}╣`);
    console.log(`║ 🔍 [INTENT & KEYWORD EXTRACTION PIPELINE]:`);
    const intentType = trace?.intentType || 'GENERAL_INQUIRY';
    console.log(`║   • Intent Classification: \x1b[36m${intentType}\x1b[0m`);
    if (trace?.extractedTarget) {
        console.log(`║   • Extracted Place/Target: "\x1b[32m${trace.extractedTarget}\x1b[0m"`);
    }
    if (trace?.extractedKeywords && trace.extractedKeywords.length > 0) {
        console.log(`║   • Extracted Keyword(s): \x1b[33m${JSON.stringify(trace.extractedKeywords)}\x1b[0m`);
    }
    if (trace?.targetPostcode) {
        console.log(`║   • Target Postcode: \x1b[36m${trace.targetPostcode}\x1b[0m`);
    }
    if (trace?.targetArea) {
        console.log(`║   • Target Area / Vicinity: \x1b[35m${trace.targetArea}\x1b[0m`);
    }
    if (trace?.excludedPlaces && trace.excludedPlaces.length > 0) {
        const previewEx = trace.excludedPlaces.slice(0, 3).join(', ');
        console.log(`║   • Excluded Places (Anti-Duplicate): [${previewEx}${trace.excludedPlaces.length > 3 ? '...' : ''}]`);
    }

    // ─────────────────────────────────────────────────────────────
    // 📚 DATA HANDLING & GROUNDING: RAG vs. MODEL INTELLIGENCE
    // ─────────────────────────────────────────────────────────────
    console.log(`╠${subHr}╣`);
    console.log(`║ 📚 [DATA HANDLING & GROUNDING: RAG vs. MODEL INTELLIGENCE]:`);
    const pathType = trace?.executionPath || (messagesSent.length > 1 ? 'HYBRID_RAG_PLUS_LLM' : 'DETERMINISTIC_RAG');

    if (pathType === 'DETERMINISTIC_RAG') {
        console.log(`║   • Execution Path: \x1b[32m🟢 DETERMINISTIC RAG GROUNDING (DB / Fast Intent)\x1b[0m`);
        console.log(`║   • Grounding Source: \x1b[36m${trace?.dataSource || 'MongoDB (places_new collection)'}\x1b[0m`);
        if (trace?.mongoQueryFilters && trace.mongoQueryFilters.length > 0) {
            console.log(`║   • Actual MongoDB Query Filter(s):`);
            trace.mongoQueryFilters.forEach((q, idx) => {
                const qLabel = q.label ? ` [${q.label}]` : '';
                console.log(`║     - Filter #${idx + 1}${qLabel}:`);
                const qLines = (q.formatted || formatMongoFilterForTerminal(q.filter)).split('\n');
                qLines.slice(0, 8).forEach(l => {
                    console.log(`║       \x1b[33m${l}\x1b[0m`);
                });
                if (qLines.length > 8) {
                    console.log(`║       \x1b[90m... (${qLines.length - 8} more lines)\x1b[0m`);
                }
            });
        } else if (trace?.ragQuery) {
            console.log(`║   • Query Executed: \x1b[33m${trace.ragQuery}\x1b[0m`);
        }
        if (trace?.matchedEntity) {
            const ent = trace.matchedEntity;
            console.log(`║   • Matched Entity: \x1b[32m${ent.name || ent.place_name}\x1b[0m (${ent.area || 'Penang'}) [Category: ${ent.category || ent.place_category || 'Place'}]`);
        } else if (trace?.searchStatus === 'NOT_FOUND') {
            console.log(`║   • Query Status: \x1b[31m⚠️ Unverified (No match found in MongoDB or OpenStreetMap)\x1b[0m`);
        }
        console.log(`║   • Model Intelligence (LLM): \x1b[90m⏭️ BYPASSED (Fast deterministic match avoids LLM hallucination)\x1b[0m`);
    } else if (pathType === 'HYBRID_RAG_PLUS_LLM') {
        console.log(`║   • Execution Path: \x1b[33m🟡 HYBRID RAG + MODEL INTELLIGENCE (LLM Grounding)\x1b[0m`);
        console.log(`║   • Step 1 [RAG Retrieval]: \x1b[36m${trace?.dataSource || 'MongoDB (places_new collection)'}\x1b[0m`);
        if (trace?.mongoQueryFilters && trace.mongoQueryFilters.length > 0) {
            console.log(`║     - Actual MongoDB Query Filter(s):`);
            trace.mongoQueryFilters.forEach((q, idx) => {
                const qLabel = q.label ? ` [${q.label}]` : '';
                console.log(`║       Filter #${idx + 1}${qLabel}:`);
                const qLines = (q.formatted || formatMongoFilterForTerminal(q.filter)).split('\n');
                qLines.slice(0, 10).forEach(l => {
                    console.log(`║         \x1b[33m${l}\x1b[0m`);
                });
                if (qLines.length > 10) {
                    console.log(`║         \x1b[90m... (${qLines.length - 10} more lines)\x1b[0m`);
                }
            });
        } else if (trace?.ragQuery) {
            console.log(`║     - DB Filter: \x1b[33m${trace.ragQuery}\x1b[0m`);
        }
        if (trace?.groundingPlaces && trace.groundingPlaces.length > 0) {
            const gNames = trace.groundingPlaces.map(p => p.name || p.place_name).join(', ');
            console.log(`║     - Retrieved Grounding Places: \x1b[32m${gNames}\x1b[0m`);
        } else {
            console.log(`║     - Retrieved Grounding Places: None (Fallback to Persona Knowledge)`);
        }
        console.log(`║   • Step 2 [Model Intelligence]: \x1b[35m${DEFAULT_MODEL}\x1b[0m via Ollama`);
        console.log(`║     - Prompt Grounding: Injected verified DB places as Option A / Option B`);
        console.log(`║     - Messages Passed: ${messagesSent.length} (System + Recent Turns + User)`);
        if (trace?.llmLatencyMs) {
            console.log(`║     - Ollama Latency: \x1b[36m${trace.llmLatencyMs}ms\x1b[0m`);
        }
    } else if (pathType === 'MODEL_INTELLIGENCE_ONLY') {
        console.log(`║   • Execution Path: \x1b[34m🔵 MODEL INTELLIGENCE ONLY (Conversational / General Query)\x1b[0m`);
        console.log(`║   • Model: \x1b[35m${DEFAULT_MODEL}\x1b[0m via Ollama`);
        console.log(`║   • Total Messages Passed: ${messagesSent.length}`);
        if (trace?.llmLatencyMs) {
            console.log(`║   • Ollama Latency: \x1b[36m${trace.llmLatencyMs}ms\x1b[0m`);
        }
    } else if (pathType === 'SYSTEM_ACTION') {
        console.log(`║   • Execution Path: \x1b[36m⚡ BUILT-IN SYSTEM ACTION HANDLER\x1b[0m`);
        console.log(`║   • Action Name: ${trace?.systemActionName || 'Fast System Handler'}`);
    }

    // ─────────────────────────────────────────────────────────────
    // 🤖 MESSAGES & RAW MODEL OUTPUT (Only shown when LLM was actually called)
    // ─────────────────────────────────────────────────────────────
    if (trace?.llmCalled && messagesSent.length > 0) {
        console.log(`╠${subHr}╣`);
        console.log(`║ 🤖 [HOW USER INPUT & CONTEXT ARE PASSED TO MODEL: ${DEFAULT_MODEL}]`);
        console.log(`║ Total Messages Sent: ${messagesSent.length}`);
        messagesSent.forEach((m, idx) => {
            const snippet = (m.content || '').replace(/\n/g, ' ').substring(0, 100);
            console.log(`║   [${idx + 1}] Role: \x1b[36m${m.role.toUpperCase()}\x1b[0m | Snippet: "${snippet}..."`);
        });
        if (rawModelResponse) {
            console.log(`╠${subHr}╣`);
            console.log(`║ 📤 [RAW MODEL RESPONSE]:`);
            const rawPreview = (rawModelResponse || '').trim().split('\n').slice(0, 6).join('\n║   ');
            console.log(`║   \x1b[35m${rawPreview}\x1b[0m`);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 📦 DISPATCHED RESPONSE RETURNED TO CLIENT
    // ─────────────────────────────────────────────────────────────
    console.log(`╠${subHr}╣`);
    console.log(`║ 📦 [DISPATCHED RESPONSE RETURNED TO CLIENT]:`);
    console.log(`║ Action: \x1b[33m${finalResponse.action || 'none'}\x1b[0m`);
    const displayMsg = (finalResponse.message || finalResponse.reply || '').replace(/\n/g, ' ').substring(0, 90);
    console.log(`║ Message: "${displayMsg}..."`);
    if (finalResponse.quickReplies?.length > 0) {
        console.log(`║ Quick Replies: ${JSON.stringify(finalResponse.quickReplies)}`);
    }
    if (finalResponse.suggestedPlaces?.length > 0) {
        console.log(`║ Suggested Places: \x1b[32m${finalResponse.suggestedPlaces.map(p => p.name || p.placeName).join(', ')}\x1b[0m`);
    }
    const elapsed = Date.now() - (trace?.startTime || Date.now());
    console.log(`║ Processing Latency: \x1b[36m${elapsed}ms\x1b[0m`);
    console.log(`╚${hr}╝\n`);
}

// Helper: Query Photon (OpenStreetMap) API within Penang boundaries
async function searchPlacesFromPhoton(query, limit = 4) {
    if (!query || typeof query !== 'string') return [];
    try {
        const cleanQuery = query.replace(/[^\w\s]/g, ' ').trim();
        if (cleanQuery.length < 2) return [];
        const url = `https://photon.komoot.io/api/?q=${encodeURIComponent(cleanQuery)}&limit=${limit * 2}&lat=5.414&lon=100.328&bbox=100.10,5.10,100.60,5.60`;
        const resp = await fetch(url, { timeout: 4000 });
        if (!resp.ok) return [];
        const json = await resp.json();
        const features = json.features || [];
        const results = [];
        const seen = new Set();

        for (const f of features) {
            const props = f.properties || {};
            const name = props.name || props.street;
            if (!name || name.length < 3 || seen.has(name.toLowerCase())) continue;
            seen.add(name.toLowerCase());

            const coords = f.geometry?.coordinates || [100.328, 5.414];
            const city = props.city || props.district || 'George Town';
            const street = props.street || '';
            const fullAddress = [name, street, city, 'Penang, Malaysia'].filter(Boolean).join(', ');
            const rawCat = props.osm_value || 'Cafes';
            const category = /bakery|pastry|cake|dessert|confectionery/i.test(rawCat) ? 'Dessert and Pastry' : 'Cafes';

            const placeObj = {
                id: `osm_${props.osm_id || Date.now()}_${Math.random().toString(36).substring(7)}`,
                name: name,
                area: city.toLowerCase().includes('georgetown') || city.toLowerCase().includes('george town') ? 'George Town' : city,
                category: category,
                description: `${name} - Notable spot in ${city}, Penang.`,
                lat: coords[1],
                lng: coords[0]
            };

            // Auto-cache into MongoDB (places_new) so it is available locally for future searches
            PlaceNew.updateOne(
                { name: name },
                {
                    $setOnInsert: {
                        name: name,
                        summary: placeObj.description,
                        primary_category: category,
                        address: fullAddress,
                        area: placeObj.area,
                        location: { type: 'Point', coordinates: coords },
                        status: 'active'
                    }
                },
                { upsert: true }
            ).catch(err => console.warn('Auto-caching OSM place to places_new failed:', err.message));

            results.push(placeObj);
            if (results.length >= limit) break;
        }
        return results;
    } catch (e) {
        console.warn('searchPlacesFromPhoton lookup error:', e.message);
        return [];
    }
}

// Helper: Fallback to OpenStreetMap (Nominatim) for Penang places
async function queryOSMPlace(query) {
    if (!query || typeof query !== 'string') return null;
    const clean = query.trim();
    const searchTerms = [
        `${clean} penang`,
        clean
    ];

    for (const term of searchTerms) {
        try {
            const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(term)}&format=json&addressdetails=1&limit=3`;
            const resp = await fetch(url, {
                headers: { 'User-Agent': 'KiaKiaPenangApp/1.0' },
                signal: AbortSignal.timeout(4000)
            });
            if (resp.ok) {
                const items = await resp.json();
                if (Array.isArray(items) && items.length > 0) {
                    for (const item of items) {
                        const lat = parseFloat(item.lat);
                        const lon = parseFloat(item.lon);
                        const display = (item.display_name || '').toLowerCase();
                        const isPenang = (lat >= 5.1 && lat <= 5.6 && lon >= 100.1 && lon <= 100.6) ||
                                         display.includes('penang') || display.includes('pinang');
                        if (isPenang) {
                            const addr = item.address || {};
                            const area = addr.suburb || addr.neighbourhood || addr.city || addr.town || addr.county || 'Penang';
                            const title = item.name || (item.display_name ? item.display_name.split(',')[0].trim() : clean);
                            return {
                                id: `osm_${item.osm_id || Date.now()}`,
                                name: title,
                                area: area,
                                category: 'Attraction',
                                description: item.display_name || `A verified landmark in ${area}, Penang.`,
                                lat: lat,
                                lng: lon
                            };
                        }
                    }
                }
            }
        } catch (e) {
            console.warn('queryOSMPlace lookup error:', e.message);
        }
    }
    return null;
}

// Helper: Resolve a place by name from MongoDB or fallback to OpenStreetMap / Mapbox
async function resolvePlaceByName(name, defaultArea = 'Penang', traceCollector = null) {
    if (!name || typeof name !== 'string') return null;
    let cleanName = name.replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*[:：]?\s*/i, '');
    cleanName = cleanName.replace(/^(?:add|visit|choose|pick)\s+/i, '');
    cleanName = cleanName.replace(/[\*\_\[\]\.,"]/g, '').trim();

    const lowerFull = cleanName.toLowerCase();

    // 1. Food intent & spatial landmark detection
    const foodKeywords = [
        'laksa', 'char koay teow', 'char kway teow', 'cendol', 'chendol', 'curry mee',
        'hokkien mee', 'nasi kandar', 'roti canai', 'hawker', 'food court', 'dim sum',
        'bakery', 'cafe', 'dessert', 'kopi', 'coffee', 'makan', 'food', 'restaurant',
        'noodle', 'rice', 'seafood', 'eats', 'treats', 'ho chiak', 'asam laksa',
        'durian', 'durians', 'nutmeg',
        '美食', '小吃', '叻沙', '炒粿条', '红豆冰', '娘惹糕', '榴莲'
    ];
    const hasFoodIntent = foodKeywords.some(kw => lowerFull.includes(kw));

    // Detect if landmark is preceded by spatial reference (e.g. "near Kek Lok Si Temple", "靠近极乐寺")
    const isSpatialLandmark = /(?:near|opposite|next to|behind|beside|around|close to|靠近|附近|旁边|对面)\s+(?:the\s+)?([a-zA-Z0-9\s'&-]+)/i.test(lowerFull);

    // Strip trailing descriptions or explanations if any
    const sepMatch = cleanName.match(/^(.*?)(?:\s+[-–—]{1,2}\s+|\s*[:：]\s+|\s+(?:for|to|offers?|features?|where|is\s+a|is\s+the|is)\s+|[。，\r\n])/i);
    let extractedName = cleanName;
    if (sepMatch && sepMatch[1] && sepMatch[1].trim().length > 1) {
        extractedName = sepMatch[1].trim();
    }

    if (!extractedName || extractedName.length < 2) return null;
    if (isSystemAction(extractedName)) return null;

    // Stripped parenthetical version (e.g., "King Street (Heritage Building Area)" -> "King Street")
    const nameWithoutParen = extractedName.replace(/\s*\(.*?\)/g, '').trim();
    const testNames = [extractedName, nameWithoutParen].filter(Boolean);

    // 1.5 DIRECT/EXACT MATCH IN MONGODB FIRST (before generic food intent fallback)
    for (const tn of testNames) {
        const cleanEscaped = tn.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        try {
            const exactPlace = await PlaceNew.findOne({
                status: 'active',
                name: { $regex: `^${cleanEscaped}$`, $options: 'i' }
            }).maxTimeMS(1500);

            if (exactPlace) {
                const resultPlace = {
                    id: exactPlace._id ? exactPlace._id.toString() : `db_${Date.now()}_${Math.random()}`,
                    name: exactPlace.name,
                    area: exactPlace.area || extractArea(exactPlace) || defaultArea,
                    category: exactPlace.primary_category || (hasFoodIntent ? 'Cafes' : 'Attraction'),
                    description: exactPlace.summary || exactPlace.address || '',
                    lat: exactPlace.location?.coordinates ? exactPlace.location.coordinates[1] : 5.414,
                    lng: exactPlace.location?.coordinates ? exactPlace.location.coordinates[0] : 100.328
                };
                if (traceCollector) {
                    traceCollector.dataSource = 'MongoDB (places_new collection)';
                    traceCollector.ragQuery = `Exact match for "${tn}" in PlaceNew.findOne`;
                    traceCollector.matchedEntity = resultPlace;
                }
                return resultPlace;
            }

            // Substring search on name
            const partialPlace = await PlaceNew.findOne({
                status: 'active',
                name: { $regex: cleanEscaped, $options: 'i' }
            }).maxTimeMS(1500);

            if (partialPlace) {
                const resultPlace = {
                    id: partialPlace._id ? partialPlace._id.toString() : `db_${Date.now()}_${Math.random()}`,
                    name: partialPlace.name,
                    area: partialPlace.area || extractArea(partialPlace) || defaultArea,
                    category: partialPlace.primary_category || (hasFoodIntent ? 'Cafes' : 'Attraction'),
                    description: partialPlace.summary || partialPlace.address || '',
                    lat: partialPlace.location?.coordinates ? partialPlace.location.coordinates[1] : 5.414,
                    lng: partialPlace.location?.coordinates ? partialPlace.location.coordinates[0] : 100.328
                };
                if (traceCollector) {
                    traceCollector.dataSource = 'MongoDB (places_new collection)';
                    traceCollector.ragQuery = `Partial match for "${tn}" in PlaceNew.findOne`;
                    traceCollector.matchedEntity = resultPlace;
                }
                return resultPlace;
            }
        } catch (e) {
            console.warn('Direct PlaceNew match error:', e.message);
        }
    }

    // 2. FOOD INTENT HANDLING: Strictly prioritize food/hawker places in MongoDB
    if (hasFoodIntent) {
        let matchedArea = null;
        for (const a of PENANG_AREAS) {
            if (lowerFull.includes(a.toLowerCase())) {
                matchedArea = normalizeAreaName(a);
                break;
            }
        }

        const matchedFood = foodKeywords.filter(k => lowerFull.includes(k) && !['food', 'eats', 'treats', 'ho chiak', 'makan', '美食'].includes(k));
        const primaryFood = matchedFood.length > 0 ? matchedFood[0] : (lowerFull.includes('hawker') ? 'hawker' : '');

        let foodQuery = {};
        if (primaryFood === 'hawker' || lowerFull.includes('hawker')) {
            foodQuery = {
                $or: [
                    { primary_category: { $in: ['Food & Dining', 'Hawker Centres & Food Courts'] } },
                    { name: { $regex: 'hawker|food court|chulia|gurney drive', $options: 'i' } }
                ]
            };
        } else if (primaryFood) {
            const foodRegex = (primaryFood === 'char koay teow' || primaryFood === 'char kway teow')
                ? 'char koay teow|char kway teow|hawker'
                : primaryFood;
            foodQuery = {
                $or: [
                    { name: { $regex: foodRegex, $options: 'i' } },
                    { summary: { $regex: foodRegex, $options: 'i' } },
                    { search_keywords: { $in: [foodRegex] } }
                ]
            };
        } else {
            foodQuery = {
                primary_category: { $in: ['Food & Dining', 'Cafes'] }
            };
        }

        if (!matchedArea && defaultArea && defaultArea !== 'Penang') {
            matchedArea = normalizeAreaName(defaultArea);
        }

        if (matchedArea) {
            foodQuery = {
                $and: [
                    { status: 'active' },
                    foodQuery,
                    buildAreaQuery(matchedArea)
                ]
            };
        } else {
            foodQuery = {
                $and: [
                    { status: 'active' },
                    foodQuery,
                    MAINLAND_FILTER
                ]
            };
        }

        try {
            let foodPlace = await PlaceNew.findOne(foodQuery);
            if (!foodPlace && primaryFood) {
                const subFoodQuery = matchedArea
                    ? { $and: [{ status: 'active' }, { name: { $regex: primaryFood, $options: 'i' } }, buildAreaQuery(matchedArea)] }
                    : { $and: [{ status: 'active' }, { name: { $regex: primaryFood, $options: 'i' } }, MAINLAND_FILTER] };
                foodPlace = await PlaceNew.findOne(subFoodQuery);
            }

            if (foodPlace) {
                const resultPlace = {
                    id: foodPlace._id ? foodPlace._id.toString() : `db_${Date.now()}_${Math.random()}`,
                    name: foodPlace.name,
                    area: foodPlace.area || extractArea(foodPlace) || matchedArea || defaultArea,
                    category: foodPlace.primary_category || 'Food & Dining',
                    description: foodPlace.summary || foodPlace.address || '',
                    lat: foodPlace.location?.coordinates ? foodPlace.location.coordinates[1] : 5.414,
                    lng: foodPlace.location?.coordinates ? foodPlace.location.coordinates[0] : 100.328
                };
                if (traceCollector) {
                    traceCollector.dataSource = 'MongoDB (places_new collection)';
                    traceCollector.ragQuery = `PlaceNew.findOne(${JSON.stringify(foodQuery)})`;
                    traceCollector.matchedEntity = resultPlace;
                    traceCollector.extractedKeywords = matchedFood.length > 0 ? matchedFood : [primaryFood];
                    if (matchedArea) traceCollector.targetArea = matchedArea;
                }
                return resultPlace;
            }
        } catch (e) {
            console.warn('resolvePlaceByName food query error:', e.message);
        }
    }

    // 3. NON-FOOD INTENT: Check KNOWN_PENANG_FACTS with strict matching (no loose .includes that catches "near Kek Lok Si")
    if (!hasFoodIntent && !isSpatialLandmark) {
        for (const tn of testNames) {
            const tnLow = tn.toLowerCase();
            const known = KNOWN_PENANG_FACTS.find(k => k.aliases.some(a => {
                const aLow = a.toLowerCase();
                return aLow === tnLow || (tnLow.startsWith(aLow) && tnLow.length < aLow.length + 10) || (aLow.startsWith(tnLow) && tnLow.length >= 6);
            }));
            if (known) {
                const resultPlace = {
                    id: `known_${Date.now()}`,
                    name: known.name,
                    area: known.address.includes('Air Itam') ? 'Air Itam' : (known.address.includes('Teluk Bahang') ? 'Teluk Bahang' : 'George Town'),
                    category: 'Attraction',
                    description: known.tip || '',
                    lat: 5.414,
                    lng: 100.328
                };
                if (traceCollector) {
                    traceCollector.dataSource = 'Penang Knowledge Base (Verified Landmark)';
                    traceCollector.ragQuery = `Exact Alias Match for "${known.name}" in KNOWN_PENANG_FACTS`;
                    traceCollector.matchedEntity = resultPlace;
                    traceCollector.extractedKeywords = [tn];
                }
                return resultPlace;
            }
        }
    }

    // 4. Query MongoDB PlaceNew collection
    try {
        const isIslandArea = defaultArea && !/bukit mertajam|butterworth|seberang/i.test(defaultArea);
        const areaFilter = (defaultArea && defaultArea !== 'Penang') ? buildAreaQuery(defaultArea) : (isIslandArea ? MAINLAND_FILTER : {});

        for (const tn of testNames) {
            const escaped = tn.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            // Prefer matching within target area first
            let p = null;
            if (defaultArea && defaultArea !== 'Penang') {
                p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: `^${escaped}$`, $options: 'i' } }, areaFilter] });
                if (!p) p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: escaped, $options: 'i' } }, areaFilter] });
            }
            if (!p) {
                p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: `^${escaped}$`, $options: 'i' } }, areaFilter] });
            }
            // Full substring match
            if (!p) {
                p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: escaped, $options: 'i' } }, areaFilter] });
            }
            // Substring without common punctuation
            if (!p && tn.includes(',')) {
                const beforeComma = tn.split(',')[0].trim();
                if (beforeComma.length > 3) {
                    const escComma = beforeComma.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: escComma, $options: 'i' } }, areaFilter] });
                }
            }
            // Singular form if ending with 's'
            if (!p && tn.toLowerCase().endsWith('s')) {
                const singular = tn.slice(0, -1).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: singular, $options: 'i' } }, areaFilter] });
            }
            // Significant word matching (e.g. "nutmeg farm" -> search for "nutmeg")
            if (!p) {
                const words = tn.split(/\s+/).filter(w => !['the', 'a', 'an', 'penang', 'cafe', 'restaurant', 'farm', 'shop', 'place'].includes(w.toLowerCase()) && w.length >= 3);
                for (const word of words) {
                    const escapedWord = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    if (defaultArea && defaultArea !== 'Penang') {
                        p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: escapedWord, $options: 'i' } }, areaFilter] });
                        if (p) break;
                    }
                    p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { name: { $regex: escapedWord, $options: 'i' } }, areaFilter] });
                    if (p) break;
                    p = await PlaceNew.findOne({ $and: [{ status: 'active' }, { summary: { $regex: escapedWord, $options: 'i' } }, areaFilter] });
                    if (p) break;
                }
            }

            if (p) {
                const resultPlace = {
                    id: p._id ? p._id.toString() : `db_${Date.now()}_${Math.random()}`,
                    name: p.name,
                    area: p.area || extractArea(p) || defaultArea,
                    category: p.primary_category || 'Attraction',
                    description: p.summary || p.address || '',
                    lat: p.location?.coordinates ? p.location.coordinates[1] : 5.414,
                    lng: p.location?.coordinates ? p.location.coordinates[0] : 100.328
                };
                if (traceCollector) {
                    traceCollector.dataSource = 'MongoDB (places_new collection)';
                    traceCollector.ragQuery = `PlaceNew.findOne({ name: { $regex: "${escaped}", $options: "i" } })`;
                    traceCollector.matchedEntity = resultPlace;
                    traceCollector.extractedKeywords = [tn];
                }
                return resultPlace;
            }
        }
    } catch (e) {
        console.warn('resolvePlaceByName MongoDB lookup error:', e.message);
    }

    // 5. Fallback A: Query OpenStreetMap (Photon)
    const isIslandGeo = defaultArea && !/bukit mertajam|butterworth|seberang/i.test(defaultArea);
    for (const tn of testNames) {
        const photonResults = await searchPlacesFromPhoton(tn, 3);
        const validPhoton = photonResults.find(pr => {
            if (isIslandGeo) {
                const prText = `${pr.name} ${pr.description || ''} ${pr.area || ''}`;
                if (new RegExp(MAINLAND_REGEX, 'i').test(prText)) return false;
            }
            return true;
        });
        if (validPhoton) {
            const resultPlace = validPhoton;
            if (traceCollector) {
                traceCollector.dataSource = 'OpenStreetMap (Photon Geo-Index)';
                traceCollector.ragQuery = `Photon OSM API: q="${tn}" within Penang Bounding Box [100.10,5.10,100.60,5.60]`;
                traceCollector.matchedEntity = resultPlace;
                traceCollector.extractedKeywords = [tn];
            }
            return resultPlace;
        }
    }

    // 6. Fallback B: Query OpenStreetMap (Nominatim)
    for (const tn of testNames) {
        const osmPlace = await queryOSMPlace(tn);
        if (osmPlace) {
            if (isIslandGeo) {
                const osmText = `${osmPlace.name} ${osmPlace.description || ''} ${osmPlace.area || ''}`;
                if (new RegExp(MAINLAND_REGEX, 'i').test(osmText)) continue;
            }
            if (traceCollector) {
                traceCollector.dataSource = 'OpenStreetMap (Nominatim API)';
                traceCollector.ragQuery = `Nominatim OSM API: q="${tn}" within Penang`;
                traceCollector.matchedEntity = osmPlace;
                traceCollector.extractedKeywords = [tn];
            }
            return osmPlace;
        }
    }

    // If completely unverified in Penang, record unverified in trace
    if (traceCollector) {
        traceCollector.dataSource = 'None (Unverified Place)';
        traceCollector.searchStatus = 'NOT_FOUND';
        traceCollector.ragQuery = `Searched MongoDB, Known Facts KB & OpenStreetMap for "${name}" (0 matches)`;
    }
    return null;
}

function isGenericCategoryPhrase(term) {
    if (!term || typeof term !== 'string') return false;
    const clean = term.toLowerCase().replace(/^(?:a|an|the|some|any)\s+/i, '').replace(/[\*\_\[\]\.,]/g, '').trim();
    const genericWords = [
        'durian shop', 'durian stall', 'durian farm', 'durian place', 'durian', 'durians',
        'cafe', 'coffee shop', 'coffee', 'kopitiam', 'bakery', 'pastry shop', 'cake shop',
        'hawker', 'hawker centre', 'hawker stall', 'food court', 'street food',
        'restaurant', 'eatery', 'food', 'makan', 'breakfast', 'lunch', 'dinner', 'supper',
        'laksa', 'asam laksa', 'char koay teow', 'curry mee', 'cendol', 'chendol', 'dessert',
        'beach', 'park', 'museum', 'temple', 'place', 'places', 'spot', 'spots',
        'attraction', 'attractions', 'farm', 'farms',
        '榴莲店', '榴莲摊', '榴莲', '咖啡馆', '咖啡厅', '面包店', '小吃摊', '熟食中心', '餐馆', '餐厅', '海滩', '公园', '博物馆', '庙', '景点', '美食'
    ];
    if (genericWords.some(gw => clean === gw || clean === `${gw}s`)) return true;
    if (/^durian\s+(?:shop|stall|farm|place|orchard|store)s?$/i.test(clean)) return true;
    if (/^(?:cafe|coffee|hawker|bakery|restaurant|food)\s+(?:shop|stall|place|store)s?$/i.test(clean)) return true;
    return false;
}

// 🎯 Detect Direct "Add to plan" Intent
// STRICT RULE: ONLY explicit "Add", "Insert", "Put into plan", "帮我加", "加入行程" triggers DIRECT_ADD_SPOT.
// Expressions like "I want to visit...", "Wanna go to...", "我想去..." MUST NOT DIRECT ADD!
function detectAddOrVisitIntent(msg) {
    if (!msg || typeof msg !== 'string') return null;
    let text = msg.trim();
    const lower = text.toLowerCase();

    // If it's a question inquiring about something without explicit add command, skip
    if (lower.includes('?') && !lower.includes('add') && !lower.includes('加')) {
        return null;
    }
    if (/^(?:how|what|where|when|why|who|is|are|can\s+i|do\s+i)\b/i.test(lower) && !lower.includes('add') && !lower.includes('加')) {
        return null;
    }

    // Fast-path: if user says "add this / add it / add that" to plan
    if (/\b(?:add|insert|include|put)\s+(?:this|it|that)\b/i.test(lower) || 
        /(?:把这个|把这|加这个|加这|加入这个).*(?:行程|计划)/.test(lower)) {
        return 'this';
    }

    // Explicit Add Patterns ONLY
    const addPatterns = [
        // "Ok, help me add blue mansion to my plan" / "please help me add X to plan" / "add X into my plan"
        /(?:ok[,\s]+)?(?:steady[,\s]+)?(?:sure[,\s]+)?(?:yes[,\s]+)?(?:please\s+|can\s+you\s+|could\s+you\s+)?(?:help\s+me\s+)?(?:add|insert|include|put)\s+(.+?)(?:\s+(?:to|into|in)\s+(?:my\s+|the\s+)?(?:plan|trip|itinerary|list))?$/i,

        // Chinese: 帮我加 [place] 到我的行程 / 把 [place] 加入计划 / 加 [place] 进计划
        /(?:帮我把|帮我加|请把|把|将)?\s*(.+?)\s*(?:加入行程|加进行程|加入计划|加进计划|加到行程|加到计划|加进我的计划|加到我的行程)/i,
        /(?:帮我加|加)\s*(.+?)(?:到行程|到计划|进计划|进行程)?$/i
    ];

    for (const pat of addPatterns) {
        const m = text.match(pat);
        if (m && m[1]) {
            let placeCandidate = m[1].replace(/[!?.]$/, '').replace(/\s+(?:please|lah|lor)$/i, '').trim();
            placeCandidate = placeCandidate.replace(/^the\s+/i, '').trim();
            // Strip any trailing "to plan / to my plan / to itinerary" that might be captured greedily
            placeCandidate = placeCandidate.replace(/\s+(?:to|into|in)\s+(?:my\s+|the\s+)?(?:plan|trip|itinerary|list)$/i, '').trim();

            if (placeCandidate === 'this' || placeCandidate === 'it' || placeCandidate === 'that') {
                return 'this';
            }

            if (placeCandidate.length > 1 && !isSystemAction(placeCandidate)) {
                if (isGenericCategoryPhrase(placeCandidate)) {
                    return null; // Route generic requests to suggestion engine for two options!
                }
                return placeCandidate;
            }
        }
    }

    // Fallback: if user says "add this to my plan" / "add this" / "help me add to plan"
    if (lower.includes('add') && (lower.includes('plan') || lower.includes('trip') || lower.includes('itinerary') || lower.includes('this'))) {
        return 'this';
    }

    return null;
}

// 🎯 Detect if user expressed interest/desire to visit a specific spot without an explicit ADD command
// e.g. "I want to visit Kek Lok Si", "I'd like to go to Blue Mansion", "我想去极乐寺"
// System will provide this spot as Option A, along with a complementary spot nearby as Option B!
function detectExpressedSpotDesire(msg) {
    if (!msg || typeof msg !== 'string') return null;
    let text = msg.trim();
    const lower = text.toLowerCase();

    // If it's already an explicit add command, skip (let detectAddOrVisitIntent handle it)
    if (/(?:add|insert|include|put|帮我加|加入行程|加进行程|加入计划|加进计划)\b/i.test(lower) || lower.startsWith('加 ')) {
        return null;
    }

    // Patterns for expressing desire to visit a place
    const desirePatterns = [
        // "i want to visit X" / "wanna go to X" / "would like to visit X" / "i want to see X"
        /(?:i\s+)?(?:also\s+)?(?:want\s+to\s+|want\s+|wanna\s+|would\s+like\s+to\s+|hoping\s+to\s+|wish\s+to\s+)(?:visit|go\s+to|head\s+to|see|check\s+out|explore)\s+([a-zA-Z0-9\s'&-]+)/i,

        // "can we visit X" / "let's go to X" / "jom visit X" / "what about visiting X"
        /(?:can\s+we\s+|let\'?s\s+|jom\s+)(?:visit|go\s+to|head\s+to|check\s+out)\s+([a-zA-Z0-9\s'&-]+)/i,
        /(?:what\s+about\s+|how\s+about\s+)(?:visiting\s+|going\s+to\s+)([a-zA-Z0-9\s'&-]+)/i,

        // Chinese: 我想去 [place] / 打算去 [place] / 想看看 [place] / 想参观 [place]
        /(?:我想去|我想参观|想去|打算去|计划去|想看看|想看|可以去)\s*(.+?)(?:好玩吗|怎么样|可以吗|行吗|[!?.])?$/i
    ];

    for (const pat of desirePatterns) {
        const m = text.match(pat);
        if (m && m[1]) {
            let placeCandidate = m[1].replace(/[!?.]$/, '').replace(/\s+(?:please|lah|lor)$/i, '').trim();
            placeCandidate = placeCandidate.replace(/^the\s+/i, '').trim();
            if (placeCandidate.length > 1 && !isSystemAction(placeCandidate)) {
                if (isGenericCategoryPhrase(placeCandidate)) {
                    return null;
                }
                return placeCandidate;
            }
        }
    }

    return null;
}

function formatPlaceForSuggestion(p, fallbackArea = 'Penang', defaultCoords = { lat: 5.414, lng: 100.328 }) {
    if (!p) return null;
    const name = (p.name || p.place_name || 'Penang Spot').trim();
    const area = p.area || extractArea(p) || fallbackArea || 'Penang';
    const category = p.primary_category || p.place_category || p.category || 'Attraction';
    const description = p.summary || p.place_summary || p.description || p.address || p.place_address || `${name} in ${area}, Penang`;
    const coords = p.location?.coordinates || p.place_location?.coordinates;
    const lng = Array.isArray(coords) ? coords[0] : (p.lng || defaultCoords.lng);
    const lat = Array.isArray(coords) ? coords[1] : (p.lat || defaultCoords.lat);
    const id = p._id ? p._id.toString() : (p.id || `place_${Date.now()}_${Math.random().toString(36).substring(7)}`);

    return {
        id,
        name,
        area,
        category,
        description,
        lat,
        lng
    };
}

// 7. Core Dispatcher & Execution
async function executeBirdChat({ mode = 'global_explorer', message, history = [], context = {} }) {
    // Validate draft_modifier requirement
    if (mode === 'draft_modifier' && !context.draftPlan) {
        context.draftPlan = { stops: [] };
    }

    const lowerMsg = message.toLowerCase().trim();
    const activeArea = resolveTargetArea(message, history, context) || 'Penang';
    const trace = {
        startTime: Date.now(),
        intentType: 'GENERAL_INQUIRY',
        extractedTarget: null,
        extractedKeywords: [],
        targetArea: activeArea !== 'Penang' ? activeArea : null,
        excludedPlaces: [],
        executionPath: 'MODEL_INTELLIGENCE_ONLY',
        dataSource: 'None',
        ragQuery: null,
        matchedEntity: null,
        groundingPlaces: [],
        searchStatus: 'SUCCESS',
        systemActionName: null,
        llmCalled: false,
        llmLatencyMs: 0
    };

    // 🎯 FAST SYSTEM ACTION DISPATCHER (Save & Optimize, Keep Exploring)
    if (isSystemAction(lowerMsg)) {
        trace.intentType = 'SYSTEM_ACTION';
        trace.executionPath = 'SYSTEM_ACTION';
        const isSaveAction = lowerMsg.includes('save') || lowerMsg.includes('optimize') || lowerMsg.includes('lock trip') || lowerMsg.includes('select dates');
        trace.systemActionName = isSaveAction ? 'SAVE_AND_OPTIMIZE_TRIP' : 'KEEP_EXPLORING';
        if (isSaveAction) {
            const saveResponse = {
                success: true,
                mode,
                message: "Jom lock in your travel dates! Once your dates are set, Weather Guard will automatically optimize your route sequence for sun, rain, and opening hours. 📅✨",
                reply: "Jom lock in your travel dates! Once your dates are set, Weather Guard will automatically optimize your route sequence for sun, rain, and opening hours. 📅✨",
                action: 'REQUIRE_DATES',
                emotion: 'happy',
                quickReplies: ['Select Dates 📅', 'Keep Planning 🗺️'],
                suggestedPlaces: [],
                model: DEFAULT_MODEL
            };
            logBirdInteraction({ mode, message, history, context, finalResponse: saveResponse, trace });
            return saveResponse;
        }
        const exploreResponse = {
            success: true,
            mode,
            message: "Flap flap! Let's keep exploring more places in Penang. What area or spots are you curious about next? 🚲🗺️",
            reply: "Flap flap! Let's keep exploring more places in Penang. What area or spots are you curious about next? 🚲🗺️",
            action: 'none',
            emotion: 'happy',
            quickReplies: [],
            suggestedPlaces: [],
            model: DEFAULT_MODEL
        };
        logBirdInteraction({ mode, message, history, context, finalResponse: exploreResponse, trace });
        return exploreResponse;
    }

    // 🎯 FAST REFERENCE RESOLUTION: Check if user selected "Add both suggestions", "Option A" or "Option B"
    const isExplicitAddBoth = lowerMsg === 'add both' || lowerMsg === 'add both suggestions' || lowerMsg === 'both' || lowerMsg.includes('add both');
    const isExplicitOptionA = lowerMsg === 'option a' || lowerMsg === 'a' || lowerMsg === 'option 1' || lowerMsg === '1' || lowerMsg === 'add option 1' || lowerMsg === 'add option a' || lowerMsg.startsWith('option a:') || lowerMsg.startsWith('option 1:');
    const isExplicitOptionB = lowerMsg === 'option b' || lowerMsg === 'b' || lowerMsg === 'option 2' || lowerMsg === '2' || lowerMsg === 'add option 2' || lowerMsg === 'add option b' || lowerMsg.startsWith('option b:') || lowerMsg.startsWith('option 2:');

    let directOptionName = null;
    if (lowerMsg.startsWith('option a:') || lowerMsg.startsWith('option 1:')) {
        directOptionName = message.replace(/^option\s*[a1]\s*[:：]\s*/i, '').trim();
    } else if (lowerMsg.startsWith('option b:') || lowerMsg.startsWith('option 2:')) {
        directOptionName = message.replace(/^option\s*[b2]\s*[:：]\s*/i, '').trim();
    }

    if (isExplicitAddBoth || isExplicitOptionA || isExplicitOptionB || directOptionName) {
        // Find the most recent assistant message
        const lastAssistantMsg = (Array.isArray(history) && history.length > 0)
            ? [...history].reverse().find(h => (h.role === 'assistant' || h.role === 'model' || h.sender === 'ai'))
            : null;
        const lastText = lastAssistantMsg ? (lastAssistantMsg.content || lastAssistantMsg.text || '') : '';
        const lastOptions = extractOptionsFromText(lastText);

        if (isExplicitAddBoth && lastAssistantMsg) {
            trace.intentType = 'OPTION_SELECTION';
            trace.executionPath = 'DETERMINISTIC_RAG';
            trace.extractedTarget = 'Both Options A & B';
            const placesToAdd = [];
            if (lastOptions.optionA) {
                const pa = await resolvePlaceByName(lastOptions.optionA, activeArea, trace);
                if (pa && !isSystemAction(pa.name)) placesToAdd.push(pa);
            }
            if (lastOptions.optionB) {
                const pb = await resolvePlaceByName(lastOptions.optionB, activeArea, trace);
                if (pb && !isSystemAction(pb.name)) placesToAdd.push(pb);
            }
            if (placesToAdd.length > 0) {
                const totalDraftCount = (context?.draftSpotCount || 0) + placesToAdd.length;
                const namesStr = placesToAdd.map(p => `**${p.name}**`).join(' and ');
                const promptSuffix = totalDraftCount >= 3
                    ? `You now have ${totalDraftCount} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨`
                    : `What other places in Penang would you like to visit next?`;
                const bothResponse = {
                    success: true,
                    mode,
                    message: `Steady lah! I've added both ${namesStr} to your travel plan (${totalDraftCount} total stops)! 🚲✨ ${promptSuffix}`,
                    reply: `Steady lah! I've added both ${namesStr} to your travel plan (${totalDraftCount} total stops)! 🚲✨ ${promptSuffix}`,
                    action: 'add_spot',
                    emotion: 'happy',
                    payload: {
                        suggestedPlaces: placesToAdd.map(p => ({
                            placeName: p.name,
                            category: p.category,
                            reason: p.description
                        }))
                    },
                    quickReplies: [],
                    suggestedPlaces: placesToAdd,
                    model: DEFAULT_MODEL
                };
                logBirdInteraction({ mode, message, history, context, finalResponse: bothResponse, trace });
                return bothResponse;
            }
        } else {
            const targetName = directOptionName || (isExplicitOptionA ? lastOptions.optionA : lastOptions.optionB);
            if (targetName && !isSystemAction(targetName)) {
                trace.intentType = 'OPTION_SELECTION';
                trace.executionPath = 'DETERMINISTIC_RAG';
                trace.extractedTarget = isExplicitOptionA ? `Option A: ${targetName}` : `Option B: ${targetName}`;
                const targetPlace = await resolvePlaceByName(targetName, activeArea, trace);
                    if (targetPlace) {
                        const totalDraftCount = (context?.draftSpotCount || 0) + 1;
                        const promptSuffix = totalDraftCount >= 3
                            ? `You now have ${totalDraftCount} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨`
                            : `What other places in Penang would you like to visit next?`;
                        const finalResponse = {
                            success: true,
                            mode: mode,
                            message: `Steady lah! I've added **${targetPlace.name}** to your travel plan (${totalDraftCount} total stops)! 🚲✨ ${promptSuffix}`,
                            reply: `Steady lah! I've added **${targetPlace.name}** to your travel plan (${totalDraftCount} total stops)! 🚲✨ ${promptSuffix}`,
                            action: 'add_spot',
                            emotion: 'happy',
                            payload: {
                                suggestedPlaces: [
                                    {
                                        placeName: targetPlace.name,
                                        category: targetPlace.category,
                                        reason: 'Selected option from conversation'
                                    }
                                ]
                            },
                            quickReplies: [],
                            suggestedPlaces: [targetPlace],
                            model: DEFAULT_MODEL
                        };

                        logBirdInteraction({
                            mode,
                            message,
                            history,
                            context,
                            finalResponse,
                            trace
                        });

                        return finalResponse;
                    }
                }
            }
        }

    // 🎯 FAST INTENT: Direct "Want to visit / Add [Place]" handling
    const addCandidate = detectAddOrVisitIntent(message);
    if (addCandidate) {
        trace.intentType = 'DIRECT_ADD_SPOT';
        trace.executionPath = 'DETERMINISTIC_RAG';
        trace.extractedTarget = addCandidate;

        let targetPlace = null;
        if (addCandidate === 'this' || addCandidate === 'it' || addCandidate.length <= 4) {
            const inqRes = await resolveTargetPlaceForInquiry(message, history, context);
            if (inqRes && inqRes.name) {
                targetPlace = await resolvePlaceByName(inqRes.name, activeArea, trace);
            }
        }
        if (!targetPlace) {
            targetPlace = await resolvePlaceByName(addCandidate, activeArea, trace);
        }
        if (targetPlace && !isSystemAction(targetPlace.name)) {
            const isIsland = activeArea && !/bukit mertajam|butterworth|seberang/i.test(activeArea);
            const targetAddress = `${targetPlace.place_address || ''} ${targetPlace.name || ''}`;
            if (isIsland && new RegExp(MAINLAND_REGEX, 'i').test(targetAddress)) {
                targetPlace = null;
            }
        }
        if (targetPlace && !isSystemAction(targetPlace.name)) {
            trace.matchedEntity = targetPlace;
            const totalDraftCount = (context?.draftSpotCount || 0) + 1;
            const promptSuffix = totalDraftCount >= 3
                ? `You now have ${totalDraftCount} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨`
                : `What other places in Penang would you like to visit next?`;
            const addResponse = {
                success: true,
                mode: mode,
                message: `I've added **${targetPlace.name}** to your travel plan (${totalDraftCount} total stops)! 🚲✨ ${promptSuffix}`,
                reply: `I've added **${targetPlace.name}** to your travel plan (${totalDraftCount} total stops)! 🚲✨ ${promptSuffix}`,
                action: 'add_spot',
                emotion: 'happy',
                payload: {
                    suggestedPlaces: [
                        {
                            placeName: targetPlace.name,
                            category: targetPlace.category,
                            reason: targetPlace.description
                        }
                    ]
                },
                quickReplies: [],
                suggestedPlaces: [targetPlace],
                model: DEFAULT_MODEL
            };

            logBirdInteraction({
                mode,
                message,
                history,
                context,
                finalResponse: addResponse,
                trace
            });

            return addResponse;
        } else {
            trace.searchStatus = 'NOT_FOUND';
            // Unverified place - do NOT blindly add fake place! Clarify with the user!
            const unverifiedResponse = {
                success: true,
                mode: mode,
                message: `I couldn't find a verified Penang location for **"${addCandidate}"** in my database or Penang map records. Could you check the exact name, or choose from popular spots like **Penang Hill** or **Kek Lok Si**? 🦜📍`,
                reply: `I couldn't find a verified Penang location for **"${addCandidate}"** in my database or Penang map records. Could you check the exact name, or choose from popular spots like **Penang Hill** or **Kek Lok Si**? 🦜📍`,
                action: 'none',
                emotion: 'thinking',
                payload: {},
                quickReplies: ['Recommend Penang food', '1-Day Heritage Tour'],
                suggestedPlaces: [],
                model: DEFAULT_MODEL
            };

            logBirdInteraction({
                mode,
                message,
                history,
                context,
                finalResponse: unverifiedResponse,
                trace
            });

            return unverifiedResponse;
        }
    }

    // Extract excluded places from history and draft plan
    const excludedPlaces = extractHistoryMentionedPlaces(history, context);
    trace.excludedPlaces = excludedPlaces;

    // 🎯 FAST INTENT CLASSIFIER & DISPATCHER (判断: Factual Inquiry vs. Recommendation vs. Itinerary Action)
    const userIntent = classifyUserIntent(message, history);
    const inquiryType = detectFactualInquiry(message, history);
    let isFactualQuery = (userIntent === 'FACTUAL_INQUIRY') || Boolean(inquiryType);
    if (userIntent === 'RECOMMENDATION_REQUEST' || userIntent === 'ITINERARY_ACTION') {
        isFactualQuery = false;
    }

    trace.intentType = userIntent || (isFactualQuery ? 'FACTUAL_INQUIRY' : 'RECOMMENDATION_REQUEST');
    trace.targetArea = resolveTargetArea(message, history, context);
    trace.targetPostcode = await resolveTargetPostcode(message, history, context);
    const reconciledChat = reconcileAreaAndPostcode(trace.targetArea, trace.targetPostcode, message, history);
    trace.targetArea = reconciledChat.targetArea;
    trace.targetPostcode = reconciledChat.targetPostcode;
    const resolvedCats = resolveTargetCategory(message, history);
    const resolvedKws = resolveTargetKeywords(message, history);
    trace.extractedKeywords = resolvedCats.length > 0 ? resolvedCats : resolvedKws;

    // Grounding: Find any verified facts for places mentioned in user query or history
    const mentionedFacts = findMentionedKnownFacts(message, history, context);

    // 🏛️ Specialized MongoDB RAG resolution for factual queries (Opening Hours, Ticket/Fees, Category, Address, etc.)
    let factualGrounding = null;
    if (isFactualQuery) {
        factualGrounding = await findFactualGroundingFromMongo(message, history, context, inquiryType, trace);
        if (factualGrounding) {
            trace.dataSource = factualGrounding.source || 'MongoDB (places_new collection)';
            trace.matchedEntity = factualGrounding;
            trace.ragQuery = `MongoDB RAG Factual Grounding for "${factualGrounding.name}" [Inquiry: ${inquiryType}]`;
        } else {
            trace.searchStatus = 'NOT_FOUND';
        }
    }

    // Retrieve grounding places from MongoDB with history exclusions and context
    const rawDbPlaces = isFactualQuery ? [] : await findRelevantPlaces(message, history, context, trace);

    const currentArea = trace.targetArea || activeArea || null;

    // Filter and guarantee neither place is in user's draft plan or excluded set, and strictly matches targetArea
    const candidatePlaces = (Array.isArray(rawDbPlaces) ? rawDbPlaces : []).filter(p => {
        const pName = p.place_name || p.name || '';
        const inArea = !currentArea || currentArea === 'Penang' || isPlaceInTargetArea(p, currentArea);
        return pName && inArea && !isPlaceInDraftPlan(pName, context) && !isPlaceExcluded(pName, excludedPlaces);
    });

    // Ensure we always have 2 distinct places (only for recommendation/suggestion requests, NEVER for factual inquiries!)
    if (!isFactualQuery && candidatePlaces.length < 2) {
        const areaToUse = currentArea || 'George Town';
        const areaComplements = getAreaCuratedPair(areaToUse, excludedPlaces);
        for (const c of areaComplements) {
            const cName = c.place_name || c.name || '';
            if (cName && !isPlaceInDraftPlan(cName, context) && !isPlaceExcluded(cName, excludedPlaces) &&
                !candidatePlaces.some(cp => (cp.place_name || cp.name || '').toLowerCase() === cName.toLowerCase())) {
                candidatePlaces.push(c);
                if (candidatePlaces.length >= 2) break;
            }
        }
    }
    // Only fall back to other island areas if user did NOT specify a specific target area
    if (!isFactualQuery && candidatePlaces.length < 2 && (!currentArea || currentArea === 'Penang' || currentArea === 'Penang Island')) {
        const fallbackAreas = ['George Town', 'Balik Pulau', 'Batu Ferringhi', 'Bayan Lepas'];
        for (const fb of fallbackAreas) {
            const fbComplements = getAreaCuratedPair(fb, excludedPlaces);
            for (const c of fbComplements) {
                const cName = c.place_name || c.name || '';
                if (cName && !isPlaceInDraftPlan(cName, context) && !isPlaceExcluded(cName, excludedPlaces) &&
                    !candidatePlaces.some(cp => (cp.place_name || cp.name || '').toLowerCase() === cName.toLowerCase())) {
                    candidatePlaces.push(c);
                    if (candidatePlaces.length >= 2) break;
                }
            }
            if (candidatePlaces.length >= 2) break;
        }
    }

    const dbPlaces = isFactualQuery ? [] : candidatePlaces.slice(0, 2);
    trace.groundingPlaces = isFactualQuery ? (factualGrounding ? [factualGrounding] : []) : dbPlaces;

    const isItineraryMutation = /^(?:delete|remove|clear|save|lock)\b/i.test(lowerMsg) ||
        lowerMsg.includes('remove spot') || lowerMsg.includes('delete spot') ||
        lowerMsg.includes('clear plan') || lowerMsg.includes('save and plan');

    // 🤖 MODEL INTELLIGENCE ENABLED (Hybrid RAG + LLM Grounding)
    if (dbPlaces.length > 0) {
        trace.executionPath = 'HYBRID_RAG_PLUS_LLM';
        trace.dataSource = 'MongoDB (places_new collection)';
        trace.ragQuery = `Address Filter (5-digit Postcode: "${trace.targetPostcode || 'N/A'}", Fallback Area: "${trace.targetArea || 'Penang'}", Categories: ${JSON.stringify(trace.extractedKeywords)})`;
        trace.groundingPlaces = dbPlaces;
    } else if (isFactualQuery && factualGrounding) {
        trace.executionPath = 'HYBRID_RAG_PLUS_LLM';
        trace.dataSource = factualGrounding.source || 'MongoDB (places_new collection)';
        trace.groundingPlaces = [factualGrounding];
    } else if (isFactualQuery && mentionedFacts.length > 0) {
        trace.executionPath = 'HYBRID_RAG_PLUS_LLM';
        trace.dataSource = 'Penang Knowledge Base (Verified Facts)';
        trace.ragQuery = `Landmark KB Grounding: ${mentionedFacts.map(f => f.name).join(', ')}`;
    } else {
        trace.executionPath = 'MODEL_INTELLIGENCE_ONLY';
        trace.dataSource = 'Ollama Knowledge Base';
    }

    // Build the dynamic system prompt with excluded places, verified facts, and MongoDB factual grounding injected
    const systemPrompt = buildPrompt(mode, context, dbPlaces, excludedPlaces, isFactualQuery, mentionedFacts, factualGrounding, inquiryType);

    // Assemble messages array with multi-turn history
    const messagesSent = [
        { role: 'system', content: systemPrompt }
    ];

    if (Array.isArray(history) && history.length > 0) {
        // Strip trailing message if duplicate of current user message
        const filteredHistory = history.filter((h, idx) => {
            if (idx === history.length - 1 && ((h.content && h.content.trim() === message.trim()) || (h.text && h.text.trim() === message.trim()))) {
                return false;
            }
            return true;
        });

        // Include only the most recent 2 conversation turns (up to 2 user + 2 assistant messages) for fast, focused memory
        const recentHistory = filteredHistory.slice(-4);
        recentHistory.forEach(h => {
            const role = (h.role === 'assistant' || h.role === 'model' || h.sender === 'ai') ? 'assistant' : 'user';
            const content = h.content || h.text || '';
            if (content.trim()) {
                messagesSent.push({ role, content });
            }
        });
    }

    // Add current user message
    messagesSent.push({ role: 'user', content: message });

    let rawModelResponse = '';
    let parsedPayload = null;
    let usedRuleBasedFallback = false;

    // 🤖 MODEL FIRST: Call Ollama with /api/chat (supports system + user + assistant history)
    trace.llmCalled = true;
    const llmStartTime = Date.now();
    try {
        const fetchTimeoutSignal = (typeof AbortSignal.timeout === 'function') 
            ? AbortSignal.timeout(15000) 
            : undefined;

        const chatRes = await fetch(OLLAMA_CHAT_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            signal: fetchTimeoutSignal,
            body: JSON.stringify({
                model: DEFAULT_MODEL,
                messages: messagesSent,
                stream: false,
                format: (mode === 'draft_modifier' && !isFactualQuery) ? 'json' : undefined,
                temperature: 0.3
            })
        });

        if (chatRes.ok) {
            const chatData = await chatRes.json();
            rawModelResponse = chatData.message?.content || '';
        } else {
            // Fallback to /api/generate
            const genRes = await fetch(OLLAMA_GEN_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                signal: fetchTimeoutSignal,
                body: JSON.stringify({
                    model: DEFAULT_MODEL,
                    system: systemPrompt,
                    prompt: message,
                    stream: false,
                    format: (mode === 'draft_modifier' && !isFactualQuery) ? 'json' : undefined,
                    temperature: 0.3
                })
            });
            if (genRes.ok) {
                const genData = await genRes.json();
                rawModelResponse = genData.response || '';
            }
        }
    } catch (err) {
        console.warn('Ollama invocation error / timeout, falling back to rule-based engine:', err.message);
    } finally {
        trace.llmLatencyMs = Date.now() - llmStartTime;
    }

    // 🛡️ RULE-BASED FALLBACK: If model failed, timed out, or returned empty text, fall back to rule-based engine!
    if (!rawModelResponse || !rawModelResponse.trim()) {
        usedRuleBasedFallback = true;
        if (isFactualQuery || inquiryType) {
            console.log('📌 [FALLBACK] Resolving factual inquiry using Rule-Based Knowledge Engine...');
            rawModelResponse = await generateRuleBasedFactualReply(message, history, context, inquiryType);
        } else if (dbPlaces.length > 0) {
            console.log('📌 [FALLBACK] Generating place recommendations using MongoDB Grounding Engine...');
            const p1 = dbPlaces[0];
            const p2 = dbPlaces[1] || dbPlaces[0];
            rawModelResponse = `*Flap flap!* Here are two wonderful spots in Penang for you:\n\n[Option A]: **${p1.place_name}** - ${p1.place_summary || p1.place_address || 'Notable Penang spot'}\n\n[Option B]: **${p2.place_name}** - ${p2.place_summary || p2.place_address || 'Great local attraction'}\n\nWhich one would you like to explore first? 🚲🗺️`;
        } else {
            rawModelResponse = `*Flap flap!* I am right here with you! Tell me what places or food in Penang you'd like to explore next. 🦜✨`;
        }
    }

    // Format Dispatched Response based on Mode
    let finalResponse = {};

    // 🔍 Auto-extract Option A and Option B from model output if present in markdown text
    const textOptions = extractOptionsFromText(rawModelResponse);
    let structuredSuggested = (dbPlaces || []).map((p, idx) => ({
        id: p._id ? p._id.toString() : `db_${idx}`,
        name: p.place_name,
        area: extractArea(p),
        category: p.place_category || 'Attraction',
        description: p.place_summary || p.place_address || '',
        lat: p.place_location?.coordinates ? p.place_location.coordinates[1] : 5.414,
        lng: p.place_location?.coordinates ? p.place_location.coordinates[0] : 100.328
    }));

    // If model explicitly mentioned Option A / Option B in text, hydrate those places!
    const activeAreaForHydrate = trace?.targetArea || 'Penang';
    const defaultCoords = getAreaDefaultCoordinates(activeAreaForHydrate);

    let textHydrationAreaMismatch = false;

    if (!isFactualQuery && (textOptions.optionA || textOptions.optionB || textOptions.rawA || textOptions.rawB)) {
        const hydratedPlaces = [];
        if (textOptions.rawA || textOptions.optionA) {
            const queryA = textOptions.rawA || textOptions.optionA;
            if (!isSystemAction(queryA)) {
                let pa = await resolvePlaceByName(queryA, activeAreaForHydrate);
                if (!pa && textOptions.optionA && textOptions.optionA !== queryA) {
                    pa = await resolvePlaceByName(textOptions.optionA, activeAreaForHydrate);
                }
                if (!pa) {
                    const fallbackName = textOptions.optionA || textOptions.rawA;
                    pa = {
                        id: `optionA_${Date.now()}`,
                        name: fallbackName,
                        area: activeAreaForHydrate,
                        category: 'Attraction',
                        description: `Recommended spot in ${activeAreaForHydrate}: ${fallbackName}`,
                        lat: defaultCoords.lat,
                        lng: defaultCoords.lng
                    };
                }
                if (pa && !isSystemAction(pa.name)) {
                    if (activeAreaForHydrate && activeAreaForHydrate !== 'Penang') {
                        const areaA = normalizeAreaName(pa.area || extractArea(pa));
                        if (areaA && areaA !== 'Penang' && areaA.toLowerCase() !== activeAreaForHydrate.toLowerCase()) {
                            console.warn(`[AREA FILTER] Filtered out Option A ${pa.name} (${areaA}) because activeAreaForHydrate is ${activeAreaForHydrate}`);
                            textHydrationAreaMismatch = true;
                            pa = null;
                        }
                    }
                    if (pa) hydratedPlaces.push(pa);
                }
            }
        }
        if (textOptions.rawB || textOptions.optionB) {
            const queryB = textOptions.rawB || textOptions.optionB;
            if (!isSystemAction(queryB)) {
                let pb = await resolvePlaceByName(queryB, activeAreaForHydrate);
                if (!pb && textOptions.optionB && textOptions.optionB !== queryB) {
                    pb = await resolvePlaceByName(textOptions.optionB, activeAreaForHydrate);
                }
                if (!pb) {
                    const fallbackName = textOptions.optionB || textOptions.rawB;
                    pb = {
                        id: `optionB_${Date.now()}`,
                        name: fallbackName,
                        area: activeAreaForHydrate,
                        category: 'Attraction',
                        description: `Recommended spot in ${activeAreaForHydrate}: ${fallbackName}`,
                        lat: defaultCoords.lat,
                        lng: defaultCoords.lng
                    };
                }
                if (pb && !isSystemAction(pb.name)) {
                    if (activeAreaForHydrate && activeAreaForHydrate !== 'Penang') {
                        const areaB = normalizeAreaName(pb.area || extractArea(pb));
                        if (areaB && areaB !== 'Penang' && areaB.toLowerCase() !== activeAreaForHydrate.toLowerCase()) {
                            console.warn(`[AREA FILTER] Filtered out Option B ${pb.name} (${areaB}) because activeAreaForHydrate is ${activeAreaForHydrate}`);
                            textHydrationAreaMismatch = true;
                            pb = null;
                        }
                    }
                    if (pb) hydratedPlaces.push(pb);
                }
            }
        }
        if (hydratedPlaces.length >= 2) {
            structuredSuggested = hydratedPlaces;
            isFactualQuery = false;
        } else if (textHydrationAreaMismatch && dbPlaces.length > 0) {
            console.log(`[AREA FILTER] Falling back to verified MongoDB dbPlaces in ${activeAreaForHydrate}:`, dbPlaces.map(p => p.place_name || p.name).join(', '));
            structuredSuggested = (dbPlaces || []).map((p, idx) => ({
                id: p._id ? p._id.toString() : `db_${idx}`,
                name: p.place_name || p.name,
                area: extractArea(p) || activeAreaForHydrate,
                category: p.place_category || p.primary_category || 'Attraction',
                description: p.place_summary || p.summary || p.place_address || '',
                lat: p.place_location?.coordinates ? p.place_location.coordinates[1] : 5.414,
                lng: p.place_location?.coordinates ? p.place_location.coordinates[0] : 100.328
            }));
        } else if (hydratedPlaces.length > 0 && (!dbPlaces || dbPlaces.length === 0)) {
            structuredSuggested = hydratedPlaces;
            isFactualQuery = false;
        }
    }

    // Deduplicate structuredSuggested and filter out excluded places so Option A / B never duplicate existing stops
    const uniqueStructured = [];
    const seenNames = new Set();
    for (const p of structuredSuggested) {
        const low = (p.name || p.placeName || '').toLowerCase().trim();
        if (low && !seenNames.has(low) && !isPlaceExcluded(low, excludedPlaces) && !isPlaceInDraftPlan(low, context) && !isSystemAction(low)) {
            seenNames.add(low);
            uniqueStructured.push(p);
        }
    }
    structuredSuggested = isFactualQuery ? [] : uniqueStructured;

    // 🎯 STRICT TWO OPTIONS GUARANTEE: If only 1 place suggested, pair with 2nd place within activeArea!
    if (!isFactualQuery && structuredSuggested.length === 1) {
        const secondCandidates = (dbPlaces && dbPlaces.length >= 2)
            ? [dbPlaces[1]]
            : getAreaCuratedPair(activeAreaForHydrate, excludedPlaces);
        const complement = secondCandidates.find(c => {
            const cName = (c.name || c.place_name || '').toLowerCase().trim();
            return cName && cName !== structuredSuggested[0].name.toLowerCase().trim() && !isPlaceExcluded(cName, excludedPlaces) && !isPlaceInDraftPlan(cName, context);
        });
        if (complement) {
            const normComplement = {
                id: complement._id ? complement._id.toString() : (complement.id || `curated_${Date.now()}`),
                name: complement.place_name || complement.name,
                area: extractArea(complement) || activeAreaForHydrate,
                category: complement.place_category || complement.category || 'Attraction',
                description: complement.place_summary || complement.description || '',
                lat: complement.lat || (complement.place_location?.coordinates ? complement.place_location.coordinates[1] : defaultCoords.lat),
                lng: complement.lng || (complement.place_location?.coordinates ? complement.place_location.coordinates[0] : defaultCoords.lng)
            };
            structuredSuggested.push(normComplement);
        }
    }

    if (mode === 'draft_modifier') {
        const cleaned = extractCleanMessageAndPayload(rawModelResponse);
        parsedPayload = cleaned;

        if (isFactualQuery) {
            structuredSuggested = [];
            parsedPayload.action = 'none';
            parsedPayload.payload = {};
        } else {
            // Reference resolution fallback: if user said "add this pasar malam"
            if ((lowerMsg.includes('add this') || lowerMsg.includes('add the') || lowerMsg.includes('add pasar malam')) && dbPlaces.length > 0) {
                if (parsedPayload.action === 'none') {
                    parsedPayload.action = 'add_spot';
                    parsedPayload.payload = parsedPayload.payload || {};
                    parsedPayload.payload.suggestedPlaces = [
                        {
                            placeName: dbPlaces[0].place_name,
                            category: dbPlaces[0].place_category || 'Night Markets (Pasar Malam)',
                            reason: 'Added from previous conversation'
                        }
                    ];
                }
            }

            // If the model provided suggestedPlaces in payload, resolve them to ensure structured details
            if (Array.isArray(parsedPayload.payload?.suggestedPlaces) && parsedPayload.payload.suggestedPlaces.length > 0) {
                const resolvedFromPayload = [];
                const targetArea = trace?.targetArea || resolveTargetArea(message, history, context);
                for (const sp of parsedPayload.payload.suggestedPlaces) {
                    const rawName = typeof sp === 'string' ? sp : (sp.placeName || sp.name || '');
                    if (rawName) {
                        let resolved = await resolvePlaceByName(rawName, targetArea);
                        // Fallback synthesis: If not in MongoDB or OSM, do not discard! Synthesize valid place object
                        if (!resolved && !isSystemAction(rawName)) {
                            const inferredArea = targetArea && targetArea !== 'Penang' 
                                ? targetArea 
                                : (detectMatchedAreas(rawName)[0] || 'Penang');
                            const defaultCoords = getAreaDefaultCoordinates(inferredArea);
                            resolved = {
                                id: `sug_${Date.now()}_${Math.random().toString(36).substring(7)}`,
                                name: rawName,
                                area: inferredArea,
                                category: sp.category || 'Cafes',
                                description: sp.reason || sp.description || `${rawName} in ${inferredArea}, Penang.`,
                                lat: defaultCoords.lat,
                                lng: defaultCoords.lng
                            };
                            // Auto-cache into MongoDB (places_new) so database continuously expands
                            PlaceNew.updateOne(
                                { name: rawName },
                                {
                                    $setOnInsert: {
                                        name: rawName,
                                        summary: resolved.description,
                                        primary_category: resolved.category,
                                        address: `${rawName}, ${inferredArea}, Penang`,
                                        area: inferredArea,
                                        location: { type: 'Point', coordinates: [resolved.lng, resolved.lat] },
                                        status: 'active'
                                    }
                                },
                                { upsert: true }
                            ).catch(e => console.warn('Auto-caching synthesized place failed:', e.message));
                        }

                        if (resolved && !isSystemAction(resolved.name)) {
                            // Enforce area boundary if anchored in a specific area (e.g. George Town, Balik Pulau)
                            if (targetArea && targetArea !== 'Penang') {
                                const normResolved = normalizeAreaName(resolved.area || extractArea(resolved));
                                if (normResolved && normResolved !== 'Penang' && normResolved.toLowerCase() !== targetArea.toLowerCase()) {
                                    console.warn(`[AREA FILTER] Filtered out ${resolved.name} (${normResolved}) because targetArea is ${targetArea}`);
                                    continue;
                                }
                            }
                            resolvedFromPayload.push(resolved);
                        }
                    }
                }
                if (resolvedFromPayload.length >= 2 || (resolvedFromPayload.length > 0 && (!dbPlaces || dbPlaces.length === 0))) {
                    structuredSuggested = resolvedFromPayload;
                } else if (dbPlaces.length > 0) {
                    console.log(`[AREA FILTER] Falling back to grounded dbPlaces for ${targetArea}:`, dbPlaces.map(p => p.place_name || p.name).join(', '));
                    structuredSuggested = (dbPlaces || []).map((p, idx) => ({
                        id: p._id ? p._id.toString() : `db_${idx}`,
                        name: p.place_name || p.name,
                        area: extractArea(p) || targetArea,
                        category: p.place_category || p.primary_category || 'Attraction',
                        description: p.place_summary || p.summary || p.place_address || '',
                        lat: p.place_location?.coordinates ? p.place_location.coordinates[1] : 5.414,
                        lng: p.place_location?.coordinates ? p.place_location.coordinates[0] : 100.328
                    })).slice(0, 2);
                }
            }

            // 🛡️ STRICT DIRECT_ADD_SPOT RULE:
            // ONLY if user explicitly issued an ADD command (e.g., "Add X to plan", "Add X", "帮我加"),
            // allow action to be 'add_spot'.
            // If user said "I want to visit...", "wanna see...", "我想去...", DO NOT DIRECT ADD!
            // Convert action to 'suggest_spots' so user can select/add it themselves!
            const isExplicitAdd = Boolean(detectAddOrVisitIntent(message));
            if (parsedPayload.action === 'add_spot' && !isExplicitAdd) {
                parsedPayload.action = 'suggest_spots';
                if (dbPlaces.length > 0) {
                    structuredSuggested = dbPlaces.slice(0, 2);
                }
            }

            // If action is add_spot, ensure we ONLY return the single targeted place
            if (parsedPayload.action === 'add_spot') {
                const targetName = parsedPayload.payload?.suggestedPlaces?.[0]?.placeName?.toLowerCase() || 
                                   (typeof parsedPayload.payload?.suggestedPlaces?.[0] === 'string' ? parsedPayload.payload.suggestedPlaces[0].toLowerCase() : '');
                if (targetName && structuredSuggested.length > 0) {
                    const matched = structuredSuggested.find(p => p.name.toLowerCase().includes(targetName) || targetName.includes(p.name.toLowerCase()));
                    if (matched) {
                        structuredSuggested = [matched];
                    } else {
                        structuredSuggested = structuredSuggested.slice(0, 1);
                    }
                } else if (structuredSuggested.length > 0) {
                    structuredSuggested = structuredSuggested.slice(0, 1);
                }
            } else {
                // When suggesting spots, guarantee exactly 2 options
                if (structuredSuggested.length === 1) {
                    const activeAreaFallback = trace?.targetArea || 'Penang';
                    const curated = getAreaCuratedPair(activeAreaFallback, excludedPlaces);
                    const extra = curated.find(c => c.name.toLowerCase() !== structuredSuggested[0].name.toLowerCase());
                    if (extra) {
                        const defaultCoords = getAreaDefaultCoordinates(activeAreaFallback);
                        structuredSuggested.push({
                            id: extra.id || `curated_${Date.now()}`,
                            name: extra.name,
                            area: activeAreaFallback,
                            category: extra.category,
                            description: extra.description,
                            lat: defaultCoords.lat,
                            lng: defaultCoords.lng
                        });
                    }
                }
                structuredSuggested = structuredSuggested.slice(0, 2);
            }
        }

        // Ensure quickReplies and structuredSuggested are strictly synchronized in count and identity!
        let rawQuickReplies = [];
        if (!isFactualQuery && parsedPayload.action !== 'add_spot' && structuredSuggested.length >= 2) {
            rawQuickReplies = [
                `Option A: ${structuredSuggested[0].name}`,
                `Option B: ${structuredSuggested[1].name}`
            ];
        } else if (!isFactualQuery && parsedPayload.action === 'add_spot' && structuredSuggested.length === 1) {
            rawQuickReplies = [
                `Add ${structuredSuggested[0].name}`
            ];
        } else if (Array.isArray(parsedPayload.payload?.quickReplies)) {
            rawQuickReplies = parsedPayload.payload.quickReplies.map(qr => {
                if (typeof qr !== 'string') return qr;
                return qr.replace(/["']/g, '').trim();
            });
        }
        const modelAction = parsedPayload.action || 'none';
        const isRemoveAction = modelAction === 'remove_spots' || modelAction === 'remove_spot';
        let finalAction = isFactualQuery ? 'none' : ((modelAction === 'suggest_spots' || modelAction === 'add_spot' || isRemoveAction) ? (isRemoveAction ? 'remove_spots' : modelAction) : 'none');

        // Check if message itself states removal if finalAction is still none
        if (!isFactualQuery && finalAction === 'none' && parsedPayload.message) {
            const textSeq = parsedPayload.message.match(/removed\s+(?:stop\s+|spot\s+|#)?(\d+)/i);
            if (textSeq && textSeq[1]) {
                finalAction = 'remove_spots';
                parsedPayload.payload = parsedPayload.payload || {};
                parsedPayload.payload.targetSequences = [parseInt(textSeq[1], 10)];
            }
        }

        // If remove action, clear suggested places and quick replies so we don't accidentally offer add options
        if (finalAction === 'remove_spots') {
            structuredSuggested = [];
            rawQuickReplies = [];
            if (!Array.isArray(parsedPayload.payload?.targetSequences) || parsedPayload.payload.targetSequences.length === 0) {
                const textSeq = (parsedPayload.message || '').match(/removed\s+(?:stop\s+|spot\s+|#)?(\d+)/i) || message.match(/^(?:remove|delete|drop)?\s*(?:stop\s+|spot\s+|#)?(\d+)$/i);
                if (textSeq && textSeq[1]) {
                    parsedPayload.payload = parsedPayload.payload || {};
                    parsedPayload.payload.targetSequences = [parseInt(textSeq[1], 10)];
                }
            }
        }

        // 🛡️ CRITICAL GUARANTEE: If quickReplies has >= 2 options, ensure structuredSuggested has both places!
        if (!isFactualQuery && finalAction !== 'add_spot' && finalAction !== 'remove_spots' && rawQuickReplies.length >= 2 && structuredSuggested.length < 2) {
            const activeAreaFallback = trace?.targetArea || resolveTargetArea(message, history, context) || 'George Town';
            structuredSuggested = await hydratePlacesFromQuickReplies(rawQuickReplies, structuredSuggested, activeAreaFallback);
        }

        const cappedQuickReplies = isFactualQuery ? [] : (Array.isArray(rawQuickReplies) ? rawQuickReplies.slice(0, 2) : []);
        let cleanMessage = parsedPayload.message || "I've reviewed your itinerary update!";
        if (!isFactualQuery && finalAction !== 'add_spot' && finalAction !== 'remove_spots' && structuredSuggested.length >= 2) {
            cleanMessage = ensureBothOptionsInMessage(cleanMessage, structuredSuggested[0], structuredSuggested[1]);
        }

        finalResponse = {
            success: true,
            mode: 'draft_modifier',
            message: cleanMessage,
            reply: cleanMessage,
            action: isFactualQuery ? 'none' : finalAction,
            payload: isFactualQuery ? {} : (parsedPayload.payload || {}),
            quickReplies: cappedQuickReplies,
            suggestedPlaces: isFactualQuery ? [] : structuredSuggested,
            options: isFactualQuery ? [] : structuredSuggested.slice(0, 2),
            isFactualInquiry: isFactualQuery,
            model: DEFAULT_MODEL
        };
    } else {
        // global_explorer / in_trip_assistant
        let quickReplies = [];
        let suggestedPlaces = [];
        let options = [];

        if (!isFactualQuery) {
            if (structuredSuggested.length >= 2) {
                quickReplies = [
                    `Option A: ${structuredSuggested[0].name}`,
                    `Option B: ${structuredSuggested[1].name}`
                ];
            } else if (textOptions.optionA && textOptions.optionB) {
                quickReplies = [
                    `Option A: ${textOptions.optionA}`,
                    `Option B: ${textOptions.optionB}`
                ];
            } else if (structuredSuggested.length === 1 && (lowerMsg.includes('add') || lowerMsg.includes('recommend') || lowerMsg.includes('visit'))) {
                quickReplies = [
                    `Add ${structuredSuggested[0].name}`
                ];
            }

            // 🛡️ CRITICAL GUARANTEE: If quickReplies has >= 2 options, ensure structuredSuggested has both places!
            if (quickReplies.length >= 2 && structuredSuggested.length < 2) {
                const activeAreaFallback = trace?.targetArea || resolveTargetArea(message, history, context) || 'George Town';
                structuredSuggested = await hydratePlacesFromQuickReplies(quickReplies, structuredSuggested, activeAreaFallback);
            }

            // Clean quickReplies so system actions are never prefixed with Option A: / Option B:
            quickReplies = quickReplies.map(qr => {
                if (isSystemAction(qr)) {
                    return qr.replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*/i, '').trim();
                }
                return qr;
            });

            structuredSuggested = structuredSuggested.filter(p => p && !isSystemAction(p.name));
            suggestedPlaces = structuredSuggested.slice(0, 2);
            options = structuredSuggested.slice(0, 2);
        } else {
            quickReplies = [];
            suggestedPlaces = [];
            options = [];
        }

        const cleaned = extractCleanMessageAndPayload(rawModelResponse);
        let cleanMessage = cleaned.message || rawModelResponse;

        let globalAction = 'none';
        if (!isFactualQuery) {
            const isExplicitAdd = Boolean(detectAddOrVisitIntent(message));
            if (cleaned.payload && cleaned.payload.action) {
                globalAction = (cleaned.payload.action === 'add_spot' && !isExplicitAdd) ? 'suggest_spots' : cleaned.payload.action;
            } else if (isExplicitAdd) {
                globalAction = 'add_spot';
            } else if (suggestedPlaces.length > 0) {
                globalAction = 'suggest_spots';
            }
        }

        if (globalAction === 'add_spot' && suggestedPlaces.length === 0) {
            const fallbackAdd = detectAddOrVisitIntent(message);
            if (fallbackAdd) {
                const p = await resolvePlaceByName(fallbackAdd);
                if (p) {
                    suggestedPlaces = [p];
                    options = [p];
                }
            }
        }

        if (!isFactualQuery && globalAction !== 'add_spot' && suggestedPlaces.length >= 2) {
            cleanMessage = ensureBothOptionsInMessage(cleanMessage, suggestedPlaces[0], suggestedPlaces[1]);
        }

        finalResponse = {
            success: true,
            mode: mode,
            message: cleanMessage,
            reply: cleanMessage,
            action: isFactualQuery ? 'none' : globalAction,
            quickReplies: isFactualQuery ? [] : quickReplies.slice(0, 2),
            suggestedPlaces: isFactualQuery ? [] : suggestedPlaces,
            options: isFactualQuery ? [] : options,
            isFactualInquiry: isFactualQuery,
            model: DEFAULT_MODEL
        };
    }

    // Print to JS Console
    logBirdInteraction({
        mode,
        message,
        history,
        context,
        systemPrompt,
        messagesSent,
        rawModelResponse,
        finalResponse,
        trace
    });

    return finalResponse;
}

module.exports = {
    executeBirdChat,
    logBirdInteraction,
    buildPrompt,
    BASE_PERSONA,
    extractOptionsFromText,
    extractHistoryMentionedPlaces,
    findRelevantPlaces,
    resolvePlaceByName,
    classifyUserIntent,
    detectFactualInquiry,
    extractArea,
    resolveTargetArea,
    resolveTargetPostcode,
    buildPostcodeQuery,
    searchPlacesWithPostcodeAndAreaFallback,
    extractDraftPlanPlaceNames,
    isPlaceInDraftPlan,
    isPlaceExcluded,
    extractCleanMessageAndPayload,
    reconcileAreaAndPostcode,
    resolveTargetCategory,
    resolveTargetKeywords,
    detectAddOrVisitIntent,
    detectExpressedSpotDesire,
    formatMongoFilterForTerminal,
    ensureBothOptionsInMessage,
    isPlaceInTargetArea,
    findFactualGroundingFromMongo,
    extractTargetPlaceNameFromText
};

