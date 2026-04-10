package main

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides role-based access control functions
type SmartContract struct {
	contractapi.Contract
}

// Asset represents a ledger asset
type Asset struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Value string `json:"value"`
	Owner string `json:"owner"`
}

// getRole extracts the 'role' attribute from the caller's X.509 certificate
func getRole(ctx contractapi.TransactionContextInterface) (string, error) {
	role, found, err := cid.GetAttributeValue(ctx.GetStub(), "role")
	if err != nil {
		return "", fmt.Errorf("error reading role attribute: %v", err)
	}
	if !found {
		return "", fmt.Errorf("role attribute not found in certificate — ensure the identity was enrolled with a 'role' attribute")
	}
	return role, nil
}

// getMSPID returns the MSP ID of the calling identity
func getMSPID(ctx contractapi.TransactionContextInterface) (string, error) {
	mspid, err := cid.GetMSPID(ctx.GetStub())
	if err != nil {
		return "", fmt.Errorf("error getting MSPID: %v", err)
	}
	return mspid, nil
}

// CreateAsset — Admin only
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id, name, value string) error {
	role, err := getRole(ctx)
	if err != nil {
		return fmt.Errorf("❌ Access denied: %v", err)
	}
	if role != "Admin" {
		return fmt.Errorf("❌ Access denied: only Admin can create assets (your role: %s)", role)
	}

	// Check if asset already exists
	existing, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if existing != nil {
		return fmt.Errorf("asset with ID '%s' already exists", id)
	}

	mspid, _ := getMSPID(ctx)
	asset := Asset{
		ID:    id,
		Name:  name,
		Value: value,
		Owner: mspid,
	}
	data, err := json.Marshal(asset)
	if err != nil {
		return fmt.Errorf("failed to marshal asset: %v", err)
	}

	err = ctx.GetStub().PutState(id, data)
	if err != nil {
		return fmt.Errorf("failed to put state: %v", err)
	}

	fmt.Printf("✅ Admin created asset: %s\n", id)
	return nil
}

// UpdateAsset — Manager only
func (s *SmartContract) UpdateAsset(ctx contractapi.TransactionContextInterface, id, name, value string) error {
	role, err := getRole(ctx)
	if err != nil {
		return fmt.Errorf("❌ Access denied: %v", err)
	}
	if role != "Manager" {
		return fmt.Errorf("❌ Access denied: only Manager can update assets (your role: %s)", role)
	}

	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if data == nil {
		return fmt.Errorf("asset with ID '%s' not found", id)
	}

	var existing Asset
	if err := json.Unmarshal(data, &existing); err != nil {
		return fmt.Errorf("failed to unmarshal asset: %v", err)
	}

	// Preserve the original owner
	updated := Asset{
		ID:    id,
		Name:  name,
		Value: value,
		Owner: existing.Owner,
	}
	newData, err := json.Marshal(updated)
	if err != nil {
		return fmt.Errorf("failed to marshal updated asset: %v", err)
	}

	err = ctx.GetStub().PutState(id, newData)
	if err != nil {
		return fmt.Errorf("failed to put state: %v", err)
	}

	fmt.Printf("✅ Manager updated asset: %s\n", id)
	return nil
}

// ReadAsset — Auditor, Manager, and Admin can query
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	role, err := getRole(ctx)
	if err != nil {
		return nil, fmt.Errorf("❌ Access denied: %v", err)
	}
	// All three roles can read
	if role != "Admin" && role != "Manager" && role != "Auditor" {
		return nil, fmt.Errorf("❌ Access denied: unknown role '%s'", role)
	}

	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if data == nil {
		return nil, fmt.Errorf("asset with ID '%s' not found", id)
	}

	var asset Asset
	if err := json.Unmarshal(data, &asset); err != nil {
		return nil, fmt.Errorf("failed to unmarshal asset: %v", err)
	}

	fmt.Printf("✅ %s queried asset: %s\n", role, id)
	return &asset, nil
}

// GetAllAssets — Returns all assets (Admin, Manager, Auditor)
func (s *SmartContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	role, err := getRole(ctx)
	if err != nil {
		return nil, fmt.Errorf("❌ Access denied: %v", err)
	}
	if role != "Admin" && role != "Manager" && role != "Auditor" {
		return nil, fmt.Errorf("❌ Access denied: unknown role '%s'", role)
	}

	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}
		var asset Asset
		if err := json.Unmarshal(queryResponse.Value, &asset); err != nil {
			return nil, err
		}
		assets = append(assets, &asset)
	}
	return assets, nil
}

// DeleteAsset — Admin only
func (s *SmartContract) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
	role, err := getRole(ctx)
	if err != nil {
		return fmt.Errorf("❌ Access denied: %v", err)
	}
	if role != "Admin" {
		return fmt.Errorf("❌ Access denied: only Admin can delete assets (your role: %s)", role)
	}

	data, err := ctx.GetStub().GetState(id)
	if err != nil {
		return fmt.Errorf("failed to read from world state: %v", err)
	}
	if data == nil {
		return fmt.Errorf("asset with ID '%s' not found", id)
	}

	return ctx.GetStub().DelState(id)
}

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		panic(fmt.Sprintf("Error creating RBAC chaincode: %v", err))
	}
	if err := chaincode.Start(); err != nil {
		panic(fmt.Sprintf("Error starting RBAC chaincode: %v", err))
	}
}