package main

import (
	"encoding/json"
	"fmt"
	"log"
	"strconv"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract provides functions for managing an Asset
type SmartContract struct {
	contractapi.Contract
}

// Asset describes basic details of what makes up a simple asset
type Asset struct {
	ID            string `json:"ID"`
	Owner         string `json:"Owner"`
	ReservedPrice int    `json:"ReservedPrice"`
	BidIncrement  int    `json:"BidIncrement"`
	BidDecrement  int    `json:"BidDecrement"`
}

type auction struct {
	ID               string `json:"ID"`
	BidValue         int    `json:"BidValue"`
	BidderID         string `json:"BidderID"`
	AssetID          string `json:"AssetID"`
	NumOrgsSubmitted int    `json:"NumOrgsSubmitted"`
	NumBelowReserved int    `json:"NumBelowReserved"`
}

type identity struct {
	ID  string `json:"ID"`
	MSP string `json:"MSP"`
}

// InitLedger adds a base set of assets to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{
			ID:            "asset1",
			Owner:         "Test1",
			ReservedPrice: 20,
			BidIncrement:  50,
			BidDecrement:  10,
		},
	}

	auctionInfo := auction{
		ID:               "auctionInfo",
		BidValue:         0,
		BidderID:         "",
		AssetID:          "asset1",
		NumOrgsSubmitted: 0,
		NumBelowReserved: 0,
	}

	auctionSubmitters := []identity{
		{
			ID:  "1",
			MSP: "none",
		},
		{
			ID:  "2",
			MSP: "none",
		},
		{
			ID:  "3",
			MSP: "none",
		},
	}

	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.ID, assetJSON)
		if err != nil {
			return fmt.Errorf("Failed to put to world state. %v", err)
		}
		// log.Printf("Asset %s initialized", asset.ID)
	}

	for _, submitter := range auctionSubmitters {
		submitterJSON, err := json.Marshal(submitter)
		if err != nil {
			return err
		}
		err = ctx.GetStub().PutState(submitter.ID, submitterJSON)
		if err != nil {
			return fmt.Errorf("Failed to put to world state. %v", err)
		}
		// log.Printf("Submitter %s initialized", submitter.ID)
	}

	auctionJSON, err := json.Marshal(auctionInfo)
	if err != nil {
		return err
	}
	err = ctx.GetStub().PutState(auctionInfo.ID, auctionJSON)
	return nil
}

// ReadAsset returns the asset stored in the world state with given id.
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	assetPtr, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetPtr == nil {
		return nil, fmt.Errorf("the asset %s does not exist", id)
	}

	var asset Asset
	err = json.Unmarshal(assetPtr, &asset)
	if err != nil {
		return nil, err
	}

	return &asset, nil
}

func (s *SmartContract) SubmitBid(ctx contractapi.TransactionContextInterface, bidValue int, assetID string) (*Asset, error) {
	assetString, err := s.ReadAsset(ctx, assetID)
	asset := assetString
	// asset, err := json.Marshal(assetString)
	// if err != nil {
	// 	return nil, err
	// }
	auctionPtr, err := ctx.GetStub().GetState("auctionInfo")
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if auctionPtr == nil {
		return nil, fmt.Errorf("Auction Info absent")
	}
	var auctionJSON auction
	err = json.Unmarshal(auctionPtr, &auctionJSON)
	if err != nil {
		return nil, err
	}

	submitterID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	nullSubmitterIdx := [5]int{-1, -1, -1, -1, -1}
	var exists bool = false
	var idx int = 0

	for i := 1; i < 4; i++ {
		submitterPtr, err := ctx.GetStub().GetState(strconv.Itoa(i))
		if err != nil {
			return nil, fmt.Errorf("failed to read from world state: %v", err)
		}
		var submitter identity
		err = json.Unmarshal(submitterPtr, &submitter)
		if err != nil {
			return nil, err
		}
		// submitter := submitterJSON
		if submitter.MSP == submitterID {
			exists = true
			break
		} else if submitter.MSP == "none" {
			nullSubmitterIdx[idx] = i
			idx++
		}
	}

	if !exists {
		// log.Printf("Null Submitte Id!")
		id := 0
		if nullSubmitterIdx[0] != -1 {
			id = nullSubmitterIdx[0]
		}

		submitter1 := identity{
			ID:  strconv.Itoa(id),
			MSP: submitterID,
		}

		submitter1JSON, err := json.Marshal(submitter1)
		if err != nil {
			return nil, err
		}
		err = ctx.GetStub().PutState(submitter1.ID, submitter1JSON)
		auctionJSON.NumOrgsSubmitted++
	}

	if auctionJSON.AssetID == assetID {
		if asset.ReservedPrice <= bidValue {
			if auctionJSON.BidValue < bidValue {
				auctionJSON.BidValue = bidValue
				auctionJSON.BidderID = submitterID
			}
		} else {
			// log.Printf("bid Value less Than reserved Price")
			auctionJSON.NumBelowReserved++
		}
	}

	if auctionJSON.NumBelowReserved >= 3 {
		auctionJSON.NumBelowReserved = 0
		asset.ReservedPrice -= asset.BidDecrement
	}

	assetPtr, err := json.Marshal(asset)
	if err != nil {
		return nil, err
	}

	auctionPtr, err = json.Marshal(auctionJSON)
	if err != nil {
		return nil, err
	}

	ctx.GetStub().PutState(assetID, assetPtr)
	ctx.GetStub().PutState("auctionInfo", auctionPtr)
	return nil, nil
}

func (s *SmartContract) DeclareWinner(ctx contractapi.TransactionContextInterface) (*auction, error) {
	auctionPtr, err := ctx.GetStub().GetState("auctionInfo")

	var auctionJSON auction
	err = json.Unmarshal(auctionPtr, &auctionJSON)
	if err != nil {
		return nil, err
	}

	// if auctionJSON.NumOrgsSubmitted >= 3 {
	// 	log.Printf("Bidder %s wins the auction at Bid Value %d", auctionJSON.BidderID, auctionJSON.BidValue)
	// } else {
	// 	fmt.Print("Auction Incomplete")
	// }

	return &auctionJSON, nil
}

// start it all
func main() {
	assetChaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating asset-transfer-basic chaincode: %v", err)
	}

	if err := assetChaincode.Start(); err != nil {
		log.Panicf("Error starting asset-transfer-basic chaincode: %v", err)
	}
}
