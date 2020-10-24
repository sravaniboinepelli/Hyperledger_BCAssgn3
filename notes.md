## Random implementation notes dumped 

explains contract-api vs shim
ledger update methods for javascript 
https://medium.com/coinmonks/start-developing-hyperledger-fabric-chaincode-in-node-js-e63b655d98db
https://hyperledger.github.io/fabric-chaincode-node/release-2.2/api/tutorial-deep-dive-contract-interface.html

https://hyperledger.github.io/fabric-chaincode-node/release-2.2/api/tutorial-using-contractinterface.html
https://hyperledger.github.io/fabric-chaincode-node/release-2.2/api/tutorial-using-iterators.html

https://hyperledger.github.io/fabric-chaincode-node/release-2.2/api/fabric-shim.ClientIdentity.html

ctx.clientIdentity. getMspID()


https://hyperledger-fabric.readthedocs.io/en/latest/developapps/transactioncontext.html

same interface (contract interface fabric-api-contract)

and endorsementpolicy(leave to default)so majority need to approve fr install

initAssets()
 ID: 'asset1'
 Owner: 'Tomoko',
 reservePrice: 300,
 bidIncrements: 15
 bidDecrements: 10

bidinfo 
bidder MspID
bid bidValue

highestbid
bidValue
bider MspID
numsubmits



modify assets for owner change, reserve price change increments, decrements change

createAsset

submitBid(assetId, bidValue)
timebased (start  and end time)
for standingbid to displace timePeriod 

Need to have 3 organizations. 3 smartcontracts to install 

traditional english auction time based but assignemnt says based on all org submitBid call

declareWinner()

An English auction is an open-outcry ascending dynamic auction. It proceeds as follows.

The auctioneer opens the auction by announcing a suggested opening bid, a starting price or reserve for the item on sale.
Then, the auctioneer accepts increasingly higher bids from the floor, consisting of buyers with an interest in the item. The auctioneer usually determines the minimum increment of bids, often raising it when bidding goes high.
The highest bidder at any given moment is considered to have the standing bid, which can only be displaced 
by a higher bid from a competing buyer.
If no competing bidder challenges the standing bid within a given time frame, the standing bid 
becomes the winner, and the item is sold to the highest bidder at a price equal to their bid.
If no bidder accepts the starting price, the auctioneer either begins to lower the starting price in increments, bidders are allowed to bid prices lower than the starting price, or the item is not sold at all, according to the wishes of the seller or protocols of the auction house

n auction mechanism is considered "English" if it involves an iterative process of adjusting the price in a direction that is unfavorable to the bidders (increasing in price if the item is being sold to competing buyers or decreasing in price in a reverse auction with competing sellers). 

 Implementation:
 we won't do reverse auction.
 single asset,
 multiple buyers 
 consensus on which organisation adds asset.
 3 different implementtaions (all java script with different ways of doing error hadling??)
 add asset at the time of init by one implementation with following fields
 initAssets()
 ID: 'asset1'
 Owner: 'Tomoko',
 reservePrice: 300,
 bidIncrements: 15
 bidDecrements: 10

 other implementations simply check if exist 
 ifexist (implemented by all)
 submitBid(assetId, bid Value)

 where do we store standing bid info?
 standing bid should contain bidder Id(MSPID?)
 bid value.
 Number of people that already submitted the bid


 declareWinner()
 check if enough people alread submitted if so then declare winner
Update Asset ownership after declare?

do we identify bids by org only or multiple users from org and have atleast one user 
from org to declare winner?

right now single user is added in org3 

