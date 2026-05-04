#!/usr/bin/env node
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

const PORT = Number(process.env.PORT || 4180);
const HOST = process.env.HOST || "0.0.0.0";
const ROOT = __dirname;
const DATA_DIR = process.env.DATA_DIR ? path.resolve(process.env.DATA_DIR) : path.join(ROOT, "data");
const DATA_FILE = process.env.DATA_FILE ? path.resolve(process.env.DATA_FILE) : path.join(DATA_DIR, "scorekeeper-state.json");
const PLAYER_IDS = ["a", "b", "c"];
const DEFAULT_PLAYERS = [
  { id: "a", seat: "A", name: "A" },
  { id: "b", seat: "B", name: "B" },
  { id: "c", seat: "C", name: "C" }
];

let clients = new Set();
let state = loadState();

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);

    if (req.method === "GET" && url.pathname === "/") {
      return serveFile(res, path.join(ROOT, "index.html"), "text/html; charset=utf-8");
    }
    if (req.method === "GET" && url.pathname === "/api/state") {
      return sendJson(res, publicState());
    }
    if (req.method === "GET" && url.pathname === "/healthz") {
      return sendJson(res, { ok: true });
    }
    if (req.method === "GET" && url.pathname === "/api/events") {
      return handleEvents(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/join") {
      return handleJoin(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/submit-score") {
      return handleSubmitScore(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/withdraw-score") {
      return handleWithdrawScore(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/reset-pending") {
      state.pending = freshPending(state.nextRoundNo);
      persistAndBroadcast();
      return sendJson(res, publicState());
    }
    if (req.method === "POST" && url.pathname === "/api/undo-last") {
      return handleUndoLast(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/clear") {
      state.rounds = [];
      state.nextRoundNo = 1;
      state.pending = freshPending(1);
      persistAndBroadcast();
      return sendJson(res, publicState());
    }
    if (req.method === "POST" && url.pathname === "/api/reset-devices") {
      state.devices = {};
      state.pending = freshPending(state.nextRoundNo);
      persistAndBroadcast();
      return sendJson(res, publicState());
    }

    if (req.method === "GET") {
      const safePath = safeStaticPath(url.pathname);
      if (safePath) return serveFile(res, safePath, contentType(safePath));
    }

    sendJson(res, { error: "Not found" }, 404);
  } catch (error) {
    sendJson(res, { error: error.message || "Server error" }, 500);
  }
});

server.listen(PORT, HOST, () => {
  const urls = getLanUrls(PORT);
  console.log(`跑得快三人计分器已启动`);
  console.log(`本机: http://127.0.0.1:${PORT}`);
  urls.forEach((url) => console.log(`手机: ${url}`));
});

function loadState() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(DATA_FILE)) return freshState();

  try {
    const raw = JSON.parse(fs.readFileSync(DATA_FILE, "utf8"));
    const players = DEFAULT_PLAYERS.map((fallback) => {
      const saved = Array.isArray(raw.players) ? raw.players.find((item) => item.id === fallback.id) : null;
      return { ...fallback, name: sanitizeName(saved?.name || fallback.name, fallback.seat) };
    });
    const rounds = Array.isArray(raw.rounds)
      ? raw.rounds.filter(Boolean).map((round, index) => ({
        id: String(round.id || `${Date.now()}-${index}`),
        roundNo: Number(round.roundNo) || index + 1,
        at: round.at || new Date().toISOString(),
        manualPlayers: Array.isArray(round.manualPlayers)
          ? round.manualPlayers.filter((id) => PLAYER_IDS.includes(id)).slice(0, 2)
          : [],
        scores: normalizeScores(round.scores || {}),
        note: String(round.note || "")
      }))
      : [];
    const nextRoundNo = Math.max(Number(raw.nextRoundNo) || 1, rounds.reduce((max, round) => Math.max(max, round.roundNo), 0) + 1);
    const pending = normalizePending(raw.pending, nextRoundNo);
    const devices = normalizeDevices(raw.devices || {});
    return { players, rounds, nextRoundNo, pending, devices, savedAt: raw.savedAt || null };
  } catch {
    return freshState();
  }
}

function freshState() {
  return {
    players: DEFAULT_PLAYERS.map((player) => ({ ...player })),
    rounds: [],
    nextRoundNo: 1,
    pending: freshPending(1),
    devices: {},
    savedAt: null
  };
}

function freshPending(roundNo) {
  return { roundNo, submissions: {} };
}

function normalizePending(pending, nextRoundNo) {
  const normalized = freshPending(Number(pending?.roundNo) || nextRoundNo);
  if (normalized.roundNo !== nextRoundNo) normalized.roundNo = nextRoundNo;
  const submissions = pending?.submissions || {};
  PLAYER_IDS.forEach((id) => {
    if (submissions[id] && Number.isFinite(Number(submissions[id].score))) {
      normalized.submissions[id] = {
        score: cleanNumber(submissions[id].score),
        note: String(submissions[id].note || "").slice(0, 80),
        at: submissions[id].at || new Date().toISOString()
      };
    }
  });
  return normalized;
}

function normalizeScores(scores) {
  return PLAYER_IDS.reduce((acc, id) => {
    acc[id] = cleanNumber(scores[id] || 0);
    return acc;
  }, {});
}

function publicState(extra = {}) {
  return {
    players: state.players,
    rounds: state.rounds,
    nextRoundNo: state.nextRoundNo,
    pending: state.pending,
    assignedCount: Object.keys(state.devices || {}).length,
    savedAt: state.savedAt,
    ...extra
  };
}

async function handleJoin(req, res) {
  const body = await readBody(req);
  const deviceId = sanitizeDeviceId(body.deviceId);
  if (!deviceId) return sendJson(res, { error: "设备身份无效，请刷新页面" }, 400);

  const existing = state.devices[deviceId];
  if (existing && PLAYER_IDS.includes(existing)) {
    return sendJson(res, publicState({ assignedPlayerId: existing }));
  }

  const used = new Set(Object.values(state.devices || {}).filter((id) => PLAYER_IDS.includes(id)));
  const nextPlayer = PLAYER_IDS.find((id) => !used.has(id));
  if (!nextPlayer) {
    return sendJson(res, { error: "三个座位已经分完了，请先重置座位" }, 409);
  }

  state.devices[deviceId] = nextPlayer;
  persistAndBroadcast();
  sendJson(res, publicState({ assignedPlayerId: nextPlayer }));
}

async function handleSubmitScore(req, res) {
  const body = await readBody(req);
  const playerId = resolvePlayerFromRequest(body);
  if (!playerId) return sendJson(res, { error: "本机还没有分配座位，请刷新页面" }, 403);
  const score = cleanNumber(body.score);
  if (!Number.isFinite(score)) return sendJson(res, { error: "分数必须是数字" }, 400);
  if (Number(body.roundNo) !== state.pending.roundNo) {
    return sendJson(res, { error: "这一局已经变化，请刷新当前局后再提交" }, 409);
  }

  state.pending.submissions[playerId] = {
    score,
    note: String(body.note || "").slice(0, 80),
    at: new Date().toISOString()
  };

  let completedRound = null;
  const submittedIds = Object.keys(state.pending.submissions).filter((id) => PLAYER_IDS.includes(id));
  if (submittedIds.length >= 2) {
    completedRound = completeRound(submittedIds.slice(0, 2));
  }

  persistAndBroadcast();
  sendJson(res, publicState({ completedRound }));
}

async function handleWithdrawScore(req, res) {
  const body = await readBody(req);
  const playerId = resolvePlayerFromRequest(body);
  if (!playerId) return sendJson(res, { error: "本机还没有分配座位，请刷新页面" }, 403);
  delete state.pending.submissions[playerId];
  persistAndBroadcast();
  sendJson(res, publicState());
}

async function handleUndoLast(req, res) {
  if (!state.rounds.length) return sendJson(res, { error: "暂无可撤销记录" }, 400);
  const last = state.rounds.reduce((current, round) => (round.roundNo > current.roundNo ? round : current), state.rounds[0]);
  state.rounds = state.rounds.filter((round) => round.id !== last.id);
  state.nextRoundNo = state.rounds.reduce((max, round) => Math.max(max, round.roundNo), 0) + 1;
  state.pending = freshPending(state.nextRoundNo);
  persistAndBroadcast();
  sendJson(res, publicState({ undoneRound: last }));
}

function completeRound(manualPlayers) {
  const scores = { a: 0, b: 0, c: 0 };
  const notes = [];
  manualPlayers.forEach((id) => {
    const submission = state.pending.submissions[id];
    scores[id] = cleanNumber(submission.score);
    if (submission.note) notes.push(`${playerName(id)}: ${submission.note}`);
  });
  const computedId = PLAYER_IDS.find((id) => !manualPlayers.includes(id));
  scores[computedId] = cleanNumber(-manualPlayers.reduce((sum, id) => sum + scores[id], 0));

  const round = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    roundNo: state.pending.roundNo,
    at: new Date().toISOString(),
    manualPlayers,
    scores,
    note: notes.join("；")
  };
  state.rounds.push(round);
  state.nextRoundNo = round.roundNo + 1;
  state.pending = freshPending(state.nextRoundNo);
  return round;
}

function persistAndBroadcast() {
  state.savedAt = new Date().toISOString();
  fs.writeFileSync(DATA_FILE, JSON.stringify(state, null, 2));
  broadcast();
}

function broadcast() {
  const payload = `data: ${JSON.stringify(publicState())}\n\n`;
  clients.forEach((client) => client.write(payload));
}

function handleEvents(req, res) {
  res.writeHead(200, {
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no"
  });
  res.write(`data: ${JSON.stringify(publicState())}\n\n`);
  clients.add(res);
  req.on("close", () => clients.delete(res));
}

function serveFile(res, filename, type) {
  fs.readFile(filename, (error, content) => {
    if (error) return sendJson(res, { error: "Not found" }, 404);
    res.writeHead(200, { "Content-Type": type });
    res.end(content);
  });
}

function safeStaticPath(urlPath) {
  const decoded = decodeURIComponent(urlPath);
  const target = path.normalize(path.join(ROOT, decoded));
  if (!target.startsWith(ROOT)) return null;
  if (!fs.existsSync(target) || !fs.statSync(target).isFile()) return null;
  return target;
}

function contentType(filename) {
  if (filename.endsWith(".html")) return "text/html; charset=utf-8";
  if (filename.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (filename.endsWith(".css")) return "text/css; charset=utf-8";
  if (filename.endsWith(".json")) return "application/json; charset=utf-8";
  if (filename.endsWith(".png")) return "image/png";
  return "application/octet-stream";
}

function sendJson(res, data, status = 200) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(data));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        req.destroy();
        reject(new Error("请求过大"));
      }
    });
    req.on("end", () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        reject(new Error("JSON 格式错误"));
      }
    });
    req.on("error", reject);
  });
}

function resolvePlayerFromRequest(body) {
  if (body.deviceId) {
    const deviceId = sanitizeDeviceId(body.deviceId);
    return state.devices?.[deviceId] || null;
  }
  if (PLAYER_IDS.includes(body.playerId)) return body.playerId;
  return null;
}

function normalizeDevices(devices) {
  const normalized = {};
  const used = new Set();
  Object.entries(devices || {}).forEach(([deviceId, playerId]) => {
    const safeDeviceId = sanitizeDeviceId(deviceId);
    if (!safeDeviceId || !PLAYER_IDS.includes(playerId) || used.has(playerId)) return;
    normalized[safeDeviceId] = playerId;
    used.add(playerId);
  });
  return normalized;
}

function sanitizeDeviceId(deviceId) {
  const text = String(deviceId || "").trim();
  if (!/^[a-zA-Z0-9._:-]{8,80}$/.test(text)) return "";
  return text;
}

function sanitizeName(name, fallback) {
  const text = String(name || "").trim().slice(0, 12);
  return text || fallback;
}

function playerName(id) {
  return state.players.find((player) => player.id === id)?.name || id.toUpperCase();
}

function cleanNumber(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return NaN;
  const fixed = Math.round((number + Number.EPSILON) * 100) / 100;
  return Object.is(fixed, -0) ? 0 : fixed;
}

function getLanUrls(port) {
  const urls = [];
  const nets = os.networkInterfaces();
  Object.values(nets).flat().forEach((info) => {
    if (!info || info.internal || info.family !== "IPv4") return;
    urls.push(`http://${info.address}:${port}`);
  });
  return urls;
}
