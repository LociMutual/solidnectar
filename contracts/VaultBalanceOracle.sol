// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

// https://soenkeba.medium.com/truly-decentralized-nfts-by-erc-1155-b9be28db2aae

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./DecentralizedERC1155.sol";

/** 
 * @title VaultBalanceOracle
 * @dev Coordinates the evidence of a balance in a physical vault.
 */
contract VaultBalanceOracle is DecentralizedERC1155, ERC1155Supply, AccessControl {
    bytes32 public constant GOV_ROLE = keccak256("GOV_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    event Report(address auditor, uint256 vaultID, uint256 assetId, uint256 proofID, uint256 balance);

    // Auditor takes snapshot of bank statement.
    // Auditor uploads snapshot to Pinata and obtains IPFS hash for the document as proof.
    // Auditor invokes mint or burn transaction and to adjust the proven reserve balance.

    constructor()
    {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles including revoking itself after assigning
        // GOV_ROLE to the one and only Governor.
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // Certain roles must be voted by Governor.
        _setRoleAdmin(FIAT_CASHIER_ROLE, GOV_ROLE);
    }

    function report(uint256 vaultID, uint256 assetID, uint256 proofId, uint256 balance)
        public
        onlyRole(AUDITOR_ROLE)
    {
        uint256 supply = totalSupply(vaultId);
    
        // The totalSupply(vaultID) tracks the real world fiat vault balance.
        // with all tokens owned by this contract.  Only the totalSupply(vaultID)
        // matters for use as an oracle.
        //
        // totalSupply(assetID) tracks the real world sum of all vault
        // balances for the 
        //
        if (balance > supply) {
            uint256 increase = balance - supply;
            _mint(address(this), vaultID, increase, ""); // for the specific vault
            _mint(address(this), assetID, increase, ""); // total of all vaults contributing to the asset
        }
        else if (balance < supply) {
            uint256 decrease = supply - balance;
            _burn(address(this), vaultID, decrease, ""); // for the specific vault
            _burn(address(this), assetID, decrease, ""); // total of all vaults contributing to the asset
        }
        
        // There is one unique proof for this report owned by the auditor/sender.
        //
        _mint(_msgSender(), proofID, 1, "");

        emit Report(_msgSender(), vaultID, assetID, proofID, balance);
    }
}
