#!/bin/bash
# ============================================================
# RBAC Chaincode Deployment Script for Hyperledger Fabric
# ============================================================
# Run this from: ~/fabric-samples/test-network
# ============================================================

set -e
cd ~/fabric-samples/test-network

CHAINCODE_NAME="rbac"
CHANNEL_NAME="mychannel"
CC_SRC_PATH="../chaincode/rbac"   # adjust if your folder is named differently
CC_VERSION="1.0"
CC_SEQUENCE="1"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     RBAC Chaincode Deployment Script     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── STEP 1: Clean up old network ────────────────────────────
echo "▶ Step 1: Tearing down any existing network..."
./network.sh down
sleep 2

# ─── STEP 2: Start network + CA ──────────────────────────────
echo ""
echo "▶ Step 2: Starting Fabric network with CA..."
./network.sh up createChannel -c $CHANNEL_NAME -ca
sleep 5

# ─── STEP 3: VERIFY chaincode exists ────────────────
echo "▶ Step 3: Checking chaincode folder..."

if [ ! -d "$CC_SRC_PATH" ]; then
  echo "❌ ERROR: Chaincode folder not found at $CC_SRC_PATH"
  echo "👉 Please create: ~/fabric-samples/chaincode/rbac"
  exit 1
fi

echo "✅ Chaincode folder found"

# ─── STEP 4: Deploy chaincode ────────────────────────────────
echo ""
echo "▶ Step 4: Deploying chaincode..."
./network.sh deployCC \
  -ccn $CHAINCODE_NAME \
  -ccp $CC_SRC_PATH \
  -ccl go \
  -ccv $CC_VERSION \
  -ccs $CC_SEQUENCE

echo ""
echo "✅ Chaincode deployed successfully!"
echo ""

# ─── STEP 5: Set up environment for Org1 (Admin role) ────────
echo "▶ Step 5: Setting up environment variables..."

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config/

# Org1 Admin
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

echo "Environment set for Org1 Admin."
echo ""

# ─── STEP 6: Show test commands ──────────────────────────────
echo "═══════════════════════════════════════════════════════════"
echo "  Chaincode is deployed! Now run the test commands:"
echo "  See scripts/test-rbac.sh for full testing"
echo "═══════════════════════════════════════════════════════════"
