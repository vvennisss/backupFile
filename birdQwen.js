const express = require('express');
const fetch = require('node-fetch'); 
const readline = require('readline'); 

const app = express();
const PORT = 3001;
const OLLAMA_URL = 'http://127.0.0.1:11434/api/generate';

app.use(express.json());

// --- 🧽 HELPER: EXTRACT THINKING PROCESS ---
// 提取 <think> 标签中的内容
function extractThinking(rawText) {
    const match = rawText.match(/<think>([\s\S]*?)<\/think>/);
    if (match) {
        return {
            thinking: match[1].trim(),
            finalAnswer: rawText.replace(/<think>[\s\S]*?<\/think>/, '').trim()
        };
    }
    return { thinking: "No thinking process detected.", finalAnswer: rawText.trim() };
}

// --- 🧠 CORE LLM FUNCTIONS ---

async function parseIntent(userInput) {
    const prompt = `
    You are a strict data extractor.
    
    CRITICAL INSTRUCTIONS:
    1. You MUST think step-by-step. Wrap your ENTIRE thinking process inside <think> and </think> tags.
    2. AFTER your thinking process, you MUST output the final result as a raw JSON object wrapped inside \`\`\`json and \`\`\` tags.
    
    Format required:
    {"places": ["list of places/types"], "activities": ["list of activities"], "pace": "relaxed or packed"}
    
    User input: "${userInput}"
    `;

    const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            model: "qwen3:4b", // 确保名字与你本地运行的模型一致
            prompt: prompt,
            stream: false
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`Ollama Internal Error: ${data.error}`);
    
    let rawText = data.response;
    let thinking = "No thinking process detected.";
    let jsonStr = "";

    // 1. 抓取思考过程 (优先找 <think> 标签，找不到就把 JSON 之前的所有废话当成思考)
    const thinkMatch = rawText.match(/<think>([\s\S]*?)<\/think>/i);
    if (thinkMatch) {
        thinking = thinkMatch[1].trim();
    } else {
        const jsonStart = rawText.indexOf('```json');
        if (jsonStart > -1) {
            thinking = rawText.substring(0, jsonStart).replace(/<think>/i, '').trim();
        }
    }
    console.log(`\n[\x1b[90m🧠 Parse Intent Thinking:\x1b[0m]\n\x1b[90m${thinking}\x1b[0m`);

    // 2. 抓取 JSON (优先找 ```json 包裹的内容，找不到就找全文本中的最后一个 { ... } 块)
    const markdownMatch = rawText.match(/```json\s*([\s\S]*?)\s*```/i) || rawText.match(/```\s*(\{[\s\S]*?\})\s*```/);
    
    if (markdownMatch) {
        jsonStr = markdownMatch[1];
    } else {
        // Fallback: 匹配所有的 { ... }，并强制只取最后一个（因为模型最后生成的才是最终答案）
        const matches = rawText.match(/\{[\s\S]*?\}/g);
        if (matches && matches.length > 0) {
            jsonStr = matches[matches.length - 1];
        }
    }

    try {
        return JSON.parse(jsonStr.trim());
    } catch (parseError) {
        console.error("\n🚨 Failed to parse this extracted JSON string:\n", jsonStr);
        throw new Error(`Failed to parse Qwen JSON. See console.`);
    }
}

async function generateItinerary(parsedIntentJSON, selectedPlaces) {
    const systemPrompt = `
    You are the travel guide bird mascot for the Kia-Kia Penang app. You are a foodie, enthusiastic, and helpful. 
    
    CRITICAL INSTRUCTIONS:
    1. ONLY speak English. No Chinese characters.
    2. SIMPLE ENGLISH ONLY: Speak in very basic, elementary English. Keep sentences short, at least 10 words.
    3. NO COMPLEX WORDS: Do NOT use idioms or Western slang. Do NOT use words like "ditch", "vibrant", "wander", "taking in the sights". Use simple words like "change", "beautiful", "walk", "see".
    4. COMMON SENSE: DO NOT suggest eating (makan) inside museums, temples, or historic sites.
    5. STRICT MANGLISH DICTIONARY: You are STRICTLY FORBIDDEN from inventing any Malay, Indonesian, or local words (DO NOT use "bualan").
    6. MANGLISH TONE: You must sound natural. Use ONLY 1 or 2 slang words per entire response from this approved list:
    - Makan (Eat)
    - Ho Chiak (Delicious)
    - Tapau (Takeaway)
    - Kia-kia (Wander/Stroll)
    - Walao (Oh my god)
    - Alamak (Oh no)
    - Jom (Let's go)
    - Syiok (Extremely satisfying)

    [POSITIVE / NEUTRAL SLANG] - Use for happy planning and good suggestions:
    - Jom: Let's go!
    - Syiok: Extremely satisfying / Great feeling!
    
    [NEGATIVE / SHOCK SLANG] - STRICT RULE: ONLY use when there is a problem. NEVER use these in a happy sentence!
    - Alamak: Oh no / Oops.
    - Walao: Oh my god / Crazy.

    EXAMPLES OF HOW YOU SHOULD SPEAK (Follow this length and structure!):
    User: Plan a trip for me!
    Bird: Awesome choice, boss!
    [Morning] We will kia-kia around the beautiful streets of Georgetown when the weather is cool. You can take many photos of the old buildings and look at the famous street art.
    [Afternoon] It is time for a rest! We will find a nice place to sit down and enjoy some ho chiak local food. You can relax, drink cold coffee, and hide from the hot sun.
    [Evening] We will take a slow walk near the water to see the sunset. The view is very beautiful at night. It is going to be syiok! Jom!

    YOUR TASK:
    Plan a 1-day itinerary based on the user's preferences and the provided locations. 
    Organize by [Morning], [Afternoon], [Evening]. 
    Keep the slang natural and minimal like the example above.
    `;

    const userPrompt = `
    User Preferences: ${JSON.stringify(parsedIntentJSON)}
    Selected Locations to include: ${selectedPlaces.join(", ")}
    Please plan an exciting 1-day Penang itinerary!
    `;

    const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            model: "qwen3:4b", 
            system: systemPrompt,
            prompt: userPrompt,
            stream: false,
            temperature: 0.3
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`Ollama Internal Error: ${data.error}`);
    
    const extracted = extractThinking(data.response);
    console.log(`\n[\x1b[90m🧠 Itinerary Planning Thinking:\x1b[0m]\n\x1b[90m${extracted.thinking}\x1b[0m`);
    
    return extracted.finalAnswer;
}

// --- 💻 INTERACTIVE TERMINAL CLI ---

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function startInteractiveChat() {
    rl.question('\n🙋‍♂️ You: ', async (userInput) => {
        if (userInput.toLowerCase() === 'exit' || userInput.toLowerCase() === 'quit') {
            console.log('🐤 Bird: Bye boss! See you in Penang! 👋\n');
            rl.close();
            process.exit(0);
        }

        try {
            console.log('\n⏳ Bird is listening...');
            const parsedJSON = await parseIntent(userInput);
            console.log("✅ Parsed JSON Intent:\n", parsedJSON);

            console.log('\n⏳ Bird is drafting your itinerary...');
            const dynamicPlaces = parsedJSON.places && parsedJSON.places.length > 0 ? parsedJSON.places : ['Georgetown Area'];
            
            const itinerary = await generateItinerary(parsedJSON, dynamicPlaces);
            console.log("\n🐤 Bird Itinerary:\n" + "\x1b[36m" + itinerary + "\x1b[0m"); // 以青色高亮显示小鸟的最终回复
            
        } catch (err) {
            console.error("\n❌ Error:", err.message);
        }

        startInteractiveChat();
    });
}

// --- START SERVER AND CLI ---
app.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`🐤 Bird Backend Server is running on port ${PORT}`);
    console.log(`======================================================`);
    console.log(`\n💬 INTERACTIVE CHAT STARTED!`);
    console.log(`Type your travel plan below, or type 'exit' to quit.`);
    startInteractiveChat();
});