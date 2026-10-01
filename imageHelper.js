const axios = require('axios');
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const PUBLIC_DIR = path.join(__dirname, '../public');

/**
 * Extracts real image target from Google imgres URLs
 */
function extractTargetUrl(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return '';
  const trimmed = rawUrl.trim();
  if (trimmed.includes('google.com/imgres')) {
    try {
      const u = new URL(trimmed);
      if (u.searchParams.has('imgurl')) {
        return u.searchParams.get('imgurl');
      }
    } catch (_) {}
  }
  return trimmed;
}

/**
 * Searches Serper for a real photo when existing photo is missing, corrupted, or 403
 */
async function fetchSerperPhoto(placeName) {
  if (!placeName || !process.env.SERPER_API_KEY) return null;
  try {
    const serperRes = await axios.post('https://google.serper.dev/images', {
      q: `${placeName}, Penang`,
      num: 3
    }, {
      headers: {
        'X-API-KEY': process.env.SERPER_API_KEY,
        'Content-Type': 'application/json'
      },
      timeout: 6000
    });

    const images = serperRes.data.images || [];
    for (const img of images) {
      if (img.imageUrl && img.imageUrl.startsWith('http') && !img.imageUrl.includes('google.com/imgres')) {
        try {
          const freshResp = await axios.get(img.imageUrl, {
            responseType: 'arraybuffer',
            headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
            timeout: 5000
          });
          const freshResized = await sharp(Buffer.from(freshResp.data))
            .resize({ width: 500, height: 350, fit: 'cover', withoutEnlargement: true })
            .jpeg({ quality: 75 })
            .toBuffer();
          return `data:image/jpeg;base64,${freshResized.toString('base64')}`;
        } catch (_) {}
      }
    }
  } catch (_) {}
  return null;
}

/**
 * Converts any image source into an optimized base64 data URI
 */
async function convertToBase64(rawSource, placeName = '') {
  if (!rawSource || typeof rawSource !== 'string') {
    return fetchSerperPhoto(placeName);
  }
  const trimmed = rawSource.trim();

  // 1. Already Base64
  if (trimmed.startsWith('data:image/')) {
    return trimmed;
  }

  // 2. If it points to undefined.jpg, fetch directly via Serper
  if (trimmed.includes('undefined.jpg') || trimmed === 'no_image_found') {
    return fetchSerperPhoto(placeName);
  }

  // 3. Local disk file (/images/places/...)
  if (trimmed.startsWith('/images/') || trimmed.startsWith('images/')) {
    const cleanPath = trimmed.startsWith('/') ? trimmed.slice(1) : trimmed;
    const fullPath = path.join(PUBLIC_DIR, cleanPath);
    if (fs.existsSync(fullPath)) {
      try {
        const fileBuf = fs.readFileSync(fullPath);
        // Verify it is not an HTML error file saved with .jpg extension
        const header = fileBuf.slice(0, 10).toString();
        if (header.includes('<') || header.includes('html') || header.includes('DOCTYPE')) {
          return fetchSerperPhoto(placeName);
        }

        const resizedBuffer = await sharp(fileBuf)
          .resize({ width: 500, height: 350, fit: 'cover', withoutEnlargement: true })
          .jpeg({ quality: 75 })
          .toBuffer();
        return `data:image/jpeg;base64,${resizedBuffer.toString('base64')}`;
      } catch (err) {
        return fetchSerperPhoto(placeName);
      }
    } else {
      return fetchSerperPhoto(placeName);
    }
  }

  // 4. Google imgres link or direct HTTP/HTTPS URL
  let targetUrl = extractTargetUrl(trimmed);
  if (targetUrl.startsWith('http://') || targetUrl.startsWith('https://')) {
    try {
      const resp = await axios.get(targetUrl, {
        responseType: 'arraybuffer',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8'
        },
        timeout: 6000
      });

      const resizedBuffer = await sharp(Buffer.from(resp.data))
        .resize({ width: 500, height: 350, fit: 'cover', withoutEnlargement: true })
        .jpeg({ quality: 75 })
        .toBuffer();

      return `data:image/jpeg;base64,${resizedBuffer.toString('base64')}`;
    } catch (err) {
      return fetchSerperPhoto(placeName);
    }
  }

  return fetchSerperPhoto(placeName);
}

/**
 * Saves any image (URL, base64, Serper search) to disk and returns its static relative URL
 */
async function saveImageLocally(rawSource, filename, placeName = '') {
  if (!filename) return '';
  const cleanFilename = filename.endsWith('.jpg') ? filename : `${filename}.jpg`;
  const targetDir = path.join(PUBLIC_DIR, 'images', 'places');
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }
  const fullDiskPath = path.join(targetDir, cleanFilename);
  const relativeUrl = `/images/places/${cleanFilename}`;

  // If already exists on disk and is not empty
  if (fs.existsSync(fullDiskPath) && fs.statSync(fullDiskPath).size > 0) {
    return relativeUrl;
  }

  // 1. If rawSource is Base64
  if (typeof rawSource === 'string' && rawSource.startsWith('data:image/')) {
    try {
      const dataPart = rawSource.replace(/^data:image\/\w+;base64,/, '');
      fs.writeFileSync(fullDiskPath, Buffer.from(dataPart, 'base64'));
      return relativeUrl;
    } catch (_) {}
  }

  // 2. If rawSource is an HTTP URL
  let targetUrl = extractTargetUrl(rawSource);
  if (targetUrl && (targetUrl.startsWith('http://') || targetUrl.startsWith('https://'))) {
    try {
      const resp = await axios.get(targetUrl, {
        responseType: 'arraybuffer',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/*'
        },
        timeout: 6000
      });

      await sharp(Buffer.from(resp.data))
        .resize({ width: 500, height: 350, fit: 'cover', withoutEnlargement: true })
        .jpeg({ quality: 75 })
        .toFile(fullDiskPath);

      return relativeUrl;
    } catch (_) {}
  }

  // 3. Search via Serper if needed
  if (placeName && process.env.SERPER_API_KEY) {
    try {
      const serperRes = await axios.post('https://google.serper.dev/images', {
        q: `${placeName}, Penang`,
        num: 3
      }, {
        headers: {
          'X-API-KEY': process.env.SERPER_API_KEY,
          'Content-Type': 'application/json'
        },
        timeout: 6000
      });

      const images = serperRes.data.images || [];
      for (const img of images) {
        if (img.imageUrl && img.imageUrl.startsWith('http') && !img.imageUrl.includes('google.com/imgres')) {
          try {
            const freshResp = await axios.get(img.imageUrl, {
              responseType: 'arraybuffer',
              headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
              timeout: 5000
            });
            await sharp(Buffer.from(freshResp.data))
              .resize({ width: 500, height: 350, fit: 'cover', withoutEnlargement: true })
              .jpeg({ quality: 75 })
              .toFile(fullDiskPath);
            return relativeUrl;
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  return '';
}

module.exports = {
  extractTargetUrl,
  convertToBase64,
  saveImageLocally
};
