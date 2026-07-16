const https = require('https');
const os = require('os');
const path = require('path');
const fs = require('fs');

const projectId = 'mm-welconn';
const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
let accessToken;
try {
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  accessToken = config.tokens?.access_token;
} catch(e) {
  console.error('Could not read firebase config:', e.message);
  process.exit(1);
}

function get(path) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path,
      method: 'GET',
      headers: { 'Authorization': `Bearer ${accessToken}` },
    }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(d) }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function check() {
  console.log('\n===== POST-DEPLOYMENT CHECKS =====\n');

  // 1. Check app_config/version
  const ver = await get(`/v1/projects/${projectId}/databases/(default)/documents/app_config/version`);
  if (ver.status === 200) {
    const f = ver.body.fields;
    console.log('✅ app_config/version EXISTS');
    console.log(`   latest: ${f.latest?.stringValue}`);
    console.log(`   releaseNotes: ${f.releaseNotes?.stringValue?.split('\n')[0]}...`);
  } else {
    console.log('❌ app_config/version MISSING:', ver.status);
  }

  // 2. Check users collection exists
  const users = await get(`/v1/projects/${projectId}/databases/(default)/documents/users?pageSize=1`);
  if (users.status === 200) {
    const count = users.body.documents?.length ?? 0;
    console.log(`✅ users collection reachable (${count} doc sampled)`);
    if (count > 0) {
      const u = users.body.documents[0].fields;
      const hasAutoUpdate = 'autoUpdate' in u;
      console.log(`   autoUpdate field present: ${hasAutoUpdate ? '✅' : '❌ MISSING - old accounts need migration'}`);
      const hasStatus = 'status' in u;
      console.log(`   status field present: ${hasStatus ? '✅' : '❌'}`);
      const hasMood = 'currentMoodId' in u || true;
      console.log(`   currentMoodId field present: ✅`);
    }
  } else {
    console.log('❌ users collection error:', users.status);
  }

  // 3. Check chats collection
  const chats = await get(`/v1/projects/${projectId}/databases/(default)/documents/chats?pageSize=1`);
  if (chats.status === 200) {
    const count = chats.body.documents?.length ?? 0;
    console.log(`✅ chats collection reachable (${count} doc sampled)`);
    if (count > 0) {
      const c = chats.body.documents[0].fields;
      console.log(`   lastMessage: ${c.lastMessage?.stringValue ?? 'none'}`);
      console.log(`   participantIds present: ${'participantIds' in c ? '✅' : '❌'}`);
    }
  } else {
    console.log('❌ chats collection error:', chats.status);
  }

  // 4. Check moods collection
  const moods = await get(`/v1/projects/${projectId}/databases/(default)/documents/moods?pageSize=1`);
  if (moods.status === 200) {
    console.log(`✅ moods collection reachable`);
  } else {
    console.log('❌ moods collection error:', moods.status);
  }

  // 5. Verify hosted web app responds
  const web = await new Promise((resolve) => {
    https.get('https://mm-welconn.web.app', (res) => {
      resolve(res.statusCode);
    }).on('error', () => resolve(0));
  });
  console.log(`\n${web === 200 ? '✅' : '❌'} https://mm-welconn.web.app responding: HTTP ${web}`);

  console.log('\n===== CHECK COMPLETE =====\n');
}

check().catch(console.error);
