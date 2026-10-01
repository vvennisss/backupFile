// require('dotenv').config();
// const mongoose = require('mongoose');
// const axios = require('axios');
// const Place = require('./models/Place');

// const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// async function enrichAllBlankSummaries() {
//   try {
//     console.log('1. Connecting to MongoDB Atlas...');
//     await mongoose.connect(process.env.MONGODB_URI);
//     console.log('Connected.\n');

//     // Fetch ALL records with blank or empty summaries (no limit)
//     const placesToUpdate = await Place.find({
//       $or: [
//         { place_summary: "" },
//         { place_summary: null },
//         { place_summary: { $exists: false } },
//         { place_summary: /^\s*$/ }
//       ]
//     });

//     const total = placesToUpdate.length;
//     if (total === 0) {
//       console.log('No blank summaries found! All places are fully enriched.');
//       return;
//     }

//     console.log(`Found ${total} places with blank summaries to process.\n`);

//     let count = 0;
//     for (let place of placesToUpdate) {
//       count++;
//       console.log(`[${count}/${total}] Generating summary for: ${place.place_name}...`);

//       const prompt = `
//         You are a local travel guide in Penang. 
//         Write a short, engaging 4-sentence description for a place called "${place.place_name}".
//         Category: ${place.place_category}. 
//         Keep it factual, exciting for tourists, and under 550 characters. Do not use hashtags.
//       `;

//       try {
//         const response = await axios.post('http://localhost:11434/api/generate', {
//           model: 'llama3.2:3b',
//           prompt: prompt,
//           stream: false
//         });

//         const newSummary = response.data.response.trim();

//         // Save new summary to MongoDB
//         place.place_summary = newSummary;
//         await place.save();

//         console.log(`-> Summary: ${newSummary}\n`);
//       } catch (err) {
//         console.error(`-> Failed to process "${place.place_name}": ${err.message}\n`);
//       }

//       // Small pause between iterations to let the hardware breathe
//       await delay(500);
//     }

//     console.log(`All ${total} records processed successfully!`);

//   } catch (error) {
//     console.error('Database connection or query error:', error);
//   } finally {
//     await mongoose.disconnect();
//     console.log('Database connection closed.');
//   }
// }

// enrichAllBlankSummaries();


require('dotenv').config();
const mongoose = require('mongoose');
const axios = require('axios');
const Place = require('./models/Place');

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// STRICT REGEX: The entire string from start (^) to end ($) must be Chinese characters or spaces.
// It will ignore names that contain any English letters, numbers, or standard punctuation.
const strictlyChineseRegex = /^[一-龥\s]+$/;

// Handle manual cancellation (Ctrl + C) gracefully
process.on('SIGINT', async () => {
  console.log('\n\nProcess interrupted by user (Ctrl+C).');
  console.log('All previously completed records are already saved in MongoDB.');
  await mongoose.disconnect();
  console.log('Database connection closed safely. Exiting...');
  process.exit(0);
});

async function enrichStrictlyChineseSummaries() {
  try {
    console.log('1. Connecting to MongoDB Atlas...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected.\n');

    // Query places where the place_name is ONLY Chinese characters
    const placesToUpdate = await Place.find({
      place_name: { $regex: strictlyChineseRegex }
    });

    const total = placesToUpdate.length;
    if (total === 0) {
      console.log('No purely Chinese place names found matching the criteria!');
      return;
    }

    console.log(`Found ${total} places with strictly Chinese names to process.\n`);

    let count = 0;
    for (let place of placesToUpdate) {
      count++;
      console.log(`[${count}/${total}] Generating English summary for: "${place.place_name}"...`);

      const prompt = `
        You are a local travel guide in Penang. 
        Write a short, engaging description for the place named "${place.place_name}".
        Category: ${place.place_category}. 
        
        STRICT RULES:
        1. The place name is in Chinese, but you MUST write the description entirely in ENGLISH.
        2. If you do not recognize the specific name, infer what it is from the category (${place.place_category}) and write an inviting, generic description.
        3. Do not apologize. Never say "I am not familiar" or "I cannot find".
        4. Keep it exciting for tourists and under 550 characters.
      `;

      try {
        const response = await axios.post('http://localhost:11434/api/generate', {
          model: 'qwen3:4b', 
          prompt: prompt,
          stream: false
        });

        const newSummary = response.data.response.trim();

        // Direct, instant update to MongoDB using updateOne
        await Place.updateOne(
          { _id: place._id },
          { $set: { place_summary: newSummary } }
        );

        console.log(`-> Summary Saved: ${newSummary}\n`);
      } catch (err) {
        console.error(`-> Failed to process "${place.place_name}": ${err.message}\n`);
      }

      await delay(500);
    }

    console.log(`All ${total} records processed successfully!`);

  } catch (error) {
    console.error('Database connection or query error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('Database connection closed.');
  }
}

enrichStrictlyChineseSummaries();