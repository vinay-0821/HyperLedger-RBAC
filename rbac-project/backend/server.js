const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const grpc = require('@grpc/grpc-js');
const { connect, hash, signers } = require('@hyperledger/fabric-gateway');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());

// ─────────────────────────────────────────────
// 📁 Paths
// ─────────────────────────────────────────────
const FABRIC_SAMPLES = path.join(process.env.HOME, 'fabric-samples');
const TEST_NETWORK = path.join(FABRIC_SAMPLES, 'test-network');

// ─────────────────────────────────────────────
// 🔐 ROLE → USER MAPPING (FIXED)
// ─────────────────────────────────────────────
const roleConfig = {
  Admin: {
    mspId: 'Org1MSP',
    userPath: path.join(TEST_NETWORK, 'organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp')
  },
  Manager: {
    mspId: 'Org1MSP',
    userPath: path.join(TEST_NETWORK, 'organizations/peerOrganizations/org1.example.com/users/ManagerUser@org1.example.com/msp')
  },
  Auditor: {
    mspId: 'Org1MSP',
    userPath: path.join(TEST_NETWORK, 'organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp')
  },
};

// ─────────────────────────────────────────────
// 🔗 Peer + TLS
// ─────────────────────────────────────────────
const peerEndpoint = 'localhost:7051';
const tlsCertPath = path.join(TEST_NETWORK,
  'organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt');

// ─────────────────────────────────────────────
// 🔌 Connect to Fabric
// ─────────────────────────────────────────────
async function getGateway(role) {
  const config = roleConfig[role];
  if (!config) throw new Error(`Invalid role: ${role}`);

  const { mspId, userPath } = config;

  const tlsCert = fs.readFileSync(tlsCertPath);

  const certPath = path.join(userPath, 'signcerts');
  const certFile = fs.readdirSync(certPath)[0];
  const cert = fs.readFileSync(path.join(certPath, certFile));

  const keyPath = path.join(userPath, 'keystore');
  const keyFile = fs.readdirSync(keyPath)[0];
  const privateKey = crypto.createPrivateKey(
    fs.readFileSync(path.join(keyPath, keyFile))
  );

  const client = new grpc.Client(
    peerEndpoint,
    grpc.credentials.createSsl(tlsCert),
    { 'grpc.ssl_target_name_override': 'peer0.org1.example.com' }
  );

  const gateway = connect({
    client,
    identity: { mspId, credentials: cert },
    signer: signers.newPrivateKeySigner(privateKey),
    hash: hash.sha256,
  });

  return { gateway, client };
}

// ─────────────────────────────────────────────
// ⚙️ Invoke / Query
// ─────────────────────────────────────────────
async function invokeChaincode(role, fn, args) {
  let gateway, client;

  try {
    ({ gateway, client } = await getGateway(role));

    const network = gateway.getNetwork('mychannel');
    const contract = network.getContract('rbac');

    if (fn === 'ReadAsset' || fn === 'GetAllAssets') {
      const result = await contract.evaluateTransaction(fn, ...args);

      return {
        success: true,
        result: JSON.parse(Buffer.from(result).toString())
      };
    }
    else {
      await contract.submitTransaction(fn, ...args);
      return { success: true, message: `${fn} SUCCESS` };
    }
  } catch (err) {
    throw new Error(err.message);
  } finally {
    gateway?.close();
    client?.close();
  }
}

// ─────────────────────────────────────────────
// 🚀 API ROUTES
// ─────────────────────────────────────────────

// Health
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK' });
});

// Create (Admin only)
app.post('/api/assets', async (req, res) => {
  const { role, id, name, value } = req.body;

  try {
    // Log the role being passed
    console.log(`Invoking CreateAsset for role: ${role}`);
    
    const result = await invokeChaincode(role, 'CreateAsset', [id, name, value]);
    res.json(result);
  } catch (err) {
    console.error('Error invoking chaincode:', err);
    res.status(403).json({ error: err.message });
  }
});

// Update (Manager only)
app.put('/api/assets/:id', async (req, res) => {
  const { role, name, value } = req.body;
  const { id } = req.params;

  try {
    const result = await invokeChaincode(role, 'UpdateAsset', [id, name, value]);
    res.json(result);
  } catch (err) {
    res.status(403).json({ error: err.message });
  }
});

// Read (All)
app.get('/api/assets/:id', async (req, res) => {
  const { role } = req.query;
  const { id } = req.params;

  try {
    const result = await invokeChaincode(role, 'ReadAsset', [id]);
    res.json(result);
  } catch (err) {
    res.status(403).json({ error: err.message });
  }
});

// Delete (Admin only)
app.delete('/api/assets/:id', async (req, res) => {
  const { role } = req.body;
  const { id } = req.params;

  try {
    const result = await invokeChaincode(role, 'DeleteAsset', [id]);
    res.json(result);
  } catch (err) {
    res.status(403).json({ error: err.message });
  }
});

// Get ALL assets (for Refresh Ledger)
app.get('/api/assets', async (req, res) => {
  const { role } = req.query;

  try {
    const result = await invokeChaincode(role, 'GetAllAssets', []);

    console.log("GetAllAssets result:", result);

    res.json(result);

  } catch (err) {
    res.status(403).json({ error: err.message });
  }
});

// ─────────────────────────────────────────────
// ▶ Start Server
// ─────────────────────────────────────────────
const PORT = 3001;
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});