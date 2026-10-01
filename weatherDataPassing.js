const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// 1. 槟城州地区下拉列表
const penangLocations = [
  'Batu Ferringhi', 'George Town', 'Georgetown', 'Air Itam', 'Ayer Itam',
  'Bayan Lepas', 'Tanjung Bungah', 'Tanjung Tokong', 'Gurney', 'Pulau Tikus',
  'Gelugor', 'Balik Pulau', 'Teluk Bahang', 'Butterworth', 'Bukit Mertajam',
  'Seberang Perai', 'Nibong Tebal', 'Kepala Batas'
];

// 2. 天气状况下拉列表
const weatherOptions = [
  { value: 'sunny', label: '晴天 (Sunny)', defaultTemp: 34 },
  { value: 'cloudy', label: '多云 / 阴天 (Cloudy)', defaultTemp: 29 },
  { value: 'rainy', label: '下雨 / 阵雨 (Rainy)', defaultTemp: 26 },
  { value: 'thunderstorm', label: '暴雨 / 雷阵雨 (Thunderstorm)', defaultTemp: 25 }
];

// 内存保存的当前最新天气状态
let currentWeather = {
  location: "George Town",
  condition: "sunny",
  temperature: 34,
  humidity: 70
};

// 内存保存的发送历史记录
let sendHistory = [];

// ---------------- API 路由 ----------------

// GET 接口：获取当前天气
app.get('/api/weather', (req, res) => {
  res.json({
    code: 200,
    msg: "success",
    data: currentWeather
  });
});

// GET 接口：获取发送历史记录
app.get('/api/history', (req, res) => {
  res.json({
    code: 200,
    data: sendHistory
  });
});

// POST 接口：提交天气数据
app.post('/api/weather', (req, res) => {
  const { location, condition, temperature, humidity } = req.body;
  const tempNum = Number(temperature);

  // 温度校验
  if (isNaN(tempNum) || tempNum < 25 || tempNum > 38) {
    return res.status(400).json({
      code: 400,
      msg: "温度必须在 25°C 到 38°C 之间！"
    });
  }

  // 🔒 闭包保护：锁定本次 POST 请求专属的数据
  const sendLocation = String(location);
  const sendCondition = String(condition);
  const sendTemp = tempNum;
  const sendHumidity = Number(humidity);
  const recordId = Date.now();
  const startTime = new Date().toLocaleTimeString();

  // 更新全局天气状态 (供 App 调取最新数据)
  currentWeather = {
    location: sendLocation,
    condition: sendCondition,
    temperature: sendTemp,
    humidity: sendHumidity
  };

  // 添加到发送历史列表头部
  const historyItem = {
    id: recordId,
    sendTime: startTime,
    location: sendLocation,
    condition: sendCondition,
    temperature: sendTemp,
    humidity: sendHumidity,
    status: 'pending' // 'pending' 倒计时中 | 'received' 已收到
  };
  sendHistory.unshift(historyItem);

  console.log(`\n--------------------------------------------------`);
  console.log(`[${startTime}] 🚀 Dashboard 传送天气数据到 Backend：`);
  console.log(`📍 地区: ${sendLocation} | 🌦️ 天气: ${sendCondition} | 🌡️ 温度: ${sendTemp}°C | 💧 湿度: ${sendHumidity}%`);
  console.log(`⏱️ 启动 2 分钟倒计时，将在 2 分钟后显示用户接收通知...`);

  // ⏱️ 设置 2 分钟 (120,000毫秒) 延时
  setTimeout(() => {
    const receiveTime = new Date().toLocaleTimeString();

    // 更新历史记录状态为已收到
    const targetItem = sendHistory.find(item => item.id === recordId);
    if (targetItem) {
      targetItem.status = 'received';
      targetItem.receiveTime = receiveTime;
    }

    console.log(`\n==================================================`);
    console.log(`[${receiveTime}] ✅ 【2分钟到了】用户终端已成功收到天气数据！`);
    console.log(`📍 收到地区: ${sendLocation}`);
    console.log(`🌦️ 天气状态: ${sendCondition}`);
    console.log(`🌡️ 温度数据: ${sendTemp}°C`);
    console.log(`💧 湿度数据: ${sendHumidity}%`);
    console.log(`==================================================\n`);
  }, 2 * 60 * 1000);

  res.json({
    code: 200,
    msg: "天气数据已传送！Terminal 将在 2 分钟后显示用户接收回显。",
    data: currentWeather
  });
});

// ---------------- 可视化 Dashboard 界面 ----------------
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
      <meta charset="UTF-8">
      <title>槟城州天气控制台 (Penang Weather Dashboard)</title>
      <style>
        * { box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f0f2f5; margin: 0; padding: 20px; }
        .container { max-width: 1280px; margin: auto; display: grid; grid-template-columns: 340px 1fr 1fr; gap: 20px; }
        @media (max-width: 1100px) {
          .container { grid-template-columns: 1fr; }
        }
        .card { background: white; padding: 22px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
        h1 { text-align: center; color: #1a365d; margin-bottom: 25px; }
        h2 { margin-top: 0; color: #2b6cb0; font-size: 17px; border-bottom: 2px solid #ebf8ff; padding-bottom: 8px; display: flex; justify-content: space-between; align-items: center; }
        .form-group { margin-bottom: 14px; }
        label { display: block; margin-bottom: 6px; font-weight: 600; color: #4a5568; font-size: 13px; }
        select, input { width: 100%; padding: 9px; border: 1px solid #cbd5e0; border-radius: 6px; font-size: 14px; }
        .hint { font-size: 12px; color: #718096; margin-top: 4px; }
        button { width: 100%; background: #3182ce; color: white; border: none; padding: 11px; font-size: 15px; font-weight: bold; border-radius: 6px; cursor: pointer; transition: background 0.2s; margin-top: 8px; }
        button:hover { background: #2b6cb0; }
        pre { background: #1a202c; color: #63b3ed; padding: 15px; border-radius: 8px; font-size: 13px; height: 380px; overflow-y: auto; margin: 0; }
        .timer-badge { display: none; margin-top: 12px; padding: 10px; background: #feebc8; color: #742a2a; border-radius: 6px; font-size: 13px; text-align: center; }
        
        /* 历史记录列表样式 */
        .history-list { height: 380px; overflow-y: auto; padding-right: 4px; }
        .history-item { background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; margin-bottom: 10px; font-size: 13px; }
        .history-header { display: flex; justify-content: space-between; margin-bottom: 6px; font-weight: bold; color: #2d3748; }
        .history-detail { color: #4a5568; font-size: 12px; line-height: 1.5; }
        .status-badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: bold; }
        .badge-pending { background: #feebc8; color: #9c4221; }
        .badge-received { background: #c6f6d5; color: #22543d; }
        .empty-history { text-align: center; color: #a0aec0; padding-top: 50px; font-size: 14px; }
      </style>
    </head>
    <body>
      <h1>🏝️ 槟城州天气数据传送 Dashboard</h1>
      <div class="container">
        
        <!-- 栏目 1: 表单卡片 -->
        <div class="card">
          <h2>传送天气数据 (Send Weather Data)</h2>
          <form id="weatherForm">
            <div class="form-group">
              <label>槟城地区 (Penang Location):</label>
              <select id="location">
                ${penangLocations.map(loc => `<option value="${loc}">${loc}</option>`).join('')}
              </select>
            </div>

            <div class="form-group">
              <label>天气情况 (Weather Condition):</label>
              <select id="condition">
                ${weatherOptions.map(opt => `<option value="${opt.value}">${opt.label}</option>`).join('')}
              </select>
            </div>

            <div class="form-group">
              <label>温度 (°C):</label>
              <input type="number" id="temperature" min="25" max="38" value="34" required>
              <div class="hint">可手动调整，范围限制在 25°C ~ 38°C 之间</div>
            </div>

            <div class="form-group">
              <label>湿度 (%):</label>
              <select id="humidity">
                <option value="60">60% (干燥)</option>
                <option value="75" selected>75% (正常)</option>
                <option value="90">90% (潮湿/大雨前夕)</option>
              </select>
            </div>

            <button type="submit">🚀 传送天气数据 (Send Weather Data)</button>
          </form>

          <div id="timerNotice" class="timer-badge">
            ⏳ 已成功发送！VS Code Terminal 将在 <b id="secondsLeft">120</b> 秒后显示“用户收到天气数据”。
          </div>
        </div>

        <!-- 栏目 2: JSON 实时预览卡片 -->
        <div class="card">
          <h2>App 当前可接收的 API 数据 (JSON)</h2>
          <pre id="jsonViewer">加载中...</pre>
        </div>

        <!-- 栏目 3: 发送历史记录 (Sending History) -->
        <div class="card">
          <h2>
            <span>发送历史记录 (Sending History)</span>
            <span style="font-size: 12px; font-weight: normal; color: #718096;" id="historyCount">0 条记录</span>
          </h2>
          <div id="historyContainer" class="history-list">
            <div class="empty-history">暂无发送历史</div>
          </div>
        </div>

      </div>

      <script>
        let countdownTimer = null;

        const weatherTempMap = {
          'sunny': 34,
          'cloudy': 29,
          'rainy': 26,
          'thunderstorm': 25
        };

        // 切换天气时自动填写对应的默认温度
        document.getElementById('condition').addEventListener('change', (e) => {
          const selectedCondition = e.target.value;
          if (weatherTempMap[selectedCondition] !== undefined) {
            document.getElementById('temperature').value = weatherTempMap[selectedCondition];
          }
        });

        // 获取并刷新当前 API JSON 数据
        async function fetchCurrentJSON() {
          const res = await fetch('/api/weather');
          const data = await res.json();
          document.getElementById('jsonViewer').innerText = JSON.stringify(data, null, 2);
        }

        // 获取并渲染发送历史记录
        async function fetchHistory() {
          const res = await fetch('/api/history');
          const result = await res.json();
          const list = result.data || [];
          
          document.getElementById('historyCount').innerText = list.length + ' 条记录';
          const container = document.getElementById('historyContainer');

          if (list.length === 0) {
            container.innerHTML = '<div class="empty-history">暂无发送历史</div>';
            return;
          }

          container.innerHTML = list.map(function(item) {
            var isPending = item.status === 'pending';
            var badgeClass = isPending ? 'badge-pending' : 'badge-received';
            var badgeText = isPending ? '⏳ 倒计时中 (2分钟)' : '✅ 用户已收到 (' + item.receiveTime + ')';

            return '<div class="history-item">' +
              '<div class="history-header">' +
                '<span>📍 ' + item.location + '</span>' +
                '<span class="status-badge ' + badgeClass + '">' + badgeText + '</span>' +
              '</div>' +
              '<div class="history-detail">' +
                '⏱️ 发送时间: <b>' + item.sendTime + '</b><br>' +
                '🌦️ 天气: <b>' + item.condition + '</b> | 🌡️ 温度: <b>' + item.temperature + '°C</b> | 💧 湿度: <b>' + item.humidity + '%</b>' +
              '</div>' +
            '</div>';
          }).join('');
        }

        // 提交表单处理
        document.getElementById('weatherForm').addEventListener('submit', async (e) => {
          e.preventDefault();

          const tempInput = Number(document.getElementById('temperature').value);

          if (tempInput < 25 || tempInput > 38) {
            alert("⚠️ 温度输入不合法！请输入 25°C 到 38°C 之间的数字。");
            return;
          }

          const payload = {
            location: document.getElementById('location').value,
            condition: document.getElementById('condition').value,
            temperature: tempInput,
            humidity: document.getElementById('humidity').value
          };

          const res = await fetch('/api/weather', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
          });

          const result = await res.json();
          document.getElementById('jsonViewer').innerText = JSON.stringify(result, null, 2);

          fetchHistory();
          startUICountdown(120);
        });

        function startUICountdown(seconds) {
          clearInterval(countdownTimer);
          const notice = document.getElementById('timerNotice');
          const secondsElem = document.getElementById('secondsLeft');
          
          notice.style.display = 'block';
          let remaining = seconds;
          secondsElem.innerText = remaining;

          countdownTimer = setInterval(() => {
            remaining--;
            secondsElem.innerText = remaining;
            if (remaining <= 0) {
              clearInterval(countdownTimer);
              notice.innerHTML = "✅ 2分钟时间到！请查看 VS Code Terminal 控制台。";
            }
          }, 1000);
        }

        // 定时（每 3 秒）自动刷新历史记录状态，确保 2 分钟到期后标签自动变绿
        setInterval(fetchHistory, 3000);

        // 初始化加载
        fetchCurrentJSON();
        fetchHistory();
      </script>
    </body>
    </html>
  `);
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`==================================================`);
  console.log(`✅ Penang Weather Server 已启动!`);
  console.log(`👉 控制台 Dashboard 地址: http://localhost:${PORT}`);
  console.log(`👉 App 调用的 API 地址: http://localhost:${PORT}/api/weather`);
  console.log(`==================================================`);
});