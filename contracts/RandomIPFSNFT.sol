// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

error RandomIpfsNft__AlreadyInitialized();
error RandomIpfsNft__NeedMoreETHSent();
error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__TransferFailed();

/*
  When we mint and NFT, we will trigger a Chainlink VRF call to get us a random number
  using that number, we will get a random NFT
  Pug, Shiba Inu, St. Bernard
  Pug super rare
  St. Bernard Common

  users have to pay to mint an NFT
  the owner of the contract can withdraw the ETH
 */
contract RandomIPFSNFT is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
  // Types
  enum Breed {
    PUG,
    SHIBA_INU,
    ST_BERNARD
  }

  // Chainlink VRF Variables
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  // Your subscription ID.
  uint64 private immutable i_subscriptionId;
  // The gas lane to use, which specifies the maximum gas price to bump to.
  // For a list of available gas lanes on each network,
  // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
  bytes32 keyHash =
    0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
  bytes32 private immutable i_gasLane;
  uint32 private immutable i_callbackGasLimit;
  // The default is 3, but you can set this higher.
  uint16 private constant RequestConfirmations = 3;
  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
  uint32 private constant NUM_WORDS = 2;

  // NFT Variables
  uint256 private immutable i_mintFee;
  uint256 private s_tokenCounter;
  uint256 internal constant MAX_CHANCE_VALUE = 100;
  string[] internal s_dogTokenUris;
  bool private s_initialized;

  // VRF Helpers
  mapping(uint256 => address) public s_requestIdToSender;

  // Events
  event NftRequested(uint256 indexed requestId, address indexed requester);
  event NftMinted(
    uint256 indexed tokenId,
    Breed indexed breed,
    address indexed minter
  );

  constructor(
    address vrfCoordinatorV2,
    uint64 subscriptionId,
    bytes32 gasLane, // keyHash
    uint256 mintFee,
    uint32 callbackGasLimit,
    string[3] memory dogTokenUris
  ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random IPFS NFT", "RIN") {
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    i_subscriptionId = subscriptionId;
    i_gasLane = gasLane;
    i_mintFee = mintFee;
    i_callbackGasLimit = callbackGasLimit;
    s_tokenCounter = 0;
    s_dogTokenUris = dogTokenUris;
  }

  function requestNFT() public payable returns (uint256 requestId) {
    if (msg.value < i_mintFee) {
      revert RandomIpfsNft__NeedMoreETHSent();
    }
    requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane,
      i_subscriptionId,
      RequestConfirmations,
      i_callbackGasLimit,
      NUM_WORDS
    );
    s_requestIdToSender[requestId] = msg.sender;
    emit NftRequested(requestId, msg.sender);
  }

  function fulfillRandomWords(
    uint256 requestId,
    uint256[] memory randomWords
  ) internal override {
    address dogOwner = s_requestIdToSender[requestId];
    uint256 newTokenId = s_tokenCounter;
    // What does this token look like?
    uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE;
    // 0 - 90
    // 7% chance -> PUG (rare chance under 10%)
    // 12% chance -> Shiba Inu
    // 88% change -> St Bernad
    // 45% change -> St Bernad
    Breed dogBreed = getBreedFromModdedRng(moddedRng);
    _safeMint(dogOwner, newTokenId);
    _setTokenURI(newTokenId, s_dogTokenUris[uint256(dogBreed)]);
    emit NftMinted(newTokenId, dogBreed, dogOwner);
  }

  function getBreedFromModdedRng(
    uint256 moddedRng
  ) public pure returns (Breed) {
    uint256 cumulativeSum = 0;
    uint256[3] memory chanceArray = getChanceArray();
    // moddedRng = 25
    // [moddedRng = 25, i = 0, cumulativeSum = 0, chanceArray[i] = 10],
    // [moddedRng = 25, i = 1, cumulativeSum = 10, chanceArray[i] = 40]
    for (uint256 i = 0; i < chanceArray.length; i++) {
      if (
        moddedRng >= cumulativeSum && moddedRng < cumulativeSum + chanceArray[i]
      ) {
        return Breed(i);
      }
      cumulativeSum += chanceArray[i];
    }
    revert RandomIpfsNft__RangeOutOfBounds();
  }

  function getChanceArray() public pure returns (uint256[3] memory) {
    return [10, 40, MAX_CHANCE_VALUE];
  }

  function withdraw() public onlyOwner {
    uint256 amount = address(this).balance;
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    if (!success) {
      revert RandomIpfsNft__TransferFailed();
    }
  }

  function getMintFee() public view returns (uint256) {
    return i_mintFee;
  }

  function getDogTokenUris(uint256 index) public view returns (string memory) {
    return s_dogTokenUris[index];
  }

  function getInitialized() public view returns (bool) {
    return s_initialized;
  }

  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }
}
