/*
 * 
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Contract } = require('fabric-contract-api');

class EnglishAuction extends Contract {

    async InitLedger(ctx) {

        const assets = [
            {
                ID: 'asset1',
                Owner: 'Test1',
                ReservedPrice: 300,
                BidIncrement: 50,
                BidDecrement: 10
            },
            
        ];
        const autionInfo = {
            ID: 'auctionInfo',
            BidValue: 0,
            BidderID: '',
            assetID: 'asset1',
            numOrgsSubmitted: 0,
            numBelowReserved: 0
        }
        const auctionSubmitters = [
            {
                ID: '1',
                MSP: 'none',
            },
            {
                ID: '2',
                MSP: 'none',
            },
            {
                ID: '3',
                MSP: 'none',
            },
        ]
       
        for (const asset of assets) {
            asset.docType = 'asset';
            await ctx.stub.putState(asset.ID, Buffer.from(JSON.stringify(asset)));
            console.info(`Asset ${asset.ID} initialized`);
        }
        for (const submitter of auctionSubmitters) {
            submitter.docType = 'submitters';
            await ctx.stub.putState(submitter.ID, Buffer.from(JSON.stringify(submitter)));
            console.info(`Submitter ${submitter.ID} initialized`);
        }
        await ctx.stub.putState(autionInfo.ID, Buffer.from(JSON.stringify(autionInfo)));
    }

    // CreateAsset issues a new asset to the world state with given details.
    async CreateAsset(ctx, id, owner, reservedPrice, bidIncr, bidDecr) {
        const asset = {
            ID: id,
            Owner: owner,
            ReservedPrice: reservedPrice,
            BidIncrement: bidIncr,
            BidDecrement: bidDecr,
        };
        return ctx.stub.putState(id, Buffer.from(JSON.stringify(asset)));
    }

    // ReadAsset returns the asset stored in the world state with given id.
    async ReadAsset(ctx, id) {
        const assetJSON = await ctx.stub.getState(id); // get the asset from chaincode state
        if (!assetJSON || assetJSON.length === 0) {
            throw new Error(`The asset ${id} does not exist`);
        }
        return assetJSON.toString();
    }

    // UpdateAsset updates an existing asset in the world state with provided parameters.
    async UpdateAsset(ctx, id, owner, reservedPrice, bidIncr, bidDecr) {
        const exists = await this.AssetExists(ctx, id);
        if (!exists) {
            throw new Error(`The asset ${id} does not exist`);
        }

        // overwriting original asset with new asset
        const updatedAsset = {
            ID: id,
            Owner: owner,
            ReservedPrice: reservedPrice,
            BidIncrement: bidIncr,
            BidDecrement: bidDecr,
        };
        return ctx.stub.putState(id, Buffer.from(JSON.stringify(updatedAsset)));
    }

    // DeleteAsset deletes an given asset from the world state.
    async DeleteAsset(ctx, id) {
        const exists = await this.AssetExists(ctx, id);
        if (!exists) {
            throw new Error(`The asset ${id} does not exist`);
        }
        return ctx.stub.deleteState(id);
    }

    // AssetExists returns true when asset with given ID exists in world state.
    async AssetExists(ctx, id) {
        const assetJSON = await ctx.stub.getState(id);
        return assetJSON && assetJSON.length > 0;
    }

    // TransferAsset updates the owner field of asset with given id in the world state.
    async TransferAsset(ctx, id, newOwner) {
        const assetString = await this.ReadAsset(ctx, id);
        const asset = JSON.parse(assetString);
        asset.Owner = newOwner;
        return ctx.stub.putState(id, Buffer.from(JSON.stringify(asset)));
    }

    // GetAllAssets returns all assets found in the world state.
    async GetAllAssets(ctx) {
        const allResults = [];
        // range query with empty string for startKey and endKey does an open-ended query of all assets in the chaincode namespace.
        const iterator = await ctx.stub.getStateByRange('asset1', 'auctionInfo');
        let result = await iterator.next();
        while (!result.done) {
            const strValue = Buffer.from(result.value.value.toString()).toString('utf8');
            let record;
            try {
                record = JSON.parse(strValue);
            } catch (err) {
                console.log(err);
                record = strValue;
            }
            allResults.push({ Key: result.value.key, Record: record });
            result = await iterator.next();
        }
        return JSON.stringify(allResults);
    }
    async SubmitBid(ctx, bidValue, assetId) {
        const assetString = await this.ReadAsset(ctx, assetId);
        const asset = JSON.parse(assetString);
        // console.log("asset1", asset);
        const auctionB = await ctx.stub.getState('auctionInfo'); 
        var auctionJSON = JSON.parse(auctionB.toString());
        // console.log("auctionJSON",auctionJSON);
        const submitterId = await ctx.clientIdentity.getMSPID();
        console.log("submitterId",submitterId);
        var i;
        var nullSubmitterIdx = [];
        var exists = false;
        var idx = 0;
        for (i = 1; i < 4; i++) {
            const submitterB = await ctx.stub.getState(i.toString());
            var submitter = JSON.parse(submitterB.toString());
            if (submitter.MSP == submitterId){
                exists = true;
                break;
            }else if (submitter.MSP == 'none'){
                nullSubmitterIdx[idx++] = i;
            }
        }
        if(exists == false){
            console.log("nullSubmitterIdx",nullSubmitterIdx )
            var id = 0;
            if (nullSubmitterIdx.length > 0){
                id = nullSubmitterIdx[0];
            }
            const submitter1 = {
                ID: id.toString(),
                MSP: submitterId
            };
            await ctx.stub.putState( submitter1.ID, Buffer.from(JSON.stringify(submitter1)));
            auctionJSON.numOrgsSubmitted++;
        }
        // console.log(auctionJSON);
        // console.log(bidValue, auctionJSON.BidValue, assetId, auctionJSON.assetID)
        if (auctionJSON.assetID == assetId) {
            if (asset.ReservedPrice <= bidValue){
                if (auctionJSON.BidValue < bidValue){
                    auctionJSON.BidValue = bidValue;
                    auctionJSON.BidderID = submitterId;       
                }         
            }else {
                console.log("bid Value less Than reserved Price");  
                auctionJSON.numBelowReserved++;
            }
        }
        if (auctionJSON.numBelowReserved >= 3){
            auctionJSON.numBelowReserved = 0;
            asset.ReservedPrice -= asset.BidDecrement;
        }
        //  console.log("auctionJSONend", auctionJSON);
         await ctx.stub.putState(assetId, Buffer.from(JSON.stringify(asset)));
         await ctx.stub.putState('auctionInfo', Buffer.from(JSON.stringify(auctionJSON)));
        
    }
    async DeclareWinner(ctx) {
        var winner = 'None'
        const auctionB = await ctx.stub.getState('auctionInfo'); 
        var auctionJSON = JSON.parse(auctionB.toString());
        console.log("auctionJSON",auctionJSON);
        if (auctionJSON.numOrgsSubmitted >= 3){
            console.log("Bidder ", auctionJSON.BidderID, " is winner of the Auction with value " ,  auctionJSON.BidValue);
            winner = auctionJSON.BidderID;
        }else {
            console.log("Aiuction not complete");
        }
        return winner;
    }


}

module.exports = EnglishAuction;
