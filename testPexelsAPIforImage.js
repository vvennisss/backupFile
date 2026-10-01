import http from 'http';
import readline from 'readline';
import open from 'open';

const API_KEY = '58SzTdsDVROtF0Ai6HkiPGID9KUWVMCtFFul7bunz3Dxe3iJdY8ZV3Jd'; // 👈 Replace with your Pexels API Key
const PORT = 3000;

// Setup console input reader
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// 1. Prompt the user in the console
rl.question('Enter a place name to search: ', async (placeName) => {
  if (!placeName.trim()) {
    console.log('Please enter a valid place name.');
    rl.close();
    return;
  }

  console.log(`Searching Pexels for "${placeName}"...`);
  
  try {
    // 2. Fetch image from Pexels API
    const response = await fetch(
      `https://pexels.com{encodeURIComponent(placeName)}&per_page=1`,
      { headers: { Authorization: API_KEY } }
    );
    
    const data = await response.json();
    const photo = data.photos?.[0];

    if (!photo) {
      console.log(`❌ No images found for "${placeName}".`);
      rl.close();
      return;
    }

    const imageUrl = photo.src.large;
    const photographer = photo.photographer;
    const photographerUrl = photo.photographer_url;

    console.log(`✅ Image found! Starting HTTP server...`);

    // 3. Create a local HTTP server to host the HTML page
    const server = http.createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(`
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>Pexels Result: ${placeName}</title>
          <style>
            body { font-family: sans-serif; text-align: center; background: #f4f4f9; padding: 20px; }
            img { max-width: 80%; max-height: 70vh; border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
            h1 { color: #333; }
            p { color: #666; }
            a { color: #05a081; text-decoration: none; font-weight: bold; }
          </style>
        </head>
        <body>
          <h1>Result for: "${placeName}"</h1>
          <img src="${imageUrl}" alt="${placeName}"><br><br>
          <p>Photo by <a href="${photographerUrl}" target="_blank">${photographer}</a> on Pexels</p>
        </body>
        </html>
      `);
    });

    // 4. Start server and launch browser
    server.listen(PORT, async () => {
      console.log(`🌐 Server running at http://localhost:${PORT}`);
      console.log(`🚀 Opening your browser automatically...`);
      await open(`http://localhost:${PORT}`);
      console.log(`Press Ctrl+C in this terminal to shut down the server when done.`);
    });

  } catch (error) {
    console.error('❌ Error fetching data:', error.message);
  }

  rl.close();
});
