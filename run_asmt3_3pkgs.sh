#!/bin/bash
FABRIC_DIR=$HOME/sem7/blockchain/asmt3/hyper-ledger-fabric/fabric-samples
CHANNEL=channel1
echo $FABRIC_DIR
export PATH=$FABRIC_DIR/bin:$PATH
# CHAINCODE_JAVASCRIPT_DIR=$FABRIC_DIR/asmt3-eng-auction/chaincode-javascript
CHAINCODE_JAVASCRIPT_DIRS=()
CHAINCODE_JAVASCRIPT_DIRS[0]=$FABRIC_DIR/asmt3-eng-auction/chaincode-javascript
CHAINCODE_JAVASCRIPT_DIRS[1]=$FABRIC_DIR/asmt3-eng-auction/chaincode-javascript
CHAINCODE_JAVASCRIPT_DIRS[2]=$FABRIC_DIR/asmt3-eng-auction/chaincode-javascript

                     
PACKAGE_NAME=engauction.tar.gz
LABEL_NAME=engauction_1.0
LABEL_NO_VERSION=engauction
CHAINCODE_LANG=node
cd $FABRIC_DIR/test-network/

# for logspout to run 
cp ../commercial-paper/organization/digibank/configuration/cli/monitordocker.sh .

echo $PWD
./network.sh down
./network.sh up 
./network.sh createChannel -c $CHANNEL
cd $FABRIC_DIR/test-network/addOrg3/
echo $CHANNEL
./addOrg3.sh up -c $CHANNEL

cd $FABRIC_DIR/test-network/
echo $PWD

# gnome-terminal --tab --title="fabric logs " --command="bash -c './monitordocker.sh net_test; ls; $SHELL'" 

# variables for Org1
ORG1_LOCALMSPID="Org1MSP"
ORG1_TLS_ROOTCERT=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
ORG1_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
ORG1_PEER_ADDRESS=localhost:7051

# variables for Org2
ORG2_LOCALMSPID="Org2MSP"
ORG2_TLS_ROOTCERT=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
ORG2_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
ORG2_PEER_ADDRESS=localhost:9051

# variables for Org3
ORG3_LOCALMSPID="Org3MSP"
ORG3_TLS_ROOTCERT=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt
ORG3_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org3.example.com/users/Admin@org3.example.com/msp
ORG3_PEER_ADDRESS=localhost:11051

ORDERER_PEER_ADDRESS=localhost:7050
ORDERER_TLS_ROOT_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
org_msps=("Org1MSP" "Org2MSP" "Org3MSP")
echo ${org_msps[0]}
org_tls_root_cert=($ORG1_TLS_ROOTCERT $ORG2_TLS_ROOTCERT $ORG3_TLS_ROOTCERT)
echo ${org_tls_root_cert[0]}
org_msp_config_path=($ORG1_MSPCONFIGPATH $ORG2_MSPCONFIGPATH $ORG3_MSPCONFIGPATH)
echo ${org_msp_config_path[1]}
org_peer_address=($ORG1_PEER_ADDRESS $ORG2_PEER_ADDRESS $ORG3_PEER_ADDRESS)
echo ${org_peer_address[2]}

# #package smart contract
# cd $CHAINCODE_JAVASCRIPT_DIR
# echo $PWD
# npm install
# cd $FABRIC_DIR/test-network/
# export PATH=${PWD}/../bin:$PATH
# export FABRIC_CFG_PATH=$PWD/../config/
# peer version
# peer lifecycle chaincode package $PACKAGE_NAME --path $CHAINCODE_JAVASCRIPT_DIR --lang $CHAINCODE_LANG --label $LABEL_NAME


pkg_ids=()
#Install the package on all peers that need to endorse it. As we are using default that is all org(org1, org2, org3) peers
for ((i=0; i<${#org_msps[@]}; i++))
do
#package smart contract
dir=${CHAINCODE_JAVASCRIPT_DIRS[i]}
cd $dir
echo $PWD
npm install
cd $FABRIC_DIR/test-network/
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
peer version
peer lifecycle chaincode package $PACKAGE_NAME --path $dir --lang $CHAINCODE_LANG --label $LABEL_NAME
sleep 3
echo "DOne package"
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${org_msps[i]}
export CORE_PEER_TLS_ROOTCERT_FILE=${org_tls_root_cert[i]}
export CORE_PEER_MSPCONFIGPATH=${org_msp_config_path[i]}
export CORE_PEER_ADDRESS=${org_peer_address[i]}
peer lifecycle chaincode install $PACKAGE_NAME
sleep 3
package_id=$(peer lifecycle chaincode queryinstalled)
package_id1=$(echo $package_id | awk '($0 ~/Package ID: /) { 
	split($0,a,"Package ID: ");
	#print "a[1]:" a[2]

	split(a[2],an,",");
	str=an[1]; 
	#if ($3 ~ /,$/) str=substr($3, 1, length($3)-1)
	print str }')

# echo $package_id1
pkg_ids[i]=$package_id1
done
# once all peers installed now start approve
for ((i=0; i<${#org_msps[@]}; i++))
do
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${org_msps[i]}
export CORE_PEER_TLS_ROOTCERT_FILE=${org_tls_root_cert[i]}
export CORE_PEER_MSPCONFIGPATH=${org_msp_config_path[i]}
export CORE_PEER_ADDRESS=${org_peer_address[i]}
export CC_PACKAGE_ID=${pkg_ids[i]}

echo " pkgid" $CC_PACKAGE_ID
echo $CORE_PEER_LOCALMSPID
#approve from orderer, single orderer for this network for all 3 orgs
peer lifecycle chaincode approveformyorg -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com --channelID $CHANNEL --name $LABEL_NO_VERSION -v 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile $ORDERER_TLS_ROOT_CERT
done
cd $FABRIC_DIR/test-network/

peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL --name $LABEL_NO_VERSION \
--version 1.0 --sequence 1 --tls --cafile $ORDERER_TLS_ROOT_CERT --output json
# commit chaincode
echo "Commit chaincode"

peer lifecycle chaincode commit -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com \
--channelID $CHANNEL --name $LABEL_NO_VERSION --version 1.0 --sequence 1 --tls --cafile \
$ORDERER_TLS_ROOT_CERT \
--peerAddresses ${org_peer_address[0]} \
--tlsRootCertFiles ${org_tls_root_cert[0]} \
--peerAddresses ${org_peer_address[1]} \
--tlsRootCertFiles ${org_tls_root_cert[1]} \
--peerAddresses ${org_peer_address[2]} \
--tlsRootCertFiles ${org_tls_root_cert[2]} 
-
echo "check commit readiness"
for ((i=0; i<${#org_msps[@]}; i++))
do
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${org_msps[i]}
export CORE_PEER_TLS_ROOTCERT_FILE=${org_tls_root_cert[i]}
export CORE_PEER_MSPCONFIGPATH=${org_msp_config_path[i]}
export CORE_PEER_ADDRESS=${org_peer_address[i]}
echo $CORE_PEER_LOCALMSPID
#query committed on all orgs
peer lifecycle chaincode querycommitted --channelID $CHANNEL --name $LABEL_NO_VERSION \
--cafile $ORDERER_TLS_ROOT_CERT
done

echo "call invoke to InitLedger"
echo $CORE_PEER_TLS_ENABLED
echo $CORE_PEER_LOCALMSPID
echo $CORE_PEER_TLS_ROOTCERT_FILE
echo $CORE_PEER_MSPCONFIGPATH
echo $CORE_PEER_ADDRESS


peer chaincode invoke -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com --tls --cafile \
$ORDERER_TLS_ROOT_CERT -C $CHANNEL -n $LABEL_NO_VERSION --peerAddresses ${org_peer_address[0]} \
--tlsRootCertFiles ${org_tls_root_cert[0]} \
--peerAddresses ${org_peer_address[1]} \
--tlsRootCertFiles ${org_tls_root_cert[1]} \
--peerAddresses ${org_peer_address[2]} \
--tlsRootCertFiles ${org_tls_root_cert[2]} \
-c '{"function":"InitLedger","Args":[]}'

# as invoke involves transactions to create block and update ledger which involves endoring by all
# peers(default policy) amd by orderer takes time for ledger to update. wait befor issuing query
sleep 3

peer chaincode query -C $CHANNEL -n $LABEL_NO_VERSION -c '{"Args":["GetAllAssets"]}'


echo "submit bid by each org"
for ((i=0; i<${#org_msps[@]}; i++))
do
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=${org_msps[i]}
export CORE_PEER_TLS_ROOTCERT_FILE=${org_tls_root_cert[i]}
export CORE_PEER_MSPCONFIGPATH=${org_msp_config_path[i]}
export CORE_PEER_ADDRESS=${org_peer_address[i]}
echo $CORE_PEER_LOCALMSPID
if [ $i -eq 0 ]
then
peer chaincode invoke -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_TLS_ROOT_CERT \
-C $CHANNEL -n $LABEL_NO_VERSION --peerAddresses ${org_peer_address[0]} \
--tlsRootCertFiles ${org_tls_root_cert[0]} \
--peerAddresses ${org_peer_address[1]} \
--tlsRootCertFiles ${org_tls_root_cert[1]} \
--peerAddresses ${org_peer_address[2]} \
--tlsRootCertFiles ${org_tls_root_cert[2]} \
-c '{"function":"SubmitBid","Args":["310", "asset1"]}'
elif [ $i -eq 1 ]
then
peer chaincode invoke -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_TLS_ROOT_CERT \
-C $CHANNEL -n $LABEL_NO_VERSION --peerAddresses ${org_peer_address[0]} \
--tlsRootCertFiles ${org_tls_root_cert[0]} \
--peerAddresses ${org_peer_address[1]} \
--tlsRootCertFiles ${org_tls_root_cert[1]} \
--peerAddresses ${org_peer_address[2]} \
--tlsRootCertFiles ${org_tls_root_cert[2]} \
-c '{"function":"SubmitBid","Args":["350", "asset1"]}'
else
peer chaincode invoke -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_TLS_ROOT_CERT \
-C $CHANNEL -n $LABEL_NO_VERSION --peerAddresses ${org_peer_address[0]} \
--tlsRootCertFiles ${org_tls_root_cert[0]} \
--peerAddresses ${org_peer_address[1]} \
--tlsRootCertFiles ${org_tls_root_cert[1]} \
--peerAddresses ${org_peer_address[2]} \
--tlsRootCertFiles ${org_tls_root_cert[2]} \
-c '{"function":"SubmitBid","Args":["400", "asset1"]}'
fi
 
sleep 5
done
# -c '{"function":"SubmitBid","Args":[]}'
# peer chaincode invoke -o $ORDERER_PEER_ADDRESS --ordererTLSHostnameOverride orderer.example.com --tls --cafile \
# $ORDERER_TLS_ROOT_CERT -C $CHANNEL -n $LABEL_NO_VERSION --peerAddresses ${org_peer_address[0]} \
# --tlsRootCertFiles ${org_tls_root_cert[0]} \
# --peerAddresses ${org_peer_address[1]} \
# --tlsRootCertFiles ${org_tls_root_cert[1]} \
# --peerAddresses ${org_peer_address[2]} \
# --tlsRootCertFiles ${org_tls_root_cert[2]} \
# -c '{"function":"SubmitBid","Args":["400", "asset1"]}'
echo "call declareWinner"

peer chaincode query -C $CHANNEL -n $LABEL_NO_VERSION -c '{"Args":["DeclareWinner"]}'


