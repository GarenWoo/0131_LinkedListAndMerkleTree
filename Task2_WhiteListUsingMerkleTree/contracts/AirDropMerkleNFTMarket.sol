//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface NFTMarket_Standard_Interface_V2 {
    function NFTPermit_PrepareForBuy(address, uint256, uint256, uint8, bytes32, bytes32) external returns (bool);

    function NFTPermit_PrepareForList(address, uint256, uint256, uint256, uint8, bytes32, bytes32)
        external
        returns (bool);

    function launchSpecialOfferWithUniformPrice(bytes32) external pure returns (bytes memory);
}

/**
 * @title This is a NFT exchange contract that can provide trading for ERC721 Tokens. Various ERC721 tokens are able to be traded here.
 * This contract was updated from `NFTMarket_V3`.
 *
 * @author Garen Woo
 */
contract AirDropMerkleNFTMarket is IERC721Receiver {
    address private owner;
    address public tokenAddr;
    mapping(address NFTAddr => mapping(uint256 tokenId => uint256 priceOfNFT)) private price;
    mapping(address user => uint256 tokenAmount) private userProfit;
    mapping(address NFTAddr => mapping(uint256 tokenId => bool isOnSale)) public onSale;

    struct Call {
        address target;
        bytes callData;
    }
    mapping(address user => Call[] calls) internal arrayOfMultiCalls;

    event NFTListed(address NFTAddr, uint256 tokenId, uint256 price);
    event NFTDelisted(address NFTAddr, uint256 tokenId);
    event NFTBought(address NFTAddr, uint256 tokenId, uint256 bidValue);
    event NFTBoughtWithPermit(address NFTAddr, uint256 tokenId, uint256 bidValue);
    event withdrawBalance(address withdrawer, uint256 withdrawnValue);
    event prepay(address tokenOwner, uint256 tokenAmount);
    event NFTClaimed(address NFTAddr, uint256 tokenId, address user);

    error zeroPrice();
    error notOwnerOfNFT();
    error notOwnerOfNFTMarket();
    error bidLessThanPrice(uint256 bidAmount, uint256 priceAmount);
    error notOnSale(address tokenAddress, uint256 tokenId);
    error withdrawalExceedBalance(uint256 withdrawAmount, uint256 balanceAmount);
    error ERC721PermitBoughtByWrongFunction(string calledFunction, string validFunction);
    error expiredSignature(uint256 currentTime, uint256 deadline);

    using SafeERC20 for IERC20;

    constructor(address _tokenAddr) {
        tokenAddr = _tokenAddr;
        owner = msg.sender;
    }

    modifier onlyOwnerNFTMarket() {
        if (msg.sender != owner) {
            revert notOwnerOfNFTMarket();
        }
        _;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    /**
     * @notice Once this function is called, the 'msg.sender' will try to buy NFT with the token transferred.
     * The NFT address and tokenId of the NFT separately come from `nftAddress` and 'tokenId', which are decoded from the `data` in the input list.
     *
     * @dev Important! If your NFT project supports the function of buying NFT with off-chain signature of messages(i.e.permit), make sure the NFT contract(s) should have realized NFTMarket_Standard_Interface_V2.
     * Without the realization of NFTMarket_Standard_Interface_V2, malevolent EOAs can directly buy NFTs without permit-checking.
     */
    function tokensReceived(address _recipient, uint256 _amount, bytes calldata _data) external {
        (address nftAddress, uint256 tokenId) = abi.decode(_data, (address, uint256));
        bool checkResult = _beforeUpdateNFT(_recipient, nftAddress, tokenId, _amount);
        bool hasNFTMarketStandardInterface_V2 = _support_NFTMarketStandardInterface(nftAddress);
        if (hasNFTMarketStandardInterface_V2) {
            revert ERC721PermitBoughtByWrongFunction("buy", "buyWithPermit");
        }
        if (checkResult) {
            _updateNFT(_recipient, nftAddress, tokenId, _amount);
            emit NFTBought(nftAddress, tokenId, _amount);
        }
    }

    /* Once the NFT is listed:
     1. The actual owner of the NFT is the NFT exchange.
     2. The previous owner of the NFT(the EOA who lists the NFT) is the current '_tokenApprovals'(@ERC721.sol) of the NFT.
     3. The spender which needs to be approved should be set as the buyer.
     */
    function list(address _nftAddr, uint256 _tokenId, uint256 _price) external {
        if (msg.sender != IERC721(_nftAddr).ownerOf(_tokenId)) {
            revert notOwnerOfNFT();
        }
        if (_price == 0) revert zeroPrice();
        require(onSale[_nftAddr][_tokenId] == false, "This NFT is already listed");
        _List(_nftAddr, _tokenId, _price);
    }

    /**
     * @dev Besides `list`, this function is also used to list NFT on a NFT exchange.
     *  this function verifies off-chain signature of the message signed by the owner of the NFT.
     *  List NFT in this way can have better user experience, because valid signature will lead to automatic approval.
     */
    function listWithPermit(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        if (_price == 0) revert zeroPrice();
        require(onSale[_nftAddr][_tokenId] == false, "This NFT is already listed");
        bool isPermitVerified = NFTMarket_Standard_Interface_V2(_nftAddr).NFTPermit_PrepareForList(
            address(this), _tokenId, _price, _deadline, _v, _r, _s
        );
        if (isPermitVerified) {
            _List(_nftAddr, _tokenId, _price);
        }
    }

    /// @dev The seller(EOA), is the owner of the NFT when it was not listed.
    function delist(address _nftAddr, uint256 _tokenId) external {
        require(IERC721(_nftAddr).getApproved(_tokenId) == msg.sender, "Not seller or Not on sale");
        if (onSale[_nftAddr][_tokenId] != true) revert notOnSale(_nftAddr, _tokenId);
        IERC721(_nftAddr).safeTransferFrom(address(this), msg.sender, _tokenId, "Delist successfully");
        delete price[_nftAddr][_tokenId];
        onSale[_nftAddr][_tokenId] = false;
        emit NFTDelisted(_nftAddr, _tokenId);
    }

    /**
     * @notice Directly Buy NFT without checking ERC721 token permit.
     *
     * @dev Important! If your NFT project supports the function of buying NFT with off-chain signature of messages(i.e.permit), make sure the NFT contract(s) should have realized NFTMarket_Standard_Interface_V2.
     * Without the realization of NFTMarket_Standard_Interface_V2, malevolent EOAs can directly buy NFTs without permit-checking.
     */
    function buy(address _nftAddr, uint256 _tokenId, uint256 _bidValue) external {
        bool checkResult = _beforeUpdateNFT(msg.sender, _nftAddr, _tokenId, _bidValue);
        bool hasNFTMarketStandardInterface_V2 = _support_NFTMarketStandardInterface(_nftAddr);
        if (hasNFTMarketStandardInterface_V2) {
            revert ERC721PermitBoughtByWrongFunction("buy", "buyWithPermit");
        }
        if (checkResult) {
            _updateNFT(msg.sender, _nftAddr, _tokenId, _bidValue);
            emit NFTBought(_nftAddr, _tokenId, _bidValue);
        }
    }

    /* 
        Buy NFT with checking the white-list membership of the msg.sender.
    */
    function buyWithPermit(
        address _nftAddr,
        uint256 _tokenId,
        uint256 _bidValue,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        bool checkResult = _beforeUpdateNFT(msg.sender, _nftAddr, _tokenId, _bidValue);
        bool isPermitVerified = NFTMarket_Standard_Interface_V2(_nftAddr).NFTPermit_PrepareForBuy(
            msg.sender, _tokenId, _deadline, _v, _r, _s
        );
        if (checkResult && isPermitVerified) {
            _updateNFT(msg.sender, _nftAddr, _tokenId, _bidValue);
            emit NFTBoughtWithPermit(_nftAddr, _tokenId, _bidValue);
        }
    }

    function withdrawBalanceByUser(uint256 _value) external {
        if (_value > userProfit[msg.sender]) {
            revert withdrawalExceedBalance(_value, userProfit[msg.sender]);
        }
        bool _success = IERC20(tokenAddr).transfer(msg.sender, _value);
        require(_success, "withdrawal failed");
        userProfit[msg.sender] -= _value;
        emit withdrawBalance(msg.sender, _value);
    }

    /**
     * @dev modify the price of the NFT of the specific tokenId.
     */
    function modifyPriceForNFT(address _nftAddr, uint256 _tokenId, uint256 _newPrice) public {
        require(IERC721(_nftAddr).getApproved(_tokenId) != msg.sender, "Not seller or Not on sale");
        price[_nftAddr][_tokenId] = _newPrice;
    }

    /**
     * @dev  supports users to pre-approve `address(this)` with ERC2612(ERC20-Permit) tokens by signing messages off-chain.
     * This function is usually called before calling `claimNFT`.
     */
    function PermitPrePay(uint256 _tokenAmount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) public returns (bool) {
        IERC20Permit(tokenAddr).permit(msg.sender, address(this), _tokenAmount, _deadline, _v, _r, _s);
        emit prepay(msg.sender, _tokenAmount);
        return true;
    }

    /**
     * @notice Users who are allowed to get NFTs with agreed prices.
     * The membership of the whitelist should be in the form of a Merkle tree.
     * Before calling this function, the user should approve `address(this)` with sufficient allowance.
     * The function `PermitPrePay` is recommended for the approval.
     *
     * @param _promisedTokenId the tokenId corresponds to the NFT which is specified to a member in the NFT's whitelist
     * @param _merkleProof a dynamic array which contains Merkle proof is used for validating the membership of the caller. This should be offered by the project party
     * @param _promisedPrice the promised price of the NFT corresponding to `_promisedTokenId`, which is one of the fields of each Merkle tree node
     * @param _NFTWhitelistData a bytes variable offered by the owner of NFT Project. it contains the compressed infomation about the NFT whitelist
     */
    function claimNFT(uint256 _promisedTokenId, bytes32[] memory _merkleProof, uint256 _promisedPrice, bytes memory _NFTWhitelistData)
        public
    {
        (address whitelistNFTAddr, bytes32 MerkleRoot) = abi.decode(_NFTWhitelistData, (address, bytes32));
        // Verify the membership of whitelist using Merkle tree.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _promisedTokenId, _promisedPrice))));
        _verifyMerkleProof(_merkleProof, MerkleRoot, leaf);
        // Considering the design of those functions with the prefix of "safe" in SafeERC20 library,
        // if the token does not support `safeTransferFrom`, it will turn to call `transferFrom` instead.
        IERC20(tokenAddr).safeTransferFrom(msg.sender, address(this), _promisedPrice);
        address NFTOwner = IERC721(whitelistNFTAddr).ownerOf(_promisedTokenId);
        IERC721(whitelistNFTAddr).transferFrom(NFTOwner, msg.sender, _promisedTokenId);
        emit NFTClaimed(whitelistNFTAddr, _promisedTokenId, msg.sender);
    }

    function aggregate() public returns(uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](arrayOfMultiCalls[msg.sender].length);
        for (uint256 i = 0; i < arrayOfMultiCalls[msg.sender].length; i++) {
            (bool success, bytes memory returnBytes) = arrayOfMultiCalls[msg.sender][i].target.call(arrayOfMultiCalls[msg.sender][i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = returnBytes;
        }
    }

    function pushCall_PermitPrePay(bool _resetArrayOfCalls, uint256 _tokenAmount, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) public {
        bytes memory callData_PermitPrePay = abi.encodeWithSignature("function PermitPrePay(address,uint256,uint256,uint8,bytes32,bytes32)", _tokenAmount, _deadline, _v, _r, _s);
        Call memory currentCall = Call ({
            target: address(this),
            callData: callData_PermitPrePay
        });
        if (_resetArrayOfCalls) {
            delete arrayOfMultiCalls[msg.sender];
        }
        arrayOfMultiCalls[msg.sender].push(currentCall);
    }

    function pushCall_ClaimNFT(bool _resetArrayOfCalls, uint256 _promisedTokenId, bytes32[] memory _merkleProof, uint256 _promisedPrice, bytes memory _NFTWhitelistData) public {
        bytes memory callData_ClaimNFT = abi.encodeWithSignature("function claimNFT(uint256,bytes32[],uint256,bytes)", _promisedTokenId, _merkleProof, _promisedPrice, _NFTWhitelistData);
        Call memory currentCall = Call ({
            target: address(this),
            callData: callData_ClaimNFT
        });
        if (_resetArrayOfCalls) {
            delete arrayOfMultiCalls[msg.sender];
        }
        arrayOfMultiCalls[msg.sender].push(currentCall);
    }

    /**
     * @dev This function is used to change the owner of this contract by modifying slot.
     */
    function changeOwnerOfNFTMarket(address _newOwner) public onlyOwnerNFTMarket {
        assembly {
            sstore(0, _newOwner)
        }
    }

    /**
     * @dev This function is used to get the owner of this contract by modifying slot.
     */
    function getOwnerOfNFTMarket() public view returns (address ownerAddress) {
        assembly {
            ownerAddress := sload(0)
        }
    }

    function checkIfApprovedByNFT(address _nftAddr, uint256 _tokenId) public view returns (bool) {
        bool isApproved = false;
        if (IERC721(_nftAddr).getApproved(_tokenId) == address(this)) {
            isApproved = true;
        }
        return isApproved;
    }

    function _verifyMerkleProof(bytes32[] memory _proof, bytes32 _root, bytes32 _leaf) internal pure {
        require(MerkleProof.verify(_proof, _root, _leaf), "Invalid Merkle proof");
    }

    function _support_NFTMarketStandardInterface(address _nftAddr) internal view returns (bool) {
        bytes4 NFTMarket_Standard_Interface_V2_Id = type(NFTMarket_Standard_Interface_V2).interfaceId;
        IERC165 NFTContract = IERC165(_nftAddr);
        return NFTContract.supportsInterface(NFTMarket_Standard_Interface_V2_Id);
    }

    function _List(address _nftAddr, uint256 _tokenId, uint256 _price) internal {
        IERC721(_nftAddr).safeTransferFrom(msg.sender, address(this), _tokenId, "List successfully");
        IERC721(_nftAddr).approve(msg.sender, _tokenId);
        price[_nftAddr][_tokenId] = _price;
        onSale[_nftAddr][_tokenId] = true;
        emit NFTListed(_nftAddr, _tokenId, _price);
    }

    function _beforeUpdateNFT(address _recipient, address _nftAddr, uint256 _tokenId, uint256 _tokenAmount)
        internal
        view
        returns (bool)
    {
        if (onSale[_nftAddr][_tokenId] != true) {
            revert notOnSale(_nftAddr, _tokenId);
        }
        if (_tokenAmount < price[_nftAddr][_tokenId]) {
            revert bidLessThanPrice(_tokenAmount, price[_nftAddr][_tokenId]);
        }
        require(
            // When NFT listed, the previous owner(EOA, the seller) should be approved. So, this EOA can delist NFT whenever he/she wants.
            // After NFT is listed successfully, getApproved() will return the orginal owner of the listed NFT.
            _recipient != IERC721(_nftAddr).getApproved(_tokenId),
            "Owner cannot buy!"
        );
        return true;
    }

    function _updateNFT(address _recipient, address _nftAddr, uint256 _tokenId, uint256 _tokenAmount) internal {
        userProfit[IERC721(_nftAddr).getApproved(_tokenId)] += _tokenAmount;
        bool _success = IERC20(tokenAddr).transferFrom(_recipient, address(this), _tokenAmount);
        require(_success, "Fail to buy or Allowance is insufficient");
        IERC721(_nftAddr).transferFrom(address(this), _recipient, _tokenId);
        delete price[_nftAddr][_tokenId];
        onSale[_nftAddr][_tokenId] = false;
    }

    function getNFTPrice(address _nftAddr, uint256 _tokenId) external view returns (uint256) {
        return price[_nftAddr][_tokenId];
    }

    function getUserProfit() external view returns (uint256) {
        return userProfit[msg.sender];
    }

    function getNFTOwner(address _nftAddr, uint256 _tokenId) external view returns (address) {
        return IERC721(_nftAddr).ownerOf(_tokenId);
    }
}
