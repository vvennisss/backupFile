const path = require('path');
// 解析上一层根目录下的 .env 文件
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
// 如果你是在本地运行独立脚本，通常需要 dotenv 来读取 .env 文件里的环境变量

const mongoose = require('mongoose');
// 请确保这里的路径正确指向你的模型文件
const Place = require('./models/Place'); 

const MONGO_URI = process.env.MONGO_URI || process.env.MONGODB_URI || process.env.MONGO_URL;

async function checkDistinctCategories() {
  try {
    if (!MONGO_URI) {
      throw new Error('未能在 .env 文件中读取到 MONGO_URI，请确认 .env 中的变量名！');
    }

    console.log('Connecting to MongoDB Atlas...');
    await mongoose.connect(MONGO_URI);
    console.log('Connected.\n');

    // Fetch just the unique category names
    const uniqueCategories = await Place.distinct('place_category');

    console.log(`Found ${uniqueCategories.length} distinct categories:\n`);
    
    // Sort alphabetically for easier reading and print them out
    uniqueCategories.sort().forEach((category, index) => {
      console.log(`${index + 1}. ${category || 'Uncategorized (Blank)'}`);
    });

  } catch (error) {
    console.error('Error fetching categories:', error.message || error);
  } finally {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
      console.log('\nDatabase connection closed.');
    }
  }
}

checkDistinctCategories();