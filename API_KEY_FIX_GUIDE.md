# API Error 404 Fix Guide - Plastic Page

## Problem

The plastic waste detection page shows **"API Error: 404. Check your API key."** when trying to analyze items.

## Root Cause

The hardcoded Gemini API key has been **disabled** because it was publicly exposed in the source code.

## Solution

### Step 1: Get Your Own Gemini API Key

1. Visit: https://aistudio.google.com/apikey
2. Sign in with your Google account
3. Click **"Create API Key"**
4. Copy the newly generated key

### Step 2: Update the Configuration

1. Open: `lib/core/gemini_config.dart`
2. Replace the old key with your new key:
   ```dart
   static const String apiKey = 'YOUR_NEW_API_KEY_HERE';
   ```

### Step 3: Security Best Practice

⚠️ **IMPORTANT**: Never commit your real API key to version control!

Add to `.gitignore`:

```
lib/core/gemini_config.dart
```

Or use environment variables instead (recommended for production).

### Step 4: Test the Fix

1. Restart the app
2. Go to "Add Plastic Waste"
3. Take a photo to test the AI detection

## Changes Made

✅ Updated plastic screen to use centralized `GeminiConfig`
✅ Changed model from `gemini-1.5-flash` to `gemini-2.5-flash-preview-09-2025` (more stable)
✅ Added detailed error messages for different API error codes:

- **404**: Invalid API key or endpoint
- **401**: Unauthorized
- **429**: Rate limit exceeded

## Error Messages

The app now shows helpful messages instead of generic "API Error":

- **404**: "Invalid API key or endpoint. Please update your Gemini API key."
- **401**: "Unauthorized. Check your API key validity."
- **429**: "Rate limit exceeded. Try again later."

## Troubleshooting

| Issue                                       | Solution                                                    |
| ------------------------------------------- | ----------------------------------------------------------- |
| Still getting 404                           | Verify the API key is correct and enabled in Google Console |
| Getting 401                                 | Check that the API key has Generative Language API enabled  |
| Getting 429                                 | Wait a few minutes before trying again (rate limit)         |
| No error, but stuck on "AI is analyzing..." | Check your internet connection                              |

## Model Specifications

- **Model**: `gemini-2.5-flash-preview-09-2025`
- **API Version**: v1beta
- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/[MODEL]:generateContent`
- **Authentication**: API Key in URL query parameter
