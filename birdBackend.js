const express = require('express');
const fetch = require('node-fetch'); // Ensure you have node-fetch@2 installed

const app = express();
const PORT = 3001;
const OLLAMA_URL = 'http://127.0.0.1:11434/api/generate';

app.use(express.json());

// --- 🗺️ GEOLOCATION LOGIC (NEW) ---
// Haversine formula to calculate distance between two [longitude, latitude] points
function calculateDistanceInKm(coord1, coord2) {
    const [lon1, lat1] = coord1;
    const [lon2, lat2] = coord2;
    const R = 6371; // Radius of the Earth in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
}

// --- 🧠 CORE LLM FUNCTIONS ---

async function parseIntent(userInput) {
    const prompt = `
    Extract the travel preferences from the user's input into a strict JSON format. 
    Format: {"places": ["list of places/types"], "activities": ["list of activities"], "pace": "relaxed or packed"}
    User input: "${userInput}"
    `;

    const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            model: "llama3.2:3b", 
            prompt: prompt,
            format: "json",
            stream: false
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`Ollama Internal Error: ${data.error}`);
    return JSON.parse(data.response);
}

// 🆕 UPDATED: Added Few-Shot Prompting to control Manglish and formatting
async function generateItinerary(parsedIntentJSON, selectedPlaces) {
    const systemPrompt = `
    You are the travel guide bird mascot for the Kia-Kia Penang app. You are a foodie, enthusiastic, and helpful. 
    
    CRITICAL INSTRUCTIONS:
    1. ONLY speak English. No Chinese characters.
    2. SIMPLE ENGLISH ONLY: Speak in very basic, elementary English. Keep sentences short.
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
    - Ngam: Perfect / Just right!
    - Syiok: Extremely satisfying / Great feeling!
    
    [NEGATIVE / SHOCK SLANG] - STRICT RULE: ONLY use when there is a problem, a conflict, or a crazy itinerary. NEVER use these in a happy sentence!
    - Alamak: Oh no / Oops (Use when places are closed or weather is bad).
    - Walao: Oh my god / Crazy (Use when the user plans 5 places in 1 hour).

    EXAMPLES OF HOW YOU SHOULD SPEAK (Learn from these!):
    User: Plan a trip for me!
    Bird: Awesome choice! We can kia-kia around Georgetown in the morning when it's cool. For lunch, let's grab some ho chiak local food. Keep it relaxed and fun!

    BAD EXAMPLE (DO NOT DO THIS): "Have a great day at the beach, Alamak!" (Wrong because Alamak is for bad situations).
    GOOD EXAMPLE: "Have a great day at the beach! It's going to be syiok!"

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
            model: "llama3.2:3b", 
            system: systemPrompt,
            prompt: userPrompt,
            stream: false,
            temperature: 0.3 //lower temperature, lesser hallucination
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`Ollama Internal Error: ${data.error}`);
    return data.response.trim();
}

async function generateBirdReaction(conflictFlag, alternativePlan) {
    const systemPrompt = `
    You are a friendly Penang travel guide bird.

    CRITICAL RULES (OBEY OR FAIL):
    1. SIMPLE ENGLISH ONLY: Speak in basic, elementary English. Keep sentences very short.
    2. NO WESTERN SLANG OR COMPLEX WORDS: DO NOT use words like "ditch", "vibe", "wander", "explore", "Instagram-worthy". Use simple words like "change", "beautiful", "walk", "see", "photos".
    3. STRICT MANGLISH: DO NOT invent words. You must use "Alamak" OR "Jom" correctly.
       - Alamak: Oh no! (Use ONLY at the very beginning of the response to react to the problem).
       - Jom: Let's go! (Use at the end to encourage the user).

    BAD EXAMPLE (DO NOT DO THIS): "Don't worry, lah! That's a long way, Alamak! Let's ditch the park." (Wrong position for Alamak, uses forbidden word 'ditch').
    GOOD EXAMPLE: "Alamak! 13.8km is too far to travel. Let's change the plan and look at the beautiful street art near the cafe instead. Jom!"

    YOUR TASK:
    React to the problem and suggest the alternative in exactly 2 or 3 short sentences.
    `;

    const userPrompt = `
    Problem: ${conflictFlag}. 
    Suggest: ${alternativePlan}.
    React to the user.
    `;

    const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            model: "llama3.2:3b", 
            system: systemPrompt,
            prompt: userPrompt,
            stream: false,
            temperature: 0.2 // 🔥 Super low temperature to prevent hallucinating complex words
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`Ollama Internal Error: ${data.error}`);
    return data.response.trim();
}

app.listen(PORT, () => {
    console.log(`\n🐤 Bird Backend running on http://localhost:${PORT}`);
});

// --- 🧪 VS CODE AUTO-TEST RUNNER ---
setTimeout(async () => {
    console.log("\n--- 🧪 STARTING LOCAL VS CODE TESTS ---\n");

    try {
        // MOCK DATABASE RECORDS
        const theDailyDose = {
            place_name: 'The Daily Dose Cafe Penang',
            coordinates: [100.3374109, 5.4193772] // Georgetown
        };
        const escapeThemePark = {
            place_name: 'Escape Theme Park',
            coordinates: [100.2166, 5.4495] // Teluk Bahang (Very far)
        };

        // STEP 1: Parse Intent
        const testInput = "I want to eat laksa, have some coffee, take photos of street art, and visit historic buildings.";
        console.log(`User Input: "${testInput}"\n`);
        console.log("Test 1: Parsing Intent...");
        const parsedJSON = await parseIntent(testInput);
        console.log("✅ Parsed JSON:\n", JSON.stringify(parsedJSON, null, 2));

        // STEP 2: Geographic Logic Test
        console.log("\nTest 2: Checking Distance between selected places...");
        const distance = calculateDistanceInKm(theDailyDose.coordinates, escapeThemePark.coordinates);
        console.log(`📏 Distance calculated: ${distance.toFixed(2)} km`);
        
        let conflictDetected = null;
        if (distance > 10) {
            conflictDetected = `The distance between ${theDailyDose.place_name} and ${escapeThemePark.place_name} is ${distance.toFixed(1)}km, which is too far for a relaxed trip.`;
            console.log("⚠️ Backend Logic Flagged a Conflict!");
        }

        // STEP 3: Bird Reaction OR Itinerary Generation
        if (conflictDetected) {
            console.log("\nTest 3: Generating Bird Reaction to Geographic Conflict...");
            const reaction = await generateBirdReaction(
                conflictDetected,
                "Drop the Theme Park and explore more street art near the cafe instead"
            );
            console.log("✅ Bird Reaction:\n", reaction);
        } else {
            console.log("\nTest 3: Generating Itinerary from JSON...");
            const itinerary = await generateItinerary(parsedJSON, [theDailyDose.place_name]);
            console.log("✅ Bird Itinerary Output:\n\n", itinerary);
        }

        console.log("\n--- 🏁 TESTS COMPLETE ---\n");
    } catch (err) {
        console.error("❌ Test Failed:", err.message);
    }
}, 1500);