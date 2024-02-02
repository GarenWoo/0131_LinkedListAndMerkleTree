// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // const ERC20Token_GTT = await hre.ethers.getContractFactory("ERC20Token_GTT");
  // const GTT = await ERC20Token_GTT.deploy();
  // await GTT.waitForDeployment();
  // const ERC20Token_GTTAddr = GTT.target;
  // console.log("ERC20Token_GTT contract has been deployed to: " + ERC20Token_GTTAddr);

  // const ERC777Token_GTST = await hre.ethers.getContractFactory("ERC777Token_GTST");
  // const GTST = await ERC777Token_GTST.deploy();
  // await GTST.waitForDeployment();
  // const ERC777Token_GTSTAddr = GTST.target;
  // console.log("ERC777Token_GTST contract has been deployed to: " + ERC777Token_GTSTAddr);

  // const FairTokenGFTContract = await hre.ethers.getContractFactory("FairTokenGFT");
  // const GFT = await FairTokenGFTContract.deploy();
  // await GFT.waitForDeployment();
  // const FairTokenGFTAddr = GFT.target;
  // console.log("FairTokenGFT contract has been deployed to: " + FairTokenGFTAddr);

  // const ERC721TokenWithPermitContract = await hre.ethers.getContractFactory("ERC721TokenWithPermit");
  // const ERC721TokenWithPermit = await ERC721TokenWithPermitContract.deploy();
  // await ERC721TokenWithPermit.waitForDeployment();
  // const ERC721TokenWithPermitAddr = ERC721TokenWithPermit.target;
  // console.log("ERC721TokenWithPermit contract has been deployed to: " + ERC721TokenWithPermitAddr);

  const SuperBank_V2_4_Contract = await hre.ethers.getContractFactory("SuperBank_V2_4");
  const SuperBank_V2_4 = await SuperBank_V2_4_Contract.deploy();
  await SuperBank_V2_4.waitForDeployment();
  const SuperBank_V2_4_Addr = SuperBank_V2_4.target;
  console.log("SuperBank_V2_4 contract has been deployed to: " + SuperBank_V2_4_Addr);

  // const ERC777Token_GTSTAddr = "0x94B1424C3435757E611F27543eedB37bcD3BDEb4";
  // const NFTMarketV2Contract = await hre.ethers.getContractFactory("NFTMarketV2");
  // const NFTMarketV2 = await NFTMarketV2Contract.deploy(ERC777Token_GTSTAddr);
  // await NFTMarketV2.waitForDeployment();
  // const NFTMarketV2Addr = NFTMarketV2.target;
  // console.log("NFTMarketV2 contract has been deployed to: " + NFTMarketV2Addr);

  // const ERC20TokenFactoryContract = await hre.ethers.getContractFactory("ERC20TokenFactory");
  // const ERC20TokenFactory = await ERC20TokenFactoryContract.deploy(FairTokenGFTAddr);
  // await ERC20TokenFactory.waitForDeployment();
  // const ERC20TokenFactoryAddr = ERC20TokenFactory.target;
  // console.log("ERC20TokenFactory contract has been deployed to: " + ERC20TokenFactoryAddr);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
