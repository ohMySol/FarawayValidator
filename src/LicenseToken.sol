// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title License Token Contract
 * @author Anton
 * @notice Contract with functionality for ERC-721 token, which represents a unique license.
 */
contract LicenseToken is ERC721, Ownable {
    uint256 private _tokenId;

    constructor()
        ERC721("License", "LCNS")
        Ownable(msg.sender)
    {}

    /**
     * @dev Mints new License token, and assign `_to` as token owner. 
     * 
     * Restrictions:
     *  - can only be called by contract owner.
     * 
     * @param _to address which will receive a unique token.
     */
    function safeMint(address _to) public onlyOwner {
        uint256 tokenId = _tokenId++;
        _safeMint(_to, tokenId);
    }
}