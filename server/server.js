const express = require('express');
const { ethers } = require('ethers');
const fs = require('fs');
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const path = require('path');
const app = express();
const cors = require('cors');
const port = 3001;

app.use(cors());
app.use(express.json());

// Build Merkle tree and save the JSON file in the server.
app.post('/save-merkle-tree', (req, res) => {
    const { values, leafEncoding } = req.body;
    console.log(`values: ${values}`);
    console.log(`leafEncoding: ${leafEncoding}`);
    const tree = StandardMerkleTree.of(values, leafEncoding);
    console.log(`Merkle Root: ${tree.root}`)
    const dirPath = path.join(__dirname, 'NFTProjectFiles');
    const filePath = path.join(dirPath, 'tree.json');

    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
    fs.writeFileSync(filePath, JSON.stringify(tree.dump()));
    res.send({ MerkleRoot: tree.root });
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});

// Load the JSON file which saves the Merkle tree and generate the merkle proof for the on-chain validation.
app.get('/merkle-proof', (req, res) => {
    const queriedInfo = req.query.queriedInfo;
    const dirPath = path.join(__dirname, 'NFTProjectFiles');
    const filePath = path.join(dirPath, 'tree.json');
    const treeData = JSON.parse(fs.readFileSync(filePath, "utf8"));
    const tree = StandardMerkleTree.load(treeData);

    for (const [i, v] of tree.entries()) {
        if (v[0] === queriedInfo) {
            const proof = tree.getProof(i);
            return res.json({
                value: v,
                MerkleProof: proof,
                tokenId: v[1],
                price: v[2]
            });
        }
    }

    res.status(404).send('Queried infomation is not found in the Merkle Tree');
});

// Generate the data of the NFT whitelist and save it in the server.
app.post('/generate-whitelist-data', async (req, res) => {
    const { NFTAddr, MerkleRoot, NFTAbi, network_RPC_URL } = req.body;
    console.log(`NFTAddr: ${NFTAddr}`);
    console.log(`MerkleRoot: ${MerkleRoot}`);
    console.log(`NFTAbi: ${NFTAbi}`);
    console.log(`network_RPC_URL: ${network_RPC_URL}`);
    const provider = new ethers.getDefaultProvider(network_RPC_URL);
    const NFTContract = new ethers.Contract(NFTAddr, NFTAbi, provider);
    let whitelistData;
    try {
        whitelistData = await NFTContract.launchSpecialOfferWithUniformPrice(MerkleRoot);
    } catch (error) {
        console.error(error);
        res.status(500).send('Error calling contract function');
    }
    console.log(`whitelistData: ${whitelistData}`);
    const dirPath = path.join(__dirname, 'NFTProjectFiles');
    const filePath = path.join(dirPath, 'whitelistData.json');

    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
    fs.writeFileSync(filePath, JSON.stringify(whitelistData));
    res.send({ message: "Whitelist data has been saved", whitelistData: whitelistData });
});

// Load the JSON file which contain the data of the whitelist of the NFT.
app.get('/whitelist-data', (req, res) => {
    const dirPath = path.join(__dirname, 'NFTProjectFiles');
    const filePath = path.join(dirPath, 'whitelistData.json');
    const whitelistData = JSON.parse(fs.readFileSync(filePath, "utf8"));
    console.log(`whitelistData@BackEnd: ${whitelistData}`);
    return res.json({
        whitelistData,
    });
});