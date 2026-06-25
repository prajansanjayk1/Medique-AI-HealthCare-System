# Zero-Cost SMS Queue Setup Guide

This guide will help you set up an automated SMS queue system using **Google Apps Script** (Server) and **MacroDroid** on your Android phone (Gateway).

**Note:** We are using **MacroDroid** because it is free and supports Webhooks without a subscription.

## Prerequisites
1.  A Google Account.
2.  An Android Phone with SIM card.
3.  **MacroDroid App** installed on the phone (Free version is sufficient).

---

## Step 1: Get Firebase Credentials
We need to let Google Script talk to your database.
1.  Go to [Firebase Console](https://console.firebase.google.com).
2.  Open your project > **Project Settings** (Gear icon) > **Service accounts**.
3.  Click **Generate new private key**.
4.  This will download a `.json` file. Open it with a text editor. You will need:
    - `client_email`
    - `private_key`
    - `project_id`

## Step 2: Set up Google Apps Script (The Brain)
1.  Go to [script.google.com](https://script.google.com) and click **New Project**.
2.  **Add Library**:
    - Click "+" next to **Libraries** on the left.
    - Paste this ID: `1VUSl4b1r1eoNcRWotZM3e87ygkxvXltOgyDZhixqncz9lQ3MjfT1iKFw`
    - Click **Look up** -> **Add**.
3.  **Paste Code**:
    - Delete everything in `Code.gs`.
    - Open `google_apps_script.js` from this folder.
    - Copy all the code and paste it into `Code.gs`.
4.  **Configure**:
    - Replace `YOUR_FIREBASE_SERVICE_ACCOUNT_EMAIL` with the `client_email` from Step 1.
    - Replace `YOUR_PRIVATE_KEY_HERE` with the `private_key` from Step 1.
    - Replace `YOUR_PROJECT_ID` with `project_id`.
    - **Important**: Search for `medique_app_id_placeholder` in the code and replace it with your actual App ID (found in `doctor.html` near `const appId = ...`).
5.  **Deploy**:
    - Click **Deploy** (Blue button) > **New deployment**.
    - Select type: **Web app**.
    - Description: "SMS Hook".
    - Execute as: **Me**.
    - Who has access: **Anyone** (This is important for MacroDroid to reach it).
    - Click **Deploy**.
    - **Copy the Web app URL**. (It looks like `https://script.google.com/macros/s/.../exec`).

## Step 3: Set up MacroDroid (The Gateway)
1.  Open **MacroDroid** on your Android Phone.
2.  Tap **Add Macro**.
3.  **Triggers (+)**:
    - Select **Call/SMS** -> **SMS Received**.
    - Select **Any Number** (or specific number if you prefer).
    - Content: **Any Content**. (You can filter for specific words like "Queue" later if you want).
4.  **Actions (+)**:
    - **Best Method**: Tap the **Search Icon** (🔍) at the top and type "HTTP".
    - Select **HTTP Request**.
        - **URL**: Paste your Google Script Web App URL.
        - **Method**: POST.
        - **Content Type**: Start typing and select `application/json`.
        - **Body**: 
          ```json
          {"phone":"[sms_number]", "message":"[sms_message]"}
          ```
          *(Note: Use the helper button `...` to select the exact variables for SMS Number and SMS Message if they differ).*
5.  **Save Macro**:
    - Give it a name like "Auto Queue".
    - Save it.

## Step 4: Test It
1.  Send an SMS to your Android phone from another number.
2.  Wait 5-10 seconds.
3.  Check your **Doctor Dashboard Queue**. The new patient should appear!
