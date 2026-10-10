/**
 * MediQue — Shared Premium UI Components v3.0
 * 
 * Modules included:
 *   1. MQToast         — Premium toast notification system
 *   2. MQChatbot       — AI Queue Assistant chatbot
 *   3. MQLang          — Multi-language switcher (EN, HI, TA, TE)
 *   4. MQHeatmap       — Peak-hour analytics heatmap
 *   5. MQVideoCall     — Telehealth video call UI layer
 *   6. MQConfetti      — Celebration animation (on queue completion)
 * 
 * Usage: Include this script AFTER Firebase is initialized.
 * <script src="medique-components.js"></script>
 */

'use strict';

/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   1. MQToast — Premium Toast Notification System
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQToast = (() => {
  const ICONS = {
    success: '✅',
    error:   '🚨',
    info:    'ℹ️',
    warning: '⚠️',
  };

  function ensureContainer() {
    let c = document.getElementById('mq-toast-container');
    if (!c) {
      c = document.createElement('div');
      c.id = 'mq-toast-container';
      document.body.appendChild(c);
    }
    return c;
  }

  function show(message, type = 'info', duration = 4000, title = null) {
    const container = ensureContainer();
    const toast = document.createElement('div');
    toast.className = `mq-toast toast-${type}`;
    toast.innerHTML = `
      <div class="mq-toast-icon">${ICONS[type] || ICONS.info}</div>
      <div style="flex:1;min-width:0;">
        ${title ? `<div style="font-weight:700;font-size:.875rem;margin-bottom:2px;color:#111827">${title}</div>` : ''}
        <div style="color:#374151;line-height:1.5;font-size:.85rem;">${message}</div>
      </div>
      <button onclick="this.closest('.mq-toast').remove()" style="background:none;border:none;cursor:pointer;color:#9ca3af;padding:4px;border-radius:6px;flex-shrink:0;font-size:1rem;line-height:1;" title="Dismiss">×</button>
    `;
    container.appendChild(toast);

    // Auto-dismiss
    if (duration > 0) {
      setTimeout(() => {
        toast.classList.add('toast-out');
        setTimeout(() => toast.remove(), 300);
      }, duration);
    }

    return toast;
  }

  return {
    success: (msg, title, dur) => show(msg, 'success', dur || 4000, title),
    error:   (msg, title, dur) => show(msg, 'error',   dur || 6000, title),
    info:    (msg, title, dur) => show(msg, 'info',    dur || 4000, title),
    warning: (msg, title, dur) => show(msg, 'warning', dur || 5000, title),
    show,
  };
})();


/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   2. MQChatbot — AI Queue Assistant
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQChatbot = (() => {
  // Context injected from outside (queue data, patient info)
  let _ctx = {
    patientName: null,
    queuePosition: null,
    totalInQueue: null,
    etaMinutes: null,
    confidence: null,
    tokenNumber: null,
    clinicName: 'MediQue Clinic',
    doctorName: null,
  };

  const QUICK_REPLIES = [
    'What is my queue position?',
    'How long is the wait?',
    'Can I reschedule?',
    'What to bring to the appointment?',
    'How do I check in?',
  ];

  // Rule-based NLP engine (works offline, no API key needed)
  const INTENTS = [
    {
      patterns: [/position|place|number|where am i|rank|queue/i],
      response: (ctx) => ctx.queuePosition
        ? `📍 You are currently at position <strong>#${ctx.queuePosition}</strong> in the queue${ctx.totalInQueue ? ` out of ${ctx.totalInQueue} patients` : ''}. Your token is <strong>${ctx.tokenNumber || 'N/A'}</strong>.`
        : `You haven't joined the queue yet. Tap the <strong>Join Queue</strong> button to get started!`,
    },
    {
      patterns: [/wait|time|eta|long|minutes|how long|when/i],
      response: (ctx) => ctx.etaMinutes
        ? `⏱️ Estimated wait time: <strong>~${ctx.etaMinutes} minutes</strong> (confidence: <em>${ctx.confidence || 'medium'}</em>). We recommend arriving at the clinic 10 minutes before your estimated turn.`
        : `I don't have your current ETA. Please join the queue first.`,
    },
    {
      patterns: [/check.?in|arrive|qr|scan|entered|reached|came/i],
      response: () => `📱 To check in, tap the <strong>QR Check-In</strong> button on your dashboard when you're inside the clinic. This lets the doctor know you've arrived and helps confirm your slot.`,
    },
    {
      patterns: [/cancel|leave|exit|quit|remove|withdraw/i],
      response: () => `To leave the queue, scroll to the bottom of your dashboard and tap <strong>Leave Queue</strong>. You can rejoin later using the same token if your slot is still available.`,
    },
    {
      patterns: [/reschedule|book|appointment|change date|different time/i],
      response: () => `📅 To reschedule, go to the <strong>Appointments</strong> tab and select your booking. You can change the date and time there, subject to availability.`,
    },
    {
      patterns: [/bring|prepare|documents|medical records|id|card|what to bring/i],
      response: () => `📋 Please bring:\n• Any previous prescriptions or reports\n• A valid ID (Aadhaar / PAN / Voter ID)\n• Your insurance card (if applicable)\n• A list of current medications`,
    },
    {
      patterns: [/payment|pay|bill|fee|upi|amount/i],
      response: () => `💳 Payment is processed via UPI. Once your consultation is complete, the doctor will send you a payment request directly in the app. You can pay using any UPI app (GPay, PhonePe, Paytm).`,
    },
    {
      patterns: [/emergency|urgent|critical|severe|serious/i],
      response: () => `🚨 If this is a medical emergency, call <strong>112</strong> immediately. For urgent but non-emergency cases, please inform the receptionist — emergency cases are given priority in the queue.`,
    },
    {
      patterns: [/hello|hi|hey|good morning|good afternoon|good evening|namaste/i],
      response: (ctx) => `👋 Hi${ctx.patientName ? `, ${ctx.patientName}` : ''}! I'm <strong>MediBot</strong>, your MediQue assistant. I can help you track your queue, check wait times, or answer clinic questions. How can I help you today?`,
    },
    {
      patterns: [/thank|thanks|thank you|thx|tysm/i],
      response: () => `😊 You're welcome! I'm always here if you need anything else. Wishing you a speedy recovery! 🌿`,
    },
    {
      patterns: [/doctor|physician|specialist|who is/i],
      response: (ctx) => ctx.doctorName
        ? `👨‍⚕️ Your assigned doctor is <strong>Dr. ${ctx.doctorName}</strong>. If you have any questions about the appointment, please bring them along!`
        : `The doctor will be assigned when you check in. Please ask the receptionist for details.`,
    },
    {
      patterns: [/clinic|hospital|address|location|where|direction|map/i],
      response: (ctx) => `📍 You're registered at <strong>${ctx.clinicName}</strong>. For directions, tap the location icon on your profile screen or search for us on Google Maps.`,
    },
  ];

  const FALLBACKS = [
    "I'm not sure about that one. Try asking about your queue position, wait time, or how to check in!",
    "Hmm, I didn't quite get that. I can help with queue status, appointments, and payment questions.",
    "That's outside my knowledge! For specific medical advice, please consult your doctor directly.",
  ];
  let fallbackIdx = 0;

  function classify(text) {
    for (const intent of INTENTS) {
      if (intent.patterns.some(p => p.test(text))) {
        return intent;
      }
    }
    return null;
  }

  function getResponse(text) {
    const intent = classify(text);
    if (intent) {
      const r = intent.response(_ctx);
      return Promise.resolve(r);
    }
    const fallback = FALLBACKS[fallbackIdx % FALLBACKS.length];
    fallbackIdx++;
    return Promise.resolve(fallback);
  }

  // ── Render ──────────────────────────────────────────────────────────
  function buildUI() {
    // FAB button
    const fab = document.createElement('button');
    fab.id = 'mq-chatbot-fab';
    fab.setAttribute('aria-label', 'Open AI Assistant');
    fab.innerHTML = `
      <div class="fab-pulse"></div>
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
    `;

    // Chat panel
    const panel = document.createElement('div');
    panel.id = 'mq-chatbot-panel';
    panel.setAttribute('role', 'dialog');
    panel.setAttribute('aria-label', 'MediBot AI Assistant');
    panel.innerHTML = `
      <div class="chatbot-header">
        <div class="chatbot-avatar">🤖</div>
        <div>
          <div style="font-weight:700;font-size:.9375rem;">MediBot</div>
          <div style="font-size:.75rem;opacity:.8;display:flex;align-items:center;gap:4px;">
            <span style="width:6px;height:6px;background:#4ade80;border-radius:50%;display:inline-block;"></span>
            AI Queue Assistant · Online
          </div>
        </div>
        <button id="mq-chatbot-close" style="margin-left:auto;background:rgba(255,255,255,.15);border:none;color:white;width:32px;height:32px;border-radius:50%;cursor:pointer;display:flex;align-items:center;justify-content:center;font-size:1.1rem;" aria-label="Close">×</button>
      </div>
      <div class="chatbot-body" id="mq-chatbot-messages">
        <!-- messages injected here -->
      </div>
      <div id="mq-quick-replies" style="padding:8px 12px;display:flex;gap:6px;flex-wrap:wrap;background:#f8fafc;border-top:1px solid #e5e7eb;"></div>
      <div class="chatbot-footer">
        <input class="chatbot-input" id="mq-chatbot-input" placeholder="Ask about your queue…" autocomplete="off" />
        <button id="mq-chatbot-send" style="width:38px;height:38px;border-radius:50%;background:linear-gradient(135deg,#0d9488,#6366f1);color:white;border:none;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:1rem;" aria-label="Send">
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>
        </button>
      </div>
    `;

    document.body.appendChild(fab);
    document.body.appendChild(panel);

    // Wire events
    fab.addEventListener('click', toggle);
    document.getElementById('mq-chatbot-close').addEventListener('click', close);

    const input = document.getElementById('mq-chatbot-input');
    document.getElementById('mq-chatbot-send').addEventListener('click', () => sendMessage(input.value));
    input.addEventListener('keydown', e => {
      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(input.value); }
    });

    // Render quick replies
    renderQuickReplies();

    // Welcome message (after slight delay)
    setTimeout(() => {
      addBotMessage(`👋 Hi${_ctx.patientName ? `, <strong>${_ctx.patientName}</strong>` : ''}! I'm <strong>MediBot</strong>, your AI queue assistant. I can help you with queue status, wait times, appointments, and more.`);
    }, 400);
  }

  function renderQuickReplies() {
    const container = document.getElementById('mq-quick-replies');
    if (!container) return;
    container.innerHTML = '';
    QUICK_REPLIES.forEach(reply => {
      const btn = document.createElement('button');
      btn.textContent = reply;
      btn.style.cssText = 'background:#e0f2fe;color:#0369a1;border:none;border-radius:999px;padding:4px 10px;font-size:.75rem;cursor:pointer;white-space:nowrap;font-weight:500;transition:background 0.15s;';
      btn.addEventListener('mouseenter', () => btn.style.background = '#bae6fd');
      btn.addEventListener('mouseleave', () => btn.style.background = '#e0f2fe');
      btn.addEventListener('click', () => sendMessage(reply));
      container.appendChild(btn);
    });
  }

  function addBotMessage(html) {
    const msgs = document.getElementById('mq-chatbot-messages');
    if (!msgs) return;
    const bubble = document.createElement('div');
    bubble.className = 'chatbot-bubble bot';
    bubble.innerHTML = html;
    msgs.appendChild(bubble);
    msgs.scrollTop = msgs.scrollHeight;
  }

  function addUserMessage(text) {
    const msgs = document.getElementById('mq-chatbot-messages');
    if (!msgs) return;
    const bubble = document.createElement('div');
    bubble.className = 'chatbot-bubble user';
    bubble.textContent = text;
    msgs.appendChild(bubble);
    msgs.scrollTop = msgs.scrollHeight;
  }

  function showTyping() {
    const msgs = document.getElementById('mq-chatbot-messages');
    if (!msgs) return null;
    const el = document.createElement('div');
    el.className = 'chatbot-bubble bot';
    el.id = 'mq-typing';
    el.innerHTML = `<div class="typing-indicator"><span></span><span></span><span></span></div>`;
    msgs.appendChild(el);
    msgs.scrollTop = msgs.scrollHeight;
    return el;
  }

  async function sendMessage(text) {
    text = (text || '').trim();
    if (!text) return;

    const input = document.getElementById('mq-chatbot-input');
    if (input) input.value = '';

    addUserMessage(text);

    // Show typing
    const typingEl = showTyping();
    const delay = 600 + Math.random() * 600;

    await new Promise(r => setTimeout(r, delay));
    typingEl && typingEl.remove();

    const response = await getResponse(text);
    addBotMessage(response);
  }

  function toggle() {
    const panel = document.getElementById('mq-chatbot-panel');
    const fab   = document.getElementById('mq-chatbot-fab');
    if (!panel) return;
    const isOpen = panel.classList.contains('open');
    if (isOpen) {
      close();
    } else {
      panel.classList.add('open');
      fab && (fab.style.transform = 'scale(0.9)');
      setTimeout(() => {
        const input = document.getElementById('mq-chatbot-input');
        input && input.focus();
      }, 300);
    }
  }

  function close() {
    const panel = document.getElementById('mq-chatbot-panel');
    const fab   = document.getElementById('mq-chatbot-fab');
    panel && panel.classList.remove('open');
    fab && (fab.style.transform = '');
  }

  return {
    init(ctx = {}) {
      Object.assign(_ctx, ctx);
      if (!document.getElementById('mq-chatbot-fab')) {
        buildUI();
      }
    },
    updateContext(ctx) {
      Object.assign(_ctx, ctx);
    },
    open: toggle,
    close,
  };
})();


/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   3. MQLang — Multi-Language Switcher
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQLang = (() => {
  const LANGS = {
    en: { label: 'EN', name: 'English' },
    hi: { label: 'HI', name: 'हिंदी' },
    ta: { label: 'TA', name: 'தமிழ்' },
    te: { label: 'TE', name: 'తెలుగు' },
  };

  let _current = localStorage.getItem('mq-lang') || 'en';
  const _listeners = [];

  function renderSwitcher(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;
    container.className = 'mq-lang-switcher';
    container.innerHTML = Object.entries(LANGS).map(([code, info]) => `
      <button class="mq-lang-btn${_current === code ? ' active' : ''}" 
              data-lang="${code}" 
              title="${info.name}"
              onclick="MQLang.set('${code}')">
        ${info.label}
      </button>
    `).join('');
  }

  function set(lang) {
    if (!LANGS[lang]) return;
    _current = lang;
    localStorage.setItem('mq-lang', lang);
    // Update active states
    document.querySelectorAll('.mq-lang-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.lang === lang);
    });
    // Apply i18n via existing translations.js if available
    if (window.applyTranslations) {
      window.applyTranslations(lang);
    } else if (window.MEDIQUE_TRANSLATIONS && window.MEDIQUE_TRANSLATIONS[lang]) {
      applyLocalTranslations(window.MEDIQUE_TRANSLATIONS[lang]);
    }
    _listeners.forEach(fn => fn(lang));
  }

  function applyLocalTranslations(dict) {
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.dataset.i18n;
      if (dict[key]) el.textContent = dict[key];
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
      const key = el.dataset.i18nPlaceholder;
      if (dict[key]) el.placeholder = dict[key];
    });
  }

  function get() { return _current; }

  function onChange(fn) { _listeners.push(fn); }

  return { renderSwitcher, set, get, onChange, LANGS };
})();


/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   4. MQHeatmap — Peak Hour Analytics Heatmap
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQHeatmap = (() => {
  const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const HOURS = Array.from({length: 24}, (_, i) => {
    if (i === 0) return '12a';
    if (i < 12) return `${i}a`;
    if (i === 12) return '12p';
    return `${i - 12}p`;
  });

  function getIntensityClass(value, max) {
    if (!value || value === 0) return 'heat-0';
    const pct = value / max;
    if (pct < 0.2) return 'heat-1';
    if (pct < 0.4) return 'heat-2';
    if (pct < 0.6) return 'heat-3';
    if (pct < 0.8) return 'heat-4';
    return 'heat-5';
  }

  /**
   * Render the heatmap into a container
   * @param {string} containerId - DOM element id
   * @param {Object} data - { day_hour: count } e.g. { "1_9": 45, "1_10": 72 }
   */
  function render(containerId, data = {}) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const maxVal = Math.max(1, ...Object.values(data));

    // Build grid: rows = days, cols = hours
    let html = `
      <div style="overflow-x:auto;">
        <div style="display:grid;grid-template-columns:40px repeat(24,minmax(28px,1fr));gap:3px;min-width:740px;">
          <!-- Header: hours -->
          <div></div>
          ${HOURS.map(h => `<div style="font-size:.65rem;color:#9ca3af;text-align:center;font-weight:500;">${h}</div>`).join('')}
    `;

    for (let d = 0; d < 7; d++) {
      html += `<div style="font-size:.7rem;color:#6b7280;font-weight:600;display:flex;align-items:center;">${DAYS[d]}</div>`;
      for (let h = 0; h < 24; h++) {
        const key = `${d}_${h}`;
        const val = data[key] || 0;
        const cls = getIntensityClass(val, maxVal);
        html += `
          <div class="mq-heatmap-cell ${cls}" 
               title="${DAYS[d]} ${HOURS[h]}: ${val} patients"
               data-val="${val}" data-day="${DAYS[d]}" data-hour="${HOURS[h]}">
          </div>`;
      }
    }

    html += `
        </div>
        <!-- Legend -->
        <div style="display:flex;align-items:center;gap:8px;margin-top:12px;justify-content:flex-end;">
          <span style="font-size:.75rem;color:#9ca3af;">Less</span>
          ${['heat-0','heat-1','heat-2','heat-3','heat-4','heat-5'].map(c =>
            `<div class="mq-heatmap-cell ${c}" style="width:18px;height:18px;flex-shrink:0;border-radius:3px;"></div>`
          ).join('')}
          <span style="font-size:.75rem;color:#9ca3af;">More</span>
        </div>
      </div>
    `;

    container.innerHTML = html;
  }

  /** Generate synthetic heatmap data from queue snapshot array */
  function fromQueueData(queueItems) {
    const data = {};
    (queueItems || []).forEach(item => {
      const date = item.joinedAt?.toDate ? item.joinedAt.toDate() : new Date(item.joinedAt);
      if (!date || isNaN(date)) return;
      const key = `${date.getDay()}_${date.getHours()}`;
      data[key] = (data[key] || 0) + 1;
    });
    return data;
  }

  return { render, fromQueueData };
})();


/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   5. MQVideoCall — Premium Telehealth Video Call Layer
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQVideoCall = (() => {
  let _state = {
    isOpen:    false,
    isMuted:   false,
    isVideoOff: false,
    isSpeaker:  true,
    duration:   0,
    timerInterval: null,
    callbackEnd: null,
  };

  function buildModal() {
    if (document.getElementById('mq-video-modal')) return;

    const modal = document.createElement('div');
    modal.id = 'mq-video-modal';
    modal.style.cssText = 'display:none;position:fixed;inset:0;z-index:9000;background:#0a0a0f;flex-direction:column;';
    modal.innerHTML = `
      <!-- Status bar -->
      <div style="position:absolute;top:0;left:0;right:0;z-index:10;padding:16px 20px;display:flex;align-items:center;justify-content:space-between;">
        <div style="display:flex;align-items:center;gap:10px;">
          <div style="width:10px;height:10px;background:#ef4444;border-radius:50%;animation:badge-pulse 1.5s ease-in-out infinite;"></div>
          <span id="mq-video-timer" style="color:white;font-weight:600;font-size:.9375rem;font-family:monospace;letter-spacing:.05em;">00:00</span>
        </div>
        <div id="mq-video-name" style="color:white;font-weight:600;font-size:.9375rem;"></div>
        <div style="width:80px;"></div>
      </div>

      <!-- Main video (remote) -->
      <div id="mq-remote-video" style="width:100%;height:100%;background:#111827;display:flex;align-items:center;justify-content:center;">
        <div style="text-align:center;color:white;opacity:0.5;">
          <div style="font-size:4rem;margin-bottom:12px;">👨‍⚕️</div>
          <div style="font-size:1rem;font-weight:500;">Connecting…</div>
        </div>
      </div>

      <!-- PIP (local video) -->
      <div class="video-pip" style="display:flex;align-items:center;justify-content:center;background:#1f2937;">
        <div id="mq-local-video" style="width:100%;height:100%;background:#374151;display:flex;align-items:center;justify-content:center;">
          <span style="font-size:2rem;">🤳</span>
        </div>
      </div>

      <!-- Controls -->
      <div class="video-controls">
        <button class="video-btn video-btn-default" id="mq-btn-mic" onclick="MQVideoCall.toggleMic()" title="Mute/Unmute">
          🎤
        </button>
        <button class="video-btn video-btn-default" id="mq-btn-camera" onclick="MQVideoCall.toggleCamera()" title="Camera On/Off">
          📷
        </button>
        <button class="video-btn video-btn-end" onclick="MQVideoCall.endCall()" title="End Call">
          📵
        </button>
        <button class="video-btn video-btn-default" id="mq-btn-speaker" onclick="MQVideoCall.toggleSpeaker()" title="Speaker">
          🔊
        </button>
        <button class="video-btn video-btn-default" onclick="MQVideoCall.openChat()" title="Chat">
          💬
        </button>
      </div>

      <!-- Incoming call overlay -->
      <div id="mq-incoming-overlay" style="display:none;position:absolute;inset:0;background:rgba(0,0,0,.7);backdrop-filter:blur(10px);z-index:20;flex-direction:column;align-items:center;justify-content:center;gap:24px;">
        <div style="text-align:center;color:white;">
          <div style="font-size:5rem;margin-bottom:12px;animation:bounceIn .5s ease;">👨‍⚕️</div>
          <div id="mq-caller-name" style="font-size:1.5rem;font-weight:700;margin-bottom:4px;">Doctor</div>
          <div style="opacity:0.7;font-size:.9375rem;">Incoming video call…</div>
        </div>
        <div style="display:flex;gap:32px;">
          <button onclick="MQVideoCall.rejectCall()" style="width:72px;height:72px;border-radius:50%;background:#ef4444;border:none;color:white;font-size:1.5rem;cursor:pointer;box-shadow:0 4px 20px rgba(239,68,68,0.5);">📵</button>
          <button onclick="MQVideoCall.acceptCall()" style="width:72px;height:72px;border-radius:50%;background:#22c55e;border:none;color:white;font-size:1.5rem;cursor:pointer;box-shadow:0 4px 20px rgba(34,197,94,0.5);">📞</button>
        </div>
      </div>
    `;
    document.body.appendChild(modal);
  }

  function startTimer() {
    _state.duration = 0;
    _state.timerInterval = setInterval(() => {
      _state.duration++;
      const m = String(Math.floor(_state.duration / 60)).padStart(2, '0');
      const s = String(_state.duration % 60).padStart(2, '0');
      const el = document.getElementById('mq-video-timer');
      if (el) el.textContent = `${m}:${s}`;
    }, 1000);
  }

  function stopTimer() {
    clearInterval(_state.timerInterval);
    _state.duration = 0;
    const el = document.getElementById('mq-video-timer');
    if (el) el.textContent = '00:00';
  }

  function open({ name = 'Doctor', onEnd } = {}) {
    buildModal();
    const modal = document.getElementById('mq-video-modal');
    const nameEl = document.getElementById('mq-video-name');
    if (nameEl) nameEl.textContent = `Dr. ${name}`;
    if (onEnd) _state.callbackEnd = onEnd;
    modal.style.display = 'flex';
    _state.isOpen = true;
    startTimer();
    // Lock orientation
    if (screen.orientation && screen.orientation.lock) {
      screen.orientation.lock('landscape').catch(() => {});
    }
  }

  function showIncoming({ callerName = 'Your Doctor', onAccept, onReject } = {}) {
    buildModal();
    const modal = document.getElementById('mq-video-modal');
    modal.style.display = 'flex';
    const overlay = document.getElementById('mq-incoming-overlay');
    overlay.style.display = 'flex';
    const callerEl = document.getElementById('mq-caller-name');
    if (callerEl) callerEl.textContent = callerName;
    _state._onAccept = onAccept;
    _state._onReject = onReject;
    // Ringtone
    if (window.Tone) {
      const synth = new Tone.Synth().toDestination();
      let ringing = true;
      const ringLoop = async () => {
        while (ringing) {
          synth.triggerAttackRelease('G4', '0.2');
          await new Promise(r => setTimeout(r, 300));
          synth.triggerAttackRelease('E4', '0.2');
          await new Promise(r => setTimeout(r, 700));
        }
      };
      ringLoop();
      _state._stopRing = () => { ringing = false; };
    }
  }

  function acceptCall() {
    const overlay = document.getElementById('mq-incoming-overlay');
    if (overlay) overlay.style.display = 'none';
    _state._stopRing && _state._stopRing();
    startTimer();
    _state._onAccept && _state._onAccept();
  }

  function rejectCall() {
    const modal = document.getElementById('mq-video-modal');
    if (modal) modal.style.display = 'none';
    _state._stopRing && _state._stopRing();
    _state._onReject && _state._onReject();
  }

  function endCall() {
    stopTimer();
    const modal = document.getElementById('mq-video-modal');
    if (modal) modal.style.display = 'none';
    _state.isOpen = false;
    if (screen.orientation && screen.orientation.unlock) {
      screen.orientation.unlock();
    }
    MQToast && MQToast.info(`Call ended · Duration: ${formatDuration(_state.duration)}`);
    _state.callbackEnd && _state.callbackEnd(_state.duration);
  }

  function formatDuration(secs) {
    const m = Math.floor(secs / 60), s = secs % 60;
    return `${m}m ${s}s`;
  }

  function toggleMic() {
    _state.isMuted = !_state.isMuted;
    const btn = document.getElementById('mq-btn-mic');
    if (btn) btn.textContent = _state.isMuted ? '🔇' : '🎤';
    if (btn) btn.style.background = _state.isMuted ? 'rgba(239,68,68,0.8)' : 'rgba(255,255,255,0.15)';
  }

  function toggleCamera() {
    _state.isVideoOff = !_state.isVideoOff;
    const btn = document.getElementById('mq-btn-camera');
    if (btn) btn.textContent = _state.isVideoOff ? '🚫' : '📷';
  }

  function toggleSpeaker() {
    _state.isSpeaker = !_state.isSpeaker;
    const btn = document.getElementById('mq-btn-speaker');
    if (btn) btn.textContent = _state.isSpeaker ? '🔊' : '📢';
  }

  function openChat() {
    MQToast && MQToast.info('Chat is available in the Chat tab.');
  }

  return { open, showIncoming, acceptCall, rejectCall, endCall, toggleMic, toggleCamera, toggleSpeaker, openChat };
})();


/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   6. MQConfetti — Celebration Animation
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQConfetti = (() => {
  const COLORS = ['#14b8a6','#6366f1','#f59e0b','#10b981','#f43f5e','#0ea5e9'];

  function burst(count = 60, duration = 3000) {
    const canvas = document.createElement('canvas');
    canvas.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;z-index:99999;pointer-events:none;';
    canvas.width  = window.innerWidth;
    canvas.height = window.innerHeight;
    document.body.appendChild(canvas);

    const ctx = canvas.getContext('2d');
    const particles = Array.from({length: count}, () => ({
      x: Math.random() * canvas.width,
      y: -10,
      vx: (Math.random() - 0.5) * 6,
      vy: Math.random() * 3 + 2,
      size: Math.random() * 8 + 4,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      rotation: Math.random() * 360,
      rotVel: (Math.random() - 0.5) * 8,
      shape: Math.random() > 0.5 ? 'rect' : 'circle',
    }));

    let frame;
    const startTime = Date.now();

    function draw() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const elapsed = Date.now() - startTime;
      const progress = elapsed / duration;

      for (const p of particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.1; // gravity
        p.rotation += p.rotVel;
        ctx.save();
        ctx.globalAlpha = Math.max(0, 1 - progress);
        ctx.translate(p.x, p.y);
        ctx.rotate((p.rotation * Math.PI) / 180);
        ctx.fillStyle = p.color;
        if (p.shape === 'circle') {
          ctx.beginPath();
          ctx.arc(0, 0, p.size / 2, 0, Math.PI * 2);
          ctx.fill();
        } else {
          ctx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
        }
        ctx.restore();
      }

      if (elapsed < duration) {
        frame = requestAnimationFrame(draw);
      } else {
        canvas.remove();
      }
    }

    draw();
    setTimeout(() => { cancelAnimationFrame(frame); canvas.remove(); }, duration + 200);
  }

  return { burst };
})();


/* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   7. MQUtils — Shared Utility Functions
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ */

window.MQUtils = {
  /** Format timestamp to "2 mins ago" */
  timeAgo(ts) {
    const date = ts?.toDate ? ts.toDate() : new Date(ts);
    const diff = Math.floor((Date.now() - date) / 1000);
    if (diff < 60)     return 'Just now';
    if (diff < 3600)   return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400)  return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  },

  /** Get initials from full name */
  initials(name = '') {
    return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2) || '?';
  },

  /** Debounce utility */
  debounce(fn, ms = 300) {
    let timer;
    return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), ms); };
  },

  /** Vibrate device (for notifications) */
  vibrate(pattern = [200]) {
    if (navigator.vibrate) navigator.vibrate(pattern);
  },

  /** Format currency (INR) */
  formatINR(amount) {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(amount || 0);
  },

  /** Check if device is mobile */
  isMobile() {
    return window.innerWidth < 768;
  },

  /** Copy text to clipboard with toast */
  async copyToClipboard(text, label = 'Text') {
    try {
      await navigator.clipboard.writeText(text);
      MQToast.success(`${label} copied!`, null, 2000);
    } catch {
      MQToast.error('Could not copy to clipboard.');
    }
  },

  /** Get confidence badge HTML */
  confidenceBadge(level) {
    const map = {
      high:     { cls: 'badge-success', label: '🎯 High Confidence' },
      medium:   { cls: 'badge-warning', label: '📊 Medium Confidence' },
      low:      { cls: 'badge-danger',  label: '⚠️ Low Confidence' },
      fallback: { cls: 'badge-gray',    label: '📐 Estimated' },
    };
    const { cls, label } = map[level] || map.fallback;
    return `<span class="mq-badge ${cls}">${label}</span>`;
  },
};

// ─── Auto-init language from localStorage ───────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  const savedLang = localStorage.getItem('mq-lang');
  if (savedLang && savedLang !== 'en') {
    MQLang.set(savedLang);
  }
});

console.log('[MediQue Components v3.0] Loaded: MQToast, MQChatbot, MQLang, MQHeatmap, MQVideoCall, MQConfetti, MQUtils');
