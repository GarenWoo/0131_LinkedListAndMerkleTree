// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Bank.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title SuperBank can receive ETH and any ERC20 tokens tokens. And also, token balance rank is supported.
 *
 * @author Garen Woo
 */
contract SuperBank_V2_4 is Bank {
    mapping(address tokenAddress => mapping(address userAddress => uint256 balance)) internal tokenBalance;
    // Array realization: state variable `tokenBalanceRank` records the rank of the token balance.
    mapping(address tokenAddress => address[] rankList) internal tokenBalanceRank;
    // The state variable `limitAmountOfRank` only influence the Rank of token balance and its query.
    mapping(address tokenAddress => uint256 limit) internal limitAmountOfRank;
    /**
     * @dev Mapping realization: two mapping variables record the info related to the rank of the token balance.
     * First, state variable `tokenRankIndexToAddr` maps the index to address.
     * Second, state variable `tokenRankAddrToIndex` maps the address to index.
     */
    address constant origin = address(1);
    mapping(address tokenAddress => mapping(uint256 rankIndex => address userAddress)) internal tokenRankIndexToAddr;
    mapping(address tokenAddress => mapping(address userAddress => uint256 rankIndex)) internal tokenRankAddrToIndex;

    using SafeERC20 for IERC20;

    IERC20 internal iERC20Token;

    event tokenReceived(address sender, uint256 amount);
    event tokenWithdrawn(address tokenAddr, uint256 amount);

    error exceededRankLimit(address tokenAddr, uint256 inputAmount, uint256 limitAmount);
    error noSuchTokenInBank(address queriedToken);
    error zeroAmountOfWithdrawal();
    error insufficientTokenBalance(address tokenAddr, uint256 withdrawnAmount, uint256 balance);

    /**
     * @dev In the parent contract `Bank`, the constructor has already declared the owner of the contract.
     * Thus, here is no need to redeclared `owner`.
     */
    constructor() {}

    function depositToken(address _tokenAddr, uint256 _tokenAmount) public {
        iERC20Token = IERC20(_tokenAddr);
        /* 
        Considering the design of those functions with the prefix of "safe" in SafeERC20 library,
        if the token does not support safeTransferFrom, it will turn to call transferFrom instead.
        */
        iERC20Token.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        tokenBalance[_tokenAddr][msg.sender] += _tokenAmount;
        _handleRankOfTokenBalance(_tokenAddr);
    }

    function depositTokenWithPermit(
        address _tokenAddr,
        uint256 _tokenAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        IERC20Permit(_tokenAddr).permit(msg.sender, address(this), _tokenAmount, _deadline, _v, _r, _s);
        iERC20Token = IERC20(_tokenAddr);
        /* 
        Considering the design of those functions with the prefix of "safe" in SafeERC20 library,
        if the token does not support safeTransferFrom, it will turn to call transferFrom instead.
        */
        iERC20Token.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        tokenBalance[_tokenAddr][msg.sender] += _tokenAmount;
        _handleRankOfTokenBalance(_tokenAddr);
    }

    /**
     * @notice Any user can withdraw any amount of tokens which are already deposited by him(her).
     */
    function withdrawTokenByUser(address _tokenAddr, uint256 _amount) public {
        iERC20Token = IERC20(_tokenAddr);
        uint256 userTokenBalanceInBank = tokenBalance[_tokenAddr][msg.sender];
        if (_amount == 0) {
            revert zeroAmountOfWithdrawal();
        }
        if (_amount > userTokenBalanceInBank) {
            revert insufficientTokenBalance(_tokenAddr, _amount, userTokenBalanceInBank);
        }
        /* 
        Considering the design of those functions with the prefix of "safe" in SafeERC20 library,
        if the token does not support safeTransfer, it will turn to call transfer instead.
        */
        iERC20Token.safeTransfer(msg.sender, _amount);
        tokenBalance[_tokenAddr][msg.sender] -= _amount;
        emit tokenWithdrawn(_tokenAddr, _amount);
    }

    function tokensReceived(address _tokenAddr, address _from, uint256 _amount) external returns (bool) {
        tokenBalance[_tokenAddr][_from] += _amount;
        emit tokenReceived(_from, _amount);
        return true;
    }

    function setLimitAmountOfRank(address _tokenAddr, uint256 _newLimit) external onlyOwner {
        require(_newLimit >= 0, "invalid limit of Rank");
        uint256 previousLimit = limitAmountOfRank[_tokenAddr];
        limitAmountOfRank[_tokenAddr] = _newLimit;
        address[] memory rankArray = new address[](_newLimit);

        for (uint256 i = 0; i < previousLimit && i < _newLimit; i++) {
            rankArray[i] = tokenBalanceRank[_tokenAddr][i];
        }

        tokenBalanceRank[_tokenAddr] = rankArray;
    }

    function getLimitAmountOfRank(address _tokenAddr) public view returns (uint256) {
        if (limitAmountOfRank[_tokenAddr] == 0) {
            revert noSuchTokenInBank(_tokenAddr);
        }
        return limitAmountOfRank[_tokenAddr];
    }

    function getTokenBalance(address _tokenAddr, address _account) public view returns (uint256) {
        return tokenBalance[_tokenAddr][_account];
    }

    function getTokenRankAccountsByArray(address _tokenAddr, uint256 _amountInRank)
        public
        view
        returns (address[] memory)
    {
        if (limitAmountOfRank[_tokenAddr] == 0) {
            revert noSuchTokenInBank(_tokenAddr);
        }
        if (_amountInRank > limitAmountOfRank[_tokenAddr]) {
            revert exceededRankLimit(_tokenAddr, _amountInRank, limitAmountOfRank[_tokenAddr]);
        }
        address[] memory rankList = new address[](_amountInRank);

        for (uint256 i = 0; i < _amountInRank; i++) {
            rankList[i] = tokenBalanceRank[_tokenAddr][i];
        }
        return rankList;
    }

    function getTokenRankAccountsByMapping(address _tokenAddr, uint256 _amountInRank)
        public
        view
        returns (address[] memory)
    {
        if (limitAmountOfRank[_tokenAddr] == 0) {
            revert noSuchTokenInBank(_tokenAddr);
        }
        if (_amountInRank > limitAmountOfRank[_tokenAddr]) {
            revert exceededRankLimit(_tokenAddr, _amountInRank, limitAmountOfRank[_tokenAddr]);
        }
        address[] memory rankList = new address[](_amountInRank);

        for (uint256 i = 0; i < _amountInRank; i++) {
            rankList[i] = tokenRankIndexToAddr[_tokenAddr][i + 1];
        }
        return rankList;
    }

    /**
     * @dev This function is used for handle all the ranks supported in this contracts.
     *
     * @notice Currently, the top3-rank and top10-rank are supported.
     *
     * @param _tokenAddr the address of the ERC20 token contract which is related to this token balance rank.
     */
    function _handleRankOfTokenBalance(address _tokenAddr) internal {
        _checkAndInitialLengthOfRankArray(_tokenAddr);
        _executeRankMappingOfTokenBalance(_tokenAddr, limitAmountOfRank[_tokenAddr]);
        _executeRankArrayOfTokenBalance(_tokenAddr, limitAmountOfRank[_tokenAddr]);
    }

    function _checkAndInitialLengthOfRankArray(address _tokenAddr) internal {
        // If limitAmountOfRank[_tokenAddr] has not been initialized(When the deposit of this token occurs for the first time),
        // initialize it with the value of 10(This value can be modified by function `setLimitAmountOfRank` which can only be called by the owner of this contract).
        if (limitAmountOfRank[_tokenAddr] == 0) {
            limitAmountOfRank[_tokenAddr] = 10;
            uint256 limit = limitAmountOfRank[_tokenAddr];
            address[] memory rankArray = new address[](limit);
            tokenBalanceRank[_tokenAddr] = rankArray;
        }
    }

    /**
     * @dev This rank algorithm of listing the top several users with the highest token balances has been realized in the form of mapping in the following function.
     * The algorithm is created by Garen Woo. Withdrawal is not considered in this function.
     *
     * @param _tokenAddr the address of the ERC20 token contract which is related to this token balance rank.
     * @param _amountInRank the amount of addresses need to be involved in the rank list.
     *
     * @notice First, `minIndexOccupied` is a variable declared in the function body. It‘s the minimum index that the token balance of the current address has exceeded.
     * Second, `indexToStartMoving` is a variable declared in the function body. Its usage is as follows:
     * When the depositor is not involved in the rank list, `indexToStartMoving` will record the largest index of the rank list.
     * When the depositor has been in the rank list, `indexToStartMoving` will record the index which follows the updated index of the depositor after the deposit.
     */
    function _executeRankMappingOfTokenBalance(address _tokenAddr, uint256 _amountInRank) internal {
        // Check if the index 0 of `tokenRankIndexToAddr` in the contract of `_tokenAddr` maps to address(0).
        // If true, it means that the `tokenRankIndexToAddr` hasn't been ininitialized. Then, initialize it with `origin`'s address.
        // If false, it means that `tokenRankIndexToAddr` has already been initialized.
        if (tokenRankIndexToAddr[_tokenAddr][0] == address(0)) {
            tokenRankIndexToAddr[_tokenAddr][0] = origin;
            tokenRankAddrToIndex[_tokenAddr][origin] = 0;
        }
        // Except for the index of `origin` which is set to be 0, the index of any address else is defaulted to be 0 which means nonmembership of the rank.
        // However, any address except for `origin` cannot reach the index of 0 after being involved in this rank ever.
        bool isInRank = tokenRankAddrToIndex[_tokenAddr][msg.sender] != 0;
        uint256 minIndexOccupied = type(uint256).max - 1;
        uint256 maxIndexToStartLoop;
        uint256 indexToStartMoving;

        if (isInRank) {
            // Case 1: msg.sender is already inside the rank mapping
            // The maximum index of the for-loop is the one in front of the index of `msg.sender`.
            maxIndexToStartLoop = tokenRankAddrToIndex[_tokenAddr][msg.sender];
            indexToStartMoving = tokenRankAddrToIndex[_tokenAddr][msg.sender];
        } else {
            // Case 2: msg.sender is not in the rank mapping.
            // Since the depositor is not involved in the rank before the deposit, so this loop starts from `_amountInRank`(regard as a virtual index follows the tail-index of the rank) and ends at 2.
            maxIndexToStartLoop = _amountInRank + 1;
            indexToStartMoving = _amountInRank;
        }

        // For-loop: traverse elements from `maxIndexToStartLoop` to the start according to the index
        // Notice that index 0 is always mapping to origin. So, index 1 is the actual first-place of the rank.
        for (uint256 i = maxIndexToStartLoop; i > 1; i--) {
            uint256 userBalance = tokenBalance[_tokenAddr][msg.sender];
            address previousUser = tokenRankIndexToAddr[_tokenAddr][i - 1];
            uint256 previousUserBalance = tokenBalance[_tokenAddr][previousUser];

            if (userBalance >= previousUserBalance) {
                // If the current address has won a new index which is in front of the current index of it,
                // record the new index by the variable `minIndexOccupied`.
                minIndexOccupied = i - 1;
            } else {
                break;
            }
        }
        // All elements located after the current index(i.e. `minIndexOccupied`) are moved back by one index.
        // If minIndexOccupied is not given a value in the previous traversal, the following for-loop will be skipped.
        for (uint256 j = indexToStartMoving; j > minIndexOccupied; j--) {
            address previousUser = tokenRankIndexToAddr[_tokenAddr][j - 1];
            tokenRankIndexToAddr[_tokenAddr][j] = previousUser;
            tokenRankAddrToIndex[_tokenAddr][previousUser] = j;
        }

        // Set the two mapping variables according to `minIndexOccupied` after the completion of both the loop and the moving back of those "rear elements".
        if (minIndexOccupied != type(uint256).max - 1) {
            tokenRankAddrToIndex[_tokenAddr][msg.sender] = minIndexOccupied;
            tokenRankIndexToAddr[_tokenAddr][minIndexOccupied] = msg.sender;
        }
    }

    /**
     * @dev This rank algorithm of listing the top several users with the highest token balances has been realized in the form of array in the following function.
     * The algorithm is created by Garen Woo. Withdrawal is not considered in this function.
     *
     * @param _tokenAddr the address of the ERC20 token contract which is related to this token balance rank.
     * @param _amountInRank the amount of addresses need to be involved in the rank list.
     *
     * @notice First, `minIndexOccupied` is a variable declared in the function body. It‘s the minimum index that the token balance of the current address has exceeded.
     * Second, `indexToStartMoving` is a variable declared in the function body. Its usage is as follows:
     * When the depositor is not involved in the rank list, `indexToStartMoving` will record the largest index of the rank list.
     * When the depositor has been in the rank list, `indexToStartMoving` will record the index which follows the updated index of the depositor after the deposit.
     */
    function _executeRankArrayOfTokenBalance(address _tokenAddr, uint256 _amountInRank) internal {
        uint256 membershipIndex = _checkTokenRankMembership(_tokenAddr, _amountInRank);
        uint256 minIndexOccupied = type(uint256).max - 1;
        uint256 maxIndexToStartLoop;
        uint256 indexToStartMoving;

        if (membershipIndex != type(uint256).max - 2) {
            // Case 1: msg.sender is already inside the rank array
            // The maximum index of the for-loop is the one in front of the index of `msg.sender`.
            maxIndexToStartLoop = membershipIndex;
            indexToStartMoving = membershipIndex;
        } else {
            // Case 2: msg.sender is not in the rank array
            // Since the depositor is not involved in the rank before the deposit, so this loop starts from `_amountInRank`(regard as a virtual index follows the tail-index of the rank) and ends at 1.
            maxIndexToStartLoop = _amountInRank;
            indexToStartMoving = _amountInRank - 1;
        }
        // Boundary case: membershipIndex == 0, is not suitable for this traversal. It means that the token balance of the current account have already at the index 0.
        // Thus, this traversal ends at 1.
        for (uint256 i = maxIndexToStartLoop; i > 0; i--) {
            // i - 1, is the index whose token balance is compared with in the current loop.
            address previousUser = tokenBalanceRank[_tokenAddr][i - 1];
            if (tokenBalance[_tokenAddr][msg.sender] >= tokenBalance[_tokenAddr][previousUser]) {
                // If the current address has won a new index which is in front of the current index of it,
                // record the new index by the variable `minIndexOccupied`.
                minIndexOccupied = i - 1;
            } else {
                break;
            }
        }
        // All elements located after the current index(i.e. `minIndexOccupied`) are moved back by one index.
        for (uint256 j = indexToStartMoving; j > minIndexOccupied; j--) {
            tokenBalanceRank[_tokenAddr][j] = tokenBalanceRank[_tokenAddr][j - 1];
        }

        // Set the value of `tokenBalanceRank[_tokenAddr][minIndexOccupied]` according to `minIndexOccupied` after the completion of both the loop and the moving back of those "rear elements".
        if (minIndexOccupied != type(uint256).max - 1) {
            tokenBalanceRank[_tokenAddr][minIndexOccupied] = msg.sender;
        }
    }

    /**
     * @dev Check if the depositor is already in the rank list.
     *
     * @param _amountInRank the amount of addresses need to be involved in the rank list
     */
    function _checkTokenRankMembership(address _tokenAddr, uint256 _amountInRank) internal view returns (uint256) {
        uint256 index = type(uint256).max - 2;
        for (uint256 i = 0; i < _amountInRank; i++) {
            if (tokenBalanceRank[_tokenAddr][i] == msg.sender) {
                index = i;
                break;
            }
        }
        return index;
    }
}
