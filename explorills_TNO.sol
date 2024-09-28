// SPDX-License-Identifier: BSD-3-Clause

// Pragma Directive
pragma solidity ^0.8.0;

// Imports
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Interfaces
interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
}

interface IMintableERC1155 {
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external;
}

/**
 * ORIGINAL AUTHOR INFORMATION:
 * 
 * @author explorills Community 2024
 * @custom:web https://explorills.com
 * @custom:contact info@explorills.com
 * @custom:security-contact info@explorills.ai
 * @custom:repository https://github.com/explorills/tno-contract
 * @title explorills TNO Contract
 * @dev ERC1155-based token with functionality for ERC20 minting and cross-chain support
 * 
 * 
 * Contract redistribution or modification:
 * 
 * 1. Any names or terms related to "explorills," "TNO," or their variations (e.g., "explorills_TNO" or "EXPL_TNO") cannot be used in any modified version's contract names, variables, or promotional materials without permission.
 * 2. The original author information (see above) must remain intact in all versions.
 * 3. In case of redistribution/modification, new author details must be added in the section below:
 * 
 * REDISTRIBUTED/MODIFIED BY:
 * 
 * /// @custom:redistributed-by <name or entity>
 * /// @custom:website <website of the redistributor>
 * /// @custom:contact <contact email or info of the redistributor>
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted under the 3-Clause BSD License. 
 * This license allows for broad usage and modification, provided the original copyright notice and disclaimer are retained.
 * The software is provided "as-is," without any warranties, and the original authors are not liable for any issues arising from its use.
 */


/// @author explorills Community 2024
/// @custom:web https://explorills.com
/// @custom:contact info@explorills.com
/// @custom:security-contact info@explorills.ai
/// @custom:repository https://github.com/explorills/tno-contract
contract explorills_TNO is ERC1155, Ownable, ReentrancyGuard, IERC1155Receiver {
    using Strings for uint256;


// variables
string public name = "explorills_TNO";
string public symbol = "EXPL_TNO";

string public baseURI;

string public constant TNO_CARD_1 = "Bronze";
string public constant TNO_CARD_2 = "Silver";
string public constant TNO_CARD_3 = "Gold";
string public constant TNO_CARD_4 = "Diamond";

address public erc20TokenAddress; 
address public erc1155TokenAddress;
address public signerPublicKey;
address public crossChainTransactionExecutor;

uint256 public price1USD = 80;
uint256 public price2USD = 720;
uint256 public price3USD = 5760;
uint256 public price4USD = 40320;

uint256 public value1 = 10000;
uint256 public value2 = 100000;
uint256 public value3 = 1000000;
uint256 public value4 = 10000000;

uint256 public abMaxSupplyToMintTerc20AsTnft = 771000000;
uint256 public abRemainingTerc20ToMintAsTnft = abMaxSupplyToMintTerc20AsTnft;

bool public paused = true;

uint256 public eventCounter;


// mapping
mapping(uint256 => bool) private mintedNFTs;
mapping(uint256 => uint256) private _totalSupply;
mapping(uint256 => uint256) private _abOtherChainsTerc20SupplyAsTnft; 
mapping(bytes32 => bool) private usedSignatures;
mapping(uint256 => EventDetails) public eventDetails;


// structures
struct EventDetails {
    address user;
    uint256 id;
    uint256 amount;
}

struct MintParams {
    uint256[] otherChainTnftIds;
    uint256[] otherChainTnftAmounts;
    uint256 id;
    uint256 mintAmount;
    string randomNonce;
    bytes signature;
}


// events
event MintListener(
    address indexed Minter,
    uint256[] otherChainTnftIds,
    uint256[] otherChainTnftAmounts,
    uint256 indexed id,
    uint256 mintAmount,
    uint256 totalSupply,
    uint256 remainingTerc20ToMint
);

event ReceiveTnftFromUserToOtherChainsSupplyListener(
    uint256 indexed eventId, 
    address indexed user, 
    uint256 indexed id, 
    uint256 amount
    );

event BurnTnftForMintTerc20Listener(
    address indexed user, 
    uint256 indexed id, 
    uint256 amount
    );

event burnTnftForMintERC1155Listener(
    address indexed user, 
    uint256 indexed id, 
    uint256 amount
    );


// constructor
constructor(string memory initialBaseURI, address _signerPublicKey) ERC1155(initialBaseURI) Ownable(msg.sender) {
    baseURI = initialBaseURI;
    signerPublicKey = _signerPublicKey;
}


// modifier
modifier mintCompliance(uint256 _mintAmount, uint256 id) {
    require(_mintAmount > 0, 'You can MINT at least 1!'); 

    uint256 nftValue;
    if (id == 1) {
        nftValue = value1;
    } else if (id == 2) {
        nftValue = value2;
    } else if (id == 3) {
        nftValue = value3;
    } else if (id == 4) {
        nftValue = value4;
    } else {
        revert("Invalid NFT type: 5.1");
    }

    require(
        abRemainingTerc20ToMintAsTnft >= nftValue * _mintAmount,
        abRemainingTerc20ToMintAsTnft == 0 
            ? "Sold Out!" 
            : string(abi.encodePacked("MINT Request Exceeds the Remaining Total Supply of ", Strings.toString(abRemainingTerc20ToMintAsTnft)))
    );

    _; 
}

// functions
function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
    return super.supportsInterface(interfaceId);
}

function setERC20TokenAddress(address _erc20TokenAddress) public onlyOwner nonReentrant {
    erc20TokenAddress = _erc20TokenAddress;
}

function burnTnftForMintTerc20(uint256 id, uint256 amount) public nonReentrant {
    require(erc20TokenAddress != address(0), "ERC20ABXTEST001 token is not yet deployed");

    uint256 nftValue;
    if (id == 1) {
        nftValue = value1;
    } else if (id == 2) {
        nftValue = value2;
    } else if (id == 3) {
        nftValue = value3;
    } else if (id == 4) {
        nftValue = value4;
    } else {
        revert("Invalid NFT type: 5.2");
    }

    require(balanceOf(_msgSender(), id) >= amount, "Insufficient NFT balance to Burn!");

    _burn(_msgSender(), id, amount);
    _totalSupply[id] -= amount;

    uint256 totalErc20Minted = nftValue * amount;
    IMintableERC20(erc20TokenAddress).mint(_msgSender(), totalErc20Minted);

    emit BurnTnftForMintTerc20Listener(_msgSender(), id, amount);

}

function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
}

function otherChainsTnftMint(uint256[] memory otherChainTnftIds, uint256[] memory otherChainTnftAmounts) internal {
    require(otherChainTnftIds.length == otherChainTnftAmounts.length, "Mismatched input lengths");
    for (uint256 i = 0; i < otherChainTnftIds.length; i++) {
        if (otherChainTnftAmounts[i] > 0) {
            uint256 nftValue;
            if (otherChainTnftIds[i] == 1) {
                nftValue = value1;
            } else if (otherChainTnftIds[i] == 2) {
                nftValue = value2;
            } else if (otherChainTnftIds[i] == 3) {
                nftValue = value3;
            } else if (otherChainTnftIds[i] == 4) {
                nftValue = value4;
            } else {
                revert("Invalid NFT type: 5.3");
            }
            
            _mint(address(this), otherChainTnftIds[i], otherChainTnftAmounts[i], "");
            _abOtherChainsTerc20SupplyAsTnft[otherChainTnftIds[i]] += otherChainTnftAmounts[i]; 
            _totalSupply[otherChainTnftIds[i]] += otherChainTnftAmounts[i];
            abRemainingTerc20ToMintAsTnft -= nftValue * otherChainTnftAmounts[i];
            mintedNFTs[otherChainTnftIds[i]] = true;
        }
    }
}

function otherChainsTnftUpdate(uint256[] memory otherChainTnftIds, uint256[] memory otherChainTnftAmounts) public onlyOwner nonReentrant{
    require(otherChainTnftIds.length == otherChainTnftAmounts.length, "Mismatched input lengths");
    for (uint256 i = 0; i < otherChainTnftIds.length; i++) {
        if (otherChainTnftAmounts[i] > 0) {
            uint256 nftValue;
            if (otherChainTnftIds[i] == 1) {
                nftValue = value1;
            } else if (otherChainTnftIds[i] == 2) {
                nftValue = value2;
            } else if (otherChainTnftIds[i] == 3) {
                nftValue = value3;
            } else if (otherChainTnftIds[i] == 4) {
                nftValue = value4;
            } else {
                revert("Invalid NFT type: 5.4");
            }
            
            _mint(address(this), otherChainTnftIds[i], otherChainTnftAmounts[i], "");
            _abOtherChainsTerc20SupplyAsTnft[otherChainTnftIds[i]] += otherChainTnftAmounts[i]; 
            _totalSupply[otherChainTnftIds[i]] += otherChainTnftAmounts[i];
            abRemainingTerc20ToMintAsTnft -= nftValue * otherChainTnftAmounts[i];
            mintedNFTs[otherChainTnftIds[i]] = true;
        }
    }
}

function mint(MintParams memory params)
    public
    payable
    nonReentrant
    mintCompliance(params.mintAmount, params.id)
{
    require(!paused, 'The contract is paused!'); // 

    bytes32 dataHash = keccak256(abi.encodePacked(msg.value, params.otherChainTnftIds, params.otherChainTnftAmounts, params.id, params.mintAmount, params.randomNonce));

    require(verifySignature(dataHash, params.signature), "Invalid signature!");

    require(!usedSignatures[dataHash], "Signature already used!");

    usedSignatures[dataHash] = true;

    otherChainsTnftMint(params.otherChainTnftIds, params.otherChainTnftAmounts);

    if (params.id == 1) {
        _mint(_msgSender(), 1, params.mintAmount, "");
        _totalSupply[1] += params.mintAmount;
        mintedNFTs[1] = true; 
    } else if (params.id == 2) {
        _mint(_msgSender(), 2, params.mintAmount, "");
        _totalSupply[2] += params.mintAmount;
        mintedNFTs[2] = true; 
    } else if (params.id == 3) {
        _mint(_msgSender(), 3, params.mintAmount, "");
        _totalSupply[3] += params.mintAmount;
        mintedNFTs[3] = true;
    } else if (params.id == 4) {
        _mint(_msgSender(), 4, params.mintAmount, "");
        _totalSupply[4] += params.mintAmount;
        mintedNFTs[4] = true;
    } else {
        revert("Invalid NFT type: 5.5");
    }

    mintedNFTs[params.id] = true;

    uint256 nftValue;
    if (params.id == 1) {
        nftValue = value1;
    } else if (params.id == 2) {
        nftValue = value2;
    } else if (params.id == 3) {
        nftValue = value3;
    } else if (params.id == 4) {
        nftValue = value4;
    }
    abRemainingTerc20ToMintAsTnft -= nftValue * params.mintAmount;

    emit MintListener(
        _msgSender(),
        params.otherChainTnftIds,
        params.otherChainTnftAmounts,
        params.id,
        params.mintAmount,
        _totalSupply[params.id],
        abRemainingTerc20ToMintAsTnft
    );
}

function totalSupply(uint256 id) internal view returns (uint256) {
    return _totalSupply[id];
}

function abOtherChainsTerc20SupplyAsTnft() public view returns (uint256) {
    uint256 totalLockedValue = 0;
    for (uint256 i = 1; i <= 4; i++) {
        uint256 nftValue;
        if (i == 1) {
            nftValue = value1;
        } else if (i == 2) {
            nftValue = value2;
        } else if (i == 3) {
            nftValue = value3;
        } else if (i == 4) {
            nftValue = value4;
        }
        totalLockedValue += _abOtherChainsTerc20SupplyAsTnft[i] * nftValue;
    }
    return totalLockedValue;
}

function abCurrentChainTerc20SupplyAsTnft() public view returns (uint256) {
    uint256 totalUnlockedValue = 0;
    for (uint256 i = 1; i <= 4; i++) {
        uint256 nftValue;
        if (i == 1) {
            nftValue = value1;
        } else if (i == 2) {
            nftValue = value2;
        } else if (i == 3) {
            nftValue = value3;
        } else if (i == 4) {
            nftValue = value4;
        }
        totalUnlockedValue += (totalSupply(i) - _abOtherChainsTerc20SupplyAsTnft[i]) * nftValue;
    }
    return totalUnlockedValue;
}

function verifySignature(bytes32 dataHash, bytes memory signature) internal view returns (bool) {
    bytes32 messageHash = prefixed(dataHash);
    return recoverSigner(messageHash, signature) == signerPublicKey;
}

function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
}

function recoverSigner(bytes32 messageHash, bytes memory signature) internal pure returns (address) {
    (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
    return ecrecover(messageHash, v, r, s);
}

function splitSignature(bytes memory signature) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
    require(signature.length == 65, "Invalid signature length");
    assembly {
        r := mload(add(signature, 32))
        s := mload(add(signature, 64))
        v := byte(0, mload(add(signature, 96)))
    }
    return (v, r, s);
}

function receiveTnftFromUserToOtherChainsSupply(
    uint256[] memory otherChainTnftIds,
    uint256[] memory otherChainTnftAmounts,
    uint256 id,
    uint256 amount,
    string memory randomNonce,
    bytes memory signature
)   
    public payable 
    nonReentrant
{
    require(balanceOf(_msgSender(), id) >= amount, "Insufficient balance to transfer");

    bytes32 dataHash = keccak256(abi.encodePacked(msg.value, otherChainTnftIds, otherChainTnftAmounts, id, amount, randomNonce));

    require(verifySignature(dataHash, signature), "Invalid signature!");

    require(!usedSignatures[dataHash], "Signature already used!");

    usedSignatures[dataHash] = true;

    otherChainsTnftMint(otherChainTnftIds, otherChainTnftAmounts);

    _safeTransferFrom(_msgSender(), address(this), id, amount, "");

    _abOtherChainsTerc20SupplyAsTnft[id] += amount;

    eventCounter++;

    eventDetails[eventCounter] = EventDetails(_msgSender(), id, amount);

    emit ReceiveTnftFromUserToOtherChainsSupplyListener(eventCounter, _msgSender(), id, amount);
}

function validateEventData(
    uint256 eventId,
    address user,
    uint256 id,
    uint256 amount
) public view returns (bool) {

    EventDetails memory storedEvent = eventDetails[eventId];

    if (
        storedEvent.user == user &&
        storedEvent.id == id &&
        storedEvent.amount == amount
    ) {
        return true; 
    }

    return false; 
}

function isEventEmitted(uint256 eventId) public view returns (bool) {
    if (eventId > 0 && eventId <= eventCounter) {
        return true; 
    } else {
        return false; 
    }
}

function updateBaseURI(string memory newBaseURI) public onlyOwner nonReentrant{
    baseURI = newBaseURI;
}

function uri(uint256 tokenId) override public view returns (string memory) {
    return string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
}

function setPaused(bool _state) public onlyOwner nonReentrant{
paused = _state;
}

function withdraw() public onlyOwner nonReentrant {
    uint256 balance = address(this).balance;
    require(balance > 0, "No funds available");
    (bool success, ) = payable(owner()).call{value: balance}('');
    require(success, "Transfer failed");
}

function abTotalTerc20SupplyAsTnft() public view returns (uint256) {
    uint256 totalValueMinted = totalSupply(1) * value1 +
                               totalSupply(2) * value2 +
                               totalSupply(3) * value3 +
                               totalSupply(4) * value4;
    return totalValueMinted;
}

function updatesignerPublicKey(address newsignerPublicKey) public onlyOwner nonReentrant{
    signerPublicKey = newsignerPublicKey;
}

function onERC1155Received(
    address, /*operator*/
    address from,
    uint256 id,
    uint256, /*value*/
    bytes memory /*data*/
) public view override returns (bytes4) {
    if (from != address(this) && from != address(0)) {
        require(mintedNFTs[id], "This NFT was not minted by this contract");
    }
    return IERC1155Receiver.onERC1155Received.selector;
}

function onERC1155BatchReceived(
    address, /*operator*/
    address from,
    uint256[] memory ids,
    uint256[] memory, /*values*/
    bytes memory /*data*/
) public view override returns (bytes4) {
    if (from != address(this) && from != address(0)) {
        for (uint256 i = 0; i < ids.length; i++) {
            require(mintedNFTs[ids[i]], "This NFT(s) was not minted by this contract");
        }
    }
    return IERC1155Receiver.onERC1155BatchReceived.selector;
}

function currentChainAddressTotalTerc20AsTnft(address account) public view returns (uint256) {
    uint256 totalValue = 0;
    totalValue += balanceOf(account, 1) * value1;
    totalValue += balanceOf(account, 2) * value2;
    totalValue += balanceOf(account, 3) * value3;
    totalValue += balanceOf(account, 4) * value4;
    return totalValue;
}

function batchTransferTnftFromGeneralSupply(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
) public onlyOwner {
    for (uint256 i = 0; i < ids.length; i++) {
        require(balanceOf(address(this), ids[i]) >= amounts[i], "Insufficient balance in general supply");
        _safeTransferFrom(address(this), to, ids[i], amounts[i], "");
    }
}

function batchTransferTnftFromOtherChainsSupply(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
) public {
    require(msg.sender == owner() || msg.sender == crossChainTransactionExecutor, "Caller is not authorized");
    for (uint256 i = 0; i < ids.length; i++) {
        require(_abOtherChainsTerc20SupplyAsTnft[ids[i]] >= amounts[i], "Insufficient balance in locked supply");
        _abOtherChainsTerc20SupplyAsTnft[ids[i]] -= amounts[i];
        _safeTransferFrom(address(this), to, ids[i], amounts[i], "");
    }
}

function moveTnftToOtherChainsSupply(
    uint256[] memory ids,
    uint256[] memory amounts
) public onlyOwner {
    for (uint256 i = 0; i < ids.length; i++) {
        require(balanceOf(address(this), ids[i]) >= amounts[i], "Insufficient balance to move to locked supply");
        _abOtherChainsTerc20SupplyAsTnft[ids[i]] += amounts[i];
    }
}

function moveTnftToGeneralSupply(
    uint256[] memory ids,
    uint256[] memory amounts
) public onlyOwner {
    for (uint256 i = 0; i < ids.length; i++) {
        require(_abOtherChainsTerc20SupplyAsTnft[ids[i]] >= amounts[i], "Insufficient balance in locked supply");
        _abOtherChainsTerc20SupplyAsTnft[ids[i]] -= amounts[i];
    }
}

function abCurrentChainTnftSupply() public view returns (uint256[] memory) {
    uint256[] memory generalSupply = new uint256[](4);
    for (uint256 i = 1; i <= 4; i++) {
        generalSupply[i - 1] = totalSupply(i) - _abOtherChainsTerc20SupplyAsTnft[i];
    }
    return generalSupply;
}

function abOtherChainsTnftSupply() public view returns (uint256[] memory) {
    uint256[] memory abOtherChainsTerc20SupplyAsTnftArray = new uint256[](4);
    for (uint256 i = 1; i <= 4; i++) {
        abOtherChainsTerc20SupplyAsTnftArray[i - 1] = _abOtherChainsTerc20SupplyAsTnft[i];
    }
    return abOtherChainsTerc20SupplyAsTnftArray;
}

function abTotalTnftSupply() public view returns (uint256[] memory) {
    uint256[] memory totalSupplyArray = new uint256[](4);
    for (uint256 i = 1; i <= 4; i++) {
        totalSupplyArray[i - 1] = totalSupply(i);
    }
    return totalSupplyArray;
}

function setERC1155TokenAddress(address _erc1155TokenAddress) public onlyOwner nonReentrant{
    erc1155TokenAddress = _erc1155TokenAddress;
}

function burnTnftForMintERC1155(uint256 id, uint256 amount) public nonReentrant{
    require(erc1155TokenAddress != address(0), "ERC1155 token contract is not set");

    require(balanceOf(_msgSender(), id) >= amount, "Insufficient ERC1155 token balance to burn");

    _burn(_msgSender(), id, amount);

    uint256 nftValue;
    if (id == 1) {
        nftValue = value1;
    } else if (id == 2) {
        nftValue = value2;
    } else if (id == 3) {
        nftValue = value3;
    } else if (id == 4) {
        nftValue = value4;
    } else {
        revert("Invalid NFT type: 5.6");
    }

    uint256 burnValue = nftValue * amount;
    abRemainingTerc20ToMintAsTnft -= burnValue;

    IMintableERC1155(erc1155TokenAddress).mint(_msgSender(), id, amount, "");

    emit burnTnftForMintERC1155Listener(_msgSender(), id, amount);

}

function sendERC20(address tokenAddress, address recipient, uint256 amount) public onlyOwner nonReentrant{
    IERC20 token = IERC20(tokenAddress);
    uint256 balance = token.balanceOf(address(this));
    require(balance >= amount, "Insufficient token balance");
    token.transfer(recipient, amount);
}

function setCrossChainTransactionExecutor(address _executor) public onlyOwner {
    crossChainTransactionExecutor = _executor;
}

function sendTnftToUserFromOtherChainsSupply(
    address to,
    uint256[] memory otherChainTnftIds,
    uint256[] memory otherChainTnftAmounts,
    uint256[] memory ids,
    uint256[] memory amounts
) public {
    require(msg.sender == owner() || msg.sender == crossChainTransactionExecutor, "Caller is not authorized");
    
    otherChainsTnftMint(otherChainTnftIds, otherChainTnftAmounts);

    batchTransferTnftFromOtherChainsSupply(to, ids, amounts);
}

function acTotalTerc20MintedAsTnft() public view returns (uint256) {
    return abMaxSupplyToMintTerc20AsTnft - abRemainingTerc20ToMintAsTnft;
}

function acTotalTerc20ClaimedAsErc20() public view returns (uint256) {
    return abMaxSupplyToMintTerc20AsTnft - abRemainingTerc20ToMintAsTnft - abTotalTerc20SupplyAsTnft();
}

function batchBurnFromOtherChainSupply(uint256[] memory ids, uint256[] memory amounts) public onlyOwner {
    require(ids.length == amounts.length, "Mismatched input lengths");

    for (uint256 i = 0; i < ids.length; i++) {
        require(_abOtherChainsTerc20SupplyAsTnft[ids[i]] >= amounts[i], "Insufficient balance in other chain supply");

        uint256 nftValue;
        if (ids[i] == 1) {
            nftValue = value1;
        } else if (ids[i] == 2) {
            nftValue = value2;
        } else if (ids[i] == 3) {
            nftValue = value3;
        } else if (ids[i] == 4) {
            nftValue = value4;
        } else {
            revert("Invalid NFT type: 5.7");
        }

        _abOtherChainsTerc20SupplyAsTnft[ids[i]] -= amounts[i];
        _totalSupply[ids[i]] -= amounts[i];
        _burn(address(this), ids[i], amounts[i]);
    }
}

function mintInformationalNFT() public onlyOwner nonReentrant{
    require(!mintedNFTs[200], "Informational NFT already minted");
    _mint(address(this), 200, 1, "");
    mintedNFTs[200] = true;

}

function getNativeBalance(address account) public view returns (uint256) {
    return account.balance;
}

function totalSupply() public view returns (uint256) {
    uint256 totalValue = 0;
    totalValue += _totalSupply[1] * value1;
    totalValue += _totalSupply[2] * value2;
    totalValue += _totalSupply[3] * value3;
    totalValue += _totalSupply[4] * value4;
    return totalValue;
}

receive() external payable {
}

}