// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface HRINodePool {
    function getNodeNumberOf(address account) external view returns (uint256);
}

contract HeroInfinityNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private tokenIds;

    /// @notice Hero Infinity Node Pool Address
    address public nodePool;

    /// @notice Max number of NFTs that can be minted per wallet.
    uint256 public constant MAX_PER_WALLET = 5;
    /// @notice Index of the last NFT reserved for team members (0 - 28).
    uint256 public constant HIGHEST_TEAM = 28;
    /// @notice Index of the last NFT for sale (29 - 1078).
    uint256 public constant HIGHEST_PUBLIC = 1078;

    /// @notice Price of each NFT for whitelisted users.
    uint256 public whitelistMintPrice = 0.0025 ether;
    /// @notice Price of each NFT for users in mint event.
    uint256 public publicMintPrice = 0.0035 ether;
    /// @notice Price of each NFT for users after mint event.
    uint256 public saleMintPrice = 0.004 ether;

    /// @notice Mint start timestamp.
    uint256 public mintStartTimestamp;
    /// @notice Mint start timestamp.
    uint256 public mintEndTimestamp;

    /// @notice sale enabled.
    bool private isSaleEnabled = false;

    /// @notice NFT cards reserved.
    bool private isReserved = false;

    /// @dev Index of the next NFT reserved for team members.
    uint256 internal teamPointer = 0;
    /// @dev Index of the next NFT for sale.
    uint256 internal publicPointer = 29;

    /// @dev Base uri of the NFT metadata
    string internal baseUri =
        "https://heroinfinity.mypinata.cloud/ipfs/QmeDBPjuwBnUiPJhUtxak49c8gw52b3fLUuPbYwqatFTqp/";

    /// @notice Number of NFTs minted by each address.
    mapping(address => uint256) public mintedAmount;

    constructor(address _pool) ERC721("TEST Cards", "TESTC") {
        nodePool = _pool;
    }

    function testMint(uint256 amount) public {
        for (uint256 i = 0; i < amount; i++) {
            tokenIds.increment();
            _safeMint(msg.sender, tokenIds.current());
        }
    }

    /// @notice Allows the public to mint a maximum of 5 NFTs per address.
    /// NFTs minted using this function range from #29 to #1078.
    /// @param amount Number of NFTs to mint (max 5).
    function mint(uint256 amount) external payable {
        require(isMintOpen(), "MINT_NOT_OPEN");
        _mintInternal(msg.sender, amount);
    }

    function sale(uint256 amount) external payable {
        require(isSaleEnabled, "SALE_NOT_OPEN");
        require(amount * saleMintPrice == msg.value, "WRONG_ETH_VALUE");

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(msg.sender, publicPointer + i);
        }

        publicPointer = publicPointer + amount;
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

        uint256 mintPrice = publicMintPrice;
        uint256 nodeCount = HRINodePool(nodePool).getNodeNumberOf(account);
        if (nodeCount > 4) {
            mintPrice = whitelistMintPrice;
        }

        require(amount * mintPrice >= msg.value, "WRONG_ETH_VALUE");

        publicPointer = newPointer;
        mintedAmount[account] = mintedWallet;

        for (uint256 i = 0; i < amount; i++) {
            _safeMint(account, currentPointer + i);
        }
    }

    /// @return `true` if the mint event is open, otherwise `false`.
    function isMintOpen() public view returns (bool) {
        return
            mintStartTimestamp > 0 &&
            block.timestamp >= mintStartTimestamp &&
            block.timestamp <= mintEndTimestamp &&
            publicPointer <= HIGHEST_PUBLIC;
    }

    /// @return `true` if the sale is open after mint event, otherwise `false`.
    function isSaleOpen() public view returns (bool) {
        return isSaleEnabled;
    }

    /// @notice Allows the owner to set the sale open after nft mint event.
    function setSaleOpen(bool _open) external onlyOwner {
        isSaleEnabled = _open;
    }

    /// @notice Allows the owner to set price set.
    function setMintPrice(
        uint256 _whitelist,
        uint256 _public,
        uint256 _sale
    ) external onlyOwner {
        whitelistMintPrice = _whitelist;
        publicMintPrice = _public;
        saleMintPrice = _sale;
    }

    /// @notice Allows the owner to set the mint timestamps
    /// @param _mintStartTimestamp The start of the nft mint event (needs to be greater than `block.timestamp`).
    /// @param _mintEndTimestamp The end of the nft mint event (needs to be greater than `mintStartTimestamp`).
    function setTimestamps(
        uint256 _mintStartTimestamp,
        uint256 _mintEndTimestamp
    ) external onlyOwner {
        require(
            _mintEndTimestamp > _mintStartTimestamp &&
                _mintStartTimestamp > block.timestamp,
            "INVALID_TIMESTAMPS"
        );

        mintStartTimestamp = _mintStartTimestamp;
        mintEndTimestamp = _mintEndTimestamp;
    }

    /// @notice Used by the owner to withdraw the eth raised during the sale.
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
            !isReserved
                ? "https://heroinfinity.mypinata.cloud/ipfs/QmeDBPjuwBnUiPJhUtxak49c8gw52b3fLUuPbYwqatFTqp/0.json"
                : string(
                    abi.encodePacked(baseURI, tokenId.toString(), ".json")
                );
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
