const path = require('path');
// Load .env variables (Checks current dir, then parent dir)
require('dotenv').config({ path: path.resolve(__dirname, './.env') });
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { MongoClient } = require('mongodb');
const axios = require('axios');
const fs = require('fs');
const { URL } = require('url');

// =================== CONFIGURATION ===================
// Use environment variable, fallback to localhost if not found
const MONGO_URI = process.env.MONGODB_URI || process.env.MONGO_URI || process.env.MONGO_URL || 'mongodb://localhost:27017';
const DB_NAME = process.env.DB_NAME || 'test';
const COLLECTION_NAME = 'places';
const DOWNLOAD_DIR = path.join(__dirname, 'public', 'images', 'places');

// Ensure the download directory exists
if (!fs.existsSync(DOWNLOAD_DIR)) {
    fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}

// Helper: Extract real direct image URL from Google imgres links
function getDirectImageUrl(rawUrl) {
    try {
        if (rawUrl.includes('google.com/imgres')) {
            const parsedUrl = new URL(rawUrl);
            const imgUrl = parsedUrl.searchParams.get('imgurl');
            return imgUrl ? decodeURIComponent(imgUrl) : rawUrl;
        }
        return rawUrl;
    } catch (err) {
        return rawUrl;
    }
}

// Helper: Download image and save to disk
async function downloadImage(url, filename) {
    const filePath = path.join(DOWNLOAD_DIR, filename);
    const response = await axios({
        url,
        method: 'GET',
        responseType: 'stream',
        timeout: 10000 // 10 second timeout
    });

    return new Promise((resolve, reject) => {
        const writer = fs.createWriteStream(filePath);
        response.data.pipe(writer);
        writer.on('finish', () => resolve(`/images/places/${filename}`)); // Returns relative path for UI
        writer.on('error', reject);
    });
}

// Main Runner
async function run() {
    console.log(`Connecting to MongoDB...`);
    const client = new MongoClient(MONGO_URI);

    try {
        await client.connect();
        console.log(`Connected successfully! Database: ${DB_NAME}`);
        
        const db = client.db(DB_NAME);
        const collection = db.collection(COLLECTION_NAME);

        // Find documents that have a thumbnail URL starting with 'http'
        const query = { "place_media.thumbnail": { $regex: "^http" } };
        const total = await collection.countDocuments(query);
        
        if (total === 0) {
            console.log('No images to process. Everything is up to date.');
            return;
        }

        console.log(`Found ${total} places to process. Starting download...\n`);

        let done = 0;
        let failed = 0;

        // Use a cursor to iterate efficiently without loading everything into RAM
        const cursor = collection.find(query);

        for await (const place of cursor) {
            const rawUrl = place.place_media.thumbnail;
            const directUrl = getDirectImageUrl(rawUrl);
            
            // Create a clean filename using the place ID
            // Handle edge cases where the URL might not have a clean extension
            let ext = directUrl.split('.').pop().split('?')[0].slice(0, 4);
            if (!['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(ext.toLowerCase())) {
                ext = 'jpg'; // Fallback extension
            }
            const filename = `${place.external_place_id}.${ext}`;

            try {
                // Download and save the image
                const localPath = await downloadImage(directUrl, filename);

                // Update the document with the new local path
                await collection.updateOne(
                    { _id: place._id },
                    { $set: { "place_media.thumbnail": localPath } }
                );
                done++;
            } catch (error) {
                failed++;
                // Silently handle the error to keep the loop going, or log it to a file
            }

            // Real-time console update using process.stdout
            const pending = total - (done + failed);
            process.stdout.write(`\rProgress: [Done: ${done}] | [Failed: ${failed}] | [Pending: ${pending}] | [Total: ${total}]`);
        }

        console.log('\n\nMigration completed successfully!');

    } catch (error) {
        console.error('\nAn error occurred:', error);
    } finally {
        await client.close();
        console.log('Database connection closed.');
    }
}

run();