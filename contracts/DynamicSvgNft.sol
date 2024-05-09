// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DynamicSvgNft is ERC721 {
  // mint
  // store our SVG info somewhere
  // some logic to say "Show X Image" or "Show Y Image"
  uint256 private s_tokenCounter;
  string private s_lowImageURI;
  string private s_highImageURI;
  AggregatorV3Interface internal immutable i_priceFeed;
  mapping(uint256 => int256) private s_tokenIdToHighValues;
  event CreatedNFT(uint256 indexed tokenId, int256 highValue);

  constructor(
    address priceFeedAddress,
    string memory lowSvg,
    string memory highSvg
  ) ERC721("Dynamic SVG NFT", "DSF") {
    i_priceFeed = AggregatorV3Interface(priceFeedAddress);
    s_tokenCounter = 0;
    s_lowImageURI = svgToImageURI(lowSvg);
    s_highImageURI = svgToImageURI(highSvg);
  }

  function mintNft(int highValue) public {
    uint256 newTokenId = s_tokenCounter;
    _safeMint(msg.sender, newTokenId);
    s_tokenCounter += 1;
    s_tokenIdToHighValues[newTokenId] = highValue;
    emit CreatedNFT(newTokenId, highValue);
  }

  // You could also just upload the raw SVG and let solildity convert it!
  function svgToImageURI(
    string memory svg
  ) public pure returns (string memory) {
    // example:
    // '<svg width="500" height="500" viewBox="0 0 285 350" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill="black" d="M150,0,L75,200,L225,200,Z"></path></svg>'
    // would return ""
    string memory baseURL = "data:image/svg+xml;base64,";
    string memory svgBase64Encoded = Base64.encode(
      bytes(string(abi.encodePacked(svg)))
    );
    return string(abi.encodePacked(baseURL, svgBase64Encoded));
  }

  function _baseURI() internal pure override returns (string memory) {
    return "data:application/json;base64,";
  }

  function tokenURI(
    uint256 tokenId
  ) public view override returns (string memory) {
    require(_exists(tokenId), "URI Query for nonexistent token");
    (, int256 price, , , ) = i_priceFeed.latestRoundData();
    string memory imageURI = s_lowImageURI;
    if (price >= s_tokenIdToHighValues[tokenId]) {
      imageURI = s_highImageURI;
    }
    return
      string(
        abi.encodePacked(
          _baseURI(),
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                name(), // You can add whatever name here
                '", "description":"An NFT that changes based on the Chainlink Feed", ',
                '"attributes": [{"trait_type": "coolness", "value": 100}], "image":"',
                imageURI,
                '"}'
              )
            )
          )
        )
      );
  }

  function getLowSVG() public view returns (string memory) {
    return s_lowImageURI;
  }

  function getHighSVG() public view returns (string memory) {
    return s_highImageURI;
  }

  function getPriceFeed() public view returns (AggregatorV3Interface) {
    return i_priceFeed;
  }

  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }
}
