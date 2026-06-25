// MediQue Central API Configuration
// REPLACE THESE PLACEHOLDERS WITH YOUR ACTUAL KEYS

var MediQueConfig = {
    // 1. Google Maps Platform (Maps JS, Places, Distance Matrix)
    // Get key: https://console.cloud.google.com/
    googleMapsKey: "AIzaSyA3MvdscSg6bBwn-6PWLTF-7OJ24p6UFfI",

    // 2. Gemini AI (Generative Language API)
    // Get key: https://aistudio.google.com/
    geminiKey: "AIzaSyCrXN6thqdpYHkfp5pTAwNWyqnIo3J7ZJQ",

    // 3. Firebase Cloud Messaging (Web Push)
    // Get key: Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
    fcmVapidKey: "HGLRzWGEVwE3qzYRCPts1UEpeliGoDzq5S4EgXtoYts",

    // 4. Google One Tap Sign-in (Client ID)
    // Get key: Google Cloud Console > APIs & Services > Credentials > OAuth 2.0 Client IDs
    oneTapClientId: "875358715704-gaivoe52gkqmk4s8mtfbrq7hhbqnu746.apps.googleusercontent.com"
};

// Config Validation Helper
function checkConfig(keyName) {
    if (!MediQueConfig[keyName] || MediQueConfig[keyName].includes('YOUR_')) {
        console.warn(`[MediQue Config] Missing configuration for: ${keyName}`);
        return false;
    }
    return true;
}
