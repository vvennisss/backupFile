/**
 * refinePlacesDescription.js
 * 
 * Refines the 'description' and 'summary' for places in MongoDB 'places_new'.
 * Produces longer, more elaborate, and beautifully written travel descriptions
 * while strictly adhering to anti-hallucination guardrails grounded in verified context.
 * 
 * Supported Providers:
 *   - ollama  (Local / Self-hosted, e.g. llama3.2:3b, mistral:latest, qwen3:4b) [Default]
 *   - gemini  (Google Gemini API, e.g. gemini-2.0-flash, gemini-1.5-flash)
 *   - openai  (OpenAI or compatible, e.g. gpt-4o-mini)
 * 
 * Usage Examples:
 *   # 1. Dry run (preview BEFORE & AFTER for 3 places without modifying DB):
 *   node refinePlacesDescription.js --dry-run --sample=3
 * 
 *   # 2. Refine only short/robotic descriptions in 'Cafes' using Ollama:
 *   node refinePlacesDescription.js --category=Cafes --only-short --limit=10
 * 
 *   # 3. Use Gemini API for high-speed processing (requires GEMINI_API_KEY in .env):
 *   node refinePlacesDescription.js --provider=gemini --model=gemini-2.0-flash --limit=20
 * 
 *   # 4. Refine a single place by MongoDB ID:
 *   node refinePlacesDescription.js --id=6ab3ae98ceab80143ca1a8de --dry-run
 * 
 *   # 5. Full run on all places with concurrency:
 *   node refinePlacesDescription.js --concurrency=4
 */

const mongoose = require('mongoose');
const path = require('path');
const fetch = require('node-fetch');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const PlaceNew = require('./models/PlaceNew');

// --- CLI Arguments Parsing ---
const args = process.argv.slice(2);
function getArg(key, defaultVal) {
  const match = args.find(a => a.startsWith(`--${key}=`));
  if (match) return match.split('=')[1];
  if (args.includes(`--${key}`)) return true;
  return defaultVal;
}

const IS_DRY_RUN = args.includes('--dry-run');
const PROVIDER = (getArg('provider', process.env.LLM_PROVIDER || 'ollama')).toLowerCase();
const LIMIT = parseInt(getArg('limit', getArg('sample', '0')), 10);
const SKIP = parseInt(getArg('skip', '0'), 10);
const IS_PAID_TIER = args.includes('--paid-tier');
const IS_FREE_TIER = args.includes('--free-tier') || (!IS_PAID_TIER && PROVIDER === 'gemini');

// Default models per provider
let MODEL = getArg('model', null);
if (!MODEL) {
  if (PROVIDER === 'gemini') MODEL = 'gemini-2.0-flash';
  else if (PROVIDER === 'openai') MODEL = 'gpt-4o-mini';
  else MODEL = 'gemma4:31b-cloud'; // Default high-capability 31B cloud model
}

const IS_CLOUD_OLLAMA = MODEL.includes('cloud');
const CONCURRENCY = parseInt(getArg('concurrency', (PROVIDER === 'gemini' && IS_FREE_TIER) ? '1' : (IS_CLOUD_OLLAMA ? '3' : '1')), 10);
const REQUEST_DELAY_MS = parseInt(getArg('delay', (PROVIDER === 'gemini' && IS_FREE_TIER) ? '4100' : '0'), 10);
const CATEGORY_FILTER = getArg('category', null);
const ONLY_SHORT = args.includes('--only-short'); // Targets short/robotic descriptions (< 180 chars)
const TARGET_ID = getArg('id', null);
const FORCE = args.includes('--force'); // Reprocess even if already marked description_refined: true

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// Configuration endpoints and keys
const MONGODB_URI = process.env.MONGODB_URI;
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const GEMINI_API_KEY = getArg('apiKey', process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '');
const OPENAI_API_KEY = getArg('apiKey', process.env.OPENAI_API_KEY || '');

// --- Verified Context Builder ---
function buildVerifiedContext(p) {
  const ctx = {
    name: p.name || p.place_name,
    primary_category: p.primary_category || p.place_category,
    sub_categories: (p.sub_categories && p.sub_categories.length > 0) ? p.sub_categories : undefined,
    area: p.area || 'Penang',
    address: p.address || p.place_address || undefined,
  };

  // Operating Hours
  if (p.raw_hours_text && p.raw_hours_text.trim() && p.raw_hours_text !== '9:00 AM – 6:00 PM') {
    ctx.operating_hours = p.raw_hours_text;
  } else if (p.opening_hours?.is_24_hours) {
    ctx.operating_hours = 'Open 24 hours';
  }

  // Price & Admission
  if (p.ticket_fee) {
    if (p.ticket_fee.is_free) {
      ctx.admission = 'Free entry / No ticket fee required';
    } else if (p.ticket_fee.amount_myr > 0) {
      ctx.admission = `RM ${p.ticket_fee.amount_myr}`;
    }
  }
  const priceRange = p.place_information?.price_level || (p.price_level === 0 ? 'Free' : undefined);
  if (priceRange) {
    ctx.typical_price_level = priceRange;
  }

  // Traveler Rating & Popularity (grounding traveler reputation)
  const rating = p.place_information?.rating || p.rating;
  const reviewsCount = p.place_information?.reviews_count || p.review_count;
  if (rating) {
    ctx.traveler_feedback = `${rating} / 5.0 stars${reviewsCount ? ` (based on ${reviewsCount.toLocaleString()} traveler reviews)` : ''}`;
  }

  // Verified Amenities & Features
  const verifiedFeatures = [];
  if (p.features?.has_aircon === true) {
    verifiedFeatures.push('Comfortable air-conditioned indoor seating');
  } else if (p.features?.has_aircon === false) {
    verifiedFeatures.push('Open-air / alfresco tropical atmosphere');
  }

  if (p.features?.is_wheelchair_accessible === true) verifiedFeatures.push('Wheelchair accessible');
  if (p.features?.has_parking === true) verifiedFeatures.push('Parking available nearby');
  if (p.features?.wifi_available === true) verifiedFeatures.push('Wi-Fi available');
  if (p.features?.is_michelin === true) verifiedFeatures.push('Michelin Guide recognized / recommended');
  if (p.features?.specialty_coffee === true) verifiedFeatures.push('Specialty artisan coffee');
  if (p.features?.is_halal === true) verifiedFeatures.push('Halal-certified');
  if (p.features?.is_vegetarian_friendly === true) verifiedFeatures.push('Vegetarian-friendly options');

  if (verifiedFeatures.length > 0) {
    ctx.verified_amenities = verifiedFeatures;
  }

  // Retain existing summary if it has meaningful historical notes (excluding generic robotic templates)
  if (p.summary && !p.summary.includes('is a cafe located in') && !p.summary.includes('Notable spot in')) {
    ctx.existing_reference_notes = p.summary;
  }

  return ctx;
}

// --- Anti-Hallucination System Prompt ---
const SYSTEM_PROMPT = `You are a distinguished travel author and local curator for "Kia Kia Penang", a premier mobile discovery guide for Penang, Malaysia.

TASK:
Refine and write an elaborate, engaging, and beautifully descriptive travel narrative for the given Penang place, based SOLELY on the provided VERIFIED CONTEXT.

STRICT ANTI-HALLUCINATION RULES:
1. TRUTH BOUNDARY: Only draw from the verified context facts (name, category, sub_categories, area, address, hours, amenities, price, rating).
2. NO INVENTED HISTORY: Do NOT invent specific founding years (e.g. "built in 1876"), fictional colonial figures, or fabricated legends.
3. NO INVENTED MENU ITEMS: Do NOT fabricate specific signature dishes or drink names (e.g., NEVER make up "try the lavender cold brew" or "famous for duck confit"). Instead, speak authentically about the style of food/beverages that match its category (e.g., "handcrafted espresso drinks, freshly baked pastries, and casual cafe fare" for cafes; "local hawker favorites and savory regional specialties" for local food).
4. NO INVENTED AMENITIES (CRITICAL ZERO-TOLERANCE): NEVER mention Wi-Fi, internet connection, air conditioning, parking, swimming pools, or any facilities unless they appear explicitly in the 'verified_amenities' array. If 'Wi-Fi' is NOT in 'verified_amenities', you MUST NOT state or imply that Wi-Fi is available.
5. NO MECHANICAL ROBOTIC LISTING: Do not write "Situated at X. It features Y. It has parking." Integrate verified features smoothly and gracefully into natural prose.
6. NO META-TALK: Never say "Based on the provided context" or "As an AI".

OUTPUT SPECIFICATIONS:
Respond ONLY with a valid JSON object matching this schema:
{
  "summary": "A punchy, evocative 1-2 sentence overview (approx 25-45 words) highlighting what makes this place special for travelers.",
  "description": "An elaborate, vivid 2 to 3 paragraph narrative (approx 120-180 words total). Separate each paragraph with a double newline (\\n\\n).
   - Paragraph 1: Introduce the place, its setting within Penang (neighborhood/area atmosphere), and its welcoming ambiance.
   - Paragraph 2: Elaborate on the visitor experience, atmosphere, and what visitors enjoy here matching its category and verified amenities (e.g. relaxing in air-conditioned comfort vs enjoying breezy open-air street vibes).
   - Paragraph 3: Practical visit guidance smoothly blending hours, admission/price range, accessibility, and parking context (ONLY if confirmed in verified_amenities)."
}`;

// --- Provider Implementations ---

// 1. Ollama Provider
async function callOllama(verifiedContext, model) {
  const prompt = `VERIFIED CONTEXT:\n${JSON.stringify(verifiedContext, null, 2)}\n\nIMPORTANT: Strictly obey all anti-hallucination rules. Do NOT mention Wi-Fi, air conditioning, or any facility unless explicitly stated in verified_amenities. Write the refined JSON description.`;
  const url = `${OLLAMA_URL.replace(/\/$/, '')}/api/generate`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: model,
      system: SYSTEM_PROMPT,
      prompt: prompt,
      stream: false,
      format: 'json',
      options: {
        temperature: 0.2, // Low temperature to maximize adherence to facts and minimize hallucination
        top_p: 0.9
      }
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Ollama HTTP ${response.status}: ${errorText}`);
  }

  const data = await response.json();
  if (data.error) throw new Error(`Ollama error: ${data.error}`);
  return cleanAndParseJson(data.response);
}

// 2. Gemini API Provider (Fast, Ultra-Capable, Cost-Effective)
async function callGemini(verifiedContext, model, apiKey, retryCount = 0) {
  if (!apiKey) {
    throw new Error('Gemini API key is required! Set GEMINI_API_KEY in .env or pass --apiKey=YOUR_KEY');
  }

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const userContent = `VERIFIED CONTEXT:\n${JSON.stringify(verifiedContext, null, 2)}\n\nWrite the refined JSON description following all rules.`;

  const payload = {
    system_instruction: {
      parts: [{ text: SYSTEM_PROMPT }]
    },
    contents: [{
      role: 'user',
      parts: [{ text: userContent }]
    }],
    generationConfig: {
      response_mime_type: 'application/json',
      temperature: 0.2
    }
  };

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const errorText = await response.text();
    // Intelligent handling of HTTP 429 (Rate Limit / Quota Exceeded)
    if (response.status === 429) {
      if (errorText.toLowerCase().includes('quota') && (errorText.toLowerCase().includes('day') || errorText.toLowerCase().includes('daily'))) {
        throw new Error(`🛑 Daily Quota Limit (1,500 RPD) reached on Free Tier. All completed records are saved. You can resume tomorrow!`);
      }
      if (retryCount < 5) {
        const waitMs = Math.min(60000, (retryCount + 1) * 12000); // 12s, 24s, 36s, 48s, 60s
        console.warn(`   ⚠️ [429 Rate Limit] Pausing for ${waitMs / 1000}s before retry (${retryCount + 1}/5)...`);
        await sleep(waitMs);
        return callGemini(verifiedContext, model, apiKey, retryCount + 1);
      }
    }
    throw new Error(`Gemini HTTP ${response.status}: ${errorText}`);
  }

  const data = await response.json();
  const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) throw new Error('No candidate content returned by Gemini API');
  return cleanAndParseJson(rawText);
}

// 3. OpenAI API Provider
async function callOpenAI(verifiedContext, model, apiKey) {
  if (!apiKey) {
    throw new Error('OpenAI API key is required! Set OPENAI_API_KEY in .env or pass --apiKey=YOUR_KEY');
  }

  const endpoint = 'https://api.openai.com/v1/chat/completions';
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model: model,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: `VERIFIED CONTEXT:\n${JSON.stringify(verifiedContext, null, 2)}` }
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2
    })
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI HTTP ${response.status}: ${errorText}`);
  }

  const data = await response.json();
  const rawText = data.choices?.[0]?.message?.content;
  if (!rawText) throw new Error('No content returned by OpenAI API');
  return cleanAndParseJson(rawText);
}

// Clean and Parse JSON response
function cleanAndParseJson(rawText) {
  let cleaned = rawText.trim();
  cleaned = cleaned.replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/```\s*$/i, '').trim();
  const parsed = JSON.parse(cleaned);

  if (!parsed.summary || !parsed.description) {
    throw new Error('Returned JSON is missing "summary" or "description" property');
  }

  return {
    summary: parsed.summary.trim(),
    description: parsed.description.trim()
  };
}

// Dispatcher for LLM Generation
async function generateRefinedDescription(context) {
  if (PROVIDER === 'gemini') {
    return await callGemini(context, MODEL, GEMINI_API_KEY);
  } else if (PROVIDER === 'openai') {
    return await callOpenAI(context, MODEL, OPENAI_API_KEY);
  } else {
    return await callOllama(context, MODEL);
  }
}

// --- Main Execution Flow ---
async function main() {
  console.log('\n======================================================');
  console.log('🏛️  Kia Kia Penang — places_new Description Refiner');
  console.log('======================================================');
  console.log(`🤖 Provider:    ${PROVIDER.toUpperCase()}`);
  console.log(`🧠 Model:       ${MODEL}`);
  if (PROVIDER === 'gemini') {
    console.log(`💳 Tier:        ${IS_PAID_TIER ? 'Paid Tier (High concurrency)' : 'Free Tier (Paced at ~14.6 RPM with auto 429 backoff)'}`);
  }
  console.log(`⚙️ Mode:        ${IS_DRY_RUN ? '🔍 DRY RUN (Simulate without saving)' : '💾 PRODUCTION (Saving to MongoDB)'}`);
  console.log(`⚡ Concurrency: ${CONCURRENCY}`);
  if (REQUEST_DELAY_MS > 0) console.log(`⏱️ Pace Delay:  ${REQUEST_DELAY_MS}ms per request`);
  if (CATEGORY_FILTER) console.log(`🏷️  Category:    ${CATEGORY_FILTER}`);
  if (ONLY_SHORT)      console.log(`📏 Filter:      Only short/robotic descriptions (< 180 chars)`);
  if (LIMIT > 0)       console.log(`🎯 Limit:       ${LIMIT} records`);
  console.log('======================================================\n');

  if (!MONGODB_URI) {
    console.error('❌ MONGODB_URI is not set in .env!');
    process.exit(1);
  }

  // Connect to MongoDB
  await mongoose.connect(MONGODB_URI);
  console.log('✅ Connected to MongoDB Atlas.');

  // Build MongoDB query
  const query = {};

  if (TARGET_ID) {
    query._id = TARGET_ID;
  } else {
    if (CATEGORY_FILTER) {
      query.primary_category = CATEGORY_FILTER;
    }
    if (ONLY_SHORT) {
      // Matches descriptions with length less than 180 characters or missing
      query.$or = [
        { description: { $exists: false } },
        { description: null },
        { description: '' },
        { $expr: { $lt: [{ $strLenCP: { $ifNull: ['$description', ''] } }, 180] } }
      ];
    }
    if (!FORCE && !IS_DRY_RUN) {
      query.description_refined = { $ne: true };
    }
  }

  let dbQuery = PlaceNew.find(query).skip(SKIP).lean({ defaults: false });
  if (LIMIT > 0) dbQuery = dbQuery.limit(LIMIT);

  const places = await dbQuery.exec();
  const total = places.length;

  if (total === 0) {
    console.log('ℹ️ No places match the specified criteria.');
    await mongoose.disconnect();
    return;
  }

  console.log(`📦 Loaded ${total} place(s) to process.\n`);

  let processedCount = 0;
  let successCount = 0;
  let failCount = 0;
  const startTime = Date.now();

  // Worker loop
  async function worker(items) {
    for (const place of items) {
      processedCount++;
      const currentIdx = processedCount;
      const placeName = place.name || place.place_name || 'Unnamed Place';

      try {
        const itemStart = Date.now();
        const verifiedContext = buildVerifiedContext(place);
        const refined = await generateRefinedDescription(verifiedContext);
        const itemElapsed = ((Date.now() - itemStart) / 1000).toFixed(1);

        if (IS_DRY_RUN) {
          console.log(`\n------------------------------------------------------`);
          console.log(`📍 [${currentIdx}/${total}] ${placeName} (${place.primary_category || 'N/A'}, ${place.area || 'Penang'}) [${itemElapsed}s]`);
          console.log(`------------------------------------------------------`);
          console.log(`🔴 OLD SUMMARY:`);
          console.log(`   ${place.summary || '(none)'}`);
          console.log(`🟢 NEW SUMMARY:`);
          console.log(`   ${refined.summary}`);
          console.log(`\n🔴 OLD DESCRIPTION (${(place.description || '').length} chars):`);
          console.log(`   ${place.description || '(none)'}`);
          console.log(`\n🟢 NEW REFINED DESCRIPTION (${refined.description.length} chars):`);
          console.log(`   ${refined.description.split('\n\n').join('\n\n   ')}`);
          console.log(`------------------------------------------------------`);
        } else {
          // Save to MongoDB
          await PlaceNew.updateOne(
            { _id: place._id },
            {
              $set: {
                summary: refined.summary,
                description: refined.description,
                description_refined: true,
                description_refined_at: new Date(),
                updatedAt: new Date()
              }
            }
          );

          successCount++;
          const percent = ((currentIdx / total) * 100).toFixed(1);
          console.log(`✅ [${currentIdx}/${total}] (${percent}%) Refined: "${placeName}" in ${itemElapsed}s`);
        }

        if (IS_DRY_RUN) successCount++;

        // Apply pacing delay between requests if configured (e.g. Free Tier)
        if (REQUEST_DELAY_MS > 0 && currentIdx < total) {
          await sleep(REQUEST_DELAY_MS);
        }

      } catch (err) {
        failCount++;
        console.error(`❌ [${currentIdx}/${total}] Failed for "${placeName}": ${err.message}`);
      }
    }
  }

  // Partition into concurrency workers
  const chunks = Array.from({ length: CONCURRENCY }, () => []);
  places.forEach((p, idx) => chunks[idx % CONCURRENCY].push(p));

  await Promise.all(chunks.map(chunk => worker(chunk)));

  const totalSeconds = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\n================== Execution Report ==================`);
  console.log(`🎉 Finished processing!`);
  console.log(`⏱️ Total Time:     ${totalSeconds}s`);
  console.log(`✅ Success:        ${successCount}`);
  console.log(`❌ Failed:         ${failCount}`);
  if (IS_DRY_RUN) {
    console.log(`💡 NOTE: This was a DRY RUN. No changes were written to MongoDB.`);
    console.log(`   To apply changes, remove the --dry-run flag.`);
  }
  console.log(`======================================================\n`);

  await mongoose.disconnect();
}

// Graceful interrupt handling
process.on('SIGINT', async () => {
  console.log('\n\n⚠️ Execution interrupted by user (Ctrl+C). Cleaning up...');
  await mongoose.disconnect();
  console.log('🔌 Disconnected from MongoDB. Exiting safely.');
  process.exit(0);
});

main().catch(err => {
  console.error('\n❌ Fatal error during execution:', err);
  mongoose.disconnect();
  process.exit(1);
});
