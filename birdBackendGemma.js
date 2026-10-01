// file:birdBackendGemma.js
const express = require('express');
const fetch = require('node-fetch'); 
const readline = require('readline'); 

const app = express();
const PORT = 3001;

// If your local Ollama is routing to the cloud, localhost works fine.
// If you are calling the Ollama Cloud API directly, change this to 'https://ollama.com/api/generate' and add your API key in the headers.
const OLLAMA_URL = 'http://127.0.0.1:11434/api/generate'; 

app.use(express.json());

// --- 🧠 LIGHTWEIGHT CLOUD LLM FUNCTION ---

async function chatWithBird(userInput) {
    // Extremely lightweight system prompt. Cloud models don't need heavy rules.
    const systemPrompt = "You are 'Travel Bird', a friendly, food-loving travel guide mascot for Penang. Keep your answers concise, helpful, and use occasional simple Manglish (like 'Jom!' or 'lah').";

    const response = await fetch(OLLAMA_URL, {
        method: 'POST',
        headers: { 
            'Content-Type': 'application/json',
            // 'Authorization': `Bearer YOUR_OLLAMA_API_KEY` // Uncomment if hitting the cloud API directly
        },
        body: JSON.stringify({
            model: "gemma4:cloud", 
            system: systemPrompt,
            prompt: userInput,
            stream: false,
            // A slightly lower temperature keeps responses focused and concise
            temperature: 0.4 
        })
    });
    
    const data = await response.json();
    if (data.error) throw new Error(`API Error: ${data.error}`);
    
    return data.response.trim();
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
            console.log('\n⏳ Bird is thinking...');
            const reply = await chatWithBird(userInput);
            console.log("\n🐤 Bird:\n" + "\x1b[36m" + reply + "\x1b[0m"); 
            
        } catch (err) {
            console.error("\n❌ Error:", err.message);
        }

        startInteractiveChat();
    });
}

// --- START SERVER AND CLI ---
app.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`🐤 Minimal Bird Backend is running on port ${PORT}`);
    console.log(`======================================================`);
    startInteractiveChat();
});