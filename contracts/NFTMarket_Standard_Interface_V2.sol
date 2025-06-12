//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title An interface of ERC721TokenWithPermit which is checked in function supportsInterface.
 *
 * @author Garen Woo
 */
interface NFTMarket_Standard_Interface_V2 {
    function NFTPermit_PrepareForBuy(address, uint256, uint256, uint8, bytes32, bytes32) external returns (bool);

    function NFTPermit_PrepareForList(address, uint256, uint256, uint256, uint8, bytes32, bytes32)
        external
        returns (bool);

    function launchSpecialOfferWithUniformPrice(bytes32) external view returns (bytes memory);
}