// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Reward Token Contract
 * @author Anton
 * @notice Contract with functionality for ERC-20 token, which stands for rewards which validators will
 * earn during the license staking.
 */
contract RewardToken is ERC20, Ownable {
    constructor(address _owner)
        ERC20("Reward", "RWD")
        Ownable(_owner)
    {}

    /**
     * @dev Mints Reward tokens `_amount` to `_to` address.
     * 
     * Restrictions:
     *  - Can only be called by contract owner.
     * 
     * @param _to address which will receive a token.
     * @param _amount amount of tokens which will be minted.
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}