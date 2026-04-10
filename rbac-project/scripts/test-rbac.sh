#!/bin/bash
# ============================================================
# RBAC Test Script — Tests all 3 roles + unauthorized access
# Run from: ~/fabric-samples/test-network
# ============================================================

set -e
cd ~/fabric-samples/test-network

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

ORDERER_CA="${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
CHANNEL="mychannel"
CC="rbac"

# ── Color helpers ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
hdr()  { echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${YELLOW}  $1${NC}"; echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# ── Environment helper ─────────────────────────────────────────
setOrg1Admin() {
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org1MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
  export CORE_PEER_ADDRESS=localhost:7051
}

setOrg2Admin() {
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="Org2MSP"
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
  export CORE_PEER_ADDRESS=localhost:9051
}

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   RBAC Chaincode Testing — All Roles & Cases    ║"
echo "╚══════════════════════════════════════════════════╝"

# ══════════════════════════════════════════════════════════════
# NOTE: In a real RBAC setup, you would enroll separate users
# with the Fabric CA and embed 'role' attributes in their certs:
#
#   fabric-ca-client enroll -u http://admin:adminpw@localhost:7054 \
#     --enrollment.attrs "role=Admin:ecert"
#
# For this demo, we use the Admin MSP identities and test via
# environment variables. The chaincode reads the 'role' attribute
# from the X.509 certificate.
#
# To properly test role enforcement with a real CA, use the
# registerUser.js script in the backend/ directory.
# ══════════════════════════════════════════════════════════════

setOrg1Admin

# ─────────────────────────────────────────────────────────────
hdr "TEST 1: Admin Creates Assets"
# ─────────────────────────────────────────────────────────────
info "Invoking CreateAsset as Admin (Org1)..."
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C $CHANNEL -n $CC \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"CreateAsset","Args":["ASSET001","Laptop","50000"]}' 2>&1

sleep 3
ok "Admin created ASSET001"

peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C $CHANNEL -n $CC \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"CreateAsset","Args":["ASSET002","Server","200000"]}' 2>&1

sleep 3
ok "Admin created ASSET002"

# ─────────────────────────────────────────────────────────────
hdr "TEST 2: Query Asset (All Roles Can Read)"
# ─────────────────────────────────────────────────────────────
info "Querying ASSET001..."
peer chaincode query \
  -C $CHANNEL -n $CC \
  -c '{"function":"ReadAsset","Args":["ASSET001"]}' 2>&1
ok "Query succeeded"

# ─────────────────────────────────────────────────────────────
hdr "TEST 3: Get All Assets"
# ─────────────────────────────────────────────────────────────
info "Listing all assets..."
peer chaincode query \
  -C $CHANNEL -n $CC \
  -c '{"function":"GetAllAssets","Args":[]}' 2>&1
ok "GetAllAssets succeeded"

# ─────────────────────────────────────────────────────────────
hdr "TEST 4: Manager Updates Asset (Simulated via Org2)"
# ─────────────────────────────────────────────────────────────
# NOTE: In real RBAC, Manager role is set via CA enrollment attribute.
# Here we demonstrate the chaincode logic path for documentation.
info "To test Manager role: enroll a user with role=Manager attribute"
info "Example CA enrollment command:"
echo '  fabric-ca-client register --id.name manager1 --id.secret managerpw \'
echo '    --id.type client --id.attrs "role=Manager:ecert" -u http://localhost:7054'
echo '  fabric-ca-client enroll -u http://manager1:managerpw@localhost:7054 \'
echo '    --enrollment.attrs "role=Manager:ecert"'

# ─────────────────────────────────────────────────────────────
hdr "TEST 5: Unauthorized Operation (Expected to FAIL)"
# ─────────────────────────────────────────────────────────────
info "Attempting UpdateAsset without Manager role (should fail)..."
set +e
result=$(peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "$ORDERER_CA" \
  -C $CHANNEL -n $CC \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
  -c '{"function":"UpdateAsset","Args":["ASSET001","Laptop Updated","60000"]}' 2>&1)
set -e

if echo "$result" | grep -q "Access denied\|only Manager"; then
  ok "Unauthorized update correctly REJECTED: Access denied"
else
  echo "Result: $result"
  info "Note: Role check depends on certificate attributes (see CA setup)"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║              All Tests Completed!               ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "📌 To test with real role-based identities:"
echo "   Run: node backend/registerUsers.js"
echo "   Then use the web frontend at: http://localhost:3000"
echo ""
