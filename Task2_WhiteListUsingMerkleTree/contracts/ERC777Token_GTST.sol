// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITokenBank {
    function tokensReceived(address, uint256) external returns (bool);
}

interface INFTMarket {
    function tokensReceived(address, uint256, bytes calldata) external;
}

contract ERC777Token_GTST is ERC20, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for ERC777Token_GTST;
    using Address for address;

    address public owner;

    error NotOwner(address caller);
    error NoTokenReceived();
    error transferTokenFail();
    error NotContract();

    event TokenMinted(uint256 amount, uint256 timestamp);

    constructor() ERC20("Garen Test Safe Token", "GTST") ERC20Permit("Garen Test Safe Token") {
        owner = msg.sender;
        /// @dev Initial totalsupply is 100,000
        _mint(msg.sender, 100000 * (10 ** uint256(decimals())));
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
        emit TokenMinted(_amount, block.timestamp);
    }

    // ERC20 Token Callback:
    function transferWithCallback(address _to, uint256 _amount) external nonReentrant returns (bool) {
        bool transferSuccess = transfer(_to, _amount);
        if (!transferSuccess) {
            revert transferTokenFail();
        }
        if (_isContract(_to)) {
            bool success = ITokenBank(_to).tokensReceived(msg.sender, _amount);
            if (!success) {
                revert NoTokenReceived();
            }
        }
        return true;
    }

    // ERC721 Token Callback:
    // @param: _data contains information of NFT, including ERC721Token address, tokenId and other potential information.
    function transferWithCallbackForNFT(address _to, uint256 _bidAmount, bytes calldata _data)
        external
        nonReentrant
        returns (bool)
    {
        if (_isContract(_to)) {
            INFTMarket(_to).tokensReceived(msg.sender, _bidAmount, _data);
        } else {
            revert NotContract();
        }
        return true;
    }

    function getBytesOfNFTInfo(address _NFTAddr, uint256 _tokenId) public pure returns (bytes memory) {
        bytes memory NFTInfo = abi.encode(_NFTAddr, _tokenId);
        return NFTInfo;
    }

    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
