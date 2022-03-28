// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HeroInfinityNFT is ERC721Enumerable, Ownable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private tokenIds;

  /// @notice Max number of NFTs that can be minted per wallet.
  uint256 public constant MAX_PER_WALLET = 5;
  /// @notice Index of the last NFT reserved for team members (0 - 28).
  uint256 public constant HIGHEST_TEAM = 28;
  /// @notice Index of the last NFT for sale (29 - 1078).
  uint256 public constant HIGHEST_PUBLIC = 1078;

  /// @notice Price of each NFT for whitelisted users (+ gas).
  uint256 public constant MINT_PRICE = 0.3 ether;

  /// @dev Root of the merkle tree used for the whitelist.
  bytes32 public immutable merkleRoot;

  /// @notice Whitelist sale start timestamp.
  uint256 public whitelistStartTimestamp;
  /// @notice Public sale start timestamp.
  uint256 public publicStartTimestamp;

  /// @dev Index of the next NFT reserved for team members.
  uint256 internal teamPointer = 0;
  /// @dev Index of the next NFT for sale.
  uint256 internal publicPointer = 29;

  /// @dev Base uri of the NFT metadata
  string internal baseUri =
    "https://heroinfinity.mypinata.cloud/ipfs/QmeDBPjuwBnUiPJhUtxak49c8gw52b3fLUuPbYwqatFTqp/";

  /// @notice Number of NFTs minted by each address.
  mapping(address => uint256) public mintedAmount;

  constructor(bytes32 root) ERC721("Hero Infinity NFT", "HRINFT") {
    merkleRoot = root;
  }

  function testMint(uint256 amount) public {
    for (uint256 i = 0; i < amount; i++) {
      tokenIds.increment();
      _safeMint(msg.sender, tokenIds.current());
    }
  }

  /// @notice Used by whitelisted users to mint a maximum of 2 NFTs per address.
  /// NFTs minted using this function range from #50 to #999.
  /// Requires a merkle proof.
  /// @param merkleProof The merkle proof to verify.
  /// @param amount Number of NFTs to mint (max 2).
  function mintWhitelist(bytes32[] calldata merkleProof, uint256 amount)
    external
    payable
  {
    require(isWhitelistOpen(), "SALE_NOT_OPEN");

    // bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    // require(
    //     MerkleProof.verify(merkleProof, merkleRoot, leaf),
    //     "INVALID_PROOF"
    // );

    _mintInternal(msg.sender, amount);
  }

  /// @notice Allows the public to mint a maximum of 2 NFTs per address.
  /// NFTs minted using this function range from #50 to #999.
  /// @param amount Number of NFTs to mint (max 2).
  function mint(uint256 amount) external payable {
    require(isPublicOpen(), "SALE_NOT_OPEN");

    _mintInternal(msg.sender, amount);
  }

  /// @notice Used by the owner (DAO) to mint NFTs reserved for team members.
  /// NFTs minted using this function range from #0 to #49.
  /// @param amount Number of NFTs to mint.
  function mintTeam(uint256 amount) external onlyOwner {
    require(amount != 0, "INVALID_AMOUNT");
    uint256 currentPointer = teamPointer;
    uint256 newPointer = currentPointer + amount;
    require(newPointer - 1 <= HIGHEST_TEAM, "TEAM_LIMIT_EXCEEDED");

    teamPointer = newPointer;

    for (uint256 i = 0; i < amount; i++) {
      // No _safeMint because the owner is a gnosis safe
      _mint(msg.sender, currentPointer + i);
    }
  }

  /// @dev Function called by `mintWhitelist` and `mint`.
  /// Performs common checks and mints `amount` of NFTs.
  /// @param account The account to mint the NFTs to.
  /// @param amount The amount of NFTs to mint.
  function _mintInternal(address account, uint256 amount) internal {
    require(amount != 0, "INVALID_AMOUNT");
    uint256 mintedWallet = mintedAmount[account] + amount;
    require(mintedWallet <= MAX_PER_WALLET, "WALLET_LIMIT_EXCEEDED");
    uint256 currentPointer = publicPointer;
    uint256 newPointer = currentPointer + amount;
    require(newPointer - 1 <= HIGHEST_PUBLIC, "SALE_LIMIT_EXCEEDED");
    require(amount * MINT_PRICE == msg.value, "WRONG_ETH_VALUE");

    publicPointer = newPointer;
    mintedAmount[account] = mintedWallet;

    for (uint256 i = 0; i < amount; i++) {
      _safeMint(account, currentPointer + i);
    }
  }

  /// @return `true` if the whitelist sale is open, otherwise `false`.
  function isWhitelistOpen() public view returns (bool) {
    return
      whitelistStartTimestamp > 0 &&
      block.timestamp >= whitelistStartTimestamp &&
      publicPointer <= HIGHEST_PUBLIC;
  }

  /// @return `true` if the public sale is open, otherwise `false`.
  function isPublicOpen() public view returns (bool) {
    return
      publicStartTimestamp > 0 &&
      block.timestamp >= publicStartTimestamp &&
      publicPointer <= HIGHEST_PUBLIC;
  }

  /// @notice Allows the owner to set the sale timestamps (whitelist and public).
  /// @param whitelistTimestamp The start of the whitelist sale (needs to be greater than `block.timestamp`).
  /// @param publicTimestamp The start of the public sale (needs to be greater than `whitelistTimestamp`).
  function setSaleTimestamps(
    uint256 whitelistTimestamp,
    uint256 publicTimestamp
  ) external onlyOwner {
    require(
      publicTimestamp > whitelistTimestamp &&
        whitelistTimestamp > block.timestamp,
      "INVALID_TIMESTAMPS"
    );

    whitelistStartTimestamp = whitelistTimestamp;
    publicStartTimestamp = publicTimestamp;
  }

  /// @notice Used by the owner (DAO) to withdraw the eth raised during the sale.
  function withdrawETH() external onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory baseURI = _baseURI();
    return
      bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
        : "";
  }

  /// @notice Used by the owner (DAO) to reveal the NFTs.
  /// NOTE: This allows the owner to change the metadata this contract is pointing to,
  /// ownership of this contract should be renounced after reveal.
  function setBaseURI(string memory uri) external onlyOwner {
    baseUri = uri;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseUri;
  }
}
