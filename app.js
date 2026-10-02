const express = require('express');
const cors = require('cors');
require('dotenv').config();
const MONGO_URI = process.env.MONGO_URI;

const app = express();

// 中间件
app.use(cors());
app.use(express.json());

// 路由注册 (后续新建)
// app.use('/api/places', require('./routes/places'));
// app.use('/api/transport', require('./routes/transport'));
// app.use('/api/accommodations', require('./routes/accommodations'));

app.get('/', (req, res) => {
  res.send('Travel App API Status: Running');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});