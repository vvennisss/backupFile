require('dotenv').config({ path: '../.env' });
const mongoose = require('mongoose');
const { executeBirdChat } = require('./services/birdPersonaEngine');

async function test() {
    await mongoose.connect(process.env.MONGODB_URI);
    const queries = [
        'what is the price level of Leong San Tong Khoo Kongsi?',
        'what is the opening hours of Leong San Tong Khoo Kongsi?',
        'what is the website of Leong San Tong Khoo Kongsi?',
        'what is the contact number of Leong San Tong Khoo Kongsi?',
        'Khoo Kongsi 的门票多少钱？',
        'Khoo Kongsi 的营业时间是什么？',
        'Khoo Kongsi 的电话号码是多少？'
    ];

    for (const q of queries) {
        console.log('\n======================================================');
        console.log('Testing query:', q);
        const res = await executeBirdChat({ message: q, history: [], context: {}, mode: 'global_explorer' });
        console.log('Result isFactualInquiry:', res.isFactualInquiry);
        console.log('Result message:', res.message);
    }

    await mongoose.disconnect();
}

test();
