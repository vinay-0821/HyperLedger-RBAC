# ⛓️ Hyperledger Fabric — Role-Based Access Control (RBAC)

> Implementing Role-Based Access Control in chaincode using the **Client Identity (CID) Library**.  
> Platform: **Hyperledger Fabric v2.5** | Language: **Go** | Channel: `mychannel` | Chaincode: `rbac`

---

## 📋 Table of Contents

1. [What is Hyperledger Fabric?](#1-what-is-hyperledger-fabric)
2. [Problem Statement](#2-problem-statement)
3. [How RBAC Works Here](#3-how-rbac-works-here)
4. [Technology Stack](#4-technology-stack)
5. [Project Structure](#5-project-structure)
6. [Prerequisites](#6-prerequisites)
7. [Complete Setup & Run Guide](#7-complete-setup--run-guide)
8. [Testing All Roles](#8-testing-all-roles)
9. [Frontend Demo](#9-frontend-demo)
10. [Chaincode Functions](#10-chaincode-functions)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. What is Hyperledger Fabric?

Hyperledger Fabric is an **open-source, enterprise-grade permissioned blockchain framework** hosted by the Linux Foundation. Unlike public blockchains like Bitcoin or Ethereum where anyone can join anonymously, Fabric is built for business — every participant is known, authenticated, and assigned specific permissions.

### How It Works

Every transaction in Fabric goes through three phases:

```
Client App  →  Endorsing Peers  →  Orderer  →  All Peers
  (propose)      (simulate +        (sequence    (validate +
                  sign)             into blocks)  commit)
```

1. **Propose** — Client submits a transaction proposal to endorsing peers
2. **Endorse** — Peers run the chaincode (smart contract) and return a signed response
3. **Order** — The Ordering Service (Raft) sequences transactions into blocks
4. **Commit** — All peers validate and commit the block to their ledger

### Key Components

| Component | Description |
|-----------|-------------|
| **Peer** | Node that hosts the ledger and runs chaincode |
| **Orderer** | Orders transactions into blocks using Raft consensus |
| **Fabric CA** | Certificate Authority — issues X.509 certificates to all participants |
| **Channel** | Private subnet between organizations, each with its own ledger |
| **Chaincode** | Smart contract — business logic written in Go, Java, or Node.js |
| **MSP** | Membership Service Provider — manages digital identities |
| **World State** | Current state of the ledger (key-value store, LevelDB) |

### Why Fabric for Enterprise?

- ✅ **Permissioned** — All participants are identified via X.509 certificates
- ✅ **No cryptocurrency** — No mining, no gas fees
- ✅ **Private data** — Sensitive data shared only between specific orgs
- ✅ **High throughput** — Thousands of TPS, suitable for production
- ✅ **Pluggable consensus** — Swap consensus mechanisms without redesign
- ✅ **Channels** — Multiple isolated ledgers on the same infrastructure

### Real-World Use Cases

| Industry | Use Case |
|----------|----------|
| Supply Chain | IBM Food Trust — tracks food from farm to store |
| Trade Finance | We.Trade — automates cross-border transactions between banks |
| Healthcare | Patient record sharing between hospitals with privacy |
| Government | Tamper-proof land registry and ownership records |
| Finance | Interbank settlement, KYC data sharing |
| Insurance | Automated claims processing via smart contracts |

---

## 2. Problem Statement

In any enterprise blockchain network, **not all participants should have equal access**. Without proper access control:

- An auditor could accidentally (or maliciously) modify records
- A manager could create unauthorized assets
- There is no enforceable separation of duties

The challenge is to implement **certificate-based RBAC at the chaincode level** — meaning access decisions are enforced by the smart contract on the blockchain itself, not just at the application layer.

> Even if someone bypasses the frontend and directly invokes the chaincode via CLI, the role check still applies — because it runs inside the peer.

### Role Permissions

| Operation | 🛡️ Admin | 📊 Manager | 🔍 Auditor |
|-----------|----------|------------|------------|
| Create Asset | ✅ | ❌ | ❌ |
| Update Asset | ❌ | ✅ | ❌ |
| Read Asset | ✅ | ✅ | ✅ |
| Delete Asset | ✅ | ❌ | ❌ |
| Get All Assets | ✅ | ✅ | ✅ |

---

## 3. How RBAC Works Here

The solution uses the **Hyperledger Fabric Client Identity (CID) Library**. When a user is enrolled with the Fabric CA, a custom `role` attribute is **embedded directly into their X.509 certificate**. The chaincode reads this attribute on every function call.

```go
// Inside chaincode — reads role from the caller's certificate
role, found, err := cid.GetAttributeValue(ctx.GetStub(), "role")
```

### Why This is Secure

- The `role` attribute is embedded in the X.509 cert, which is **cryptographically signed by the CA**
- The certificate **cannot be forged or tampered with**
- The check happens **inside the peer**, before any ledger read/write
- The ledger always records **who** performed each operation

---

## 4. Technology Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| Hyperledger Fabric | v2.5 | Core permissioned blockchain platform |
| Go (Golang) | v1.21 | Chaincode language |
| fabric-chaincode-go | latest | Official Fabric Go SDK + CID library |
| fabric-contract-api-go | v1.2.2 | High-level contract API for chaincode |
| Fabric CA | v1.5 | Issues X.509 certificates with role attributes |
| Docker & Docker Compose | v24+ | Containerizes all Fabric components |
| Node.js + Express.js | v18+ | Backend REST API |
| @hyperledger/fabric-gateway | v1.4 | Node.js SDK to connect to Fabric |
| HTML / CSS / JavaScript | — | Frontend demo UI |
| Ubuntu | 22.04 LTS | Development environment |

---

## 5. Project Structure

```
~/fabric-samples/
├── chaincode/
│   └── rbac/                        ← Smart contract lives here
│       ├── smartcontract.go         ← Main RBAC chaincode logic
│       ├── go.mod                   ← Go module definition
│       ├── go.sum                   ← Dependency checksums
│       └── vendor/                  ← Vendored Go dependencies
│
└── test-network/                    ← Fabric test network
    ├── network.sh                   ← Start/stop network
    └── organizations/               ← Crypto material, certs, MSPs

~/rbac-project/                      ← Application layer
├── README.md                        ← This file
├── frontend/
│   └── index.html                   ← Demo UI (open in browser)
├── backend/
│   ├── server.js                    ← Express REST API
│   └── package.json                 ← Node.js dependencies
└── scripts/
    ├── deploy.sh                    ← Network + chaincode deployment
    └── test-rbac.sh                 ← CLI test suite
```

---

## 6. Prerequisites

Make sure the following are installed before proceeding:

```bash
# Check Docker
docker --version          # Need v24+
docker compose version    # Need v2+

# Check Go
go version                # Need v1.21+

# Check Node.js
node --version            # Need v18+

# Check Fabric binaries are in PATH
peer version
fabric-ca-client version
```

> **Fabric binaries** must be installed via `fabric-samples`. If not done, run:
> ```bash
> curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.5.0 1.5.7
> ```

---

## 7. Complete Setup & Run Guide

### Step 1 — Deploy Network + Chaincode

```bash
cd ~/fabric-samples/test-network
bash ~/rbac-project/scripts/deploy.sh
```

This script will:
- Tear down any existing network
- Start the network with CA enabled
- Create `mychannel`
- Package, install, approve, and commit the `rbac` chaincode

✅ You should see **"Chaincode deployed successfully!"** at the end.

---

### Step 2 — Set Environment Variables

Run these in every new terminal session before using the peer CLI:

```bash
cd ~/fabric-samples/test-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Also set the orderer CA path (used in invoke commands)
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

---

### Step 3 — Register Users with Role Attributes

This registers three users with the Fabric CA and embeds the `role` attribute into their certificates:

```bash
cd ~/fabric-samples/test-network

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/org1.example.com/

# Register Admin user
fabric-ca-client register --caname ca-org1 \
  --id.name adminUser --id.secret adminpw \
  --id.type client \
  --id.attrs "role=Admin:ecert" \
  --tls.certfiles ${PWD}/organizations/fabric-ca/org1/ca-cert.pem

# Register Manager user
fabric-ca-client register --caname ca-org1 \
  --id.name managerUser --id.secret managerpw \
  --id.type client \
  --id.attrs "role=Manager:ecert" \
  --tls.certfiles ${PWD}/organizations/fabric-ca/org1/ca-cert.pem

# Register Auditor user
fabric-ca-client register --caname ca-org1 \
  --id.name auditorUser --id.secret auditorpw \
  --id.type client \
  --id.attrs "role=Auditor:ecert" \
  --tls.certfiles ${PWD}/organizations/fabric-ca/org1/ca-cert.pem
```

---

### Step 4 — Enroll Users + Fix MSP (admincerts)

> ⚠️ **Important:** After enrollment, you must manually create the `admincerts` folder.  
> The Fabric peer CLI requires this folder to exist or it will reject the identity with an MSP error.  
> This is a known requirement of Fabric's MSP structure — `admincerts` tells the peer  
> that this certificate is authorized to act on behalf of the organization.

```bash
cd ~/fabric-samples/test-network

# ── Enroll Admin ──────────────────────────────────────────────────────────────
fabric-ca-client enroll \
  -u https://adminUser:adminpw@localhost:7054 \
  --caname ca-org1 \
  -M ${PWD}/organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp \
  --enrollment.attrs "role" \
  --tls.certfiles ${PWD}/organizations/fabric-ca/org1/ca-cert.pem

# Fix AdminUser MSP — create admincerts
mkdir -p organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp/admincerts
cp organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp/signcerts/cert.pem \
   organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp/admincerts/


# ── Enroll Manager ────────────────────────────────────────────────────────────
fabric-ca-client enroll \
  -u https://managerUser:managerpw@localhost:7054 \
  --caname ca-org1 \
  -M ${PWD}/organizations/peerOrganizations/org1.example.com/users/ManagerUser@org1.example.com/msp \
  --enrollment.attrs "role" \
  --tls.certfiles ${PWD}/organizations/fabric-ca/org1/ca-cert.pem

# Fix ManagerUser MSP — create admincerts
mkdir -p organizations/peerOrganizations/org1.example.com/users/ManagerUser@org1.example.com/msp/admincerts
cp organizations/peerOrganizations/org1.example.com/users/ManagerUser@org1.example.com/msp/signcerts/cert.pem \
   organizations/peerOrganizations/org1.example.com/users/ManagerUser@org1.example.com/msp/admincerts/


# ── Enroll Auditor ────────────────────────────────────────────────────────────
fabric-ca-client enroll \
  -u https://auditorUser:auditorpw@localhost:7054 \
  --caname ca-org1 \
  -M ${PWD}/organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp \
  --enrollment.attrs "role" \
  --tls.certfiles ${PWD}/organizations/fabric-ca/org1/ca-cert.pem

# Fix AuditorUser MSP — create admincerts
mkdir -p organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp/admincerts
cp organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp/signcerts/cert.pem \
   organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp/admincerts/
```

---

## 8. Testing All Roles

> Before every test, switch identity using `export CORE_PEER_MSPCONFIGPATH=...`  
> This is how you tell the peer CLI **which user** is making the call.

---

### Test 1 — Admin Creates an Asset ✅

```bash
# Switch to Admin identity
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n rbac \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"CreateAsset","Args":["ASSET001","Laptop","50000"]}'

sleep 3
```

**Expected:** `chaincode response: 200`

---

### Test 2 — Auditor Reads an Asset ✅

```bash
# Switch to Auditor identity
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp

peer chaincode query \
  -C mychannel -n rbac \
  -c '{"function":"ReadAsset","Args":["ASSET001"]}'
```

**Expected:** `{"id":"ASSET001","name":"Laptop","value":"50000","owner":"Org1MSP"}`

---

### Test 3 — Auditor Tries to Create ❌ (Must Fail)

```bash
# Still using Auditor identity from above

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n rbac \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"CreateAsset","Args":["ASSET002","Phone","20000"]}'
```

**Expected error:** `❌ Access denied: only Admin can create assets (your role: Auditor)`

---

### Test 4 — Manager Updates an Asset ✅

```bash
# Switch to Manager identity
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/ManagerUser@org1.example.com/msp

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n rbac \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"UpdateAsset","Args":["ASSET001","Laptop Pro","75000"]}'

sleep 3
```

**Expected:** `chaincode response: 200`

---

### Test 5 — Manager Tries to Delete ❌ (Must Fail)

```bash
# Still using Manager identity from above

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n rbac \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"DeleteAsset","Args":["ASSET001"]}'
```

**Expected error:** `❌ Access denied: only Admin can delete assets (your role: Manager)`

---

### Test 6 — Get All Assets ✅

```bash
# Works for any role — switch to Auditor to demonstrate read-only access
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/AuditorUser@org1.example.com/msp

peer chaincode query \
  -C mychannel -n rbac \
  -c '{"function":"GetAllAssets","Args":[]}'
```

**Expected:** JSON array of all assets on the ledger

---

### Test 7 — Admin Deletes an Asset ✅

```bash
# Switch back to Admin
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/AdminUser@org1.example.com/msp

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C mychannel -n rbac \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"DeleteAsset","Args":["ASSET001"]}'
```

**Expected:** `chaincode response: 200`

---

## 9. Frontend Demo

Open a **new terminal** and run:

```bash
# Install dependencies and start backend
cd ~/rbac-project/backend
npm install
node server.js
```

Then open the frontend:

```bash
python3 -m http.server 8000
```

The UI lets you switch between Admin, Manager, and Auditor roles and perform all operations. Authorized operations show **green**, unauthorized ones show **red** with the exact error message from the chaincode.

---

## 10. Chaincode Functions

All functions are in `chaincode/rbac/smartcontract.go`:

| Function | Access | Description |
|----------|--------|-------------|
| `CreateAsset(id, name, value)` | Admin only | Creates a new asset. Fails if ID already exists. |
| `UpdateAsset(id, name, value)` | Manager only | Updates an existing asset. Preserves original owner. |
| `ReadAsset(id)` | All roles | Returns a single asset by ID. |
| `GetAllAssets()` | All roles | Returns all assets on the ledger. |
| `DeleteAsset(id)` | Admin only | Permanently removes an asset. |

### Core RBAC Code

```go
func getRole(ctx contractapi.TransactionContextInterface) (string, error) {
    role, found, err := cid.GetAttributeValue(ctx.GetStub(), "role")
    if err != nil {
        return "", fmt.Errorf("error reading role attribute: %v", err)
    }
    if !found {
        return "", fmt.Errorf("role attribute not found in certificate")
    }
    return role, nil
}

func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id, name, value string) error {
    role, err := getRole(ctx)
    if err != nil {
        return fmt.Errorf("❌ Access denied: %v", err)
    }
    if role != "Admin" {
        return fmt.Errorf("❌ Access denied: only Admin can create assets (your role: %s)", role)
    }
    // ... create asset logic
}
```

---

## 11. Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `Path to chaincode does not exist` | Wrong `-ccp` path | Verify `~/fabric-samples/chaincode/rbac/` contains `go.mod` |
| `role attribute not found in certificate` | Default Admin cert has no role | Must enroll users via CA with `--id.attrs "role=Admin:ecert"` |
| `no MSP found` or `missing admincerts` | `admincerts/` folder not created | Run the `mkdir + cp` commands after each enrollment (Step 4) |
| `Error endorsing transaction` | Missing peer addresses | Always specify both `--peerAddresses` (Org1 and Org2) in invoke |
| `connection refused localhost:7051` | Fabric containers stopped | Run `docker ps` — if empty, re-run `deploy.sh` |
| `Local binaries out of sync` warning | Version mismatch | Harmless warning, network still works |
| `npm install` fails | Wrong Node.js version | Run `node --version` — need v18+ |

---

## Quick Reference

```bash
# ── Network ───────────────────────────────────────────────────
./network.sh up createChannel -c mychannel -ca    # Start
./network.sh down                                  # Stop
docker ps                                          # Check containers

# ── Deploy ────────────────────────────────────────────────────
./network.sh deployCC -ccn rbac -ccp ../chaincode/rbac -ccl go -ccv 1.0 -ccs 1

# ── Switch identity ───────────────────────────────────────────
export CORE_PEER_MSPCONFIGPATH=.../users/AdminUser@org1.example.com/msp
export CORE_PEER_MSPCONFIGPATH=.../users/ManagerUser@org1.example.com/msp
export CORE_PEER_MSPCONFIGPATH=.../users/AuditorUser@org1.example.com/msp

# ── Query (no orderer needed) ─────────────────────────────────
peer chaincode query -C mychannel -n rbac -c '{"function":"ReadAsset","Args":["ASSET001"]}'
peer chaincode query -C mychannel -n rbac -c '{"function":"GetAllAssets","Args":[]}'

# ── Check installed chaincode ─────────────────────────────────
peer lifecycle chaincode queryinstalled
peer lifecycle chaincode querycommitted -C mychannel
```

---

## License

This project is submitted as part of a Blockchain Technology course assignment.

---

*Built with Hyperledger Fabric v2.5 · Go · Node.js · Docker*
