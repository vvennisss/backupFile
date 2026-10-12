const express = require('express');
const router = express.Router();
const fetch = require('node-fetch'); 
const PlaceNew = require('../models/PlaceNew');
const { executeBirdChat, classifyUserIntent, extractCleanMessageAndPayload } = require('../services/birdPersonaEngine');

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434/api/generate'; 
const OLLAMA_EMBED_URL = process.env.OLLAMA_EMBED_URL || 'http://127.0.0.1:11434/api/embeddings';
const EMBED_MODEL = process.env.EMBED_MODEL || 'llama3.2:3b'; 

// Known Penang Areas
const PENANG_AREAS = [
    'Batu Ferringhi', 'George Town', 'Georgetown', 'Air Itam', 'Ayer Itam',
    'Bayan Lepas', 'Tanjung Bungah', 'Tanjung Tokong', 'Gurney', 'Pulau Tikus',
    'Gelugor', 'Balik Pulau', 'Teluk Bahang', 'Butterworth', 'Bukit Mertajam',
    'Seberang Perai', 'Nibong Tebal', 'Kepala Batas'
];

// Comprehensive category keyword mappings for all 47 MongoDB categories
const CATEGORY_KEYWORDS = {
    'clan houses': ['clan house', 'clan houses', 'kongsi', 'ancestral hall', 'association hall', 'chinese clan'],
    'clan jetty': ['clan jetty', 'clan jetties', 'chew jetty', 'tan jetty', 'lee jetty', 'wooden pier', 'water village'],
    'beaches': ['beach', 'beaches', 'pantai', 'coast', 'coastal', 'seaside', 'sea', 'shore', 'bay', 'sunset spot', 'sand', 'beachfront', 'island'],
    'nature & parks': ['nature', 'park', 'national park', 'botanical', 'hill', 'garden', 'forest', 'hiking', 'flora', 'tree', 'green', 'waterfall', 'outdoors', 'river'],
    'Cafes': ['cafe', 'cafes', 'coffee', 'kopi', 'tea', 'matcha', 'latte', 'espresso', 'brunch'],
    'Dessert and Pastry': ['dessert', 'pastry', 'cake', 'bakery', 'waffle', 'ice cream', 'cendol', 'ais kacang', 'boba', 'sweet'],
    'Hawker Centres & Food Courts': ['hawker', 'food court', 'stall', 'medan selera', 'kopitiam', 'street food', 'char kway teow', 'laksa', 'hokkien mee'],
    'food & beverages': ['food', 'makan', 'restaurant', 'dinner', 'lunch', 'breakfast', 'noodle', 'rice', 'seafood', 'dining'],
    'Halal restaurant': ['halal', 'muslim', 'nasi kandar', 'roti canai', 'mee goreng', 'murtabak', 'briyani'],
    'Street Art & Murals': ['street art', 'mural', 'wall art', 'armenian street art', 'graffiti', 'painting', 'artwork'],
    'Museums & Galleries': ['museum', 'gallery', 'art exhibition', 'peranakan', 'wonderfood', 'heritage museum'],
    'places of worship': ['temple', 'mosque', 'church', 'shrine', 'pagoda', 'kek lok si', 'kapitan keling', 'st george', 'wat', 'worship'],
    'cultural & heritage': ['heritage', 'history', 'historic', 'historical sites', 'historic buildings', 'monuments', 'fort', 'colonial', 'unesco', 'mausoleums & cemeteries'],
    'Accommodations & Hotels': ['hotel', 'stay', 'resort', 'homestay', 'hostel', 'inn', 'lodge', 'apartments', 'suite', 'villa'],
    'adventure': ['adventure', 'escape', 'theme park', 'water park', 'zip line', 'thrill', 'kayak'],
    'bars & bistros': ['bar', 'bistro', 'pub', 'cocktail', 'nightlife', 'wine', 'beer', 'lounge'],
    'Night Markets (Pasar Malam)': ['night market', 'pasar malam', 'evening market'],
    'shopping & malls': ['shopping', 'mall', 'gurney plaza', 'queensbay', 'store', 'plaza', 'local handicrafts & souvenirs'],
    'Wellness & Spas': ['spa', 'wellness', 'massage', 'reflexology'],
};

// 1. Phrasal patterns to strip from the edges (prevents aggressive middle-word deletions)
const INTENT_PREFIX_PATTERNS = [
    /^(can\s+you\s+)?(please\s+)?(tell\s+me|show\s+me|check|find|recommend|suggest)\s+(about\s+|for\s+)?/i,
    /^(what\s+is|what\s+are|where\s+is|where\s+are|how\s+to\s+go\s+to)\s+/i,
    /^(i\s+want\s+to\s+(go\s+to|visit|see)|looking\s+for)\s+/i,
    /^(is|are)\s+/i
];

const QUESTION_SUFFIX_PATTERNS = [
    /\s+(business\s+hours?|opening\s+hours?|hours?|timing|ticket\s+price|entry\s+fee|fee|cost|location|address)(\s+like|\s+now|\s+today|\s+currently)?\??$/i,
    /\s+(open|closed?|operating)(\s+today|\s+now|\s+tomorrow)?\??$/i
];

// 2. Focused word-level filter (keep this lean)
const QUESTION_FILTER_WORDS = new Set([
    // Basic auxiliaries
    'is', 'are', 'was', 'were', 'do', 'does', 'did', 'can', 'could', 'would', 'should',
    // Question pronouns
    'what', 'where', 'when', 'which', 'who', 'why', 'how',
    // Common prepositions (use with caution: only strip if isolated)
    'near', 'around', 'nearby',
    // Metadata query terms
    'hour', 'hours', 'time', 'timing', 'open', 'opening', 'close', 'closing', 'closed',
    'price', 'ticket', 'fee', 'cost', 'fare', 'entry', 'rate', 'rates',
    'address', 'location', 'contact', 'phone', 'tel', 'website',
    // Conversational fillers & local particles
    'please', 'tell', 'show', 'check', 'recommend', 'suggest', 'details', 'info'
]);

const STOP_WORDS = new Set([
    'add', 'me', 'one', 'two', 'three', 'four', 'five', 'or', 'and', 'i', 'want', 'to', 'go',
    'visit', 'find', 'see', 'any', 'the', 'a', 'an', 'in', 'at', 'on', 'near', 'around', 'area',
    'please', 'can', 'you', 'recommend', 'suggest', 'where', 'what', 'good', 'best', 'some',
    'for', 'looking', 'spot', 'spots', 'place', 'places', 'option', 'options', 'bring',
    'show', 'give', 'tell', 'about', 'like', 'with', 'from', 'help'
]);

/**
 * Clean user input to isolate entity / topic keywords.
 */
function extractTargetSearchTerm(rawInput) {
    if (!rawInput || typeof rawInput !== 'string') return '';

    // Step 1: Normalize (lowercase, remove excess punctuation except hyphens/apostrophes)
    let cleaned = rawInput.trim().toLowerCase().replace(/[?,!;:"]/g, '');

    // Step 2: Strip outer phrasal question wrappers
    for (const pattern of INTENT_PREFIX_PATTERNS) {
        cleaned = cleaned.replace(pattern, '');
    }
    for (const pattern of QUESTION_SUFFIX_PATTERNS) {
        cleaned = cleaned.replace(pattern, '');
    }

    cleaned = cleaned.trim();

    // Step 3: Tokenize and filter residual standalone stop words
    const tokens = cleaned.split(/\s+/);
    const retainedTokens = tokens.filter((token) => !QUESTION_FILTER_WORDS.has(token) && !STOP_WORDS.has(token));

    // Fallback: If filtering stripped everything (e.g. user just typed "opening hours"),
    // return the cleaned prefix-stripped input rather than an empty string.
    return retainedTokens.length > 0 ? retainedTokens.join(' ') : cleaned;
}

// Helper: Format business hours object into readable string
function formatBusinessHours(hours) {
    if (!hours) return 'Opening hours not listed';
    if (typeof hours === 'string') return hours;
    if (typeof hours === 'object') {
        const entries = Object.entries(hours);
        if (entries.length === 0) return 'Opening hours not listed';
        return entries.map(([day, time]) => `${day.charAt(0).toUpperCase() + day.slice(1)}: ${time}`).join(', ');
    }
    return 'Opening hours not listed';
}

// Helper: Determine if category is primarily outdoor
function isOutdoorCategory(category = '') {
    const cat = category.toLowerCase();
    return cat.includes('beach') || 
           cat.includes('nature') || 
           cat.includes('park') || 
           cat.includes('street art') || 
           cat.includes('mural') || 
           cat.includes('adventure') ||
           cat.includes('jetty');
}

function normalizeAreaName(area) {
    if (!area) return area;
    const lower = area.toLowerCase();
    if (lower === 'georgetown') return 'George Town';
    if (lower === 'ayer itam') return 'Air Itam';
    return area;
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

function detectMatchedCategories(text) {
    const lower = text.toLowerCase();
    const matches = [];
    const seen = new Set();

    for (const [cat, kws] of Object.entries(CATEGORY_KEYWORDS)) {
        for (const kw of kws) {
            const reg = new RegExp(`\\b${kw}\\b`, 'i');
            const match = lower.match(reg);
            if (match && !seen.has(cat)) {
                seen.add(cat);
                matches.push({ category: cat, index: match.index });
                break;
            }
        }
    }

    matches.sort((a, b) => a.index - b.index);
    return matches.map(m => m.category);
}

function buildAreaQuery(area) {
    if (!area) return {};
    const norm = area.toLowerCase();
    const areaRegex = new RegExp(area.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    if (norm === 'balik pulau') {
        return {
            $and: [
                {
                    $or: [
                        { area: /Balik Pulau/i },
                        { name: { $regex: 'Audi Dream|Balik Pulau|Nutmeg|Kim Laksa|Seni Warisan', $options: 'i' } },
                        { address: { $regex: '11000|11010|Balik Pulau', $options: 'i' } }
                    ]
                },
                { address: { $not: { $regex: 'Air Itam|Ayer Itam|George Town|Georgetown|Teluk Bahang', $options: 'i' } } }
            ]
        };
    }
    if (norm === 'bayan lepas' || norm === 'bayan baru') {
        return {
            $and: [
                {
                    $or: [
                        { area: /Bayan Lepas|Bayan Baru/i },
                        { name: { $regex: 'Snake Temple|Setia SPICE|SPICE Canopy|War Museum|Bayan Lepas|Bayan Baru|Tanjung Asam', $options: 'i' } },
                        { address: { $regex: '11900|11950|Bayan Lepas|Bayan Baru', $options: 'i' } }
                    ]
                },
                { name: { $not: { $regex: 'Tropical Spice', $options: 'i' } } },
                { address: { $not: { $regex: 'Batu Ferringhi|Teluk Bahang|George Town', $options: 'i' } } }
            ]
        };
    }
    if (norm === 'george town' || norm === 'georgetown') {
        return {
            $or: [
                { area: /George Town/i },
                { name: { $regex: 'Chew Jetty|Khoo Kongsi|Peranakan Mansion|Fort Cornwallis|Armenian', $options: 'i' } },
                { address: { $regex: '10200|10300|10450|Georgetown|George Town', $options: 'i' } }
            ]
        };
    }
    if (norm === 'air itam' || norm === 'ayer itam') {
        return {
            $or: [
                { area: /Air Itam/i },
                { name: { $regex: 'Kek Lok Si|Penang Hill|Bukit Bendera|Air Itam Market|The Habitat', $options: 'i' } },
                { address: { $regex: 'Air Itam|Ayer Itam|11500', $options: 'i' } }
            ]
        };
    }
    if (norm === 'batu ferringhi' || norm === 'batu feringghi') {
        return {
            $or: [
                { area: /Batu Ferringhi/i },
                { name: { $regex: 'Batu Ferringhi Beach|Tropical Spice Garden|Batu Ferringhi|Feringghi', $options: 'i' } },
                { address: { $regex: 'Batu Ferringhi|Batu Feringghi|11100', $options: 'i' } }
            ]
        };
    }
    if (norm === 'teluk bahang') {
        return {
            $or: [
                { area: /Teluk Bahang/i },
                { name: { $regex: 'ESCAPE|Entopia|Penang National Park|Teluk Bahang', $options: 'i' } },
                { address: { $regex: 'Teluk Bahang|11050', $options: 'i' } }
            ]
        };
    }
    return {
        $or: [
            { area: areaRegex },
            { address: areaRegex },
            { name: areaRegex },
            { summary: areaRegex }
        ]
    };
}

// --- 🧠 SEMANTIC VIBE & INTENT TAXONOMY FOR VECTOR SIMILARITY ---
const VIBE_SEMANTIC_DIMENSIONS = [
    {
        name: 'sunset_beach_ocean',
        label: '海滩日落与海滨风光',
        // 强地标与专属区域（高权重）
        landmarks_entities: [
            'batu ferringhi', 'tanjung bungah', 'teluk bahang', 'monkey beach',
            'turtle beach', 'pantai kerachut', 'gurney bay', 'gurney drive waterfront',
            'clan jetties'
        ],
        // 场景与氛围关键词
        attributes_keywords: [
            'sunset', 'dusk', 'golden hour', 'beach', 'pantai', 'sea view', 'seaside',
            'ocean', 'oceanfront', 'coastal', 'coastline', 'waves', 'shore', 'island breeze',
            'waterfront promenade', 'sandy beach'
        ]
    },
    {
        name: 'heritage_colonial_history',
        label: '世界遗产与南洋历史古迹',
        landmarks_entities: [
            'pinang peranakan mansion', 'cheong fatt tze', 'blue mansion', 'fort cornwallis',
            'khoon kongsi', 'leong san tong khoo kongsi', 'cheah kongsi', 'george town unesco',
            'queen victoria memorial clock tower', 'st george church', 'city hall penang'
        ],
        attributes_keywords: [
            'heritage', 'history', 'historic', 'colonial', 'unesco', 'mansion', 'clan jetty',
            'ancestral', 'vintage', 'antique', 'peranakan', 'baba nyonya', 'straits chinese',
            'monument', 'museum', 'nostalgia', 'old world', 'traditional architecture',
            'pre war shophouse', 'prewar'
        ]
    },
    {
        name: 'nature_hiking_parks',
        label: '自然生态、徒步与山野公园',
        landmarks_entities: [
            'penang hill', 'bukit bendera', 'the habitat', 'penang national park',
            'taman negara pulau pinang', 'botanical gardens', 'waterfall gardens',
            'youth park', 'titi kerrawang waterfall', 'air hitam dam', 'frog hill'
        ],
        attributes_keywords: [
            'nature', 'hiking', 'trekking', 'nature trail', 'greenery', 'lush', 'forest',
            'jungle', 'botanical', 'rainforest', 'canopy walk', 'flora', 'fauna', 'waterfall',
            'outdoors', 'scenic view', 'panoramic view', 'mountain breeze', 'fresh air'
        ]
    },
    {
        name: 'cozy_cafe_coffee_brunch',
        label: '精品咖啡、早午餐与惬意空间',
        landmarks_entities: [
            'chinahouse', 'narrow marrow', 'macallum connoisseurs', 'the daily dose'
        ],
        attributes_keywords: [
            'cafe', 'cafes', 'coffee', 'specialty coffee', 'artisan coffee', 'kopi',
            'espresso', 'latte', 'flat white', 'pourover', 'cold brew', 'matcha',
            'croissant', 'sourdough', 'brunch', 'chill', 'cozy', 'aesthetic',
            'instagrammable', 'relaxing vibe', 'work friendly', 'free wifi', 'pastry',
            'bakery', 'dessert', 'cake', 'waffle'
        ]
    },
    {
        name: 'street_food_hawker_night_market',
        label: '街头熟食、地道小吃与夜市',
        landmarks_entities: [
            'new lane hawker', 'chulia street hawker', 'gurney drive hawker',
            'kimberley street food night market', 'pasar malam batu ferringhi',
            'cecil street market', 'air itam pasar'
        ],
        attributes_keywords: [
            'street food', 'hawker food', 'hawker centre', 'kopitiam', 'food court',
            'pasar malam', 'night market', 'char kway teow', 'char koay teow', 'ckt',
            'asam laksa', 'penang laksa', 'hokkien mee', 'har mee', 'prawn mee',
            'cendol', 'chendol', 'chendul', 'nasi kandar', 'roti canai', 'curry mee',
            'lor bak', 'oyster omelette', 'or chien', 'ho chiak', 'makan', 'local eats',
            'authentic flavor', 'supper spot', 'cheap eats'
        ]
    },
    {
        name: 'spiritual_temple_worship',
        label: '宗教圣地、百年庙宇与宁静参拜',
        landmarks_entities: [
            'kek lok si', 'kek lok si temple', 'kapitan keling mosque',
            'wat chayamangkalaram', 'dhammikarama burmese temple',
            'sri mahamariamman temple', 'goddess of mercy temple', 'kuan yin teng',
            'snake temple', 'st anne church'
        ],
        attributes_keywords: [
            'temple', 'mosque', 'masjid', 'church', 'shrine', 'pagoda', 'worship',
            'sacred', 'spiritual', 'prayer', 'blessing', 'peaceful', 'serene', 'tranquil',
            'buddhist', 'hindu', 'taoist', 'islamic heritage', 'sanctuary', 'reverence'
        ]
    },
    {
        name: 'arts_culture_murals',
        label: '街头壁画、文创展览与艺术空间',
        landmarks_entities: [
            'armenian street', 'hin bus depot', 'kids on bicycle mural',
            'upside down museum', 'wonderfood museum', 'penang 3d trick art museum',
            'batik painting museum'
        ],
        attributes_keywords: [
            'street art', 'mural', 'murals', 'wall art', 'wall painting', 'graffiti art',
            'creative hub', 'art exhibition', 'art gallery', 'craft market', 'visual arts',
            'artistic vibe', 'handcrafted', 'installation art', 'interactive museum'
        ]
    },
    {
        name: 'adventure_thrill_activities',
        label: '刺激冒险、极限运动与户外探险',
        landmarks_entities: [
            'escape theme park', 'escape penang', 'the gravityz',
            'rainbow skywalk komtar', 'pedal boat', 'atv tour penang'
        ],
        attributes_keywords: [
            'adventure', 'thrill', 'water park', 'theme park', 'zip line', 'zipline',
            'ropes course', 'wall climbing', 'water slide', 'adrenaline rush',
            'exciting activities', 'outdoor challenge', 'skywalk', 'high ropes'
        ]
    },
    {
        name: 'nightlife_bars_bistros',
        label: '夜生活、微醺酒吧与音乐酒馆',
        landmarks_entities: [
            'love lane', 'chulia street bars', 'nagore square nightlife'
        ],
        attributes_keywords: [
            'nightlife', 'cocktail bar', 'speakeasy', 'bistro', 'craft beer', 'taproom',
            'wine bar', 'pub', 'live band', 'live music', 'drinks with friends',
            'late night drinks', 'chill lounge', 'rooftop bar', 'night hangout'
        ]
    },
    {
        name: 'shopping_retail_souvenirs',
        label: '大型商场、特色伴手礼与文创手信',
        landmarks_entities: [
            'gurney plaza', 'gurney paragon', 'queensbay mall', '1st avenue mall',
            'chowrasta market', 'him heang', 'ban heang'
        ],
        attributes_keywords: [
            'shopping mall', 'retail therapy', 'souvenir', 'local souvenir', 'handicrafts',
            'boutique shopping', 'local tidbits', 'tambun biscuit', 'tau sar piah',
            'nutmeg products', 'white coffee gifts', 'bazaar'
        ]
    },
    {
        name: 'romantic_couples_dates',
        label: '情侣约会、浪漫夜景与精致体验',
        landmarks_entities: [
            'david brown restaurant', 'penang hill lookout', 'ferringhi garden'
        ],
        attributes_keywords: [
            'romantic', 'date night', 'couples spot', 'intimate setting', 'candlelight dinner',
            'fine dining', 'sunset dinner', 'panoramic night view', 'picturesque sunset',
            'memorable date', 'quiet romantic stroll', 'cozy atmosphere'
        ]
    },
    {
        name: 'family_kids_friendly',
        label: '亲子出行、儿童友好与科普研学',
        landmarks_entities: [
            'entopia by penang butterfly farm', 'audi dream farm', 'penang tech dome',
            'countryside stables penang', 'teddyville museum'
        ],
        attributes_keywords: [
            'family friendly', 'kids friendly', 'child friendly', 'children activities',
            'educational trip', 'interactive learning', 'stroller accessible',
            'butterfly sanctuary', 'petting zoo', 'hands on science', 'spacious park'
        ]
    }
];

/**
 * 计算文本命中的氛围维度得分
 * @param {string} text - 用户提问或景点详情
 * @returns {Array<{name: string, score: number}>}
 */
function scoreVibeDimensions(text) {
    if (!text) return [];
    const lowerText = text.toLowerCase();

    return VIBE_SEMANTIC_DIMENSIONS.map(dimension => {
        let score = 0;

        // 1. 匹配强实体/地标（单次命中计 3 分）
        for (const entity of dimension.landmarks_entities) {
            // 使用边界匹配避免子串误伤
            const regex = new RegExp(`(^|\\W)${entity.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\W|$)`, 'i');
            if (regex.test(lowerText)) {
                score += 3;
            }
        }

        // 2. 匹配普通关键词（单次命中计 1 分）
        for (const kw of dimension.attributes_keywords) {
            const regex = new RegExp(`(^|\\W)${kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\W|$)`, 'i');
            if (regex.test(lowerText)) {
                score += 1;
            }
        }

        return { name: dimension.name, label: dimension.label, score };
    })
    .filter(item => item.score > 0)
    .sort((a, b) => b.score - a.score);
}

// 🔢 Deterministic semantic vector projection for Penang places & concepts
function generateSemanticVector(text) {
    if (!text || typeof text !== 'string') {
        return new Array(VIBE_SEMANTIC_DIMENSIONS.length + 16).fill(0);
    }

    const lower = text.toLowerCase();
    const vector = new Array(VIBE_SEMANTIC_DIMENSIONS.length + 16).fill(0);

    // 1. Semantic Vibe Dimensions Matching (Landmarks: 3.0, Keywords: 1.0)
    VIBE_SEMANTIC_DIMENSIONS.forEach((dim, idx) => {
        let score = 0;
        if (Array.isArray(dim.landmarks_entities)) {
            for (const entity of dim.landmarks_entities) {
                const regex = new RegExp(`(^|\\W)${entity.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\W|$)`, 'i');
                if (regex.test(lower)) score += 3.0;
            }
        }
        if (Array.isArray(dim.attributes_keywords)) {
            for (const kw of dim.attributes_keywords) {
                const regex = new RegExp(`(^|\\W)${kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\W|$)`, 'i');
                if (regex.test(lower)) score += 1.0;
            }
        }
        vector[idx] = score;
    });

    // 2. Hash-based subword / feature projections for open vocabulary coverage
    const words = lower.replace(/[^\w\s]/g, ' ').split(/\s+/).filter(w => w.length > 2);
    for (const word of words) {
        let hash = 0;
        for (let i = 0; i < word.length; i++) {
            hash = ((hash << 5) - hash) + word.charCodeAt(i);
            hash |= 0;
        }
        const offset = VIBE_SEMANTIC_DIMENSIONS.length;
        const bucket = Math.abs(hash) % 16;
        vector[offset + bucket] += 0.5;
    }

    // Normalize to unit length (L2 norm)
    let norm = 0;
    for (let i = 0; i < vector.length; i++) {
        norm += vector[i] * vector[i];
    }
    norm = Math.sqrt(norm);

    if (norm > 0) {
        for (let i = 0; i < vector.length; i++) {
            vector[i] = vector[i] / norm;
        }
    }

    return vector;
}

/**
 * 🧠 Generates an embedding vector array from raw user input.
 * Takes the user's raw input and returns a vector array (number[]).
 * Attempts Ollama Embeddings API first, falling back to normalized semantic feature vector.
 */
async function getEmbedding(rawInput) {
    if (!rawInput || typeof rawInput !== 'string' || rawInput.trim().length === 0) {
        return [];
    }

    // 1. Attempt Ollama Embeddings API endpoint
    try {
        const response = await fetch(OLLAMA_EMBED_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: EMBED_MODEL,
                prompt: rawInput.trim()
            }),
            timeout: 3000
        });

        if (response.ok) {
            const data = await response.json();
            if (data && Array.isArray(data.embedding) && data.embedding.length > 0) {
                return data.embedding;
            }
            if (data && Array.isArray(data.embeddings) && Array.isArray(data.embeddings[0])) {
                return data.embeddings[0];
            }
        }
    } catch (err) {
        // Embeddings endpoint not active or timed out - continue to semantic vectorization
    }

    // 2. High-dimensional normalized semantic vector representation
    return generateSemanticVector(rawInput);
}

/**
 * 📐 Cosine Similarity calculation between two numeric vectors:
 * Sim(A, B) = (A · B) / (||A|| * ||B||)
 */
function calculateCosineSimilarity(vecA, vecB) {
    if (!Array.isArray(vecA) || !Array.isArray(vecB) || vecA.length === 0 || vecB.length === 0) {
        return 0;
    }

    const len = Math.min(vecA.length, vecB.length);
    let dotProduct = 0;
    let normA = 0;
    let normB = 0;

    for (let i = 0; i < len; i++) {
        dotProduct += vecA[i] * vecB[i];
        normA += vecA[i] * vecA[i];
        normB += vecB[i] * vecB[i];
    }

    if (normA === 0 || normB === 0) return 0;
    return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

/**
 * ⚡ Vector Similarity Search against MongoDB Places collection.
 * Retrieves top 3 to 5 places that semantically match the user's "vibe", "intent", or "metaphor".
 */
async function performVectorSimilaritySearch(queryText, limit = 4, minSimilarity = 0.22) {
    try {
        const queryVector = await getEmbedding(queryText);
        if (!queryVector || queryVector.length === 0) {
            return [];
        }

        // Strategy A: MongoDB Atlas $vectorSearch aggregation pipeline (if configured)
        try {
            const atlasResults = await PlaceNew.aggregate([
                {
                    $vectorSearch: {
                        index: "vector_index",
                        path: "embedding",
                        queryVector: queryVector,
                        numCandidates: limit * 10,
                        limit: Math.min(Math.max(limit, 3), 5)
                    }
                }
            ]).maxTimeMS(2000);

            if (Array.isArray(atlasResults) && atlasResults.length >= 2) {
                console.log(`[Vector Search] Found ${atlasResults.length} places via MongoDB Atlas $vectorSearch`);
                return atlasResults;
            }
        } catch (atlasErr) {
            // $vectorSearch index not available on this cluster, seamlessly continue to in-memory cosine ranking
        }

        // Strategy B: In-Memory Cosine Similarity search across MongoDB PlaceNew documents
        // Prioritize documents with precomputed embeddings or evaluate on candidate places
        const places = await PlaceNew.find({ status: 'active' }).maxTimeMS(3000).limit(800);
        if (!places || places.length === 0) {
            return [];
        }

        const scoredPlaces = places.map(p => {
            const placeVec = Array.isArray(p.embedding) && p.embedding.length > 0
                ? p.embedding
                : generateSemanticVector(`${p.name} ${p.primary_category || ''} ${p.summary || ''} ${p.address || ''}`);

            const sim = calculateCosineSimilarity(queryVector, placeVec);
            return { place: p, score: sim };
        });

        // Filter by minimum similarity score and sort descending
        const relevant = scoredPlaces
            .filter(item => item.score >= minSimilarity)
            .sort((a, b) => b.score - a.score);

        const targetCount = Math.min(Math.max(limit, 3), 5); // Retrieve top 3 to 5 places
        const topResults = relevant.slice(0, targetCount).map(r => r.place);

        if (topResults.length > 0) {
            console.log(`[Vector Search] Retrieved top ${topResults.length} places with cosine similarity for query: "${queryText}"`);
        }

        return topResults;
    } catch (err) {
        console.warn("[Vector Search] Error during vector similarity search:", err.message);
        return [];
    }
}

/**
 * 🔍 Legacy Regex Matching Engine (Fallback)
 */
async function findPlacesByRegex(queryText) {
    try {
        const lowerQuery = queryText.toLowerCase().trim();
        const matchedAreas = detectMatchedAreas(lowerQuery);
        const matchedCategories = detectMatchedCategories(lowerQuery);

        // CASE 1: MULTI-AREA COMPARISON (e.g. "Bayan Lepas or Balik Pulau")
        if (matchedAreas.length >= 2) {
            const area1 = matchedAreas[0];
            const area2 = matchedAreas[1];

            const place1 = await PlaceNew.findOne({ ...buildAreaQuery(area1), status: 'active' }).maxTimeMS(1500);
            const place2 = await PlaceNew.findOne({ ...buildAreaQuery(area2), status: 'active' }).maxTimeMS(1500);

            const results = [];
            if (place1) results.push(place1);
            if (place2) results.push(place2);
            if (results.length > 0) return results;
        }

        // CASE 2: MULTI-CATEGORY COMPARISON
        if (matchedCategories.length >= 2 && matchedAreas.length <= 1) {
            const cat1 = matchedCategories[0];
            const cat2 = matchedCategories[1];
            const singleArea = matchedAreas[0];

            let q1 = {
                status: 'active',
                $or: [
                    { primary_category: { $regex: cat1, $options: 'i' } },
                    { sub_categories: { $regex: cat1, $options: 'i' } }
                ]
            };
            let q2 = {
                status: 'active',
                $or: [
                    { primary_category: { $regex: cat2, $options: 'i' } },
                    { sub_categories: { $regex: cat2, $options: 'i' } }
                ]
            };

            if (singleArea) {
                q1 = { $and: [q1, buildAreaQuery(singleArea)] };
                q2 = { $and: [q2, buildAreaQuery(singleArea)] };
            }

            const place1 = await PlaceNew.findOne(q1).maxTimeMS(1500);
            const place2 = await PlaceNew.findOne(q2).maxTimeMS(1500);

            const results = [];
            if (place1) results.push(place1);
            if (place2) results.push(place2);
            if (results.length > 0) return results;
        }

        // CASE 3: DIRECT SPECIFIC PLACE NAME SEARCH
        const targetSearchPhrase = extractTargetSearchTerm(queryText);
        const searchTerms = targetSearchPhrase ? targetSearchPhrase.split(/\s+/).filter(w => w.length > 1) : [];

        if (searchTerms.length > 0) {
            const phrase = searchTerms.join(' ');
            const normalizedPhrase = phrase.replace(/ferringhi/g, 'feringghi').replace(/night\s*market/g, 'pasar malam');
            
            let directNameMatches = await PlaceNew.find({
                status: 'active',
                $or: [
                    { name: { $regex: phrase, $options: 'i' } },
                    { name: { $regex: normalizedPhrase, $options: 'i' } },
                    { summary: { $regex: phrase, $options: 'i' } }
                ]
            }).limit(2);

            if (directNameMatches.length === 0 && searchTerms.length > 1) {
                const wordAndQueries = searchTerms.map(w => {
                    const altW = w === 'ferringhi' ? 'feringghi' : (w === 'night' ? 'pasar' : (w === 'market' ? 'malam' : w));
                    return {
                        $or: [
                            { name: { $regex: w, $options: 'i' } },
                            { name: { $regex: altW, $options: 'i' } }
                        ]
                    };
                });
                directNameMatches = await PlaceNew.find({ status: 'active', $and: wordAndQueries }).limit(2);
            }

            if (directNameMatches.length > 0) {
                return directNameMatches;
            }
        }

        const singleArea = matchedAreas[0];
        if (matchedCategories.length > 0) {
            let catQuery = {
                status: 'active',
                $or: [
                    { primary_category: { $regex: matchedCategories[0], $options: 'i' } },
                    { sub_categories: { $regex: matchedCategories[0], $options: 'i' } }
                ]
            };
            if (singleArea) {
                catQuery = { $and: [catQuery, buildAreaQuery(singleArea)] };
            }
            const catMatches = await PlaceNew.find(catQuery).maxTimeMS(1200).limit(2);
            if (catMatches.length > 0) return catMatches;
        }

        if (singleArea) {
            return await PlaceNew.find({ ...buildAreaQuery(singleArea), status: 'active' }).maxTimeMS(1200).limit(2);
        }

        return [];
    } catch (err) {
        console.error("Regex place fallback lookup error:", err.message);
        return [];
    }
}

/**
 * 🌟 REFACTORED FIND PLACES FROM MONGO
 * Performs a vector similarity search (cosine similarity) in MongoDB to retrieve top 3 to 5 places
 * that semantically match the user's "vibe", "intent", or "metaphor", rather than just literal nouns.
 * Seamlessly falls back to current regex matching when vector search yields no results or on error.
 */
async function findPlacesFromMongo(queryText, options = {}) {
    if (!queryText || typeof queryText !== 'string' || queryText.trim().length === 0) {
        return [];
    }

    try {
        const limit = options.limit || 4; // Default to top 3-5 places
        
        // 1. Perform Vector Similarity Search (Cosine Similarity)
        const vectorMatches = await performVectorSimilaritySearch(queryText, limit);

        if (Array.isArray(vectorMatches) && vectorMatches.length >= 1) {
            console.log(`[findPlacesFromMongo] Vector search succeeded with ${vectorMatches.length} semantic place matches.`);
            return vectorMatches;
        }

        // 2. Fallback to Legacy Regex Matching Engine
        console.log(`[findPlacesFromMongo] Vector search returned no matches; executing regex matching fallback for: "${queryText}"`);
        const regexMatches = await findPlacesByRegex(queryText);
        return regexMatches;

    } catch (err) {
        console.error("[findPlacesFromMongo] Error in vector search pipeline, attempting regex fallback:", err.message);
        return await findPlacesByRegex(queryText);
    }
}

function extractArea(place) {
    if (place.area) {
        return place.area;
    }
    const addr = place.address || place.place_address || '';
    if (addr) {
        for (const area of PENANG_AREAS) {
            if (addr.toLowerCase().includes(area.toLowerCase())) {
                return area;
            }
        }
    }
    return 'Penang';
}

// Helper: Query indoor backup recommendations from MongoDB dynamically based on travel area
async function getIndoorBackupPlaces(count = 3, targetAreas = [], centerCoords = null) {
    try {
        const indoorCats = ['Heritage & Culture', 'Museums & Galleries', 'Cafes', 'Shopping & Markets', 'Arts & Workshops', 'Entertainment', 'Food & Dining'];
        let places = [];
        
        const validAreas = (targetAreas || []).map(a => normalizeAreaName(a)).filter(a => a && a.toLowerCase() !== 'penang');
        
        if (validAreas.length > 0) {
            places = await PlaceNew.find({
                status: 'active',
                primary_category: { $in: indoorCats },
                area: { $in: validAreas }
            }).lean();
        }

        if (places.length < count && centerCoords && centerCoords.lat && centerCoords.lng) {
            const excludeIds = places.map(p => p._id);
            const nearby = await PlaceNew.find({
                _id: { $nin: excludeIds },
                status: 'active',
                primary_category: { $in: indoorCats },
                'location.coordinates': {
                    $near: {
                        $geometry: { type: 'Point', coordinates: [centerCoords.lng, centerCoords.lat] },
                        $maxDistance: 25000
                    }
                }
            }).limit(15).lean().catch(() => []);
            places = places.concat(nearby);
        }

        if (places.length === 0) {
            places = await PlaceNew.find({
                status: 'active',
                primary_category: { $in: indoorCats }
            }).limit(count * 3).lean();
        }

        if (centerCoords && centerCoords.lat && centerCoords.lng) {
            places.sort((a, b) => {
                const aLat = a.location?.coordinates ? a.location.coordinates[1] : 5.416;
                const aLng = a.location?.coordinates ? a.location.coordinates[0] : 100.33;
                const bLat = b.location?.coordinates ? b.location.coordinates[1] : 5.416;
                const bLng = b.location?.coordinates ? b.location.coordinates[0] : 100.33;
                const da = getHaversineDistance(centerCoords.lat, centerCoords.lng, aLat, aLng);
                const db = getHaversineDistance(centerCoords.lat, centerCoords.lng, bLat, bLng);
                return da - db;
            });
        }

        return places.slice(0, count);
    } catch (e) {
        console.error("Error in getIndoorBackupPlaces:", e.message);
        return [];
    }
}

// --- 📚 FEW-SHOT REFERENCE DATASET ---
const referenceDataset = `
REFERENCE EXAMPLES (Learn intent & response style):

[Scenario 1A: Factual Inquiry - Opening Hours & Weekend Difference]
User: "what is batu ferringhi night market business hour"
Places Grounding: [Option A]: Name: "Pasar Malam Batu Feringghi" | Area: "Batu Ferringhi" | Category: "Night Markets (Pasar Malam)" | Business Hours: Monday-Thursday: 7-10 PM, Friday-Sunday: 7-11 PM | Address: Jalan Pantai Batu, Tanjong Bungah
Bird: "Pasar Malam Batu Feringghi opens daily from 7 PM to 10 PM on weekdays, and closes at 11 PM on weekends. Great spot for late-night street food and souvenirs!"

[Scenario 1B: Factual Inquiry - Ticket Price / Entrance Fee]
User: "how much is entry ticket to pinang peranakan mansion"
Places Grounding: [Option A]: Name: "Pinang Peranakan Mansion" | Area: "George Town" | Category: "Museums & Galleries" | Ticket Price: RM 25 for adults, free for kids under 6 | Summary: 19th-century emerald-green Baba Nyonya ancestral home.
Bird: "Admission is RM 25 for adults and free for children under 6. Tour the restored emerald-green mansion to discover authentic Baba Nyonya antiques!"

[Scenario 1C: Factual Inquiry - Address & Location]
User: "where is toh soon cafe located"
Places Grounding: [Option A]: Name: "Toh Soon Cafe" | Area: "George Town" | Category: "Kopitiam" | Address: Lebuh Campbell, George Town | Business Hours: 8:00 AM - 5:00 PM (Closed Sundays)
Bird: "Toh Soon Cafe is tucked along Lebuh Campbell in George Town. Enjoy traditional charcoal-toasted bread paired with rich local kopi!"

[Scenario 1D: Factual Inquiry - Rest Days & Closures (Alamak Context)]
User: "is toh soon cafe open on sundays"
Places Grounding: [Option A]: Name: "Toh Soon Cafe" | Area: "George Town" | Category: "Kopitiam" | Business Hours: Monday-Saturday: 8:00 AM - 5:00 PM, Sunday: Closed | Address: Lebuh Campbell, George Town | Summary: Heritage back-alley coffee stall famous for charcoal-toasted bread and soft-boiled eggs.
Bird: "Alamak, Toh Soon Cafe is closed on Sundays! They operate Monday through Saturday from 8:00 AM to 5:00 PM. Drop by tomorrow for charcoal toast and coffee!"

[Scenario 2A: Recommendation - Food & Local Eats (Ho Chiak & Jom)]
User: "Recommend some famous local dinner spots around George Town"
Places Grounding: 
[Option A]: Name: "New Lane Hawker Centre" | Area: "George Town" | Category: "Street Food" | Address: Lorong Baru, George Town | Summary: Bustling open-air street packed with stalls serving char koay teow, popiah, and grilled chicken wings.
[Option B]: Name: "Kimberley Street Food Night Market" | Area: "George Town" | Category: "Street Food" | Address: Lebuh Kimberley, George Town | Summary: Famous heritage street renowned for duck kway chap, braised chicken feet, and herbal desserts.
Bird: "Jom feast! Option A is New Lane Hawker Centre for sizzling char koay teow and lively open-air stalls. Option B is Kimberley Street, famous for tender duck kway chap and comforting herbal desserts. Both are super ho chiak —tap Option A or Option B to add to your plan!"

[Scenario 2B: Recommendation - Nature & Scenic Outdoors]
User: "Any nice spots to enjoy nature or catch panoramic views?"
Places Grounding: 
[Option A]: Name: "The Habitat Penang Hill" | Area: "Air Itam" | Category: "Nature & Parks" | Address: Bukit Bendera, Penang | Summary: Rainforest discovery center featuring a canopy walkway and 360-degree viewing platform.
[Option B]: Name: "Penang National Park" | Area: "Teluk Bahang" | Category: "Nature & Parks" | Address: Pejabat Taman Negara Pulau Pinang | Summary: Coastal nature reserve offering scenic jungle hiking trails to secluded beaches like Monkey Beach.
Bird: "For fresh air and lush views, Option A is The Habitat on Penang Hill, featuring an iconic treetop canopy walk. Option B is Penang National Park, perfect for a coastal trail hike down to Monkey Beach! Which outdoor adventure suits your mood today?"

[Scenario 2C: Recommendation - Cozy Cafes & Chill Spots]
User: "Looking for a nice aesthetic cafe to grab coffee and dessert"
Places Grounding: 
[Option A]: Name: "ChinaHouse" | Area: "George Town" | Category: "Cafes" | Address: 153 Beach Street, George Town | Summary: Longest heritage cafe in Penang showcasing an enormous counter of artisanal cakes, pastries, and art spaces.
[Option B]: Name: "Narrow Marrow" | Area: "George Town" | Category: "Cafes" | Address: 312 Lebuh Chulia, George Town | Summary: Quirky, rustic artsy cafe known for its signature tiramisu varieties, craft drinks, and indie vibe.
Bird: "Time for a sweet break! Option A is ChinaHouse, famous for its massive selection of artisanal cakes in a heritage shophouse. Option B is Narrow Marrow, an intimate artsy nook celebrated for its signature tiramisu. Tap Option A or Option B to pick your hangout spot!"

[Scenario 2D: Recommendation - Heritage & Cultural Exploration]
User: "Recommend me some good heritage spots in George Town"
Places Grounding: 
[Option A]: Name: "Khoo Kongsi" | Area: "George Town" | Category: "Clan Houses" | Address: 18 Cannon Square, George Town | Summary: Magnificent historic Chinese clan temple with grand architecture and intricate woodcarvings.
[Option B]: Name: "Pinang Peranakan Mansion" | Area: "George Town" | Category: "Museums & Galleries" | Address: 29 Church Street, George Town | Summary: Restored 19th-century emerald-green mansion showcasing Baba Nyonya heritage and antiques.
Bird: "Jom explore George Town! Option A is Khoo Kongsi, a magnificent clan temple with grand carvings. Option B is Pinang Peranakan Mansion, a stunning emerald-green museum showcasing Baba Nyonya treasures! Which one would you prefer to visit?"

[Scenario 3A: Draft Milestone - Proactive Save & Weather Guard Nudge]
Context: User just added their 3rd or 4th place.
Bird: "You've gathered some great spots! Want to set your dates and let Weather Guard optimize your route, or keep exploring? Option A: Save and optimize trip. Option B: I still want to plan."

[Scenario 3B: User Chooses Option A - Request Dates for Weather Guard]
User: "Option A" / "Save the trip" / "Let's optimize"
Places Grounding: None
Bird: "Jom! Pick your travel dates on the calendar. Once set, Weather Guard will check the hourly forecast so I can sequence indoor and outdoor stops smoothly! [INTENT: REQUIRE_DATES]"

[Scenario 3C: User Chooses Option B (Continue Planning)]
User: "Option B" / "I still want to plan" / "Not yet"
Places Grounding: None
Bird: "No problem! What vibe are we adding next —a cozy cafe, heritage landmark, or some ho chiak street food?"

[Scenario 4: Trip Optimization - Weather Guard Active & Route Sequenced]
User: "[System Event: Dates selected 2026-10-15 to 2026-10-16]"
Context: 
- Weather Data: 2026-10-15 Afternoon Heavy Rain (2:00 PM - 4:30 PM), Morning Sunny.
- Places: Penang Hill (Outdoor), Pinang Peranakan Mansion (Indoor), New Lane (Evening Outdoor/Hawker).
Bird: "Trip locked! Weather Guard detects afternoon rain, so I've sequenced Penang Hill for the clear morning breeze, moving Pinang Peranakan Mansion indoors during the 2 PM shower, ending with dinner at New Lane. Enjoy! [INTENT: LOCK_TRIP]"

[Scenario 5: Trip Control - Cancel Trip]
User: "I want to stop the trip now" / "Cancel my current trip"
Places Grounding: None
Bird: "No problem, I've cleared your active trip! Want to take a break, or shall we start fresh with a new plan? [INTENT: CANCEL_TRIP]"
`;

// Helper: Detect if user query is a factual question
function isFactualQuestion(text) {
    if (!text || typeof text !== 'string') return false;
    const lower = text.toLowerCase();

    const isInfoSeeking = /\b(?:want|wish|like|wanna)\s+to\s+(?:know|learn|find\s+out|check|ask)\b/i.test(lower) ||
        lower.includes('want to know') || lower.includes('wanna know') ||
        lower.includes('know more about') || lower.includes('tell me more about') ||
        lower.includes('more about the') || lower.includes('more about this') ||
        lower.includes('tell me about') || lower.includes('info on') || lower.includes('details of') ||
        lower.includes('我想了解') || lower.includes('我想知道') || lower.includes('了解更多');

    // Explicit preference, desire, and recommendation triggers are NEVER factual questions (unless seeking info/details)!
    if (!isInfoSeeking && (
        lower.includes('i want') || lower.includes('i wish') || lower.includes('i would like') ||
        lower.includes('want to') || lower.includes('want visit') || lower.includes('wanna') ||
        lower.includes('looking for') || lower.includes('recommend') || lower.includes('suggest') ||
        lower.includes('nearby') || lower.includes('near to') || lower.includes('around here') ||
        lower.includes('clan house') || lower.includes('clan houses') || lower.includes('kongsi') ||
        lower.includes('我想') || lower.includes('我要') || lower.includes('想去') || lower.includes('想找'))) {
        return false;
    }

    if (isInfoSeeking) {
        return true;
    }

    if (typeof classifyUserIntent === 'function') {
        const intent = classifyUserIntent(text);
        if (intent === 'RECOMMENDATION_REQUEST' || intent === 'ITINERARY_ACTION') {
            return false;
        }
        if (intent === 'FACTUAL_INQUIRY') {
            return true;
        }
    }
    const qTriggers = [
        'what is', 'what are', 'when is', 'when does', 'is it open', 'opening hour', 'business hour',
        'operating hour', 'what time', 'how much', 'ticket price', 'fee', 'entry fee', 'entrance fee',
        'rate', 'rates', 'fare', 'fares', 'charges', 'where is', 'where are',
        'how to go', 'contact number', 'phone number', 'address',
        'which area', 'what area', 'in which area', 'in what area', 'which part', 'what part',
        'where are they located', 'where is it located', 'is the same as', 'same as', 'difference between', 'different from',
        '在哪个区', '在什么区', '在哪个地方', '什么位置', '具体位置', '具体地址',
        '在哪里', '在哪', '在何处', '位于哪里', '属于哪个区', '地址是什么', '地址在哪', '怎么去',
        '几点开', '几点关', '营业时间', '开放时间', '开门时间', '关门时间', '今天有开吗', '明天有开吗',
        '门票', '多少钱', '要门票吗', '需要门票吗', '免费吗', '收费吗', '收费', '门票价格'
    ];
    return qTriggers.some(t => lower.includes(t));
}

// --- 🧠 CORE AI CHAT LOGIC ---
async function chatWithBird(userInput, hasActiveTrip, placesFound, hasTravelDates) {
    // 1. Data Truncation: Strictly limit placesFound to top 2 places (Option A and Option B)
    const truncatedPlaces = Array.isArray(placesFound) ? placesFound.slice(0, 2) : [];

    const userContext = hasActiveTrip 
        ? "Note: The user currently has an ONGOING active trip." 
        : "Note: The user is currently drafting a trip or asking companion questions.";

    const isQuestion = isFactualQuestion(userInput);

    let dbPlacesContext = "";
    if (truncatedPlaces && truncatedPlaces.length > 0) {
        dbPlacesContext = "\nREAL PENANG MONGODB PLACES GROUNDING DATA (STRICT 2-OPTION CHOICES):\n";
        truncatedPlaces.forEach((p, idx) => {
            const optLabel = idx === 0 ? "Option A" : "Option B";
            const area = extractArea(p);
            const hoursStr = formatBusinessHours(p.place_business_hours);
            dbPlacesContext += `[${optLabel}]:
- Name: "${p.place_name}"
- Area: "${area}"
- Category: "${p.place_category || 'General'}"
- Address: "${p.place_address || 'Penang'}"
- Business Hours: "${hoursStr}"
- Summary: "${p.place_summary || 'Popular attraction in Penang'}"\n\n`;
        });

        if (isQuestion) {
            dbPlacesContext += `
CRITICAL RESPONSE INSTRUCTIONS (USER ASKED A FACTUAL QUESTION):
1. The user's exact question is: "${userInput}".
2. You MUST directly, accurately, and politely answer their question using the specific field requested (such as Business Hours, Address, or Details) from [Option A] above.
3. State the exact business hours, days, or information clearly.
4. DO NOT recommend random unrelated places. DO NOT force the user to pick an option when they are just asking for factual information!
`;
        } else {
            dbPlacesContext += `
CRITICAL RESPONSE INSTRUCTIONS (RECOMMENDATION / TRIP PLANNING - OPTION A / OPTION B ALIGNMENT):
1. The user's query is: "${userInput}".
2. When recommending, introduce the suggested places strictly as **Option A** (and **Option B** if available).
3. Clearly explain each option's unique highlights and vibe based on their Category, Area, and Summary.
4. Always ask the user which option they prefer (e.g., "Would you prefer Option A or Option B?").
`;
        }
    }

    const systemPrompt = `
    You are 'Penny' (Kia-Kia Penang Pink Bird mascot, 潘妮), a friendly, knowledgeable travel guide mascot for Penang, Malaysia. 
    
    CORE RULES:
    1. ACCURACY FIRST: When the user asks a specific question (like opening hours, location, price, details), ALWAYS answer the exact question directly based on the Grounding Data provided.
    2. NO SPAM / FORCED PROMPTS: Do not force "Tap Add Option 1" or push unrelated places if the user is only asking for business hours or information.
    3. TONE & PENANG LOCAL FLAIR (STRICT GUIDELINES):
       - Personality: Friendly, enthusiastic, and warm local companion.
       - Length: Keep answers concise (under 50 words).
       - FORBIDDEN PARTICLES (DO NOT USE): Never use particles like 'lah', 'leh', 'lor', or 'gok'. Keep sentence endings clean and natural.
       - ALLOWED LOCAL SLANG (USE CONTEXTUALLY & SPARINGLY):
         * "Ho chiak" (Hokkien for delicious): Use ONLY when describing tasty Penang food, hawker stalls, or signature snacks.
         * "Alamak" (Exclamation of mild shock/surprise): Use ONLY for negative or unexpected situations (e.g., a shop is closed, rainy weather, long queues, missing dates). NEVER use it for neutral or happy statements.
         * "Jom": Use naturally as an invitation ("Jom go try...", "Jom, let's explore!").
         * "Tapao": Use when referring to takeaway food.
       - RULE OF THUMB: Do not force slang into every sentence. Maximum 1 local expression per response to keep it polished and readable.
    4. LENGTH & FORMATTING:
        - For factual questions (hours, address): Keep answers extremely crisp (under 40 words). Zero filler.
        - For recommendations/planning: Keep descriptions vivid but brief (under 80 words).
        - Ensure the answer fits comfortably inside a mobile chat bubble without excessive scrolling.
    
    ${userContext}
    Travel Dates Known: ${hasTravelDates ? "YES" : "NO"}
    ${dbPlacesContext}
    ${referenceDataset}
    
    SPECIAL RULES FOR TRIP COMMANDS:
    - If user explicitly asks to save, lock, or finalize their trip schedule, DO NOT ask for travel dates in chat! Ask the user to tap on the bottom-left checklist icon (with the total number of draft places badge at the corner) and generate the plan there.
    - When user asks to plan a trip in an area (e.g. "Plan trip for me in Batu Ferringhi", "Quick plan in George Town"), DO NOT ask for travel dates! Introduce the area highlights and offer Option A & Option B!
    - If user wants to cancel the trip, reply with [INTENT: CANCEL_TRIP].
    - If user wants to lock/start trip and dates are known, reply with [INTENT: LOCK_TRIP].
    `;

    console.log('\n--- 🤖 [AI PROMPT CONTEXT SENT TO gemma4:cloud] ---');
    console.log(JSON.stringify({
        model: "gemma4:cloud",
        userPrompt: userInput,
        isFactualQuestion: isQuestion,
        hasTravelDates,
        placesGroundingCount: placesFound.length,
        systemInstructionLength: systemPrompt.length
    }, null, 2));

    const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            model: "gemma4:cloud", 
            system: systemPrompt,
            prompt: userInput,
            stream: false,
            temperature: 0.2 // Lower temperature for higher factual precision
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`API Error: ${data.error}`);
    
    return data.response.trim();
}


// --- 🌐 API ENDPOINT FOR FLUTTER CHAT (PERSONA ENGINE & DYNAMIC MODE DISPATCHER) ---
// --- 🌐 API ENDPOINT FOR FLUTTER CHAT (PERSONA ENGINE & DYNAMIC MODE DISPATCHER) ---
router.post('/chat', async (req, res) => {
    try {
        const {
            message,
            mode = 'global_explorer',
            history = [],
            context = {},
            hasActiveTrip = false,
            travel_dates = null
        } = req.body;

        if (!message || typeof message !== 'string' || !message.trim()) {
            return res.status(400).json({ success: false, error: "A non-empty message is required" });
        }

        const trimmedMsg = message.trim();
        const lowerMsg = trimmedMsg.toLowerCase();

        // 1. Context Normalization
        const enrichedContext = { ...context };
        if (hasActiveTrip && !enrichedContext.activeTrip) {
            enrichedContext.activeTrip = { tripId: 'legacy_active', currentStopIndex: 0, remainingStops: [] };
        }
        if (travel_dates && !enrichedContext.existingTripDates) {
            enrichedContext.existingTripDates = [{
                startDate: travel_dates.start_date || '',
                endDate: travel_dates.end_date || '',
                title: 'Penang Trip'
            }];
        }

        const hasTravelDates = Boolean(
            (travel_dates && travel_dates.start_date) ||
            (enrichedContext.existingTripDates && enrichedContext.existingTripDates.length > 0)
        );

        // 2. Dispatch to LLM / Persona Engine
        const result = await executeBirdChat({
            mode,
            message: trimmedMsg,
            history,
            context: enrichedContext,
            hasTravelDates
        });

        let rawReply = result.message || result.reply || '';
        if (typeof extractCleanMessageAndPayload === 'function' &&
            (rawReply.includes('"message":') || rawReply.startsWith('```') || rawReply.startsWith('{'))) {
            const cleaned = extractCleanMessageAndPayload(rawReply);
            if (cleaned.message) {
                rawReply = cleaned.message;
            }
        }

        // 3. Extract Embedded Protocol Tags (e.g., [INTENT: LOCK_TRIP])
        let detectedAction = result.action || 'none';
        const intentMatch = rawReply.match(/\[INTENT:\s*([A-Z_]+)\]/i);
        if (intentMatch) {
            if (detectedAction !== 'add_spot' && detectedAction !== 'suggest_spots') {
                detectedAction = intentMatch[1].toUpperCase();
            }
            // Clean tag out so raw metadata never displays inside Flutter chat bubbles
            rawReply = rawReply.replace(/\[INTENT:\s*[A-Z_]+\]/gi, '').trim();
        }

        // 3.5 Quick Plan by Area Response Enrichment
        const isQuickPlan = Boolean(enrichedContext.isQuickPlanBatch || lowerMsg.startsWith('plan trip for me in') || lowerMsg.startsWith('quick plan'));
        if (isQuickPlan && Array.isArray(enrichedContext.newlyAddedBatch) && enrichedContext.newlyAddedBatch.length > 0) {
            if (!rawReply.includes("I've added these 3 must-visit highlights") && !rawReply.includes("我已将这3个必游") && !rawReply.includes("added these 3")) {
                const areaTitle = enrichedContext.targetArea || 'Penang';
                const isChinese = /[\u4e00-\u9fa5]/.test(trimmedMsg);
                const highlightsHeader = isChinese
                    ? `✨ **以下是为您推荐的 ${areaTitle} 3个必游经典景点：**\n` +
                      enrichedContext.newlyAddedBatch.map((p, i) => `${i + 1}. **${p.name}** — ${p.summary || '著名景点'}`).join('\n') +
                      `\n\n📌 *我已将这3个必游经典景点直接添加到您的行程中（共3站）！*\n\n` +
                      `🎯 **为了让您的行程更丰富，我还为您准备了两个备选地点。您更想将哪一个作为第4站呢？**\n`
                    : `✨ **Here are 3 must-visit iconic highlights for ${areaTitle}:**\n` +
                      enrichedContext.newlyAddedBatch.map((p, i) => `${i + 1}. **${p.name}** — ${p.summary || 'Iconic highlight'}`).join('\n') +
                      `\n\n📌 *I've added these 3 must-visit highlights directly to your travel plan (3 total stops)!*\n\n` +
                      `🎯 **To complete your day, here are two more great options in ${areaTitle} retrieved for you. Which one would you prefer as your 4th stop?**\n`;

                const optAIndex = rawReply.search(/(?:###\s*\[?Option\s*A\]?|\*\*\[?Option\s*A\]?|\[?Option\s*A\]?:)/i);
                if (optAIndex !== -1) {
                    rawReply = highlightsHeader + rawReply.substring(optAIndex);
                } else {
                    rawReply = highlightsHeader + '\n' + rawReply;
                }
            }
        }
        if (isQuickPlan) {
            detectedAction = 'suggest_spots';
        }

        // 4. Keyword Fallback for Missing Date Interceptions
        const saveKeywords = ['save and plan', 'save my trip', 'save trip', 'lock trip', 'lock itinerary', 'lock it in'];
        if (!isQuickPlan && saveKeywords.some(kw => lowerMsg.includes(kw)) && !hasTravelDates && detectedAction !== 'add_spot') {
            detectedAction = 'REQUIRE_DATES';
        }

        // 5. Proactive 3-Spot Draft Nudge Check
        const draftCount = Array.isArray(enrichedContext.draftPlaces) ? enrichedContext.draftPlaces.length : (enrichedContext.draftSpotCount || 0);
        const isTriggeringMilestone = !isQuickPlan && draftCount >= 3 && !hasTravelDates && !enrichedContext.hasPromptedSave;

        // 6. Emotion State Resolution
        const EMOTION_MAP = {
            LOCK_TRIP: 'success',
            CANCEL_TRIP: 'sad',
            REQUIRE_DATES: 'happy',
            add_spot: 'happy',
            suggest_spots: 'happy',
            none: 'happy'
        };
        const emotion = EMOTION_MAP[detectedAction] || 'happy';

        // 7. Grounding & Selection Capping (Strictly Max 2 for Mobile UI)
        const SYSTEM_ACTION_LIST = [
            'save & optimize', 'save and optimize', 'save & plan', 'save and plan',
            'save trip', 'save plan', 'save the trip', 'save and plan trip for me now',
            'keep exploring', 'keep planning', 'select dates', 'lock trip',
            'optimize trip', 'require dates', 'i still want to plan', 'add more places',
            'add more', 'select dates 📅', 'keep planning 🗺️'
        ];
        const isSysAction = (str) => {
            if (!str || typeof str !== 'string') return false;
            const clean = str.replace(/^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*/i, '').replace(/[\*\_\[\]\.,]/g, '').trim().toLowerCase();
            return SYSTEM_ACTION_LIST.some(k => clean === k || clean.startsWith(k) || k.startsWith(clean));
        };

        const hasOptionABInText = (rawReply.includes('[Option A]') || rawReply.includes('Option A:')) &&
            (rawReply.includes('[Option B]') || rawReply.includes('Option B:'));

        const isFactual = hasOptionABInText ? false : (Boolean(result.isFactualInquiry) ||
            ((isFactualQuestion(trimmedMsg) || isFactualQuestion(lowerMsg)) && (detectedAction !== 'suggest_spots' && detectedAction !== 'add_spot')));
        let rawSuggested = isFactual ? [] : (Array.isArray(result.suggestedPlaces) 
            ? result.suggestedPlaces.filter(p => !isSysAction(p.name || p.place_name || p.placeName))
            : []);

        // Fallback hydration if rawReply offered Option A & Option B but rawSuggested was empty
        if (!isFactual && hasOptionABInText && rawSuggested.length < 2) {
            const optAPattern = /(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#\.]+)/i;
            const optBPattern = /(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#\.]+)/i;
            const mA = rawReply.match(optAPattern);
            const mB = rawReply.match(optBPattern);
            const sep = /\s+[-–—]{1,2}\s+|\s*[:：]\s+/;
            if (mA && mB) {
                let nameA = mA[1].replace(/[\*\_\[\]]/g, '').trim();
                let nameB = mB[1].replace(/[\*\_\[\]]/g, '').trim();
                if (sep.test(nameA)) nameA = nameA.split(sep)[0].trim();
                if (sep.test(nameB)) nameB = nameB.split(sep)[0].trim();
                if (nameA && nameB) {
                    rawSuggested = [
                        { name: nameA, placeName: nameA, area: 'George Town', category: 'Attraction' },
                        { name: nameB, placeName: nameB, area: 'George Town', category: 'Attraction' }
                    ];
                }
            }
        }
        const cappedSuggested = rawSuggested.slice(0, 2);

        // 8. Dynamic Quick Reply Synthesis
        let quickReplies = result.quickReplies || (result.payload && result.payload.quickReplies) || [];
        if (isFactual) {
            quickReplies = [];
        } else if (!Array.isArray(quickReplies) || quickReplies.length === 0) {
            if (detectedAction === 'REQUIRE_DATES') {
                quickReplies = ['Select Dates 📅', 'Keep Planning 🗺️'];
            } else if (isTriggeringMilestone) {
                quickReplies = ['🚀 Save and Plan Trip for Me Now', '➕ Add More Places'];
            } else if (cappedSuggested.length === 2) {
                quickReplies = ['Option A', 'Option B'];
            }
        }
        const cappedQuickReplies = isFactual ? [] : quickReplies.slice(0, 2);

        // 9. Structured Response Payload
        const sanitizedPayload = {
            ...(result.payload || {}),
            hasTravelDates,
            draftSpotCount: draftCount
        };
        if (isFactual || isQuickPlan) {
            delete sanitizedPayload.suggestedPlaces;
            if (isFactual) {
                delete sanitizedPayload.quickReplies;
            }
        }

        return res.json({
            success: true,
            mode: result.mode || mode,
            message: rawReply,
            reply: rawReply,
            action: isFactual ? 'none' : detectedAction,
            emotion,
            isFactualInquiry: isFactual,
            payload: sanitizedPayload,
            quickReplies: cappedQuickReplies,
            suggestedPlaces: cappedSuggested,
            options: isFactual ? [] : (result.options || cappedSuggested),
            model: result.model || "gemma4:cloud"
        });

    } catch (err) {
        console.error("[Bird API Error]:", err);
        return res.status(500).json({ 
            success: false, 
            error: "Failed to communicate with Travel Bird via Persona Engine." 
        });
    }
});

// --- 📍 GEOGRAPHIC DISTANCE & SPATIAL TSP (2-OPT) OPTIMIZER ---
function calculateHaversineKm(lat1, lon1, lat2, lon2) {
    if (lat1 === undefined || lon1 === undefined || lat2 === undefined || lon2 === undefined) return 0;
    const R = 6371; // Earth radius in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

/**
 * Solves Geographic Route Optimization (TSP with 2-Opt)
 * Prioritizes minimizing total travel distance and untangles criss-cross / zig-zag lines.
 * Preserves the first destination as the anchor start point.
 */
function optimizeGeographicRoute(placesList) {
    if (!Array.isArray(placesList) || placesList.length <= 2) {
        return [...placesList];
    }

    // Step 1: Nearest-Neighbor greedy sequence starting from the 1st stop (anchor)
    const unvisited = [...placesList];
    const tour = [unvisited.shift()];

    while (unvisited.length > 0) {
        const lastStop = tour[tour.length - 1];
        let bestIdx = 0;
        let minDistance = Infinity;

        for (let i = 0; i < unvisited.length; i++) {
            const cand = unvisited[i];
            const dist = calculateHaversineKm(lastStop.lat, lastStop.lng, cand.lat, cand.lng);
            if (dist < minDistance) {
                minDistance = dist;
                bestIdx = i;
            }
        }

        tour.push(unvisited.splice(bestIdx, 1)[0]);
    }

    // Step 2: 2-Opt local search to eliminate crossing paths (untangle criss-cross / zig-zag lines)
    let improved = true;
    let iterations = 0;
    const maxIterations = 50;

    while (improved && iterations < maxIterations) {
        improved = false;
        iterations++;

        for (let i = 1; i < tour.length - 1; i++) {
            for (let k = i + 1; k < tour.length; k++) {
                const dCurrent = calculateHaversineKm(tour[i - 1].lat, tour[i - 1].lng, tour[i].lat, tour[i].lng) +
                    (k + 1 < tour.length ? calculateHaversineKm(tour[k].lat, tour[k].lng, tour[k + 1].lat, tour[k + 1].lng) : 0);

                const dReversed = calculateHaversineKm(tour[i - 1].lat, tour[i - 1].lng, tour[k].lat, tour[k].lng) +
                    (k + 1 < tour.length ? calculateHaversineKm(tour[i].lat, tour[i].lng, tour[k + 1].lat, tour[k + 1].lng) : 0);

                if (dReversed < dCurrent - 0.0001) {
                    const segment = tour.slice(i, k + 1).reverse();
                    tour.splice(i, segment.length, ...segment);
                    improved = true;
                }
            }
        }
    }

    return tour;
}

// --- 🧭 AI ITINERARY OPTIMIZATION & TIME SCHEDULER ENDPOINT ---
router.post('/plan-itinerary', async (req, res) => {
    try {
        console.log('\n======================================================');
        console.log('📥 [ITINERARY PLANNING REQUEST RECEIVED]:');
        console.log(JSON.stringify(req.body, null, 2));
        console.log('======================================================');

        const { places = [], travel_dates = null, weather_info = null, user_overrides = [], depart_time = null, end_time = null } = req.body;

        if (!Array.isArray(places) || places.length === 0) {
            return res.status(400).json({ success: false, error: "At least one place is required to plan an itinerary." });
        }

        // Phase 2 Date Gatekeeper
        if (!travel_dates || !travel_dates.start_date) {
            return res.json({
                success: false,
                require_dates: true,
                action: "REQUIRE_DATES",
                mascot_message: "Before I can schedule your itinerary and check venue opening hours, what date will you be visiting Penang? [INTENT: REQUIRE_DATES]"
            });
        }

        // Calculate Target Day of Week (e.g. "monday", "tuesday")
        const travelStartDate = new Date(travel_dates.start_date);
        const daysOfWeek = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        const targetDay = daysOfWeek[travelStartDate.getDay()] || 'monday';
        const formattedDateString = travel_dates.start_date;

        console.log(`📅 Target Travel Date: ${formattedDateString} (${targetDay.toUpperCase()})`);

        // 1. Enrich places with MongoDB data (business hours for target day, category, coordinates)
        const enrichedPlaces = [];
        let hasOutdoorStops = false;

        for (const p of places) {
            let dbPlace = null;
            if (p.name) {
                const escapedName = p.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                dbPlace = await PlaceNew.findOne({ name: { $regex: `^${escapedName}$`, $options: 'i' } })
                    || await PlaceNew.findOne({ name: { $regex: escapedName, $options: 'i' } })
                    || await PlaceNew.findOne({ name: { $regex: p.name.split(' ')[0], $options: 'i' } });
            }

            const category = p.category || dbPlace?.primary_category || dbPlace?.place_category || 'Attraction';
            const isOutdoor = isOutdoorCategory(category);
            if (isOutdoor) hasOutdoorStops = true;

            const bHoursObj = (dbPlace?.place_business_hours && typeof dbPlace.place_business_hours === 'object' && Object.keys(dbPlace.place_business_hours).length > 0)
                ? dbPlace.place_business_hours
                : (dbPlace?.opening_hours || {});

            let todayHours = '9:00 AM - 6:00 PM';
            if (typeof bHoursObj === 'object' && bHoursObj[targetDay]) {
                const dayVal = bHoursObj[targetDay];
                if (typeof dayVal === 'string') {
                    todayHours = dayVal.trim();
                } else if (dayVal && typeof dayVal === 'object') {
                    todayHours = (dayVal.is_closed ? 'Closed' : `${dayVal.open || '9:00 AM'} - ${dayVal.close || '6:00 PM'}`).trim();
                }
            } else if (dbPlace?.raw_hours_text) {
                todayHours = dbPlace.raw_hours_text.trim();
            }
            const isClosedToday = todayHours.toLowerCase().includes('closed');

            enrichedPlaces.push({
                id: p.id || dbPlace?._id?.toString() || `stop_${Date.now()}_${Math.random()}`,
                name: p.name,
                area: p.area || (dbPlace ? extractArea(dbPlace) : 'Penang'),
                category: category,
                isOutdoor: isOutdoor,
                estimatedStayMinutes: p.estimatedStayMinutes || (category.toLowerCase().includes('cafe') ? 45 : 60),
                lat: p.lat || (dbPlace?.place_location?.coordinates ? dbPlace.place_location.coordinates[1] : 5.414),
                lng: p.lng || (dbPlace?.place_location?.coordinates ? dbPlace.place_location.coordinates[0] : 100.328),
                description: p.description || dbPlace?.place_summary || '',
                todayHours: todayHours,
                isClosedToday: isClosedToday
            });
        }

        // --- STAGE 1: GEOGRAPHIC ROUTE OPTIMIZATION (PRIORITIZED) ---
        // Optimize stops geographically using TSP + 2-Opt to minimize total travel distance and eliminate zig-zag criss-crosses
        const optimizedPlaces = optimizeGeographicRoute(enrichedPlaces);
        console.log(`🧭 [Geographic TSP Optimization]: Sequenced ${enrichedPlaces.length} places into shortest path:`,
            optimizedPlaces.map((p, idx) => `${idx + 1}. ${p.name}`).join(' -> ')
        );

        // Check Weather Forecast
        const isRainyWeather = !!(weather_info && (
            (weather_info.condition && weather_info.condition.toLowerCase().includes('rain')) ||
            (weather_info.condition && weather_info.condition.toLowerCase().includes('thunderstorm')) ||
            (weather_info.condition && weather_info.condition.toLowerCase().includes('drizzle')) ||
            (weather_info.precipitation_probability && weather_info.precipitation_probability > 50)
        ));

        // Calculate trip window in minutes and evaluate whether Free Time bridge fits
        let departMinutes = 9 * 60; // 09:00 default
        let endMinutes = 17 * 60; // 17:00 default
        if (depart_time && typeof depart_time === 'string') {
            const parts = depart_time.split(':');
            if (parts.length >= 2) {
                departMinutes = parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
            }
        }
        if (end_time && typeof end_time === 'string') {
            const parts = end_time.split(':');
            if (parts.length >= 2) {
                endMinutes = parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
            }
        }
        if (endMinutes <= departMinutes) {
            endMinutes = departMinutes + 360; // default 6h
        }
        const totalTripWindow = endMinutes - departMinutes;
        const canHaveFreeTime = totalTripWindow >= 330 && endMinutes >= (15 * 60) && departMinutes <= (11 * 60) && optimizedPlaces.length >= 3;

        // 2. Formulate Prompt for gemma4:cloud with Scheduling, Heat & Free-Time rules
        const prompt = `
You are 'Penny' (Kia-Kia Penang Pink Bird mascot, 潘妮), an expert AI travel guide for Penang, Malaysia.
The user is planning a trip on ${formattedDateString} (${targetDay.toUpperCase()}) with ${optimizedPlaces.length} selected places.
Trip Schedule Window: ${depart_time || '09:00'} to ${end_time || '17:00'} (Total available duration: ${Math.round(totalTripWindow / 60 * 10) / 10} hours / ${totalTripWindow} minutes).

SELECTED PLACES (GEOGRAPHICALLY OPTIMIZED SEQUENCE - PRESERVE ORDER):
${optimizedPlaces.map((p, i) => `${i + 1}. "${p.name}" (Area: ${p.area}, Category: ${p.category}, Outdoor: ${p.isOutdoor}, Hours: "${p.todayHours}", Closed: ${p.isClosedToday}, Coordinates: [${p.lng}, ${p.lat}])`).join('\n')}

SCHEDULING & SEQUENCING RULES:
0. **Strict Travel Window & Dynamic Stay Duration Budgeting**:
   - The user starts at ${depart_time || '09:00 AM'}. The first stop MUST start around ${depart_time || '09:00 AM'}.
   - The user PREFERS to conclude the trip around ${end_time || '05:00 PM'}. The final stop MUST finish at or before ${end_time || '05:00 PM'}.
   - You MUST dynamically budget each stop's stay duration so all ${optimizedPlaces.length} stops fit comfortably within this window (${totalTripWindow} minutes). NEVER schedule stops beyond ${end_time || '05:00 PM'}!
1. **PRESERVE GEOGRAPHIC SEQUENCE (HIGHEST PRIORITY)**:
   - The sequence above is already mathematically optimized to minimize travel distance and eliminate backtracking/zig-zagging.
   - You MUST visit the places in this exact order: ${optimizedPlaces.map((p, i) => `${i + 1}. ${p.name}`).join(' -> ')}. DO NOT scramble or reorder this sequence!
2. **Midday Peak Heat (11:00 AM - 03:00 PM)**:
   - If an outdoor spot falls in the midday slot (11:00 AM - 03:00 PM), assign "warning_flag": "PEAK_HEAT", and advise sun protection / drinking plenty of water in the tip.
   - If an indoor museum/mall falls in this slot, highlight it as a great air-conditioned refuge.
3. **Venue Status & Soft Warnings**:
   - If a place is closed on ${targetDay}, set "warning_flag": "CLOSED".
   - Otherwise, set "warning_flag": null.
${canHaveFreeTime ? `4. **Bridge-Based "Free Time" Block (自由时间)**:
   - Insert exactly ONE 1.0 to 1.5-hour "free_time" block (e.g. 01:00 PM - 02:30 PM) bridging distinct geographic zones or after lunch.
   - For this free_time block, generate 3 localized options:
     * Option A: Spontaneous activity near previous stop.
     * Option B: Early transit & light activity near next stop.
     * Option C: Rest / unstructured free roaming.` : `4. **No Free Time Block**:
   - Since this is a focused half-day travel window (${Math.round(totalTripWindow / 60 * 10) / 10} hours), DO NOT insert any "free_time" block. Budget all time directly to visiting the selected places so the user finishes by ${end_time || '05:00 PM'}.`}
5. Provide a short tip for each stop.

Respond ONLY with a valid JSON object matching this schema:
{
  "mascot_message": "Cheerful overview in Penang Manglish (e.g. Jom, lah, ho chiak)",
  "timeline": [
    {
      "type": "stop",
      "place_name": "Exact place name",
      "time_slot": "09:00 AM - 10:30 AM",
      "tip": "Short visit tip",
      "warning_flag": null
    }${canHaveFreeTime ? `,
    {
      "type": "free_time",
      "time_slot": "01:30 PM - 03:00 PM",
      "duration": "1.5 hours",
      "options": {
        "A": "Option A near previous stop",
        "B": "Option B near next stop",
        "C": "Rest and relax"
      }
    }` : ''}
  ]
}
`;

        console.log('🤖 [Calling gemma4:cloud for Multi-Phase Itinerary Generation]...');

        let parsedPlan = null;
        try {
            const response = await fetch(OLLAMA_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: "gemma4:cloud",
                    prompt: prompt,
                    stream: false,
                    format: "json",
                    temperature: 0.3
                })
            });

            const data = await response.json();
            if (!data.error && data.response) {
                let rawOutput = data.response.trim();
                if (rawOutput.startsWith('```json')) {
                    rawOutput = rawOutput.replace(/^```json\s*/, '').replace(/\s*```$/, '').trim();
                } else if (rawOutput.startsWith('```')) {
                    rawOutput = rawOutput.replace(/^```\s*/, '').replace(/\s*```$/, '').trim();
                }
                parsedPlan = JSON.parse(rawOutput);
            }
        } catch (e) {
            console.error("LLM Generation failed or timed out, generating deterministic timeline:", e.message);
        }

        // 3. Assemble Final Timeline Items with Strict Contract
        const timeline = [];
        const usedPlaces = new Set();

        if (parsedPlan && Array.isArray(parsedPlan.timeline) && parsedPlan.timeline.length > 0) {
            for (const item of parsedPlan.timeline) {
                if (item.type === 'free_time') {
                    timeline.push({
                        type: 'free_time',
                        time_slot: item.time_slot || '01:30 PM - 03:00 PM',
                        duration: item.duration || '1.5 hours',
                        options: {
                            A: item.options?.A || 'Explore local cafes and street art nearby.',
                            B: item.options?.B || 'Head early towards the next area for seaside views.',
                            C: item.options?.C || 'Free exploration or rest at accommodation.'
                        }
                    });
                } else if (item.type === 'stop' || item.place_name || item.name) {
                    const stopName = (item.place_name || item.name || '').toLowerCase().trim();
                    const ep = optimizedPlaces.find(p => p.name.toLowerCase().includes(stopName) || stopName.includes(p.name.toLowerCase()))
                               || optimizedPlaces.find((p) => !usedPlaces.has(p.name))
                               || optimizedPlaces[0];

                    if (ep) {
                        usedPlaces.add(ep.name);
                        let warningFlag = item.warning_flag || null;
                        if (ep.isClosedToday) {
                            warningFlag = 'CLOSED';
                        } else if (!warningFlag && ep.isOutdoor && ((item.time_slot || '').includes('12:') || (item.time_slot || '').includes('01:') || (item.time_slot || '').includes('02:'))) {
                            warningFlag = 'PEAK_HEAT';
                        }

                        timeline.push({
                            type: 'stop',
                            place_name: ep.name,
                            area: ep.area,
                            category: ep.category,
                            lat: ep.lat,
                            lng: ep.lng,
                            time_slot: item.time_slot || '10:00 AM - 11:30 AM',
                            tip: item.tip || `Enjoy exploring ${ep.name}!`,
                            warning_flag: warningFlag
                        });
                    }
                }
            }
        }

        // Helper to format minutes to 12-hour clock (e.g. "09:45 AM")
        const formatMinutesToClock = (totalMinutes) => {
            const norm = totalMinutes % (24 * 60);
            const h24 = Math.floor(norm / 60);
            const m = norm % 60;
            const period = h24 >= 12 ? 'PM' : 'AM';
            let h12 = h24 % 12;
            if (h12 === 0) h12 = 12;
            return `${h12.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')} ${period}`;
        };

        // Fallback: If LLM didn't return all places or failed, build deterministically
        if (timeline.filter(t => t.type === 'stop').length < optimizedPlaces.length) {
            timeline.length = 0; // reset

            // Strict geographic order: sequence follows optimized shortest route without zig-zags
            const ordered = [...optimizedPlaces];

            const transitPerLeg = 15;
            const totalTransitMins = Math.max(0, (ordered.length - 1) * transitPerLeg);
            const freeTimeMins = canHaveFreeTime ? 90 : 0;
            const availableStayMins = Math.max(ordered.length * 20, totalTripWindow - totalTransitMins - freeTimeMins);

            // Compute dynamic stay duration per stop, rounded to 5 mins
            const stayPerStop = Math.max(20, Math.floor(availableStayMins / ordered.length / 5) * 5);

            let currentMinutes = departMinutes;

            ordered.forEach((p, idx) => {
                // Insert Free Time after 2nd stop ONLY if eligible, midday, and not already added
                if (canHaveFreeTime && idx === 2 && currentMinutes >= (12 * 60) && currentMinutes < (14 * 60)) {
                    const freeStart = formatMinutesToClock(currentMinutes);
                    currentMinutes += freeTimeMins;
                    const freeEnd = formatMinutesToClock(currentMinutes);
                    timeline.push({
                        type: 'free_time',
                        time_slot: `${freeStart} - ${freeEnd}`,
                        duration: '1.5 hours',
                        options: {
                            A: `Stay in ${p.area} for famous Penang desserts & street art.`,
                            B: `Head early to ${ordered[Math.min(idx + 1, ordered.length - 1)]?.area || 'next stop'} for a breezy coffee.`,
                            C: 'Unstructured rest & recharge at accommodation.'
                        }
                    });
                }

                const startClock = formatMinutesToClock(currentMinutes);
                // Adjust last stop to cap tightly at endMinutes if needed
                const stopStay = (idx === ordered.length - 1)
                    ? Math.min(stayPerStop, Math.max(20, endMinutes - currentMinutes))
                    : stayPerStop;
                const endStopMinutes = currentMinutes + stopStay;
                const endClock = formatMinutesToClock(endStopMinutes);
                const timeSlot = `${startClock} - ${endClock}`;

                const curHour = Math.floor(currentMinutes / 60);
                let warningFlag = null;
                if (p.isClosedToday) {
                    warningFlag = 'CLOSED';
                } else if (p.isOutdoor && curHour >= 11 && curHour <= 14) {
                    warningFlag = 'PEAK_HEAT';
                }

                timeline.push({
                    type: 'stop',
                    place_name: p.name,
                    area: p.area,
                    category: p.category,
                    lat: p.lat,
                    lng: p.lng,
                    time_slot: timeSlot,
                    tip: p.isOutdoor ? 'Wear sunscreen and stay hydrated!' : 'Great spot to enjoy indoors during the day.',
                    warning_flag: warningFlag
                });

                if (idx < ordered.length - 1) {
                    currentMinutes = endStopMinutes + transitPerLeg;
                } else {
                    currentMinutes = endStopMinutes;
                }
            });
        }

        // 4. Generate Rainy-Day Backup Plan if Rainy & Outdoor Stops Exist
        let weatherAlert = null;
        let backupPlan = null;

        if (isRainyWeather && hasOutdoorStops) {
            const planAreas = [...new Set(enrichedPlaces.map(p => p.area).filter(a => a && a.toLowerCase() !== 'penang'))];
            const validCoords = enrichedPlaces.filter(p => typeof p.lat === 'number' && typeof p.lng === 'number');
            const centerLat = validCoords.length > 0 ? validCoords.reduce((s, p) => s + p.lat, 0) / validCoords.length : 5.416;
            const centerLng = validCoords.length > 0 ? validCoords.reduce((s, p) => s + p.lng, 0) / validCoords.length : 100.33;

            const indoorAlts = await getIndoorBackupPlaces(3, planAreas, { lat: centerLat, lng: centerLng });
            const primaryAreaName = planAreas.length > 0 ? planAreas.join(', ') : 'Penang';

            weatherAlert = {
                is_rainy: true,
                condition: weather_info.condition || 'Rain',
                description: weather_info.description || 'rain showers forecasted',
                date: formattedDateString,
                message: `Rain is forecasted for your travel date on ${formattedDateString}! We've created an indoor rainy-day backup plan with sheltered spots in ${primaryAreaName}.`
            };

            backupPlan = [];
            const timeSlots = ['09:30 AM - 11:30 AM', '11:45 AM - 01:15 PM', '03:00 PM - 04:30 PM'];

            if (indoorAlts.length > 0) {
                backupPlan.push({
                    type: 'stop',
                    place_name: indoorAlts[0].name,
                    area: indoorAlts[0].area || primaryAreaName,
                    category: indoorAlts[0].primary_category || 'Indoor Attraction',
                    lat: indoorAlts[0].location?.coordinates ? indoorAlts[0].location.coordinates[1] : centerLat,
                    lng: indoorAlts[0].location?.coordinates ? indoorAlts[0].location.coordinates[0] : centerLng,
                    time_slot: timeSlots[0],
                    tip: indoorAlts[0].summary || `Sheltered indoor attraction in ${indoorAlts[0].area || primaryAreaName} protected from the rain.`,
                    warning_flag: null
                });
            }

            if (indoorAlts.length > 1) {
                backupPlan.push({
                    type: 'stop',
                    place_name: indoorAlts[1].name,
                    area: indoorAlts[1].area || primaryAreaName,
                    category: indoorAlts[1].primary_category || 'Indoor Attraction',
                    lat: indoorAlts[1].location?.coordinates ? indoorAlts[1].location.coordinates[1] : centerLat,
                    lng: indoorAlts[1].location?.coordinates ? indoorAlts[1].location.coordinates[0] : centerLng,
                    time_slot: timeSlots[1],
                    tip: indoorAlts[1].summary || `Air-conditioned indoor spot in ${indoorAlts[1].area || primaryAreaName} comfortable for dining and exploration.`,
                    warning_flag: null
                });
            }

            backupPlan.push({
                type: 'free_time',
                time_slot: '01:15 PM - 02:45 PM',
                duration: '1.5 hours',
                options: {
                    A: `Enjoy hot drinks and local delicacies in covered cafes around ${primaryAreaName}.`,
                    B: `Explore covered local shops and markets in ${primaryAreaName}.`,
                    C: 'Rest and recharge.'
                }
            });

            if (indoorAlts.length > 2) {
                backupPlan.push({
                    type: 'stop',
                    place_name: indoorAlts[2].name,
                    area: indoorAlts[2].area || primaryAreaName,
                    category: indoorAlts[2].primary_category || 'Indoor Attraction',
                    lat: indoorAlts[2].location?.coordinates ? indoorAlts[2].location.coordinates[1] : centerLat,
                    lng: indoorAlts[2].location?.coordinates ? indoorAlts[2].location.coordinates[0] : centerLng,
                    time_slot: timeSlots[2],
                    tip: indoorAlts[2].summary || `Immerse in local sights in ${indoorAlts[2].area || primaryAreaName} without worrying about wet weather.`,
                    warning_flag: null
                });
            }
        }

        const weatherRecs = await getWeatherCandidates(enrichedPlaces, targetDay);

        const responsePayload = {
            success: true,
            mascot_message: parsedPlan?.mascot_message || "Ngam lah! Here is your AI-optimized itinerary timeline with best visit times!",
            timeline: timeline,
            weather_alert: weatherAlert,
            backup_plan: backupPlan,
            travel_dates: travel_dates,
            heat_recommendations: weatherRecs.heatCandidates,
            rain_recommendations: weatherRecs.rainCandidates,
            emotion: "success"
        };

        console.log('\n📤 [OPTIMIZED TIMELINE RESPONSE]:');
        console.log(JSON.stringify(responsePayload, null, 2));
        console.log('======================================================\n');

        res.json(responsePayload);

    } catch (err) {
        console.error("Itinerary Planning API Error:", err.message);
        res.status(500).json({ success: false, error: "Failed to optimize and plan itinerary." });
    }
});

// Helper for distance calculation
function getHaversineDistance(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) return 5.0;
    const R = 6371; // km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

// Helper to parse time string like "09:00 AM", "6:00 PM", "18:00" to minutes from midnight
function parseTimeToMinutes(timeStr) {
    if (!timeStr || typeof timeStr !== 'string') return null;
    const clean = timeStr.trim().toUpperCase();
    const isPM = clean.includes('PM');
    const isAM = clean.includes('AM');
    const numMatch = clean.match(/(\d+):(\d+)/);
    if (numMatch) {
        let h = parseInt(numMatch[1], 10);
        const m = parseInt(numMatch[2], 10);
        if (isPM && h < 12) h += 12;
        if (isAM && h === 12) h = 0;
        return h * 60 + m;
    }
    const singleHourMatch = clean.match(/(\d+)\s*(AM|PM)?/);
    if (singleHourMatch) {
        let h = parseInt(singleHourMatch[1], 10);
        if (singleHourMatch[2] === 'PM' && h < 12) h += 12;
        if (singleHourMatch[2] === 'AM' && h === 12) h = 0;
        return h * 60;
    }
    return null;
}

// Helper to query indoor/sheltered candidates from MongoDB for Heat & Rain dynamically scoped to user plan's travel area
async function getWeatherCandidates(currentPlaces = [], targetDay = 'monday') {
    try {
        const indoorCats = ['Heritage & Culture', 'Museums & Galleries', 'Cafes', 'Shopping & Markets', 'Arts & Workshops', 'Entertainment', 'Food & Dining'];
        const existingNames = new Set((currentPlaces || []).map(p => (p.name || '').toLowerCase().trim()));
        
        // 1. Resolve distinct travel areas from current plan stops
        const planAreasSet = new Set();
        for (const p of (currentPlaces || [])) {
            let pArea = p.area ? normalizeAreaName(p.area.trim()) : null;
            if (pArea && pArea.toLowerCase() !== 'penang') {
                planAreasSet.add(pArea);
            } else if (p.address) {
                const detected = detectMatchedAreas(p.address);
                if (detected.length > 0) planAreasSet.add(detected[0]);
            }
        }

        // If no explicit area provided, look up in MongoDB by place name
        if (planAreasSet.size === 0 && currentPlaces.length > 0) {
            for (const p of currentPlaces) {
                if (p.name) {
                    const escaped = p.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    const match = await PlaceNew.findOne({ name: { $regex: escaped, $options: 'i' } }).select('area location').lean();
                    if (match && match.area && match.area.toLowerCase() !== 'penang') {
                        planAreasSet.add(normalizeAreaName(match.area));
                    }
                }
            }
        }
        const planAreas = Array.from(planAreasSet);

        // 2. Identify centroid coordinates of user plan
        const validCoords = (currentPlaces || []).filter(p => (typeof p.lat === 'number' && !isNaN(p.lat)) && (typeof p.lng === 'number' && !isNaN(p.lng)));
        const centerLat = validCoords.length > 0 ? validCoords.reduce((s, p) => s + p.lat, 0) / validCoords.length : null;
        const centerLng = validCoords.length > 0 ? validCoords.reduce((s, p) => s + p.lng, 0) / validCoords.length : null;

        // 3. Query candidates dynamically based on user travel area
        let candidates = [];
        if (planAreas.length > 0) {
            candidates = await PlaceNew.find({
                status: 'active',
                primary_category: { $in: indoorCats },
                area: { $in: planAreas }
            }).lean();
        }

        // If fewer than 8 candidates found in specific area, broaden dynamically by proximity
        if (candidates.length < 8) {
            const excludeIds = candidates.map(c => c._id);
            let nearby = [];
            if (centerLat != null && centerLng != null) {
                nearby = await PlaceNew.find({
                    _id: { $nin: excludeIds },
                    status: 'active',
                    primary_category: { $in: indoorCats },
                    'location.coordinates': {
                        $near: {
                            $geometry: { type: 'Point', coordinates: [centerLng, centerLat] },
                            $maxDistance: 25000
                        }
                    }
                }).limit(20).lean().catch(() => []);
            }
            if (nearby.length === 0) {
                nearby = await PlaceNew.find({
                    _id: { $nin: excludeIds },
                    status: 'active',
                    primary_category: { $in: indoorCats }
                }).limit(30).lean();
            }
            candidates = candidates.concat(nearby);
        }

        const filtered = candidates.filter(c => !existingNames.has((c.name || '').toLowerCase().trim()));
        
        const withDist = filtered.map(c => {
            const cLat = c.location?.coordinates ? c.location.coordinates[1] : 5.416;
            const cLng = c.location?.coordinates ? c.location.coordinates[0] : 100.33;
            let minDist = 999;
            for (const p of (currentPlaces || [])) {
                const pLat = p.lat || centerLat || 5.416;
                const pLng = p.lng || centerLng || 100.33;
                const d = getHaversineDistance(pLat, pLng, cLat, cLng);
                if (d < minDist) minDist = d;
            }
            const isInPlanArea = planAreas.includes(c.area);
            const img = c.cover_image || c.place_media?.thumbnail || (c.images && c.images[0]?.url) || '';
            const bHours = c.raw_hours_text || '9:00 AM – 6:00 PM';
            return {
                id: c._id?.toString() || `rec_${Date.now()}_${Math.random()}`,
                name: c.name,
                area: c.area || 'Penang',
                category: c.primary_category || 'Indoor Attraction',
                lat: cLat,
                lng: cLng,
                imageUrl: img,
                distanceKm: Math.round(minDist * 10) / 10,
                isInPlanArea: isInPlanArea,
                businessHours: bHours,
                description: c.summary || c.description || `Sheltered indoor spot in ${c.area || 'Penang'}.`
            };
        });

        // Primary sort: places in user's travel area first, then closest distance
        withDist.sort((a, b) => {
            if (a.isInPlanArea && !b.isInPlanArea) return -1;
            if (!a.isInPlanArea && b.isInPlanArea) return 1;
            return a.distanceKm - b.distanceKm;
        });

        // Heat candidates: indoor / aircon (strictly <= 12 words)
        const heatCandidates = withDist.slice(0, 4).map(c => ({
            ...c,
            suggestedVisitTime: "12:30 PM - 02:00 PM",
            reason: `Air-conditioned shelter in ${c.area} avoiding peak midday heat.`
        }));

        // Rain candidates: covered / sheltered (strictly <= 12 words)
        const rainCandidates = (withDist.length >= 8 ? withDist.slice(4, 8) : withDist.slice(0, 4)).map(c => ({
            ...c,
            suggestedVisitTime: "02:30 PM - 04:00 PM",
            reason: `Sheltered indoor spot in ${c.area} safe from rain.`
        }));

        return { heatCandidates, rainCandidates };
    } catch (e) {
        console.error("Error generating weather candidates:", e);
        return { heatCandidates: [], rainCandidates: [] };
    }
}

// --- 🌦️ WEATHER RECOMMENDATIONS ENDPOINT ---
router.post('/weather-recommendations', async (req, res) => {
    try {
        const { places = [], target_day = 'monday' } = req.body;
        const result = await getWeatherCandidates(places, target_day);
        res.json({
            success: true,
            heat_recommendations: result.heatCandidates,
            rain_recommendations: result.rainCandidates
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// --- 🔄 OPTIMIZE MODIFIED PLAN ENDPOINT (Save and Apply) ---
router.post('/optimize-modified-plan', async (req, res) => {
    try {
        const { places = [], travel_dates = null, depart_time = null, end_time = null } = req.body;
        if (!Array.isArray(places) || places.length === 0) {
            return res.status(400).json({ success: false, error: "At least one place is required." });
        }

        const travelStartDate = (travel_dates && travel_dates.start_date) ? new Date(travel_dates.start_date) : new Date();
        const daysOfWeek = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
        const targetDay = daysOfWeek[travelStartDate.getDay()] || 'monday';
        const formattedDateString = (travel_dates && travel_dates.start_date) ? travel_dates.start_date : new Date().toISOString().split('T')[0];

        // 1. Enrich places with MongoDB
        const enriched = [];
        for (const p of places) {
            let dbPlace = null;
            if (p.name) {
                const escapedName = p.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                dbPlace = await PlaceNew.findOne({ name: { $regex: `^${escapedName}$`, $options: 'i' } })
                    || await PlaceNew.findOne({ name: { $regex: escapedName, $options: 'i' } });
            }

            const category = p.category || dbPlace?.primary_category || 'Attraction';
            const bHoursObj = dbPlace?.place_business_hours || dbPlace?.opening_hours || {};
            let closeMins = 18 * 60; // default 18:00
            let openMins = 9 * 60;  // default 09:00
            let isClosedToday = false;

            if (bHoursObj && typeof bHoursObj === 'object' && bHoursObj[targetDay]) {
                const daySched = bHoursObj[targetDay];
                if (typeof daySched === 'string') {
                    if (daySched.toLowerCase().includes('closed')) {
                        isClosedToday = true;
                    } else {
                        const match = daySched.match(/(\d+(?::\d+)?)\s*(am|pm)?\s*[-–—]\s*(\d+(?::\d+)?)\s*(am|pm)/i);
                        if (match) {
                            let [_, op, opAp, cl, clAp] = match;
                            if (!opAp) opAp = clAp;
                            const pOpen = parseTimeToMinutes(`${op} ${opAp}`);
                            const pClose = parseTimeToMinutes(`${cl} ${clAp}`);
                            if (pOpen !== null) openMins = pOpen;
                            if (pClose !== null) closeMins = pClose;
                        }
                    }
                } else if (daySched && typeof daySched === 'object') {
                    if (daySched.is_closed === true) {
                        isClosedToday = true;
                    }
                    if (daySched.open) {
                        const parsedOpen = parseTimeToMinutes(daySched.open);
                        if (parsedOpen !== null) openMins = parsedOpen;
                    }
                    if (daySched.close) {
                        const parsedClose = parseTimeToMinutes(daySched.close);
                        if (parsedClose !== null) closeMins = parsedClose;
                    }
                }
            } else if (dbPlace?.raw_hours_text) {
                const raw = dbPlace.raw_hours_text.toLowerCase();
                if (raw.includes('closed')) isClosedToday = true;
                const match = raw.match(/(\d+(?::\d+)?)\s*(am|pm)?\s*[-–—]\s*(\d+(?::\d+)?)\s*(am|pm)/i);
                if (match) {
                    let [_, op, opAp, cl, clAp] = match;
                    if (!opAp) opAp = clAp;
                    const pOpen = parseTimeToMinutes(`${op} ${opAp}`);
                    const pClose = parseTimeToMinutes(`${cl} ${clAp}`);
                    if (pOpen !== null) openMins = pOpen;
                    if (pClose !== null) closeMins = pClose;
                }
            }

            const img = p.imageUrl || dbPlace?.cover_image || dbPlace?.place_media?.thumbnail || (dbPlace?.images && dbPlace.images[0]?.url) || '';

            enriched.push({
                id: p.id || dbPlace?._id?.toString() || `stop_${Date.now()}_${Math.random()}`,
                name: p.name,
                area: p.area || (dbPlace ? extractArea(dbPlace) : 'Penang'),
                category: category,
                lat: p.lat || (dbPlace?.place_location?.coordinates ? dbPlace.place_location.coordinates[1] : 5.414),
                lng: p.lng || (dbPlace?.place_location?.coordinates ? dbPlace.place_location.coordinates[0] : 100.328),
                description: p.description || dbPlace?.summary || '',
                imageUrl: img,
                openMinutes: openMins,
                closeMinutes: closeMins,
                isClosedToday: isClosedToday,
                stayMinutes: p.estimatedStayMinutes || 60,
                existingTip: p.tip || null
            });
        }

        // 2. Parse travel window
        let departMinutes = 9 * 60;
        let endMinutes = 17 * 60;
        if (depart_time && typeof depart_time === 'string') {
            const parts = depart_time.split(':');
            if (parts.length >= 2) departMinutes = parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
        }
        if (end_time && typeof end_time === 'string') {
            const parts = end_time.split(':');
            if (parts.length >= 2) endMinutes = parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
        }
        if (endMinutes <= departMinutes) endMinutes = departMinutes + 360;

        // Helper to format minutes to 12-hour clock (e.g. "09:45 AM")
        const formatMinutesToClock = (totalMinutes) => {
            const norm = totalMinutes % (24 * 60);
            const h24 = Math.floor(norm / 60);
            const m = norm % 60;
            const period = h24 >= 12 ? 'PM' : 'AM';
            let h12 = h24 % 12;
            if (h12 === 0) h12 = 12;
            return `${h12.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')} ${period}`;
        };

        // 3. Detect conflicts and re-sequence if necessary (with Geographic Route Optimization)
        const transitMins = 15;
        let currentMins = departMinutes;
        let adjustedPlaces = optimizeGeographicRoute(enriched);
        let hasAdjustment = false;
        const adjustmentReasons = {};

        // Tentative check of stops in user's sequence
        for (let i = 0; i < adjustedPlaces.length; i++) {
            const p = adjustedPlaces[i];
            const arrivalMins = currentMins;
            const departureMins = arrivalMins + p.stayMinutes;

            // Conflict condition:
            // Venue closes at or before departureMins, or arrival is after closing, or less than 15 mins available
            const closingConflict = !p.isClosedToday && (departureMins > p.closeMinutes || arrivalMins >= (p.closeMinutes - 15));
            if (closingConflict && i > 0) {
                // Find a position earlier where venue is open during visit
                let swapTargetIdx = -1;
                for (let j = 0; j < i; j++) {
                    const earlyPlace = adjustedPlaces[j];
                    if (earlyPlace.closeMinutes > p.closeMinutes || earlyPlace.closeMinutes >= 20 * 60) {
                        swapTargetIdx = j;
                        break;
                    }
                }
                if (swapTargetIdx === -1) swapTargetIdx = 0;

                const removed = adjustedPlaces.splice(i, 1)[0];
                adjustedPlaces.splice(swapTargetIdx, 0, removed);
                hasAdjustment = true;

                const closeTimeClock = formatMinutesToClock(removed.closeMinutes);
                adjustmentReasons[removed.name] = `Rescheduled: Venue closes at ${closeTimeClock}; moved earlier.`;
                break; // re-evaluated
            }
            currentMins = departureMins + transitMins;
        }

        // 4. Try Ollama (gemma4:cloud) for tips and AI validation
        let gemmaTips = {};
        try {
            const prompt = `
You are 'Penny' (Kia-Kia Penang Pink Bird mascot, 潘妮), an expert AI travel companion.
User has updated their itinerary on ${formattedDateString}.
Places in sequence:
${adjustedPlaces.map((p, idx) => `${idx + 1}. "${p.name}" (Area: ${p.area}, Category: ${p.category})`).join('\n')}

For each place, provide a lively, friendly Manglish mascot tip (12-18 words, e.g. using 'Jom', 'lah', 'must try').
Respond strictly in JSON:
{
  "tips": {
    ${adjustedPlaces.map(p => `"${p.name}": "tip text"`).join(',\n    ')}
  }
}
`;
            const gemmaRes = await fetch(OLLAMA_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: 'gemma4:cloud',
                    prompt: prompt,
                    stream: false,
                    format: 'json',
                    temperature: 0.3
                })
            });
            const gemmaData = await gemmaRes.json();
            if (gemmaData && gemmaData.response) {
                let clean = gemmaData.response.trim();
                if (clean.startsWith('```json')) clean = clean.replace(/^```json\s*/, '').replace(/\s*```$/, '').trim();
                else if (clean.startsWith('```')) clean = clean.replace(/^```\s*/, '').replace(/\s*```$/, '').trim();
                const parsed = JSON.parse(clean);
                if (parsed.tips && typeof parsed.tips === 'object') {
                    gemmaTips = parsed.tips;
                }
            }
        } catch (e) {
            console.log("Gemma tip generation fallback:", e.message);
        }

        // 5. Build timeline items & final synchronized places
        const timeline = [];
        const finalPlaces = [];
        let walkMins = departMinutes;
        const totalTripWindow = endMinutes - departMinutes;
        const canHaveFreeTime = totalTripWindow >= 330 && endMinutes >= (15 * 60) && departMinutes <= (11 * 60) && adjustedPlaces.length >= 3;

        adjustedPlaces.forEach((p, idx) => {
            // Check Free Time Bridge insertion
            if (canHaveFreeTime && idx === 2 && walkMins >= (12 * 60) && walkMins < (14 * 60)) {
                const freeStart = formatMinutesToClock(walkMins);
                walkMins += 90;
                const freeEnd = formatMinutesToClock(walkMins);
                timeline.push({
                    type: 'free_time',
                    time_slot: `${freeStart} - ${freeEnd}`,
                    duration: '1.5 hours',
                    options: {
                        A: `Explore nearby local cafes in ${p.area}.`,
                        B: `Head early to next area for seaside views.`,
                        C: 'Relax and recharge before the next stop.'
                    }
                });
            }

            const startClock = formatMinutesToClock(walkMins);
            const stopStay = p.stayMinutes;
            const endStopMins = walkMins + stopStay;
            const endClock = formatMinutesToClock(endStopMins);
            const timeSlot = `${startClock} - ${endClock}`;

            const tip = gemmaTips[p.name] || p.existingTip || `Enjoy exploring ${p.name}! Don't forget to take photos lah!`;
            const isAdj = !!adjustmentReasons[p.name];
            const reason = adjustmentReasons[p.name] || null;

            timeline.push({
                type: 'stop',
                place_name: p.name,
                area: p.area,
                category: p.category,
                lat: p.lat,
                lng: p.lng,
                time_slot: timeSlot,
                tip: tip,
                warning_flag: p.isClosedToday ? 'CLOSED' : null,
                is_adjusted: isAdj,
                adjustment_reason: reason
            });

            finalPlaces.push({
                id: p.id,
                name: p.name,
                area: p.area,
                category: p.category,
                lat: p.lat,
                lng: p.lng,
                description: p.description,
                imageUrl: p.imageUrl,
                estimatedStayMinutes: p.stayMinutes,
                suggestedVisitTime: timeSlot,
                tip: tip,
                isAdjusted: isAdj,
                adjustmentReason: reason
            });

            walkMins = endStopMins + transitMins;
        });

        res.json({
            success: true,
            timeline: timeline,
            places: finalPlaces,
            mascot_message: hasAdjustment 
                ? "I adjusted your visit sequence to make sure you visit before venues close! 🤖✨" 
                : "Applied your updated itinerary with fresh tips! 🤖✨"
        });
    } catch (err) {
        console.error("Optimize Modified Plan API Error:", err.message);
        res.status(500).json({ success: false, error: "Failed to optimize modified plan." });
    }
});

// --- 🔍 DIRECT VECTOR SEARCH ENDPOINT ---
router.post('/places/search-vector', async (req, res) => {
    try {
        const { query, limit = 4 } = req.body;
        if (!query) {
            return res.status(400).json({ success: false, error: "query is required" });
        }

        const vector = await getEmbedding(query);
        const places = await findPlacesFromMongo(query, { limit });

        res.json({
            success: true,
            query: query,
            vector_length: vector.length,
            count: places.length,
            places: places
        });
    } catch (err) {
        console.error("Vector Search API Error:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
module.exports.findPlacesFromMongo = findPlacesFromMongo;
module.exports.getEmbedding = getEmbedding;
module.exports.calculateCosineSimilarity = calculateCosineSimilarity;
module.exports.performVectorSimilaritySearch = performVectorSimilaritySearch;
module.exports.findPlacesByRegex = findPlacesByRegex;
module.exports.extractTargetSearchTerm = extractTargetSearchTerm;
module.exports.scoreVibeDimensions = scoreVibeDimensions;
module.exports.VIBE_SEMANTIC_DIMENSIONS = VIBE_SEMANTIC_DIMENSIONS;



// # DATE REQUIREMENT & LOCK PLAN RULE
// If the user wants to lock or finalize the trip, DO NOT ask for travel dates in chat! 
// Direct the user to tap the bottom-left checklist icon (with the draft count badge at the corner) and generate the plan there.

// # SCHEDULING & BUSINESS HOURS RULE
// When generating the final timeline with known dates, strictly respect the provided operating hours for each location. Do not schedule a visit when a place is closed (e.g., closed on Mondays).

// # THE "FREE TIME" RULE
// When generating a full-day itinerary, you MUST include at least one "Free Time (自由时间)" block of 1.5 to 2 hours (e.g., after lunch or before dinner). 
// - Label it clearly as "Free Time / 自由时间" in the schedule.
// - If the user later asks "What should I do during my free time?", suggest 2-3 spontaneous nearby activities (like a hidden cafe, street art hunting, or local dessert) based on their last scheduled location.

// # ADVICE VS. OVERRIDE RULE
// - You have strong domain knowledge of Penang's weather and optimal visiting windows (e.g., beaches at sunset, indoor heritage mansions during midday heat).
// - When generating the initial itinerary, always place outdoor/beach activities in the early morning or late afternoon (after 5:00 PM).
// - If the user insists on visiting an outdoor/beach place at midday (11:00 AM - 3:00 PM):
//   1. Respect their choice and assign the requested time.
//   2. Add a friendly, lighthearted warning about the heat/sun.
//   3. Suggest carrying sun protection or staying hydrated.

