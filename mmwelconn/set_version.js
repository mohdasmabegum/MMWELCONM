const { execSync } = require('child_process');
const https = require('https');

// Get access token from Firebase CLI
let token;
try {
  token = execSync('firebase --token "" login:ci 2>nul', { stdio: 'pipe' }).toString().trim();
} catch (_) {}

// Simpler: use the REST API with the CLI token from ~/.config/configstore/firebase-tools.json
const os = require('os');
const path = require('path');
const fs = require('fs');

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
let accessToken;
try {
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  accessToken = config.tokens?.access_token;
} catch(e) {
  console.error('Could not read firebase config:', e.message);
  process.exit(1);
}

if (!accessToken) {
  console.error('No access token found');
  process.exit(1);
}

const projectId = 'mm-welconn';
const docPath = 'app_config/version';
const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${docPath}`;

const body = JSON.stringify({
  fields: {
    latest: { stringValue: '1.3.0' },
    releaseDate: { stringValue: new Date().toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) },
    releaseNotes: { stringValue: '- Added Schedules & Event Reminders directly from chats\n- Integrated full-screen alert dialogs with Snooze/Complete options\n- Added multi-message selection and bulk message deletion\n- Added direct image sharing externally using native share sheets\n- Added per-chat online status privacy disclosures' }
  }
});

const options = {
  method: 'PATCH',
  headers: {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  }
};

const req = https.request(url, options, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    if (res.statusCode === 200) {
      console.log('app_config/version updated to 1.3.0 ✓');
    } else {
      console.error(`HTTP ${res.statusCode}: ${data}`);
      process.exit(1);
    }
  });
});
req.on('error', e => { console.error(e.message); process.exit(1); });
req.write(body);
req.end();
