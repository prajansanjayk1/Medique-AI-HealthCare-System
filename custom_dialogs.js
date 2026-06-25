/**
 * MediQue Unified Custom Dialogs & Toast Notifications
 * Intercepts window.alert and provides asynchronous showConfirm/showAlert systems.
 * Styled with modern glassmorphism (frosted blurs, smooth animations, micro-interactions).
 */

(function() {
    // 1. DYNAMIC CSS STYLING INJECTION
    const styleEl = document.createElement('style');
    styleEl.textContent = `
        /* Custom Toast Styles */
        .custom-toast-container {
            position: fixed;
            top: 24px;
            right: 24px;
            z-index: 999999;
            display: flex;
            flex-direction: column;
            gap: 12px;
            max-width: 380px;
            width: calc(100% - 48px);
            pointer-events: none;
        }
        .custom-toast {
            background: rgba(255, 255, 255, 0.85);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.4);
            border-radius: 20px;
            padding: 16px;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.05), 0 10px 10px -5px rgba(0, 0, 0, 0.03);
            display: flex;
            align-items: flex-start;
            gap: 14px;
            pointer-events: auto;
            cursor: pointer;
            transform: translateX(120%);
            opacity: 0;
            transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.4s ease;
        }
        .custom-toast.active {
            transform: translateX(0);
            opacity: 1;
        }
        .custom-toast.exit {
            transform: translateY(-20px) scale(0.9);
            opacity: 0;
            transition: transform 0.3s ease, opacity 0.3s ease;
        }
        .custom-toast-icon {
            flex-shrink: 0;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .custom-toast-body {
            flex-grow: 1;
            padding-top: 1px;
        }
        .custom-toast-title {
            font-size: 14px;
            font-weight: 700;
            color: #0f172a;
            margin-bottom: 2px;
            line-height: 1.25;
        }
        .custom-toast-message {
            font-size: 13px;
            color: #475569;
            font-weight: 500;
            line-height: 1.4;
        }
        
        /* Custom Modal Styles */
        .custom-modal-overlay {
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.3);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            z-index: 999998;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .custom-modal-overlay.active {
            opacity: 1;
            pointer-events: auto;
        }
        .custom-modal-card {
            background: rgba(255, 255, 255, 0.9);
            backdrop-filter: blur(24px);
            -webkit-backdrop-filter: blur(24px);
            border: 1px solid rgba(255, 255, 255, 0.6);
            border-radius: 32px;
            padding: 28px;
            width: 100%;
            max-width: 440px;
            box-shadow: 0 25px 50px -12px rgba(15, 23, 42, 0.15);
            transform: scale(0.92) translateY(10px);
            opacity: 0;
            transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.4s ease;
        }
        .custom-modal-overlay.active .custom-modal-card {
            transform: scale(1) translateY(0);
            opacity: 1;
        }
        .custom-modal-header {
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 16px;
        }
        .custom-modal-title {
            font-size: 20px;
            font-weight: 800;
            color: #0f172a;
            line-height: 1.2;
        }
        .custom-modal-desc {
            font-size: 14px;
            color: #475569;
            font-weight: 500;
            line-height: 1.5;
            margin-bottom: 24px;
        }
        .custom-modal-footer {
            display: flex;
            justify-content: flex-end;
            gap: 12px;
        }
        .custom-modal-btn {
            padding: 12px 20px;
            font-size: 14px;
            font-weight: 700;
            border-radius: 14px;
            transition: all 0.2s ease;
            cursor: pointer;
            outline: none;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            border: 1px solid transparent;
            min-height: 44px;
        }
        .custom-modal-btn-cancel {
            background: #f1f5f9;
            color: #475569;
            border: 1px solid #e2e8f0;
        }
        .custom-modal-btn-cancel:hover {
            background: #e2e8f0;
            color: #1e293b;
        }
        .custom-modal-btn-confirm {
            background: #4f46e5;
            color: white;
            box-shadow: 0 10px 15px -3px rgba(79, 70, 229, 0.2);
        }
        .custom-modal-btn-confirm:hover {
            background: #4338ca;
            transform: translateY(-1px);
            box-shadow: 0 10px 15px -3px rgba(79, 70, 229, 0.3);
        }
        .custom-modal-btn-confirm:active {
            transform: translateY(0);
        }
        .custom-modal-btn-danger {
            background: #f43f5e;
            color: white;
            box-shadow: 0 10px 15px -3px rgba(244, 63, 94, 0.2);
        }
        .custom-modal-btn-danger:hover {
            background: #e11d48;
            transform: translateY(-1px);
            box-shadow: 0 10px 15px -3px rgba(244, 63, 94, 0.3);
        }
        .custom-modal-btn-danger:active {
            transform: translateY(0);
        }

        /* Responsive adaptation */
        @media (max-width: 480px) {
            .custom-toast-container {
                top: 16px;
                right: 16px;
                width: calc(100% - 32px);
            }
            .custom-modal-card {
                padding: 20px;
                border-radius: 24px;
            }
            .custom-modal-footer {
                flex-direction: column-reverse;
                gap: 8px;
            }
            .custom-modal-btn {
                width: 100%;
            }
        }

        /* Ripple effect CSS */
        .ripple-btn {
            position: relative !important;
            overflow: hidden !important;
        }
        .ripple-effect {
            position: absolute;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.35);
            transform: scale(0);
            animation: ripple 0.5s ease-out;
            pointer-events: none;
        }
        @keyframes ripple {
            to {
                transform: scale(4);
                opacity: 0;
            }
        }
        
        /* Persistent Update Toast Styles */
        .custom-toast-update {
            border-left: 4px solid #4f46e5 !important;
            background: rgba(238, 242, 255, 0.95) !important;
            cursor: default !important;
        }
        .update-action-btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            background: #4f46e5;
            color: white;
            font-size: 11px;
            font-weight: 700;
            padding: 6px 12px;
            border-radius: 8px;
            margin-top: 8px;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 6px -1px rgba(79, 70, 229, 0.2);
            transition: all 0.2s ease;
        }
        .update-action-btn:hover {
            background: #4338ca;
            transform: translateY(-1px);
        }
    `;
    document.head.appendChild(styleEl);

    // 2. CREATE AND INJECT CONTAINER ELEMENTS
    let toastContainer;
    let confirmOverlay;

    function ensureContainers() {
        if (!toastContainer) {
            toastContainer = document.getElementById('custom-toast-container');
            if (!toastContainer) {
                toastContainer = document.createElement('div');
                toastContainer.id = 'custom-toast-container';
                toastContainer.className = 'custom-toast-container';
                document.body.appendChild(toastContainer);
            }
        }

        if (!confirmOverlay) {
            confirmOverlay = document.getElementById('custom-confirm-modal');
            if (!confirmOverlay) {
                confirmOverlay = document.createElement('div');
                confirmOverlay.id = 'custom-confirm-modal';
                confirmOverlay.className = 'custom-modal-overlay';
                confirmOverlay.innerHTML = `
                    <div class="custom-modal-card" id="custom-modal-card" role="dialog" aria-modal="true">
                        <div class="custom-modal-header">
                            <div id="custom-modal-icon-container"></div>
                            <h3 class="custom-modal-title" id="custom-modal-title">Confirm Action</h3>
                        </div>
                        <p class="custom-modal-desc" id="custom-modal-desc">Are you sure you want to proceed?</p>
                        <div class="custom-modal-footer">
                            <button type="button" class="custom-modal-btn custom-modal-btn-cancel" id="custom-modal-btn-cancel">Cancel</button>
                            <button type="button" class="custom-modal-btn custom-modal-btn-confirm" id="custom-modal-btn-confirm">Confirm</button>
                        </div>
                    </div>
                `;
                document.body.appendChild(confirmOverlay);
            }
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', ensureContainers);
    } else {
        ensureContainers();
    }

    // 3. TOAST NOTIFICATION FUNCTION
    window.showToast = function(message, type = 'info', duration = 4000) {
        ensureContainers();
        
        const toast = document.createElement('div');
        toast.className = 'custom-toast';
        
        let colorClasses = '';
        let iconSvg = '';
        let titleText = 'Notice';

        switch (type) {
            case 'success':
                colorClasses = 'border-l-4 border-emerald-500';
                titleText = 'Success';
                iconSvg = `<svg class="w-5 h-5 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"></path></svg>`;
                break;
            case 'error':
                colorClasses = 'border-l-4 border-rose-500';
                titleText = 'Error';
                iconSvg = `<svg class="w-5 h-5 text-rose-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12"></path></svg>`;
                break;
            case 'warning':
                colorClasses = 'border-l-4 border-amber-500';
                titleText = 'Warning';
                iconSvg = `<svg class="w-5 h-5 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>`;
                break;
            case 'info':
            default:
                colorClasses = 'border-l-4 border-indigo-500';
                titleText = 'Information';
                iconSvg = `<svg class="w-5 h-5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`;
                break;
        }

        toast.className = `custom-toast ${colorClasses}`;
        toast.innerHTML = `
            <div class="custom-toast-icon">${iconSvg}</div>
            <div class="custom-toast-body">
                <div class="custom-toast-title">${titleText}</div>
                <div class="custom-toast-message">${message}</div>
            </div>
        `;

        toastContainer.appendChild(toast);
        
        // Trigger entry animation
        setTimeout(() => toast.classList.add('active'), 50);

        // Auto close handler
        let autoCloseTimeout = setTimeout(() => {
            closeToast(toast);
        }, duration);

        // Click to close
        toast.addEventListener('click', () => {
            clearTimeout(autoCloseTimeout);
            closeToast(toast);
        });
    };

    function closeToast(toast) {
        toast.classList.remove('active');
        toast.classList.add('exit');
        setTimeout(() => toast.remove(), 400);
    }

    // 4. CUSTOM CONFIRM MODAL FUNCTION (PROMISE-BASED)
    window.showConfirm = function(title, message, confirmText = 'Confirm', cancelText = 'Cancel', danger = false) {
        ensureContainers();
        return new Promise((resolve) => {
            const titleEl = document.getElementById('custom-modal-title');
            const descEl = document.getElementById('custom-modal-desc');
            const btnCancel = document.getElementById('custom-modal-btn-cancel');
            const btnConfirm = document.getElementById('custom-modal-btn-confirm');
            const iconContainer = document.getElementById('custom-modal-icon-container');

            titleEl.textContent = title;
            descEl.textContent = message;
            btnCancel.textContent = cancelText;
            btnConfirm.textContent = confirmText;

            // Apply style depending on action severity (Danger vs Normal)
            if (danger) {
                btnConfirm.className = 'custom-modal-btn custom-modal-btn-danger';
                iconContainer.className = 'w-10 h-10 rounded-full bg-rose-100 flex items-center justify-center';
                iconContainer.innerHTML = `<svg class="w-6 h-6 text-rose-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>`;
            } else {
                btnConfirm.className = 'custom-modal-btn custom-modal-btn-confirm';
                iconContainer.className = 'w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center';
                iconContainer.innerHTML = `<svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`;
            }

            confirmOverlay.classList.add('active');
            
            // Focus confirm button for accessibility
            btnConfirm.focus();

            const cleanup = (result) => {
                confirmOverlay.classList.remove('active');
                
                // Remove temporary event listeners
                btnConfirm.removeEventListener('click', onConfirm);
                btnCancel.removeEventListener('click', onCancel);
                document.removeEventListener('keydown', onKeyDown);
                confirmOverlay.removeEventListener('click', onOverlayClick);
                
                resolve(result);
            };

            const onConfirm = () => cleanup(true);
            const onCancel = () => cleanup(false);

            const onKeyDown = (e) => {
                if (e.key === 'Escape') {
                    cleanup(false);
                } else if (e.key === 'Enter' && document.activeElement !== btnCancel) {
                    cleanup(true);
                }
            };

            const onOverlayClick = (e) => {
                if (e.target === confirmOverlay) {
                    cleanup(false);
                }
            };

            btnConfirm.addEventListener('click', onConfirm);
            btnCancel.addEventListener('click', onCancel);
            document.addEventListener('keydown', onKeyDown);
            confirmOverlay.addEventListener('click', onOverlayClick);
        });
    };

    // 5. CUSTOM ALERT MODAL FUNCTION
    window.showAlert = function(title, message, buttonText = 'OK') {
        ensureContainers();
        return new Promise((resolve) => {
            const titleEl = document.getElementById('custom-modal-title');
            const descEl = document.getElementById('custom-modal-desc');
            const btnCancel = document.getElementById('custom-modal-btn-cancel');
            const btnConfirm = document.getElementById('custom-modal-btn-confirm');
            const iconContainer = document.getElementById('custom-modal-icon-container');

            titleEl.textContent = title;
            descEl.textContent = message;
            btnConfirm.textContent = buttonText;

            // Hide cancel button
            btnCancel.style.display = 'none';

            btnConfirm.className = 'custom-modal-btn custom-modal-btn-confirm w-full';
            iconContainer.className = 'w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center';
            iconContainer.innerHTML = `<svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>`;

            confirmOverlay.classList.add('active');
            btnConfirm.focus();

            const cleanup = () => {
                confirmOverlay.classList.remove('active');
                
                // Restore cancel button state
                btnCancel.style.display = 'block';

                btnConfirm.removeEventListener('click', onConfirm);
                document.removeEventListener('keydown', onKeyDown);
                confirmOverlay.removeEventListener('click', onOverlayClick);
                
                resolve();
            };

            const onConfirm = () => cleanup();

            const onKeyDown = (e) => {
                if (e.key === 'Escape' || e.key === 'Enter') {
                    cleanup();
                }
            };

            const onOverlayClick = (e) => {
                if (e.target === confirmOverlay) {
                    cleanup();
                }
            };

            btnConfirm.addEventListener('click', onConfirm);
            document.addEventListener('keydown', onKeyDown);
            confirmOverlay.addEventListener('click', onOverlayClick);
        });
    };

    // 6. MONKEY PATCH WINDOW.ALERT
    const nativeAlert = window.alert;
    window.alert = function(message) {
        if (!message) return;
        
        // Intelligent text matching to determine severity/color
        const msgLower = message.toLowerCase();
        let type = 'info';

        if (msgLower.includes('success') || msgLower.includes('confirmed') || msgLower.includes('paid') || 
            msgLower.includes('created') || msgLower.includes('added') || msgLower.includes('saved') || 
            msgLower.includes('updated') || msgLower.includes('enabled') || msgLower.includes('copied')) {
            type = 'success';
        } else if (msgLower.includes('error') || msgLower.includes('failed') || msgLower.includes('invalid') || 
                   msgLower.includes('wrong') || msgLower.includes('disabled') || msgLower.includes('denied') || 
                   msgLower.includes('missing')) {
            type = 'error';
        } else if (msgLower.includes('warning') || msgLower.includes('alert') || msgLower.includes('caution') || 
                   msgLower.includes('lockout') || msgLower.includes('cooldown') || msgLower.includes('limit')) {
            type = 'warning';
        }

        window.showToast(message, type);
        
        // Log to console for debugging
        console.log(`[Custom UI Intercepted Alert] (${type}): ${message}`);
    };

    // 7. GLOBAL RIPPLE EFFECT LISTENER
    document.addEventListener('mousedown', function (e) {
        const target = e.target.closest('.ripple-btn') || (e.target.tagName === 'BUTTON' && e.target && !e.target.classList.contains('no-ripple'));
        if (!target) return;
        
        // Ensure relative positioning
        if (window.getComputedStyle(target).position === 'static') {
            target.style.position = 'relative';
        }
        
        const rect = target.getBoundingClientRect();
        const ripple = document.createElement('span');
        ripple.className = 'ripple-effect';
        
        const size = Math.max(rect.width, rect.height);
        ripple.style.width = ripple.style.height = `${size}px`;
        
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;
        ripple.style.left = `${x}px`;
        ripple.style.top = `${y}px`;
        
        target.appendChild(ripple);
        ripple.addEventListener('animationend', () => {
            ripple.remove();
        });
    });

    // 8. PWA AUTO-UPDATE PERSISTENT TOAST
    window.showUpdateToast = function(onConfirm) {
        ensureContainers();
        
        // Check if update toast already exists
        if (document.getElementById('custom-toast-update-banner')) return;
        
        const toast = document.createElement('div');
        toast.id = 'custom-toast-update-banner';
        toast.className = 'custom-toast custom-toast-update';
        
        const iconSvg = `<svg class="w-5 h-5 text-indigo-600 animate-bounce" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>`;
        
        toast.innerHTML = `
            <div class="custom-toast-icon">${iconSvg}</div>
            <div class="custom-toast-body" style="pointer-events: auto;">
                <div class="custom-toast-title" style="color: #4f46e5;">Update Available</div>
                <div class="custom-toast-message">A new version of MediQue is ready. Click below to refresh.</div>
                <button type="button" class="update-action-btn ripple-btn" id="update-toast-reload-btn">Update Now</button>
            </div>
        `;
        
        toastContainer.appendChild(toast);
        
        // Trigger entry animation
        setTimeout(() => toast.classList.add('active'), 50);
        
        const reloadBtn = toast.querySelector('#update-toast-reload-btn');
        reloadBtn.addEventListener('click', () => {
            if (typeof onConfirm === 'function') {
                onConfirm();
            } else {
                window.location.reload();
            }
        });
    };
})();
