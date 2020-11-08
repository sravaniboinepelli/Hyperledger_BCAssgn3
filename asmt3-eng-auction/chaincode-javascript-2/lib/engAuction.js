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

    // ReadAsset returns the asset stored in the world state with given id.
    async ReadAsset(ctx, id) {
        const assetJSON = await ctx.stub.getState(id); // get the asset from chaincode state
        if (!assetJSON || assetJSON.length === 0) {
            throw new Error(`The asset ${id} does not exist`);
        }
        return assetJSON.toString();
    }
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
        
        const readAsset = await this.ReadAsset(ctx, assetId);
        const submitterId = await ctx.clientIdentity.getMSPID();
        const auctionState = await ctx.stub.getState('auctionInfo'); 
        const asset = JSON.parse(readAsset);
        var auctionJSON = JSON.parse(auctionState.toString());
        var nullSubmitterIdx = [];
        var doesexist = false;
        var idx = 0;
        var i = 1;
        while(i < 4) {
            const submitterB = await ctx.stub.getState(i.toString());
            var submitter = JSON.parse(submitterB.toString());
            if (submitter.MSP == 'none'){
                nullSubmitterIdx[idx++] = i;
            }
            else
            if (submitter.MSP == submitterId){
                doesexist = true;
            }
            i = i + 1;
        }
        if(!(doesexist)){
            var id = 0;
            var checklength = nullSubmitterIdx.length;
            if (checklength > 0){
                id = nullSubmitterIdx[0];
            }
            var idstore = id.toString()
            const submitter1 = {
                ID: idstore,
                MSP: submitterId
            };
            await ctx.stub.putState( submitter1.ID, Buffer.from(JSON.stringify(submitter1)));
            auctionJSON.numOrgsSubmitted = auctionJSON.numOrgsSubmitted + 1;
        }
        if (auctionJSON.assetID == assetId && asset.ReservedPrice <= bidValue && auctionJSON.BidValue < bidValue){
                auctionJSON.BidValue = bidValue;
                auctionJSON.BidderID = submitterId;       
        }         
        else if(auctionJSON.assetID == assetId && asset.ReservedPrice > bidValue){  
            auctionJSON.numBelowReserved = auctionJSON.numBelowReserved + 1;
        }
        if (auctionJSON.numBelowReserved > 2){
            auctionJSON.numBelowReserved = 0;
            asset.ReservedPrice = asset.ReservedPrice - asset.BidDecrement;
        }
        else{
            // Catch errors
            console.log("Auction Failure")
            asset.ReservedPrice = asset.ReservedPrice;
        }
         await ctx.stub.putState(assetId, Buffer.from(JSON.stringify(asset)));
         await ctx.stub.putState('auctionInfo', Buffer.from(JSON.stringify(auctionJSON)));
        
    }
    async DeclareWinner(ctx) {
        const auctionB = await ctx.stub.getState('auctionInfo'); 
        var auctionJSON = JSON.parse(auctionB.toString());
        var winner = 'None'
        if (auctionJSON.numOrgsSubmitted > 2){
            winner = auctionJSON.BidderID;
        }
        return winner;
    }
}

module.exports = EnglishAuction;
