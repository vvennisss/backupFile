/**
 * batchUpdateDescriptionSummary.js
 * 
 * 批量根据已验证上下文 (VERIFIED CONTEXT) 重写 places_new 集合的 summary 和 description。
 * 严格遵守 4 项核心规则：
 * 1. Base the description ONLY on the provided VERIFIED CONTEXT.
 * 2. DO NOT make up dates, construction materials, historical figures, or amenities not present in the context.
 * 3. If the context is missing details, provide a brief factual summary based solely on what is known.
 * 4. Output MUST be valid JSON matching the requested schema.
 * 
 * 使用方式：
 *   node batchUpdateDescriptionSummary.js                   # 默认运行
 *   node batchUpdateDescriptionSummary.js --limit=10        # 仅测试处理前 10 条
 *   node batchUpdateDescriptionSummary.js --concurrency=5   # 设置并发数 (默认 4)
 *   node batchUpdateDescriptionSummary.js --model=...       # 自定义模型
 */

const mongoose = require('mongoose');
const fetch = require('node-fetch');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const PlaceNew = require('./models/PlaceNew');

const MONGODB_URI = process.env.MONGODB_URI;
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434/api/generate';

// 命令行参数解析
const args = process.argv.slice(2);
const limitArg = args.find(a => a.startsWith('--limit='));
const LIMIT = limitArg ? parseInt(limitArg.split('=')[1], 10) : 0;
const concurrencyArg = args.find(a => a.startsWith('--concurrency='));
const CONCURRENCY = concurrencyArg ? parseInt(concurrencyArg.split('=')[1], 10) : 4;
const modelArg = args.find(a => a.startsWith('--model='));
let TARGET_MODEL = modelArg ? modelArg.split('=')[1] : 'llama-3.3:70b-cloud';

// 提取单条地点的已验证事实上下文 (VERIFIED CONTEXT)
function buildVerifiedContext(p) {
  const ctx = {
    name: p.name,
    area: p.area || 'Penang',
    primary_category: p.primary_category,
    address: p.address || undefined,
    price_level: p.place_information?.price_level || (p.price_level === 0 ? 'Free' : undefined),
    opening_hours: p.raw_hours_text || undefined,
    contact_phone: p.place_information?.phone || undefined,
    website: (p.place_information?.website && !p.place_information.website.includes('cid=')) ? p.place_information.website : undefined
  };

  // 仅在明确为 true 时列出核准设施
  const verifiedAmenities = [];
  if (p.features?.is_wheelchair_accessible === true) verifiedAmenities.push('wheelchair accessible');
  if (p.features?.has_parking === true) verifiedAmenities.push('parking available');
  if (p.features?.wifi_available === true) verifiedAmenities.push('Wi-Fi available');
  if (p.features?.has_aircon === true) verifiedAmenities.push('air conditioning');
  else if (p.features?.has_aircon === false) verifiedAmenities.push('open-air/outdoor setting (no air conditioning)');
  if (p.features?.is_michelin === true) verifiedAmenities.push('Michelin recognized');
  if (p.features?.specialty_coffee === true) verifiedAmenities.push('specialty coffee');
  if (p.features?.is_halal === true) verifiedAmenities.push('Halal certified');

  if (verifiedAmenities.length > 0) {
    ctx.verified_amenities = verifiedAmenities;
  }

  if (p.ticket_fee) {
    if (p.ticket_fee.is_free) {
      ctx.admission = 'Free admission';
    } else if (p.ticket_fee.amount_myr > 0) {
      ctx.admission = `RM ${p.ticket_fee.amount_myr}`;
    }
  }

  return ctx;
}

// 调用大模型生成严格符合规则的 JSON
async function generateStrictFactualJson(verifiedContext, modelToUse) {
  const systemPrompt = `You are a strict factual data generator for travel destinations.
STRICT RULES:
1. Base the description ONLY on the provided VERIFIED CONTEXT.
2. DO NOT make up dates, construction materials, historical figures, or amenities not present in the context.
3. If the context is missing details, provide a brief factual summary based solely on what is known.
4. Output MUST be valid JSON matching the requested schema:
{"summary": "1-2 brief factual sentences summarizing the place", "description": "2-4 factual sentences describing the place based solely on context"}
DO NOT output any introductory text, markdown code blocks, or explanations. Only pure valid JSON.`;

  const userPrompt = `VERIFIED CONTEXT:\n${JSON.stringify(verifiedContext, null, 2)}`;

  const response = await fetch(OLLAMA_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: modelToUse,
      system: systemPrompt,
      prompt: userPrompt,
      stream: false,
      format: 'json',
      temperature: 0.1
    })
  });

  const data = await response.json();
  if (data.error) {
    throw new Error(data.error);
  }

  let text = data.response.trim();
  // 过滤多余的 markdown 包裹
  text = text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '').trim();
  return JSON.parse(text);
}

// 主批量更新流程
async function runBatch() {
  console.log(`\n======================================================`);
  console.log(`🚀 Batch Enrichment: Strictly Factual description & summary`);
  console.log(`🎯 Target Model: ${TARGET_MODEL}`);
  console.log(`⚡ Concurrency: ${CONCURRENCY}`);
  if (LIMIT > 0) console.log(`📌 Processing Limit: ${LIMIT} places`);
  console.log(`======================================================\n`);

  try {
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB Atlas.');

    // 检查模型可用性，若指定模型不存在则自动回退到已验证可用的云端模型
    let activeModel = TARGET_MODEL;
    try {
      await generateStrictFactualJson({ name: 'Test Place', area: 'Penang' }, activeModel);
      console.log(`✨ Model '${activeModel}' is online and verified.`);
    } catch (err) {
      console.warn(`⚠️ Warning: Model '${activeModel}' returned error: ${err.message}`);
      if (activeModel.includes('llama')) {
        console.log(`🔄 Automatically falling back to verified cloud model 'gemma4:31b-cloud'...`);
        activeModel = 'gemma4:31b-cloud';
        await generateStrictFactualJson({ name: 'Test Place', area: 'Penang' }, activeModel);
        console.log(`✅ Fallback model '${activeModel}' ready.`);
      } else {
        throw err;
      }
    }

    // 查询所有地点
    let query = PlaceNew.find({}, {
      name: 1,
      area: 1,
      primary_category: 1,
      address: 1,
      place_information: 1,
      raw_hours_text: 1,
      features: 1,
      ticket_fee: 1,
      price_level: 1
    }).lean();

    if (LIMIT > 0) query = query.limit(LIMIT);
    const places = await query.exec();
    const total = places.length;
    console.log(`📦 Loaded ${total} places to process.\n`);

    let processedCount = 0;
    let successCount = 0;
    let failCount = 0;
    const startTime = Date.now();

    // 并发工作池
    async function worker(items) {
      for (const place of items) {
        processedCount++;
        const currentIdx = processedCount;
        const ctx = buildVerifiedContext(place);

        try {
          const resJson = await generateStrictFactualJson(ctx, activeModel);

          if (resJson && resJson.summary && resJson.description) {
            await PlaceNew.updateOne(
              { _id: place._id },
              {
                $set: {
                  summary: resJson.summary.trim(),
                  description: resJson.description.trim(),
                  updatedAt: new Date()
                }
              }
            );
            successCount++;
            if (currentIdx % 20 === 0 || currentIdx === total) {
              const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);
              const percent = ((currentIdx / total) * 100).toFixed(1);
              console.log(`[${currentIdx}/${total}] (${percent}%) - Success: ${successCount}, Failed: ${failCount} (${elapsedSec}s elapsed)`);
            }
          } else {
            throw new Error('Invalid JSON format returned');
          }
        } catch (err) {
          failCount++;
          console.error(`❌ [${currentIdx}/${total}] Failed for "${place.name}":`, err.message);
        }
      }
    }

    // 分配到工作池并发执行
    const chunks = Array.from({ length: CONCURRENCY }, () => []);
    places.forEach((p, idx) => chunks[idx % CONCURRENCY].push(p));

    await Promise.all(chunks.map(chunk => worker(chunk)));

    const totalSeconds = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`\n================== 执行完成报告 ==================`);
    console.log(`🎉 批量处理完毕！`);
    console.log(`⏱️ 总用时: ${totalSeconds} 秒`);
    console.log(`✅ 成功更新地点数: ${successCount}`);
    console.log(`❌ 失败条数: ${failCount}`);
    console.log(`==================================================\n`);

  } catch (err) {
    console.error('❌ 执行失败:', err);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 已安全断开 MongoDB 连接。\n');
  }
}

// 优雅处理 Ctrl+C
process.on('SIGINT', async () => {
  console.log('\n\n⚠️ 用户手动中断任务 (Ctrl+C)。已完成记录已成功安全持久化到 MongoDB。');
  await mongoose.disconnect();
  process.exit(0);
});

runBatch();
