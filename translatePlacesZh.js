/**
 * translatePlacesZh.js
 * 
 * 使用 Ollama 的 gemma4:31b-cloud 模型将 places_new 集合中的
 * description 与 summary 翻译为高质量、地道流畅的简体中文，
 * 并保存为 description_zh 和 summary_zh。
 * 
 * 核心特性：
 * 1. 【断点续传 & 故障安全】：每翻译完一条记录立即持久化保存到 MongoDB，
 *    即使程序被随时手动终止（Ctrl+C）或网络闪断，已翻译的数据绝对不会丢失；
 *    重新运行时自动跳过已翻译的地点，从中断处无缝继续。
 * 2. 【高容错网络屏障】：深度防范 MongoDB Atlas read ECONNRESET、SocketTimeout 与网络重置，
 *    配备连接池主动保活、断线自动重连与写入指数退避重试机制。
 * 3. 【精准地名强约束】：内置马来西亚槟城官方权威译名表（如 Bayan Lepas = 峇六拜，绝非峇都丁宜）。
 * 4. 【并发批量处理】：支持基于工作池的高效并发（默认 4 并发，可自由调节）。
 * 
 * 使用示例：
 *   node translatePlacesZh.js                   # 默认模式，处理所有未翻译地点 (4 并发)
 *   node translatePlacesZh.js --limit=5         # 仅测试翻译前 5 条
 *   node translatePlacesZh.js --concurrency=6   # 提升并发加速处理
 *   node translatePlacesZh.js --dry-run --limit=2 # 演练模式（仅打印，不写入数据库）
 *   node translatePlacesZh.js --force --limit=3 # 强制重新翻译已有记录
 *   node translatePlacesZh.js --category=Cafes  # 仅处理指定分类
 */

const mongoose = require('mongoose');
const path = require('path');
const fs = require('fs');

// 兼容全局 fetch 与 node-fetch
const fetch = globalThis.fetch || require('node-fetch');

// 优先读取本地或上级目录的 .env
const envPaths = [
  path.join(__dirname, '.env'),
  path.join(__dirname, '../.env')
];
for (const p of envPaths) {
  if (fs.existsSync(p)) {
    require('dotenv').config({ path: p });
    break;
  }
}

const PlaceNew = require('./models/PlaceNew');

// --- 命令行参数解析 ---
const args = process.argv.slice(2);
function getArg(key, defaultVal = null) {
  const match = args.find(a => a.startsWith(`--${key}=`));
  if (match) return match.split('=')[1];
  if (args.includes(`--${key}`)) return true;
  return defaultVal;
}

const LIMIT = parseInt(getArg('limit', '0'), 10);
const CONCURRENCY = parseInt(getArg('concurrency', '4'), 10);
const IS_DRY_RUN = args.includes('--dry-run');
const FORCE = args.includes('--force');
const CATEGORY_FILTER = getArg('category', null);
const TARGET_ID = getArg('id', null);
const MODEL = getArg('model', process.env.TRANSLATE_MODEL || 'gemma4:31b-cloud');
const OLLAMA_HOST = (getArg('ollama', process.env.OLLAMA_URL || 'http://127.0.0.1:11434')).replace(/\/$/, '');
const MONGODB_URI = process.env.MONGODB_URI;

// 状态标记（支持平滑中断）
let isShuttingDown = false;

// 延时辅助函数
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

// --- MongoDB Atlas 高可用连接配置与防 ECONNRESET 优化 ---
const MONGO_OPTIONS = {
  maxPoolSize: 10,
  minPoolSize: 1,
  maxIdleTimeMS: 30000,         // 30秒主动淘汰空闲连接，避开 Atlas 防火墙静默断开造成的 ECONNRESET
  serverSelectionTimeoutMS: 45000,
  socketTimeoutMS: 90000,       // 允许大模型处理耗时期间 socket 保持
  connectTimeoutMS: 45000,
  heartbeatFrequencyMS: 10000,  // 定期心跳探测保持长连接活跃
  retryWrites: true,
  retryReads: true
};

// 监听并拦截 Mongoose 连接层事件，杜绝未监听 'error' 导致 Node.js 进程意外崩溃
mongoose.connection.on('error', (err) => {
  console.warn(`⚠️ [MongoDB 连接事件警告] ${err.message || err}`);
});
mongoose.connection.on('disconnected', () => {
  if (!isShuttingDown) {
    console.warn('⚠️ [MongoDB 连接状态] 连接已断开，底层正在尝试重新连接...');
  }
});
mongoose.connection.on('reconnected', () => {
  console.log('✅ [MongoDB 连接状态] 数据库连接已恢复正常！');
});

// 确保连接处于可用状态
async function ensureDbConnected() {
  if (mongoose.connection.readyState === 1) return;
  try {
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
    await mongoose.connect(MONGODB_URI, MONGO_OPTIONS);
  } catch (err) {
    console.warn(`⚠️ 尝试连接 MongoDB 出现异常: ${err.message}，稍后将重试...`);
    throw err;
  }
}

// 具备网络瞬断重试功能的数据库更新操作
async function safeDbUpdate(id, updateDoc, maxRetries = 5) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await ensureDbConnected();
      const col = mongoose.connection.db.collection('places_new');
      await col.updateOne({ _id: id }, updateDoc);
      return;
    } catch (err) {
      const isNetworkIssue =
        err.name === 'MongoNetworkError' ||
        err.name === 'MongoServerSelectionError' ||
        err.message?.includes('ECONNRESET') ||
        err.message?.includes('ETIMEDOUT') ||
        err.message?.includes('closed') ||
        err.hasErrorLabel?.('RetryableError') ||
        err.hasErrorLabel?.('SystemOverloadedError');

      if (isNetworkIssue && attempt < maxRetries && !isShuttingDown) {
        const backoff = attempt * 2000;
        console.warn(`⚠️ 检测到 MongoDB 瞬态网络重置 (${err.message})，正在第 ${attempt}/${maxRetries} 次重试并重连 (等待 ${backoff}ms)...`);
        try {
          await mongoose.disconnect();
        } catch (_) {}
        await sleep(backoff);
      } else {
        throw err;
      }
    }
  }
}

// 清理与解析 LLM 返回的 JSON
function cleanAndParseJson(rawText) {
  if (!rawText || typeof rawText !== 'string') {
    throw new Error('Empty response from model');
  }

  let cleaned = rawText.trim();
  cleaned = cleaned.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();

  try {
    return JSON.parse(cleaned);
  } catch (e1) {
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      const jsonCandidate = cleaned.substring(firstBrace, lastBrace + 1);
      return JSON.parse(jsonCandidate);
    }
    throw new Error(`JSON parse failed: ${e1.message}. Raw text: ${rawText.substring(0, 150)}...`);
  }
}

// 翻译单个地点（带重试机制）
async function translatePlace(place, maxRetries = 2) {
  const sourceName = place.name || place.place_name || 'Penang Attraction';
  const sourceCategory = place.primary_category || place.place_category || 'Travel';
  const sourceArea = place.area || 'Penang';
  const sourceSummary = (place.summary || '').trim();
  const sourceDescription = (place.description || '').trim();

  // 如果原本既没有 summary 也没有 description
  if (!sourceSummary && !sourceDescription) {
    return {
      summary_zh: '',
      description_zh: '',
      skippedEmpty: true
    };
  }

  const systemPrompt = `You are an expert bilingual travel guide author and professional translator for "Kia Kia Penang" (槟城漫游指南).
Your task is to translate English place "summary" and "description" into natural, fluent, elegant, and culturally accurate Simplified Chinese (简体中文).

PENANG OFFICIAL TOPONYMY & LOCAL TERMINOLOGY (CRITICAL ACCURACY):
- "Bayan Lepas" -> 峇六拜 (CRITICAL: Bayan Lepas is ALWAYS 峇六拜! NEVER translate Bayan Lepas as 峇都丁宜!)
- "Batu Ferringhi" -> 峇都丁宜 (Batu Ferringhi is the beach resort area in the north)
- "Batu Maung" -> 峇都茅 (Southern coast near Bayan Lepas where Penang War Museum is situated)
- "George Town" -> 乔治市
- "Air Itam" -> 亚依淡 (Kek Lok Si area)
- "Balik Pulau" -> 浮罗山背 (Countryside / durian orchards)
- "Butterworth" -> 北海
- "Seberang Perai" -> 威省
- "Gurney" / "Gurney Drive" -> 新关仔角
- "Tanjung Tokong" -> 丹绒道光
- "Tanjung Bungah" -> 丹绒武雅
- "Gelugor" -> 牛汝莪
- "Jelutong" -> 日落洞
- "Penang Hill" / "Bukit Bendera" -> 升旗山
- "Clan Jetties" -> 姓氏桥
- "Peranakan / Baba Nyonya" -> 娘惹 / 峇峇娘惹
- "Kopitiam / Hawker Center" -> 传统咖啡店 / 小贩中心

STRICT RULES:
1. FAITHFUL TRANSLATION: Accurately reflect the original English meaning without hallucinating or inventing new facts, facilities, dates, or amenities.
2. CORRECT LOCAL NAMES: Strictly follow the Penang official toponymy table above.
3. NATURAL & ELEGANT TONE: Use idiomatic, captivating Simplified Chinese appropriate for a high-end Penang travel guide.
4. PURE JSON OUTPUT: Respond ONLY with a valid JSON object matching the schema below. NEVER add markdown backticks, conversational preamble, or explanations.

JSON SCHEMA:
{
  "summary_zh": "1-2句地道流畅的中文精炼概括",
  "description_zh": "2-3段完整连贯的中文深度介绍，段落之间用双换行符 \\n\\n 隔开"
}`;

  const userPrompt = `PLACE CONTEXT:
Name: ${sourceName}
Category: ${sourceCategory}
Area: ${sourceArea}

ENGLISH TEXT TO TRANSLATE:
Summary: ${sourceSummary || '(None)'}
Description: ${sourceDescription || '(None)'}

Translate the above into Simplified Chinese (简体中文). Remember that Bayan Lepas is 峇六拜, NOT 峇都丁宜. Output valid JSON only.`;

  let lastError = null;
  for (let attempt = 1; attempt <= maxRetries + 1; attempt++) {
    try {
      const response = await fetch(`${OLLAMA_HOST}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: MODEL,
          system: systemPrompt,
          prompt: userPrompt,
          stream: false,
          format: 'json',
          options: {
            temperature: 0.1, // 低温度确保稳定、保真
            top_p: 0.9
          }
        })
      });

      if (!response.ok) {
        const errText = await response.text();
        throw new Error(`Ollama HTTP ${response.status}: ${errText}`);
      }

      const data = await response.json();
      if (data.error) {
        throw new Error(`Ollama returned error: ${data.error}`);
      }

      const parsed = cleanAndParseJson(data.response);

      let summaryZh = typeof parsed.summary_zh === 'string' ? parsed.summary_zh.trim() : '';
      let descriptionZh = typeof parsed.description_zh === 'string' ? parsed.description_zh.trim() : '';

      // 地名自动校验纠错防护栏（严格防止大模型误将 Bayan Lepas 翻译为 峇都丁宜）
      if (sourceArea === 'Bayan Lepas' || sourceName.toLowerCase().includes('bayan lepas')) {
        summaryZh = summaryZh.replace(/峇都丁宜/g, '峇六拜');
        descriptionZh = descriptionZh.replace(/峇都丁宜/g, '峇六拜');
      }

      return {
        summary_zh: summaryZh,
        description_zh: descriptionZh
      };
    } catch (err) {
      lastError = err;
      if (attempt <= maxRetries) {
        const waitMs = attempt * 1500;
        await sleep(waitMs);
      }
    }
  }

  throw new Error(`Failed after ${maxRetries + 1} attempts: ${lastError?.message}`);
}

// 主执行流程
async function run() {
  console.log('\n' + '='.repeat(60));
  console.log('🌏 Kia Kia Penang - places_new 中文翻译批量处理任务');
  console.log('='.repeat(60));
  console.log(`🤖 目标模型:      ${MODEL}`);
  console.log(`🌐 Ollama 接口:   ${OLLAMA_HOST}`);
  console.log(`⚡ 并发工作数:    ${CONCURRENCY}`);
  console.log(`🛡️ 运行模式:      ${IS_DRY_RUN ? '🔍 DRY-RUN (演练预览，不写入数据库)' : '💾 PRODUCTION (实时持久化写入 MongoDB)'}`);
  if (FORCE) console.log(`🔄 强制模式:      --force (重新翻译所有记录)`);
  if (LIMIT > 0) console.log(`📌 处理上限:      ${LIMIT} 条`);
  if (CATEGORY_FILTER) console.log(`🏷️ 分类过滤:      ${CATEGORY_FILTER}`);
  if (TARGET_ID) console.log(`🎯 单条指定 ID:   ${TARGET_ID}`);
  console.log('='.repeat(60) + '\n');

  if (!MONGODB_URI) {
    console.error('❌ 错误: MONGODB_URI 未在 .env 中配置！');
    process.exit(1);
  }

  // 1. 连接 MongoDB (带高可用重试)
  console.log('📡 正在连接 MongoDB Atlas...');
  await ensureDbConnected();
  console.log('✅ MongoDB 连接成功！');
  const collection = mongoose.connection.db.collection('places_new');

  // 2. 检查 Ollama 服务及模型连通性
  console.log(`🔍 正在验证 Ollama 及模型 '${MODEL}' 状态...`);
  try {
    const testRes = await fetch(`${OLLAMA_HOST}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: MODEL,
        prompt: 'Ping',
        stream: false
      })
    });
    if (!testRes.ok) {
      throw new Error(`HTTP ${testRes.status}`);
    }
    console.log(`✅ 模型 '${MODEL}' 就绪可用！\n`);
  } catch (e) {
    console.error(`❌ 无法连接到 Ollama 模型 '${MODEL}': ${e.message}`);
    console.error(`👉 请确认 Ollama 是否已启动，并已通过 'ollama pull ${MODEL}' 拉取该模型。\n`);
    await mongoose.disconnect();
    process.exit(1);
  }

  // 3. 构建待处理地点的查询过滤条件 (关键：断点续传逻辑)
  const filter = {};

  if (TARGET_ID) {
    filter._id = new mongoose.Types.ObjectId(TARGET_ID);
  } else {
    if (CATEGORY_FILTER) {
      filter.primary_category = CATEGORY_FILTER;
    }

    if (!FORCE) {
      filter.$or = [
        { translated_at: { $exists: false } },
        { translated_at: null },
        { description_zh: { $exists: false } },
        { description_zh: null },
        { description_zh: '' },
        { summary_zh: { $exists: false } },
        { summary_zh: null },
        { summary_zh: '' }
      ];
    }
  }

  // 4. 查询待翻译记录
  console.log('🔎 正在扫描 places_new 集合中待翻译的地点...');
  let query = collection.find(filter, {
    projection: {
      name: 1,
      place_name: 1,
      primary_category: 1,
      place_category: 1,
      area: 1,
      summary: 1,
      description: 1,
      summary_zh: 1,
      description_zh: 1,
      translated_at: 1
    }
  });

  if (LIMIT > 0) {
    query = query.limit(LIMIT);
  }

  const places = await query.toArray();
  const total = places.length;

  // 查询已有总进度统计
  const totalInDb = await collection.countDocuments();
  const alreadyCompleted = await collection.countDocuments({
    description_zh: { $exists: true, $nin: [null, ''] },
    summary_zh: { $exists: true, $nin: [null, ''] }
  });

  console.log(`📊 数据库全量地点: ${totalInDb.toLocaleString()} 条`);
  console.log(`✅ 已完成翻译地点: ${alreadyCompleted.toLocaleString()} 条`);
  console.log(`⏳ 本次待处理地点: ${total.toLocaleString()} 条\n`);

  if (total === 0) {
    console.log('🎉 所有地点均已翻译完成！无需处理。如需重新翻译，可附加 --force 参数。');
    await mongoose.disconnect();
    return;
  }

  // 5. 并发工作池执行
  let currentIndex = 0;
  let successCount = 0;
  let failCount = 0;
  let skippedCount = 0;
  const startTime = Date.now();

  // 工作池单个 worker
  async function worker(workerId) {
    while (currentIndex < places.length) {
      if (isShuttingDown) break;

      const placeIdx = currentIndex++;
      const place = places[placeIdx];
      const itemNum = placeIdx + 1;
      const placeName = place.name || place.place_name || `(ID:${place._id})`;
      const placeStart = Date.now();

      try {
        const result = await translatePlace(place);

        if (result.skippedEmpty) {
          if (!IS_DRY_RUN) {
            await safeDbUpdate(place._id, {
              $set: {
                summary_zh: '',
                description_zh: '',
                translated_at: new Date(),
                translation_model: 'empty_source'
              }
            });
          }
          skippedCount++;
          console.log(`[${itemNum}/${total}] ⚪ [跳过空文本] "${placeName}"`);
          continue;
        }

        // 核心：通过高可用 safeDbUpdate 单条即时持久化到 MongoDB
        if (!IS_DRY_RUN) {
          await safeDbUpdate(place._id, {
            $set: {
              summary_zh: result.summary_zh,
              description_zh: result.description_zh,
              translated_at: new Date(),
              translation_model: MODEL
            }
          });
        }

        successCount++;
        const elapsedSec = ((Date.now() - placeStart) / 1000).toFixed(1);
        const overallElapsed = ((Date.now() - startTime) / 1000).toFixed(0);
        const percent = ((itemNum / total) * 100).toFixed(1);

        console.log(
          `[${itemNum}/${total}] (${percent}%) ✅ "${placeName}" 翻译完成 (${elapsedSec}s) [总已耗时: ${overallElapsed}s]`
        );

        if (IS_DRY_RUN) {
          console.log(`   📝 summary_zh:     ${result.summary_zh}`);
          console.log(`   📖 description_zh: ${result.description_zh.substring(0, 100)}...`);
        }
      } catch (err) {
        failCount++;
        console.error(`❌ [${itemNum}/${total}] 地点 "${placeName}" 翻译失败: ${err.message}`);
      }
    }
  }

  // 启动并发 Worker 线程池
  const workers = [];
  const actualConcurrency = Math.min(CONCURRENCY, places.length);
  for (let i = 0; i < actualConcurrency; i++) {
    workers.push(worker(i + 1));
  }

  await Promise.all(workers);

  // 6. 统计报告
  const totalElapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  const avgSpeed = (successCount > 0 ? (totalElapsed / successCount).toFixed(1) : 0);

  console.log('\n' + '='.repeat(60));
  if (isShuttingDown) {
    console.log('⚠️ 任务已被用户主动中断 (Ctrl+C)。');
    console.log('🛡️ 所有已翻译成功的记录均已安全保存入库，断点已记录！');
    console.log('👉 下次重新执行该命令时，程序将自动跳过已处理数据，无缝继续。');
  } else {
    console.log('🎉 批量翻译任务执行完毕！');
  }
  console.log('='.repeat(60));
  console.log(`⏱️ 总用时:        ${totalElapsed} 秒 (平均单条用时: ${avgSpeed} 秒)`);
  console.log(`✅ 成功翻译并入库: ${successCount} 条`);
  console.log(`⚪ 空文本跳过:    ${skippedCount} 条`);
  console.log(`❌ 失败错误条数:  ${failCount} 条`);
  console.log('='.repeat(60) + '\n');

  try {
    await mongoose.disconnect();
    console.log('🔌 已安全断开 MongoDB 连接。\n');
  } catch (_) {}
}

// 优雅处理 Ctrl+C 和程序关闭中断信号
async function handleShutdown(signal) {
  if (isShuttingDown) return;
  isShuttingDown = true;
  console.log(`\n\n🛑 接收到退出信号 (${signal})，正在等待正在进行的请求保存入库，请稍候...`);
  await sleep(2000);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  console.log('💾 所有已翻译数据均已安全保留在 MongoDB 中。程序安全退出。');
  process.exit(0);
}

process.on('SIGINT', () => handleShutdown('SIGINT'));
process.on('SIGTERM', () => handleShutdown('SIGTERM'));

// 捕获未处理的 Promise Rejection 避免因网络抖动直接杀死进程
process.on('unhandledRejection', (reason) => {
  console.warn('⚠️ 捕获到未处理的 Promise 异常 (已安全拦截):', reason?.message || reason);
});

// 运行脚本
run().catch(async (err) => {
  console.error('\n❌ 运行发生未捕获异常:', err);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
