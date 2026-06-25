/**
 * MEDIQUE FREE OTP BACKEND SERVICE (GOOGLE APPS SCRIPT)
 * 
 * INSTRUCTIONS FOR DEPLOYMENT:
 * -------------------------------------------------------------
 * 1. Open Google Chrome and navigate to: https://script.google.com/
 * 2. Click "New Project" in the top left.
 * 3. Delete any boilerplate code inside the editor and paste this entire file's code.
 * 4. Click the Rename title text at the top and name it: "MediQue OTP Service".
 * 5. Click the "Save" icon (or press Ctrl + S).
 * 6. Click "Deploy" (blue button in top-right) -> Select "New deployment".
 * 7. Click the gear icon next to "Select type" and choose "Web app".
 * 8. Configure the web app settings:
 *    - Description: "MediQue OTP Web App Service"
 *    - Execute as: "Me (your-gmail-address@gmail.com)"  <-- IMPORTANT: This allows sending mail from your inbox
 *    - Who has access: "Anyone"                          <-- IMPORTANT: This allows web/mobile client apps to access it
 * 9. Click "Deploy".
 * 10. A popup will ask you to "Authorize Access". Click "Authorize access", choose your Google Account.
 * 11. Since it's a personal script, Google might show an "Advanced/Unverified App" warning. 
 *     Click "Advanced" in the bottom-left, then click "Go to MediQue OTP Service (unsafe)".
 * 12. Click "Allow" to grant permission for sending emails.
 * 13. Copy the "Web app URL" displayed (e.g., https://script.google.com/macros/s/AKfy.../exec).
 * 14. Paste this copied Web App URL inside your client code:
 *     - Web app: In "index.html" -> search for "const scriptUrl = "";" (around line 223) and paste it.
 *     - Mobile app: In "mediqueue_flutter/lib/features/auth/otp_screen.dart" -> search for "static const String _googleAppsScriptUrl = "";" (around line 28) and paste it.
 * 15. Redeploy your web app to Firebase and build/run your mobile APK.
 * -------------------------------------------------------------
 */

function doPost(e) {
  try {
    // Parse incoming JSON data
    var requestData = JSON.parse(e.postData.contents);
    var action = requestData.action;
    var email = requestData.email;
    
    if (!email) {
      return respondJson({ success: false, error: "Email is required" });
    }
    
    email = email.trim().toLowerCase();
    var cache = CacheService.getScriptCache();
    
    // ACTION: Send OTP Email
    if (action === "sendOtp") {
      // 1. Generate random 6-digit OTP code
      var otp = "";
      for (var i = 0; i < 6; i++) {
        otp += Math.floor(Math.random() * 10);
      }
      
      // 2. Store OTP in script cache (expires in 10 minutes = 600 seconds)
      // Cache key includes email address to prevent concurrency clashes
      cache.put("otp_" + email, otp, 600);
      
      // 3. Send Email using GmailApp
      var subject = "Your MediQue 2FA Code";
      
      // Premium HTML Email Template
      var htmlBody = `
      <div style="font-family: 'Inter', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f8fafc; padding: 40px 20px; border-radius: 12px;">
        <div style="background-color: #ffffff; padding: 40px; border-radius: 16px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03); text-align: center;">
          <h1 style="color: #4f46e5; margin-bottom: 8px; font-size: 28px; font-weight: 800; letter-spacing: -0.5px;">MediQue</h1>
          <p style="color: #64748b; font-size: 16px; margin-bottom: 32px;">Secure Account Verification</p>
          
          <div style="margin: 32px 0; padding: 24px; background-color: #f1f5f9; border-radius: 12px; border: 1px solid #e2e8f0;">
            <p style="color: #334155; font-size: 14px; margin-bottom: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px;">Your Verification Code</p>
            <div style="font-size: 42px; font-weight: 900; color: #1e293b; letter-spacing: 8px; margin: 0;">${otp}</div>
          </div>
          
          <p style="color: #475569; font-size: 15px; line-height: 1.6; margin-bottom: 24px;">
            Please enter this code on the verification screen to securely log into your account. This code is valid for the next 10 minutes.
          </p>
          
          <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
          
          <p style="color: #94a3b8; font-size: 12px; line-height: 1.5; margin: 0;">
            If you didn't request this code, you can safely ignore this email. Someone might have mistyped their email address.<br><br>
            &copy; ${new Date().getFullYear()} MediQue Health Systems. All rights reserved.
          </p>
        </div>
      </div>
      `;
                 
      MailApp.sendEmail({
        to: email,
        subject: subject,
        htmlBody: htmlBody,
        name: "MediQue Security"
      });
      
      return respondJson({ success: true, message: "OTP email sent successfully" });
      
    } 
    // ACTION: Verify OTP Code
    else if (action === "verifyOtp") {
      var userOtp = requestData.otp;
      if (!userOtp) {
        return respondJson({ success: false, error: "OTP code is required" });
      }
      
      // Retrieve cached code
      var cachedOtp = cache.get("otp_" + email);
      if (!cachedOtp) {
        return respondJson({ success: false, error: "OTP code has expired or was not requested. Please request a new one." });
      }
      
      // Compare codes
      if (cachedOtp === userOtp.trim()) {
        cache.remove("otp_" + email); // Clean up cache upon successful verification
        return respondJson({ success: true, message: "OTP code verified successfully" });
      } else {
        return respondJson({ success: false, error: "Invalid OTP code. Please check and try again." });
      }
    } 
    // ACTION: Unknown
    else {
      return respondJson({ success: false, error: "Unknown request action: " + action });
    }
    
  } catch (error) {
    return respondJson({ success: false, error: "Server Error: " + error.toString() });
  }
}

// Return JSON response with CORS headers
function respondJson(data) {
  var output = ContentService.createTextOutput(JSON.stringify(data));
  output.setMimeType(ContentService.MimeType.JSON);
  return output;
}

// Handle CORS preflight (OPTIONS)
function doOptions(e) {
  var output = ContentService.createTextOutput("");
  output.setMimeType(ContentService.MimeType.TEXT);
  return output;
}
