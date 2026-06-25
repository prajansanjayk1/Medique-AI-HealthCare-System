const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();
const runtimeConfig = (typeof functions.config === "function" ? functions.config() : {}) || {};

const APP_ID = process.env.APP_ID || "medique-b29ee";
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || "prajansanjayko@gmail.com").toLowerCase();
function isAdminEmail(email) {
  if (!email) return false;
  const clean = String(email).trim().toLowerCase();
  return clean === ADMIN_EMAIL || clean === "prajansanjayko@gmsil.com";
}
const QUEUE_PATH = `artifacts/${APP_ID}/public/data/queue`;
const ACTIVE_QUEUE_PATH = `artifacts/${APP_ID}/public/data/activeQueue`;
const USERS_PATH = `artifacts/${APP_ID}/users`;
const ML_SAMPLES_PATH = `artifacts/${APP_ID}/public/data/ml_queue_samples`;
const ML_MODEL_DOC = `artifacts/${APP_ID}/public/data/ml_models/wait_time`;
const CLINIC_META_PATH = `artifacts/${APP_ID}/public/data/meta/tokenCounter`;
const AUDIT_LOGS_PATH = `artifacts/${APP_ID}/private/security/audit_logs`;
const AUDIT_ARCHIVE_PATH = `artifacts/${APP_ID}/private/security/audit_archive`;
const AUDIT_ARCHIVE_META_DOC = `artifacts/${APP_ID}/private/security/audit_archive_meta/state`;
const OTP_PATH = `artifacts/${APP_ID}/private/security/otps`;
const PASSWORD_RESET_PATH = `artifacts/${APP_ID}/private/security/password_reset_requests`;
const OTP_PEPPER = process.env.OTP_PEPPER || runtimeConfig.security?.otp_pepper || "dev-only-otp-pepper-change-me";
const OTP_MAX_ATTEMPTS = Number(process.env.OTP_MAX_ATTEMPTS || runtimeConfig.security?.otp_max_attempts || 5);
const OTP_COOLDOWN_SECONDS = Number(process.env.OTP_COOLDOWN_SECONDS || runtimeConfig.security?.otp_cooldown_seconds || 45);
const PHONE_HOOK_SECRET = process.env.PHONE_HOOK_SECRET || runtimeConfig.security?.phone_hook_secret || "";
const PASSWORD_RESET_CONTINUE_URL =
  process.env.PASSWORD_RESET_CONTINUE_URL ||
  runtimeConfig.security?.password_reset_continue_url ||
  `https://${APP_ID}.web.app/index.html`;
const PASSWORD_RESET_COOLDOWN_SECONDS =
  Number(process.env.PASSWORD_RESET_COOLDOWN_SECONDS || runtimeConfig.security?.password_reset_cooldown_seconds || 60);
const RETENTION_QUEUE_DAYS = Number(process.env.RETENTION_QUEUE_DAYS || 365);
const RETENTION_AUDIT_DAYS = Number(process.env.RETENTION_AUDIT_DAYS || 2190); // 6 years
const RETENTION_OTP_DAYS = Number(process.env.RETENTION_OTP_DAYS || 30);
const RETENTION_ML_SAMPLE_DAYS = Number(process.env.RETENTION_ML_SAMPLE_DAYS || 365);
const NEAR_RT_RETRAIN_MIN_INTERVAL_MINUTES = Number(process.env.NEAR_RT_RETRAIN_MIN_INTERVAL_MINUTES || 20);
const NEAR_RT_RETRAIN_SAMPLE_DELTA = Number(process.env.NEAR_RT_RETRAIN_SAMPLE_DELTA || 15);
const NEAR_RT_RETRAIN_LOCK_MINUTES = Number(process.env.NEAR_RT_RETRAIN_LOCK_MINUTES || 8);
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS ||
  "https://medique-b29ee.web.app,https://medique-b29ee.firebaseapp.com,https://aishwaryam-acu.web.app,https://aishwaryam-acu.firebaseapp.com,http://localhost:5000,http://127.0.0.1:5000,http://localhost:3000,http://localhost:8080,http://127.0.0.1:8080")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);


const waitMs = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function hashOtp(email, otp) {
  return crypto.createHash("sha256").update(`${email}|${otp}|${OTP_PEPPER}`).digest("hex");
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}

function redactSensitiveObject(value) {
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.map(redactSensitiveObject);
  if (typeof value !== "object") return value;

  const sensitiveKeyRegex = /(email|phone|mobile|otp|token|name|address|dob|patient|ssn|aadhaar)/i;
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (sensitiveKeyRegex.test(k)) {
      out[k] = typeof v === "string" || typeof v === "number" ? `redacted:${sha256Hex(v).slice(0, 12)}` : "redacted";
    } else {
      out[k] = redactSensitiveObject(v);
    }
  }
  return out;
}

function getClientIp(req) {
  const fwd = req.headers["x-forwarded-for"];
  if (Array.isArray(fwd)) return fwd[0] || "unknown";
  if (typeof fwd === "string") return fwd.split(",")[0].trim();
  return req.ip || "unknown";
}

async function writeAuditLog(action, actor = {}, details = {}, severity = "INFO") {
  try {
    await db.collection(AUDIT_LOGS_PATH).add({
      action,
      severity,
      actor: {
        uid: actor.uid || null,
        email: actor.email ? `hash:${sha256Hex(actor.email).slice(0, 16)}` : null,
        ip: actor.ip ? `hash:${sha256Hex(actor.ip).slice(0, 16)}` : null,
        userAgent: actor.userAgent || null,
      },
      details: redactSensitiveObject(details),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error("Audit log write failed:", err?.message || err);
  }
}

function isAllowedOrigin(origin) {
  if (!origin) return false;
  return ALLOWED_ORIGINS.includes(origin);
}

function setCors(req, res) {
  const origin = req.get("origin");
  if (origin) {
    res.set("Access-Control-Allow-Origin", origin);
    res.set("Vary", "Origin");
  } else {
    res.set("Access-Control-Allow-Origin", "*");
  }
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS, GET");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

async function verifyAdminRequest(req) {
  const authHeader = req.get("authorization") || "";
  if (!authHeader.startsWith("Bearer ")) return null;
  const idToken = authHeader.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const email = (decoded.email || "").toLowerCase();
    
    // 1. Fast path: check admin email or admin/doctor/staff custom claim
    if (isAdminEmail(email) || ["admin", "doctor", "receptionist", "staff"].includes(decoded.role)) {
      return decoded;
    }
    
    // 2. Fallback: Query Firestore staff collection to see if they are active staff
    const staffDoc = await admin.firestore().doc(`artifacts/${APP_ID}/public/data/staff/${decoded.uid}`).get();
    if (staffDoc.exists && staffDoc.data().isActive !== false) {
      decoded.role = staffDoc.data().role || "staff";
      return decoded;
    }
  } catch (err) {
    console.error("verifyAdminRequest Error:", err);
  }
  return null;
}

function isAdminContext(context) {
  if (!context?.auth) return false;
  const email = (context.auth.token?.email || "").toLowerCase();
  return context.auth.token?.role === "admin" || isAdminEmail(email);
}

function daysAgoTimestamp(days) {
  return admin.firestore.Timestamp.fromDate(new Date(Date.now() - (days * 24 * 60 * 60 * 1000)));
}

function clamp(num, min, max) {
  return Math.min(max, Math.max(min, num));
}

function asDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.floor((p / 100) * (sorted.length - 1))));
  return sorted[idx];
}

function buildFeatureVector(input = {}) {
  const queueAhead = clamp(Number(input.queueAhead || 0), 0, 250);
  const urgentAhead = clamp(Number(input.urgentAhead || 0), 0, 80);
  const isEmergency = input.isEmergency ? 1 : 0;
  const hour = clamp(Number(input.hour ?? new Date().getHours()), 0, 23);
  const dayOfWeek = clamp(Number(input.dayOfWeek ?? new Date().getDay()), 0, 6);
  const avgConsultationMinutes = clamp(Number(input.avgConsultationMinutes || 5), 2, 45);

  const hourAngle = (2 * Math.PI * hour) / 24;
  const dowAngle = (2 * Math.PI * dayOfWeek) / 7;
  const peakHour = (hour >= 9 && hour <= 13) || (hour >= 17 && hour <= 20) ? 1 : 0;
  const urgentRatio = queueAhead > 0 ? urgentAhead / Math.max(1, queueAhead) : 0;

  return [
    1,
    queueAhead,
    Math.log1p(queueAhead),
    (queueAhead * queueAhead) / 100,
    urgentAhead,
    urgentRatio,
    isEmergency,
    Math.sin(hourAngle),
    Math.cos(hourAngle),
    Math.sin(dowAngle),
    Math.cos(dowAngle),
    peakHour,
    avgConsultationMinutes / 10,
  ];
}

function computeFeatureStats(vectors) {
  if (!vectors.length) return null;
  const dim = vectors[0].length;
  const medians = Array(dim).fill(0);
  const iqrs = Array(dim).fill(1);
  for (let j = 0; j < dim; j += 1) {
    const col = vectors.map((v) => Number(v[j] || 0)).sort((a, b) => a - b);
    const q1 = percentile(col, 25);
    const q3 = percentile(col, 75);
    medians[j] = percentile(col, 50);
    iqrs[j] = Math.max(0.5, q3 - q1);
  }
  return { medians, iqrs };
}

function normalizeVector(vec, stats) {
  if (!stats) return vec.slice();
  return vec.map((v, i) => {
    if (i === 0) return 1; // Keep bias untouched
    return (v - stats.medians[i]) / stats.iqrs[i];
  });
}

function dot(a, b) {
  let total = 0;
  const len = Math.min(a.length, b.length);
  for (let i = 0; i < len; i += 1) total += a[i] * b[i];
  return total;
}

function trainRidgeRegression(vectors, targets, lambda = 0.12, iterations = 1400, lr = 0.015) {
  const featureSize = vectors[0]?.length || 13;
  const weights = Array(featureSize).fill(0);
  if (!vectors.length) return weights;

  for (let iter = 0; iter < iterations; iter += 1) {
    const grads = Array(featureSize).fill(0);
    for (let i = 0; i < vectors.length; i += 1) {
      const x = vectors[i];
      const y = targets[i];
      const pred = dot(weights, x);
      // Smooth robust loss (bounded gradient) to reduce outlier impact
      const err = clamp(pred - y, -45, 45);
      for (let j = 0; j < featureSize; j += 1) grads[j] += err * x[j];
    }
    const scale = 2 / vectors.length;
    for (let j = 0; j < featureSize; j += 1) {
      const reg = j === 0 ? 0 : lambda * weights[j]; // no regularization on bias
      weights[j] -= lr * (scale * grads[j] + reg);
    }
  }
  return weights;
}

function evaluateModel(samples, model, fallbackBaseline = 8) {
  if (!samples.length) return { mae: fallbackBaseline, rmse: fallbackBaseline, mape: 0 };
  let absErr = 0;
  let sqErr = 0;
  let mapeAccum = 0;
  for (const s of samples) {
    const raw = buildFeatureVector(s);
    const x = normalizeVector(raw, model.featureStats);
    const pred = clamp(dot(model.weights, x), 1, 240);
    const err = pred - s.waitMinutes;
    absErr += Math.abs(err);
    sqErr += err * err;
    if (s.waitMinutes > 0) {
      mapeAccum += Math.abs(err) / s.waitMinutes;
    }
  }
  return {
    mae: Math.round((absErr / samples.length) * 10) / 10,
    rmse: Math.round(Math.sqrt(sqErr / samples.length) * 10) / 10,
    mape: Math.round((mapeAccum / samples.length) * 1000) / 10,
  };
}

async function readActiveWaitModel() {
  const snap = await db.doc(ML_MODEL_DOC).get();
  if (!snap.exists) return null;
  return snap.data();
}

async function maybeTriggerNearRealtimeRetrain() {
  const modelRef = db.doc(ML_MODEL_DOC);
  const now = Date.now();
  const minIntervalMs = NEAR_RT_RETRAIN_MIN_INTERVAL_MINUTES * 60 * 1000;
  const lockMs = NEAR_RT_RETRAIN_LOCK_MINUTES * 60 * 1000;
  let trigger = false;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(modelRef);
    const model = snap.exists ? (snap.data() || {}) : {};
    const pendingSampleCount = Number(model.pendingSampleCount || 0) + 1;
    const lastTrainMs = Number(model.lastTrainedAtMs || 0);
    const lockUntilMs = Number(model.retrainLockUntilMs || 0);
    const enoughSamples = pendingSampleCount >= NEAR_RT_RETRAIN_SAMPLE_DELTA;
    const intervalOk = (now - lastTrainMs) >= minIntervalMs;
    const lockFree = lockUntilMs <= now;
    trigger = enoughSamples && intervalOk && lockFree;

    const updatePayload = {
      pendingSampleCount,
      lastSampleAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (trigger) {
      updatePayload.retrainLockUntilMs = now + lockMs;
    }
    tx.set(modelRef, updatePayload, { merge: true });
  });

  if (!trigger) return { triggered: false };
  try {
    await trainAndPersistWaitModel("near_realtime");
    await modelRef.set({
      retrainLockUntilMs: 0,
      lastNearRealtimeRetrainAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { triggered: true, success: true };
  } catch (err) {
    await modelRef.set({
      retrainLockUntilMs: 0,
      nearRealtimeLastError: err?.message || "unknown",
      nearRealtimeLastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    throw err;
  }
}

function inferConfidence(model, queueAhead) {
  if (!model || !model.active) return "fallback";
  const sampleCount = Number(model.sampleCount || 0);
  const mae = Number(model.metrics?.mae || 999);
  const residualP90 = Number(model.residualP90 || 99);
  if (sampleCount >= 250 && mae <= 4 && residualP90 <= 8 && queueAhead <= 8) return "high";
  if (sampleCount >= 80 && mae <= 8 && residualP90 <= 16) return "medium";
  return "low";
}

/**
 * Handle incoming SMS from Twilio
 * URL: https://us-central1-<project-id>.cloudfunctions.net/incomingSMS
 */
// --- SHARED QUEUE LOGIC ---

async function checkQueueStatus(phone) {
  const qSnap = await db.collection(QUEUE_PATH)
    .where("phone", "==", phone)
    .where("status", "==", "waiting") // Only check active waiting
    .get();

  if (!qSnap.empty) {
    const data = qSnap.docs[0].data();
    return { 
      exists: true, 
      token: data.token, 
      message: `You are already in the queue! Your Token is #${data.token}.` 
    };
  }
  return { exists: false };
}

async function addToQueue(phone, defaultName = "Phone User", source = "sms") {
  // 1. Check if already in queue
  const status = await checkQueueStatus(phone);
  if (status.exists) return status;

  // 2. Lookup existing user history
  const userRef = db.doc(`${USERS_PATH}/${phone}`);
  const userDoc = await userRef.get();
  
  let finalName = phone; // Default to showing their phone number if new
  if (userDoc.exists && userDoc.data().name) {
    const existingName = userDoc.data().name;
    // Use existing name if it's not a placeholder
    if (existingName !== "Voice Patient" && existingName !== "Phone User") {
      finalName = existingName;
    }
  }

  // 3. Register User (If not exists)
  await userRef.set({
    phone: phone,
    name: finalName,
    lastSeen: admin.firestore.FieldValue.serverTimestamp(),
    isPhoneUser: true
  }, { merge: true });

  // 4. Add to Queue
  const token = Math.floor(1000 + Math.random() * 9000);
  const queueRef = db.collection(QUEUE_PATH).doc(phone);
  
  await queueRef.set({
    patientId: phone,
    name: finalName,
    joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'waiting',
    source: source,
    token: token,
    phone: phone
  });

  return { 
    exists: false, 
    token: token, 
    message: `Welcome to MediQue! You are added to the queue. Your Token is #${token}.` 
  };
}

async function getQueuePosition(phone) {
  const qSnap = await db.collection(QUEUE_PATH)
    .where("status", "==", "waiting")
    .orderBy("joinedAt", "asc")
    .get();
  
  const docs = qSnap.docs;
  const index = docs.findIndex(doc => doc.id === phone || doc.data().phone === phone);
  return index !== -1 ? index + 1 : docs.length + 1;
}

const TRANSLATIONS = {
  en: {
    join_success: "Welcome to MediQue. You are added to the queue. Your Token is {token}. Your position is {position}, estimated wait is {wait} minutes.",
    already_join: "You are already in the queue. Your Token is {token}. Your position is {position}, estimated wait is {wait} minutes.",
    status_in: "You are currently in the queue. Your Token number is {token}. Position {position}.",
    status_out: "You are not currently in the queue.",
    invalid: "No valid input received. Please try again.",
    notify_msg: "It's almost your turn! Please come to the consultation room."
  },
  ta: {
    join_success: "MediQue-kku varavEtkirOm. Neengal queue-vil serkkappatteergal. Ungal Token yen {token}. Ungal idham {position}, kaathiruppu nEram {wait} nimidangal.",
    already_join: "Neengal erkanave queue-vil ullergal. Ungal Token yen {token}. Ungal idham {position}, kaathiruppu nEram {wait} nimidangal.",
    status_in: "Neengal queue-vil ullergal. Ungal Token yen {token}. Idham {position}.",
    status_out: "Neengal queue-vil illai.",
    invalid: "Thavaraana therivu. Meendum muyarchi seiyyavum.",
    notify_msg: "Ungal murai nerungivittadhu! Kadhavaik kavanikkavum."
  },
  hi: {
    join_success: "MediQue mein swagat hai. Aap queue mein jud gaye hain. Aapka Token number {token} hai. Aapka sthaan {position} hai, prateeksha samay {wait} minute hai.",
    already_join: "Aap pehle se hi queue mein hain. Aapka Token number {token} hai. Aapka sthaan {position} hai, prateeksha samay {wait} minute hai.",
    status_in: "Aap abhi queue mein hain. Aapka Token number {token} hai. Sthaan {position}.",
    status_out: "Aap queue mein nahi hain.",
    invalid: "Kripya sahi number dabayein.",
    notify_msg: "Aapki baari aane wali hai! Kripya kamre ke paas aayein."
  },
  te: {
    join_success: "MediQue ki swagatham. Meeru queue lo cherchabadinirru. Mee Token number {token}. Mee sthaanam {position}, వేచి ఉండే సమయం {wait} నిమిషాలు.",
    already_join: "Meeru mundhugaane queue lo unnaru. Mee Token number {token}. Mee sthaanam {position}, వేచి ఉండే సమయం {wait} నిమిషాలు.",
    status_in: "Meeru prasthutham queue lo unnaru. Mee Token number {token}. Sthaanam {position}.",
    status_out: "Meeru queue lo leru.",
    invalid: "Dayachesi sariaina number nu nokkandi.",
    notify_msg: "మీ వంతు రాబోతోంది! దయచేసి సంప్రదింపు గదికి రండి."
  }
};

/**
 * Android Phone Hook (Triggered by the local Android Server App)
 * URL: .../phoneCallHook?phone=1234567890
 */
exports.phoneCallHook = functions.https.onRequest(async (req, res) => {
  try {
    // Phone hook secret MUST be configured in production
    if (!PHONE_HOOK_SECRET) {
      console.error("[SECURITY] PHONE_HOOK_SECRET is not configured. All requests denied.");
      return res.status(503).send({ success: false, error: "Service not configured. Set PHONE_HOOK_SECRET env var." });
    }
    const incomingSecret = req.get("x-hook-secret") || req.query.secret;
    if (incomingSecret !== PHONE_HOOK_SECRET) {
      await writeAuditLog("PHONE_HOOK_DENIED", {
        ip: getClientIp(req),
        userAgent: req.get("user-agent"),
      }, { reason: "invalid_hook_secret" }, "WARNING");
      return res.status(403).send({ success: false, error: "Unauthorized hook" });
    }

    const phone = req.query.phone || req.body.phone;
    if (!phone) {
      return res.status(400).send({ success: false, error: "Phone number missing" });
    }

    // Call shared queue logic
    const cleanPhone = phone.replace(/\D/g, '');
    const result = await addToQueue(cleanPhone, "Voice Patient", 'voice');
    const position = await getQueuePosition(cleanPhone);
    const waitTime = position * 5;

    let msg = "";
    const t = TRANSLATIONS['en']; // default to English for MVP SMS
    if (result.exists) {
       msg = t.already_join.replace('{token}', result.token).replace('{position}', position).replace('{wait}', waitTime);
    } else {
       msg = t.join_success.replace('{token}', result.token).replace('{position}', position).replace('{wait}', waitTime);
    }

    // Return the message so the Android App can send it via SMS
    res.status(200).send({
      success: true,
      exists: result.exists,
      token: result.token,
      position: position,
      smsMessage: msg // App will send this text
    });

  } catch (error) {
    console.error("Phone Hook Error:", error);
    res.status(500).send({ success: false, error: "System Error" });
  }
});



/**
 * Handle Patient Turn Notification (Triggered by Doctor Web UI)
 */
exports.notifyPatient = functions.https.onRequest(async (req, res) => {
  setCors(req, res);

  // Handle Preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== "POST") {
    return res.status(405).send({ success: false, error: "Method not allowed" });
  }

  try {
    const actor = await verifyAdminRequest(req);
    if (!actor) {
      await writeAuditLog("NOTIFY_PATIENT_DENIED", {
        ip: getClientIp(req),
        userAgent: req.get("user-agent"),
      }, { reason: "unauthorized" }, "WARNING");
      return res.status(403).send({ success: false, error: "Unauthorized" });
    }

    const data = req.body || {};
    const { phone, lang = 'en', patientId } = data;

    if (!phone && !patientId) {
      console.error("Notify Error: Phone and patientId missing");
      return res.status(400).send({ success: false, error: 'Missing identifier' });
    }

    const t = TRANSLATIONS[lang] || TRANSLATIONS['en'];
    const messageBody = t.notify_msg;
    let pushSent = false;

    // 1. Try FCM Push Notification if patientId exists
    if (patientId) {
      const userDoc = await db.doc(`${USERS_PATH}/${patientId}`).get();
      const userData = userDoc.data();
      if (userData && userData.pushToken) {
        try {
          await admin.messaging().send({
            token: userData.pushToken,
            notification: {
              title: "It's Your Turn! - MediQue",
              body: messageBody,
            },
            android: {
              priority: "high",
              notification: {
                sound: "default",
                channelId: "high_importance_channel",
                clickAction: "OPEN_DASHBOARD"
              }
            },
            apns: {
              headers: {
                "apns-priority": "10"
              },
              payload: {
                aps: {
                  sound: "default"
                }
              }
            },
            webpush: {
              fcmOptions: {
                link: `https://aishwaryam-acu.web.app/patient.html?clinicId=${APP_ID}`
              }
            },
            data: {
              click_action: "OPEN_DASHBOARD",
              status: "calling",
              patientId: patientId,
              clinicId: APP_ID,
              target_url: "patient.html"
            }
          });
          console.log(`FCM Push sent to ${patientId}`);
          pushSent = true;
        } catch (fcmError) { console.warn("FCM error, falling back...", fcmError); }
      }
    }

    // 2. Set 'notified' flag in the queue document to trigger local sound/UI on the patient page
    if (patientId) {
      console.log(`Setting notified flag for patientId: ${patientId} at path: ${QUEUE_PATH}/${patientId}`);
      await db.collection(QUEUE_PATH).doc(patientId).set({
        notified: true,
        notifiedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      console.log(`Firestore 'notified' flag set for ${patientId}`);
    }

    await writeAuditLog("NOTIFY_PATIENT_SENT", {
      uid: actor.uid,
      email: actor.email,
      ip: getClientIp(req),
      userAgent: req.get("user-agent"),
    }, { patientId: patientId || null, pushSent }, "INFO");

    return res.status(200).send({ 
      success: true, 
      message: pushSent ? "Push notification sent." : "Patient dashboard alert triggered." 
    });

  } catch (error) {
    console.error("Notify Main Error:", error);
    await writeAuditLog("NOTIFY_PATIENT_FAILED", {
      ip: getClientIp(req),
      userAgent: req.get("user-agent"),
    }, { message: error?.message || "unknown" }, "ERROR");
    return res.status(500).send({ 
       success: false, 
       error: 'Failed to send notification', 
       details: error.message 
    });
  }
});

/**
 * Automatically trigger FCM push notification when doctor updates queue status to 'calling'
 */
// Helper to send in-app and push notification to any user
async function sendNotificationToUser(appId, userId, title, body, category, targetUrl = "patient.html") {
  try {
    const notificationId = db.collection(`artifacts/${appId}/users/${userId}/notifications`).doc().id;
    const notificationDocRef = db.doc(`artifacts/${appId}/users/${userId}/notifications/${notificationId}`);
    
    await notificationDocRef.set({
      title,
      body,
      category,
      status: 'unread',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`[Notification Log] Written for user: ${userId}`);

    const userDoc = await db.doc(`artifacts/${appId}/users/${userId}`).get();
    if (userDoc.exists) {
      const userData = userDoc.data() || {};
      if (userData.pushToken) {
        await admin.messaging().send({
          token: userData.pushToken,
          notification: {
            title: title,
            body: body,
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "high_importance_channel",
              clickAction: "OPEN_DASHBOARD"
            }
          },
          apns: {
            headers: {
              "apns-priority": "10"
            },
            payload: {
              aps: {
                sound: "default"
              }
            }
          },
          data: {
            click_action: "OPEN_DASHBOARD",
            category: category,
            patientId: userId,
            clinicId: appId,
            target_url: targetUrl
          }
        });
        console.log(`[Notification FCM] Sent to token for user: ${userId} (${targetUrl})`);
      }
    }
  } catch (err) {
    console.error(`Error sending user notification:`, err);
  }
}

// Helper to send in-app and push notification to patient
async function sendNotificationToPatient(appId, patientId, title, body, category, targetUrl = "patient.html") {
  await sendNotificationToUser(appId, patientId, title, body, category, targetUrl);
}

// Helper to recalculate queue positions
async function recalculateQueuePositions(appId, doctorId) {
  try {
    const qSnap = await db.collection(`artifacts/${appId}/public/data/queue`)
      .where("status", "==", "waiting")
      .where("doctorId", "==", doctorId)
      .get();

    const waitingPatients = [];
    qSnap.forEach(doc => {
      waitingPatients.push({ id: doc.id, ref: doc.ref, ...doc.data() });
    });

    waitingPatients.sort((a, b) => {
      const scoreA = a.priorityScore || 20;
      const scoreB = b.priorityScore || 20;
      if (scoreA !== scoreB) return scoreB - scoreA;
      const secA = a.joinedAt?.seconds || 0;
      const secB = b.joinedAt?.seconds || 0;
      return secA - secB;
    });

    for (let i = 0; i < waitingPatients.length; i++) {
      const patient = waitingPatients[i];
      const newPos = i + 1;
      const oldPos = patient.lastPosition;

      if (oldPos !== newPos) {
        // Update document with new position
        await patient.ref.set({ lastPosition: newPos }, { merge: true });

        // Trigger notification
        let notifyText = `Your position in the queue is now #${newPos}.`;
        let category = 'update';

        if (newPos === 4) {
          notifyText = "Only 3 patients remain ahead of you. Please be ready.";
          category = 'update';
        } else if (newPos === 2) {
          notifyText = "Only 1 patient remains ahead of you. Please proceed near the doctor's room.";
          category = 'turn';
        }

        await sendNotificationToPatient(appId, patient.id, "Queue Update", notifyText, category);
      }
    }
  } catch (err) {
    console.error(`Error recalculating queue positions for ${doctorId}:`, err);
  }
}

/**
 * Automatically trigger FCM push notification when queue updates or status transitions
 */
exports.onQueueStatusChange = functions.firestore
  .document('artifacts/{appId}/public/data/queue/{patientId}')
  .onWrite(async (change, context) => {
    const appId = context.params.appId;
    const patientId = context.params.patientId;

    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    async function sendNotification(title, body, category) {
      await sendNotificationToPatient(appId, patientId, title, body, category);
    }

    // 1. Create Event: Token Generated
    if (!before && after) {
      const token = after.token || 'N/A';
      await sendNotification(
        "Token Generated",
        `Welcome! Your token number is #${token}. We will keep you updated in real-time.`,
        "queue"
      );
      
      if (after.doctorId) {
        await sendNotificationToUser(
          appId,
          after.doctorId,
          "New Patient in Queue",
          `${after.name} (Token #${token}) has been added to your queue.`,
          "doctor_queue",
          "doctor.html"
        );
        await recalculateQueuePositions(appId, after.doctorId);
      }
      return null;
    }

    // 2. Delete Event: Patient Left or Removed
    if (before && !after) {
      if (before.doctorId) {
        await recalculateQueuePositions(appId, before.doctorId);
      }
      return null;
    }

    // 3. Update Event
    if (before && after) {
      // Doctor Assigned
      if (!before.doctorId && after.doctorId) {
        const docName = after.doctorName || 'your doctor';
        await sendNotification(
          "Doctor Assigned",
          `Dr. ${docName} has been assigned to your consultation.`,
          "queue"
        );
        await sendNotificationToUser(
          appId,
          after.doctorId,
          "New Patient in Queue",
          `${after.name} (Token #${after.token}) has been added to your queue.`,
          "doctor_queue",
          "doctor.html"
        );
      }
      
      // Doctor Changed
      else if (before.doctorId && after.doctorId && before.doctorId !== after.doctorId) {
        const docName = after.doctorName || 'your doctor';
        await sendNotification(
          "Doctor Changed",
          `Your consulting doctor has changed to Dr. ${docName}.`,
          "queue"
        );
        // Notify the new doctor
        await sendNotificationToUser(
          appId,
          after.doctorId,
          "New Patient in Queue",
          `${after.name} (Token #${after.token}) has been added to your queue.`,
          "doctor_queue",
          "doctor.html"
        );
        // Notify the old doctor
        await sendNotificationToUser(
          appId,
          before.doctorId,
          "Patient Removed",
          `${before.name} has been reassigned to another doctor.`,
          "doctor_queue",
          "doctor.html"
        );
      }

      // Patient's Turn Arrives
      if (before.status !== 'calling' && after.status === 'calling') {
        const lang = after.lang || 'en';
        const t = TRANSLATIONS[lang] || TRANSLATIONS['en'];
        const messageBody = t.notify_msg || "It's almost your turn! Please come to the consultation room.";
        
        if (!after.notified) {
          await change.after.ref.set({
            notified: true,
            notifiedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        }
        
        await sendNotification(
          "It's Your Turn!",
          messageBody,
          "turn"
        );
      }

      // Appointment Completed
      const wasOpen = ["waiting", "pre_registered", "pending_payment"].includes(before.status);
      if (wasOpen && after.status === 'seen' && before.status !== 'seen') {
        await sendNotification(
          "Consultation Completed",
          "Your visit has been marked complete. Please proceed to the receptionist counter.",
          "billing"
        );
      }

      // Payment Receipt Generated
      if (before.paymentStatus !== 'Paid' && after.paymentStatus === 'Paid') {
        const invNum = after.invoiceNumber || 'N/A';
        await sendNotification(
          "Payment Completed",
          `Thank you! Receipt for Invoice #${invNum} has been generated.`,
          "billing"
        );
      }

      // Recalculate queue positions if status, priorityScore, or doctorId changed
      const wasWaiting = before.status === 'waiting';
      const isWaiting = after.status === 'waiting';
      
      if (wasWaiting !== isWaiting || before.priorityScore !== after.priorityScore || before.doctorId !== after.doctorId) {
        if (before.doctorId && before.doctorId !== after.doctorId) {
          await recalculateQueuePositions(appId, before.doctorId);
        }
        if (after.doctorId) {
          await recalculateQueuePositions(appId, after.doctorId);
        }
      }
    }
    return null;
  });

/**
 * Bootstrap/admin utility: set custom role claim.
 * Caller must already be authorized admin.
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }
  const callerEmail = (context.auth.token?.email || "").toLowerCase();
  if (!isAdminEmail(callerEmail) && context.auth.token?.role !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Only admin can set roles.");
  }

  const { uid, role } = data || {};
  if (!uid || !role) {
    throw new functions.https.HttpsError("invalid-argument", "uid and role are required.");
  }
  if (!["admin", "doctor", "staff", "patient"].includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid role.");
  }

  const user = await admin.auth().getUser(uid);
  const existing = user.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, {
    ...existing,
    role,
    roleAssignedAt: Date.now(),
  });

  await writeAuditLog("ROLE_UPDATED", {
    uid: context.auth.uid,
    email: context.auth.token?.email || null,
  }, { targetUid: uid, role }, "INFO");

  return { success: true, uid, role };
});

/**
 * Queue enrichment: capture queue-ahead context at join time.
 */
exports.enrichQueueEntry = functions.firestore
  .document(`${QUEUE_PATH}/{queueId}`)
  .onCreate(async (snap) => {
    const data = snap.data() || {};
    const joinedAt = asDate(data.joinedAt);
    if (!joinedAt) {
      // joinedAt may not be immediately materialized in some write paths; retry once
      await waitMs(800);
    }

    const refetched = await snap.ref.get();
    const fresh = refetched.data() || {};
    const joinedAtFresh = asDate(fresh.joinedAt);
    if (!joinedAtFresh) return null;

    const qSnap = await db.collection(QUEUE_PATH)
      .where("status", "==", "waiting")
      .where("joinedAt", "<=", admin.firestore.Timestamp.fromDate(joinedAtFresh))
      .get();

    let ahead = 0;
    let urgentAhead = 0;
    qSnap.forEach((doc) => {
      if (doc.id === snap.id) return;
      ahead += 1;
      const d = doc.data() || {};
      if ((d.priorityScore || 0) >= 60) urgentAhead += 1;
    });

    const hour = joinedAtFresh.getHours();
    const dayOfWeek = joinedAtFresh.getDay();
    await snap.ref.set({
      queueAheadAtJoin: ahead,
      urgentAheadAtJoin: urgentAhead,
      joinedHour: hour,
      joinedDayOfWeek: dayOfWeek,
    }, { merge: true });
    return null;
  });

/**
 * Queue completion logger: writes ML training samples when a visit is completed.
 */
exports.captureQueueTrainingSample = functions.firestore
  .document(`${QUEUE_PATH}/{queueId}`)
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const wasOpen = ["waiting", "pre_registered", "pending_payment"].includes(before.status);
    const isClosed = ["seen", "completed"].includes(after.status);
    if (!wasOpen || !isClosed) return null;

    const joinedAt = asDate(after.joinedAt || before.joinedAt);
    const closedAt = asDate(after.completedAt || after.updatedAt || new Date());
    if (!joinedAt || !closedAt) return null;

    const waitMinutes = Math.max(1, Math.round((closedAt.getTime() - joinedAt.getTime()) / 60000));
    if (waitMinutes > 360) return null;

    const sampleRef = db.collection(ML_SAMPLES_PATH).doc(context.params.queueId);
    const existingSample = await sampleRef.get();
    if (existingSample.exists) return null;

    await sampleRef.set({
      queueId: context.params.queueId,
      waitMinutes,
      queueAhead: Number(after.queueAheadAtJoin || 0),
      urgentAhead: Number(after.urgentAheadAtJoin || 0),
      isEmergency: !!after.isEmergency,
      hour: Number(after.joinedHour ?? joinedAt.getHours()),
      dayOfWeek: Number(after.joinedDayOfWeek ?? joinedAt.getDay()),
      avgConsultationMinutes: clamp(
        Number(after.consultationMinutes || after.avgConsultationMinutes || after.slotDurationMinutes || 5),
        2,
        45
      ),
      source: after.source || "web",
      doctorId: after.doctorId || "default",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      joinedAt: admin.firestore.Timestamp.fromDate(joinedAt),
      completedAt: admin.firestore.Timestamp.fromDate(closedAt),
    }, { merge: false });

    try {
      await maybeTriggerNearRealtimeRetrain();
    } catch (err) {
      console.error("Near real-time retrain trigger failed:", err?.message || err);
    }
    return null;
  });

async function trainAndPersistWaitModel(trigger = "manual") {
  const fromDate = new Date(Date.now() - (1000 * 60 * 60 * 24 * 90));
  const snap = await db.collection(ML_SAMPLES_PATH)
    .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(fromDate))
    .orderBy("createdAt", "desc")
    .limit(3000)
    .get();

  const samples = [];
  snap.forEach((doc) => {
    const d = doc.data() || {};
    if (!d.waitMinutes || d.waitMinutes <= 0) return;
    samples.push({
      waitMinutes: Number(d.waitMinutes),
      queueAhead: Number(d.queueAhead || 0),
      urgentAhead: Number(d.urgentAhead || 0),
      isEmergency: !!d.isEmergency,
      hour: Number(d.hour || 0),
      dayOfWeek: Number(d.dayOfWeek || 0),
      avgConsultationMinutes: Number(d.avgConsultationMinutes || 5),
    });
  });

  if (samples.length < 25) {
    const baseline = samples.length
      ? Math.round(samples.reduce((s, x) => s + x.waitMinutes, 0) / samples.length)
      : 8;
    await db.doc(ML_MODEL_DOC).set({
      active: false,
      reason: "insufficient_samples",
      sampleCount: samples.length,
      baselineMinutes: baseline,
      modelType: "ridge_regression_v2",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      trigger,
    }, { merge: true });
    return { active: false, sampleCount: samples.length, baselineMinutes: baseline };
  }

  const avgConsultationMinutes = Math.round(
    (samples.reduce((sum, item) => sum + clamp(Number(item.avgConsultationMinutes || 5), 2, 45), 0) / samples.length) * 10
  ) / 10;

  const split = Math.max(1, Math.floor(samples.length * 0.8));
  const trainSamples = samples.slice(0, split);
  const testSamples = samples.slice(split);
  const trainVectorsRaw = trainSamples.map((s) => buildFeatureVector(s));
  const trainTargets = trainSamples.map((s) => Number(s.waitMinutes));
  const featureStats = computeFeatureStats(trainVectorsRaw);
  const trainVectors = trainVectorsRaw.map((v) => normalizeVector(v, featureStats));

  const weights = trainRidgeRegression(trainVectors, trainTargets);
  const evalSet = testSamples.length ? testSamples : trainSamples;
  const metrics = evaluateModel(evalSet, { weights, featureStats }, avgConsultationMinutes);
  const residuals = evalSet
    .map((s) => {
      const raw = buildFeatureVector(s);
      const x = normalizeVector(raw, featureStats);
      const pred = clamp(dot(weights, x), 1, 240);
      return Math.abs(pred - Number(s.waitMinutes || 0));
    })
    .sort((a, b) => a - b);
  const residualP50 = Math.round(percentile(residuals, 50) * 10) / 10;
  const residualP90 = Math.round(percentile(residuals, 90) * 10) / 10;

  await db.doc(ML_MODEL_DOC).set({
    active: true,
    modelType: "ridge_regression_v2",
    weights,
    featureStats,
    baselineMinutes: avgConsultationMinutes,
    residualP50,
    residualP90,
    sampleCount: samples.length,
    pendingSampleCount: 0,
    metrics,
    lastTrainedAtMs: Date.now(),
    trainedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    trigger,
  }, { merge: true });

  return {
    active: true,
    sampleCount: samples.length,
    metrics,
    residualP50,
    residualP90,
    baselineMinutes: avgConsultationMinutes,
  };
}

/**
 * Manual training endpoint.
 */
exports.trainQueueModel = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }
  const adminEmail = (context.auth.token?.email || "").toLowerCase();
  if (!isAdminEmail(adminEmail)) {
    throw new functions.https.HttpsError("permission-denied", "Only admin can retrain model.");
  }
  const result = await trainAndPersistWaitModel("manual");
  return { success: true, result };
});

/**
 * Auto-retraining every day.
 */
exports.scheduledQueueModelTraining = functions.pubsub
  .schedule("every day 02:30")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    await trainAndPersistWaitModel("scheduled");
    return null;
  });

/**
 * Real-time wait prediction API with fallback when model is cold.
 */
exports.predictWaitTime = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }
  const queueAhead = Number(data?.queueAhead || 0);
  const urgentAhead = Number(data?.urgentAhead || 0);
  const isEmergency = !!data?.isEmergency;
  const avgConsultationMinutes = Number(data?.avgConsultationMinutes || 5);
  const hour = Number(data?.hour ?? new Date().getHours());
  const dayOfWeek = Number(data?.dayOfWeek ?? new Date().getDay());

  const model = await readActiveWaitModel();
  const fallbackUnit = Number(model?.baselineMinutes || avgConsultationMinutes || 5);
  const fallbackMinutes = clamp(Math.round(Math.max(1, queueAhead) * Math.max(1, fallbackUnit)), 2, 240);

  if (!model || !model.active || !Array.isArray(model.weights)) {
    return {
      predictedWaitMinutes: fallbackMinutes,
      confidence: "fallback",
      modelUsed: false,
    };
  }

  const features = buildFeatureVector({
    queueAhead,
    urgentAhead,
    isEmergency,
    hour,
    dayOfWeek,
    avgConsultationMinutes: fallbackUnit,
  });
  const normalized = normalizeVector(features, model.featureStats);
  const raw = dot(model.weights, normalized);
  const blended = (raw * 0.75) + (fallbackMinutes * 0.25);
  const predicted = clamp(Math.round(blended), 2, 240);
  const residualBand = clamp(Number(model.residualP90 || 12), 3, 45);

  return {
    predictedWaitMinutes: predicted,
    predictionWindow: {
      low: clamp(Math.round(predicted - residualBand), 1, 240),
      high: clamp(Math.round(predicted + residualBand), 2, 300),
    },
    confidence: inferConfidence(model, queueAhead),
    modelUsed: true,
    modelType: model.modelType || "ridge_regression_v2",
    sampleCount: Number(model.sampleCount || 0),
    metrics: model.metrics || null,
  };
});

async function exportAuditLogsIncremental() {
  const metaRef = db.doc(AUDIT_ARCHIVE_META_DOC);
  const metaSnap = await metaRef.get();
  const meta = metaSnap.exists ? (metaSnap.data() || {}) : {};
  let sequence = Number(meta.sequence || 0);
  let prevHash = meta.lastHash || "GENESIS";
  let lastCreatedAt = meta.lastCreatedAt || null;
  let exportedCount = 0;

  for (let i = 0; i < 6; i += 1) {
    let q = db.collection(AUDIT_LOGS_PATH)
      .orderBy("createdAt", "asc")
      .limit(200);
    if (lastCreatedAt) q = q.startAfter(lastCreatedAt);
    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    let batchWrites = 0;

    for (const docSnap of snap.docs) {
      const data = docSnap.data() || {};
      const createdAt = data.createdAt;
      if (!createdAt) continue;
      if (data.archiveHash) {
        lastCreatedAt = createdAt;
        continue;
      }

      sequence += 1;
      const canonical = {
        sourceId: docSnap.id,
        action: data.action || "UNKNOWN",
        severity: data.severity || "INFO",
        actor: data.actor || {},
        details: data.details || {},
        createdAt: createdAt.toMillis(),
      };
      const payload = JSON.stringify(canonical);
      const hash = sha256Hex(`${prevHash}|${payload}`);
      const archiveRef = db.collection(AUDIT_ARCHIVE_PATH).doc(docSnap.id);

      batch.set(archiveRef, {
        ...canonical,
        payloadHash: hash,
        prevHash,
        sequence,
        immutable: true,
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      batch.set(docSnap.ref, {
        archiveHash: hash,
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      prevHash = hash;
      lastCreatedAt = createdAt;
      exportedCount += 1;
      batchWrites += 2;
    }

    if (batchWrites > 0) {
      batch.set(metaRef, {
        sequence,
        lastHash: prevHash,
        lastCreatedAt: lastCreatedAt || admin.firestore.FieldValue.serverTimestamp(),
        lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      await batch.commit();
    }

    if (snap.size < 200) break;
  }

  return { exportedCount, sequence, lastHash: prevHash };
}

async function runDataRetention() {
  const queueCutoff = daysAgoTimestamp(RETENTION_QUEUE_DAYS);
  const otpCutoff = daysAgoTimestamp(RETENTION_OTP_DAYS);
  const mlCutoff = daysAgoTimestamp(RETENTION_ML_SAMPLE_DAYS);
  const auditCutoff = daysAgoTimestamp(RETENTION_AUDIT_DAYS);
  const result = {
    otpDeleted: 0,
    mlDeleted: 0,
    queueRedacted: 0,
    auditDeleted: 0,
  };

  // 1) Cleanup expired OTP records
  for (let i = 0; i < 5; i += 1) {
    const snap = await db.collection(OTP_PATH)
      .where("expiresAt", "<", otpCutoff)
      .limit(300)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    result.otpDeleted += snap.size;
    if (snap.size < 300) break;
  }

  // 2) Cleanup old ML samples
  for (let i = 0; i < 5; i += 1) {
    const snap = await db.collection(ML_SAMPLES_PATH)
      .where("createdAt", "<", mlCutoff)
      .limit(300)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    result.mlDeleted += snap.size;
    if (snap.size < 300) break;
  }

  // 3) Redact closed queue entries past retention
  for (let i = 0; i < 5; i += 1) {
    const snap = await db.collection(QUEUE_PATH)
      .where("status", "in", ["seen", "completed", "cancelled"])
      .where("joinedAt", "<", queueCutoff)
      .limit(200)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    for (const d of snap.docs) {
      const v = d.data() || {};
      if (v.piiRedacted) continue;
      batch.set(d.ref, {
        name: admin.firestore.FieldValue.delete(),
        mobile: admin.firestore.FieldValue.delete(),
        phone: admin.firestore.FieldValue.delete(),
        issue: admin.firestore.FieldValue.delete(),
        patientIdHash: sha256Hex(`${v.patientId || d.id}|${OTP_PEPPER}`),
        patientId: admin.firestore.FieldValue.delete(),
        piiRedacted: true,
        piiRedactedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      result.queueRedacted += 1;
    }
    await batch.commit();
    if (snap.size < 200) break;
  }

  // 4) Purge archived raw audit logs after retention window
  for (let i = 0; i < 5; i += 1) {
    const snap = await db.collection(AUDIT_LOGS_PATH)
      .where("createdAt", "<", auditCutoff)
      .limit(250)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    let deletions = 0;
    for (const d of snap.docs) {
      const v = d.data() || {};
      if (!v.archiveHash) continue; // keep until archive chain is created
      batch.delete(d.ref);
      deletions += 1;
    }
    if (deletions > 0) {
      await batch.commit();
      result.auditDeleted += deletions;
    }
    if (snap.size < 250) break;
  }

  return result;
}

exports.scheduledSecurityMaintenance = functions.pubsub
  .schedule("every day 03:45")
  .timeZone("Asia/Kolkata")
  .onRun(async () => {
    const archive = await exportAuditLogsIncremental();
    const retention = await runDataRetention();
    await writeAuditLog("SECURITY_MAINTENANCE_SCHEDULED", {}, { archive, retention }, "INFO");
    return null;
  });

exports.runSecurityMaintenanceNow = functions.https.onCall(async (data, context) => {
  if (!isAdminContext(context)) {
    throw new functions.https.HttpsError("permission-denied", "Admin required.");
  }
  const archive = await exportAuditLogsIncremental();
  const retention = await runDataRetention();
  await writeAuditLog("SECURITY_MAINTENANCE_MANUAL", {
    uid: context.auth.uid,
    email: context.auth.token?.email || null,
  }, { archive, retention }, "INFO");
  return { success: true, archive, retention };
});

const nodemailer = require("nodemailer");

const SMTP_USER = process.env.SMTP_USER || runtimeConfig.smtp?.user || "";
const SMTP_PASS = process.env.SMTP_PASS || runtimeConfig.smtp?.pass || "";
const SMTP_FROM =
  process.env.SMTP_FROM ||
  runtimeConfig.smtp?.from ||
  `"MediQue by Atherion Technologies" <${SMTP_USER || "no-reply@medique.local"}>`;

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASS,
  },
});

function assertMailConfigured() {
  if (!SMTP_USER || !SMTP_PASS) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "SMTP credentials are not configured. Set SMTP_USER and SMTP_PASS environment variables."
    );
  }
}

exports.sendOtpEmail = functions.https.onCall(async (data, context) => {
    assertMailConfigured();
    const { email } = data;
    if (!email) {
        throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }

    const cleanEmail = String(email).trim().toLowerCase();
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    const otpHash = hashOtp(cleanEmail, otp);
    const otpRef = db.collection(OTP_PATH).doc(cleanEmail);
    const existing = await otpRef.get();
    const existingData = existing.exists ? existing.data() : null;
    const now = Date.now();
    const lastSentAt = existingData?.lastSentAt?.toMillis?.() || 0;
    const elapsedSeconds = Math.floor((now - lastSentAt) / 1000);
    if (elapsedSeconds < OTP_COOLDOWN_SECONDS) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Please wait ${OTP_COOLDOWN_SECONDS - elapsedSeconds}s before requesting another OTP.`
        );
    }

    // Save hashed OTP (expires in 10 minutes)
    await otpRef
        .set({
            otpHash: otpHash,
            expiresAt: new Date(Date.now() + 10 * 60000),
            attempts: 0,
            used: false
        });

    const mailOptions = {
        from: SMTP_FROM,
        to: cleanEmail,
        subject: 'Your MediQue 2FA Code',
        text: `Your MediQue login code is: ${otp}\n\nNote: If you didn't request this code, please ignore this email. Check your spam folder if you couldn't find it.`
    };

    try {
        await transporter.sendMail(mailOptions);
        await otpRef.set({
          lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
          requestedByUid: context.auth.uid || null,
        }, { merge: true });
        await writeAuditLog("OTP_SENT", {
          uid: context.auth.uid,
          email: context.auth.token?.email || null,
        }, { targetEmailHash: crypto.createHash("sha256").update(cleanEmail).digest("hex") }, "INFO");
        return { success: true, message: 'OTP sent successfully.' };
    } catch (error) {
        console.error("Error sending OTP email:", error);
        await writeAuditLog("OTP_SEND_FAILED", {
          uid: context.auth.uid,
          email: context.auth.token?.email || null,
        }, { message: error?.message || "unknown" }, "ERROR");
        throw new functions.https.HttpsError('internal', 'Unable to send OTP email', error);
    }
});

exports.sendPasswordResetLink = functions.https.onCall(async (data, context) => {
    assertMailConfigured();
    const email = String(data?.email || "").trim().toLowerCase();
    if (!email) {
      throw new functions.https.HttpsError("invalid-argument", "Email is required.");
    }

    const resetRef = db.collection(PASSWORD_RESET_PATH).doc(email);
    const existing = await resetRef.get();
    const existingData = existing.exists ? (existing.data() || {}) : {};
    const now = Date.now();
    const lastSentAt = existingData?.lastSentAt?.toMillis?.() || 0;
    const elapsedSeconds = Math.floor((now - lastSentAt) / 1000);
    if (elapsedSeconds < PASSWORD_RESET_COOLDOWN_SECONDS) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Please wait ${PASSWORD_RESET_COOLDOWN_SECONDS - elapsedSeconds}s before requesting another reset link.`
      );
    }

    const targetEmailHash = sha256Hex(email);
    try {
      const resetLink = await admin.auth().generatePasswordResetLink(email, {
        url: PASSWORD_RESET_CONTINUE_URL,
        handleCodeInApp: false,
      });

      await transporter.sendMail({
        from: SMTP_FROM,
        to: email,
        subject: "Reset your MediQue password",
        text:
          `We received a request to reset your MediQue password.\n\n` +
          `Reset link: ${resetLink}\n\n` +
          `If you did not request this, you can ignore this email.`,
      });

      await resetRef.set({
        emailHash: targetEmailHash,
        lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
        requestedByUid: context?.auth?.uid || null,
      }, { merge: true });
      await writeAuditLog("PASSWORD_RESET_LINK_SENT", {
        uid: context?.auth?.uid || null,
        email: context?.auth?.token?.email || null,
      }, { targetEmailHash }, "INFO");
    } catch (err) {
      // Avoid account enumeration in client-visible response
      await writeAuditLog("PASSWORD_RESET_LINK_REQUESTED", {
        uid: context?.auth?.uid || null,
        email: context?.auth?.token?.email || null,
      }, {
        targetEmailHash,
        providerResponse: err?.message || "unknown",
      }, "WARNING");
    }

    return {
      success: true,
      message: "If this account exists, a password reset link has been sent.",
    };
});

exports.verifyOtpAndLogin = functions.https.onCall(async (data, context) => {
    const { email, otp } = data;
    if (!email || !otp) {
        throw new functions.https.HttpsError('invalid-argument', 'Email and OTP required');
    }
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Login required');
    }
    
    const cleanEmail = String(email).trim().toLowerCase();
    const otpRef = db.collection(OTP_PATH).doc(cleanEmail);
    const otpDoc = await otpRef.get();
    
    if (!otpDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'No OTP found.');
    }
    
    const otpData = otpDoc.data();
    const expiresAt = otpData.expiresAt?.toDate?.() || new Date(0);
    const attempts = Number(otpData.attempts || 0);
    const incomingHash = hashOtp(cleanEmail, String(otp).trim());
    const isExpired = expiresAt < new Date();
    const isUsed = !!otpData.used;
    const isMatch = otpData.otpHash === incomingHash;

    if (attempts >= OTP_MAX_ATTEMPTS) {
        await writeAuditLog("OTP_VERIFY_LOCKED", {
          uid: context.auth.uid,
          email: context.auth.token?.email || null,
        }, { targetEmailHash: crypto.createHash("sha256").update(cleanEmail).digest("hex") }, "WARNING");
        throw new functions.https.HttpsError('permission-denied', 'Too many attempts. Request a new OTP.');
    }

    if (isUsed || isExpired || !isMatch) {
        await otpRef.set({
          attempts: attempts + 1,
          lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        await writeAuditLog("OTP_VERIFY_FAILED", {
          uid: context.auth.uid,
          email: context.auth.token?.email || null,
        }, { targetEmailHash: crypto.createHash("sha256").update(cleanEmail).digest("hex") }, "WARNING");
        throw new functions.https.HttpsError('permission-denied', 'Invalid or expired OTP.');
    }
    
    await otpRef.update({ used: true, verifiedAt: admin.firestore.FieldValue.serverTimestamp() });
    await writeAuditLog("OTP_VERIFY_SUCCESS", {
      uid: context.auth.uid,
      email: context.auth.token?.email || null,
    }, { targetEmailHash: crypto.createHash("sha256").update(cleanEmail).digest("hex") }, "INFO");
    
    return { success: true };
});

exports.verifyClinicCode = functions.https.onCall(async (data, context) => {
    const { code } = data;
    if (!code) {
        throw new functions.https.HttpsError('invalid-argument', 'Clinic code is required');
    }
    const cleanCode = String(code).trim().toUpperCase();
    
    // For single-tenant / general validation:
    // We map 'CARE5E', 'MEDIQ1', '123456', or codes containing '5EEEA' or 'CARE' to the active Firebase project ID.
    if (cleanCode === 'CARE5E' || cleanCode === 'MEDIQ1' || cleanCode === '123456' || cleanCode.includes('5EEEA') || cleanCode.includes('CARE')) {
        return {
            success: true,
            clinicId: APP_ID,
            clinicName: "MediQue Clinic"
        };
    }
    
    // If not matching, check if there is a document in a `clinic_codes` collection
    const codeDoc = await db.collection('clinic_codes').doc(cleanCode).get();
    if (codeDoc.exists) {
        const codeData = codeDoc.data();
        return {
            success: true,
            clinicId: codeData.clinicId,
            clinicName: codeData.clinicName || "MediQue Clinic"
        };
    }
    
    return {
        success: false,
        error: "Invalid Clinic Code. Try 'CARE5E' or '123456'."
    };
});



