const { assert, expect } = require("chai");
const { network, deployments, ethers } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Random IPFS NFT Unit Tests", () => {
      let randomIpfsNft, deployer, vrfCoordinatorV2Mock;

      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        await deployments.fixture(["mocks", "randomipfs"]);
        randomIpfsNft = await ethers.getContract("RandomIPFSNFT");
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
      });

      describe("constructor", () => {
        it("initial values in constructor correctly", async () => {
          const name = await randomIpfsNft.name();
          const symbol = await randomIpfsNft.symbol();
          const dogTokenUri0 = await randomIpfsNft.getDogTokenUris(0);
          const isInitialized = await randomIpfsNft.getInitialized();

          assert.equal(name, "Random IPFS NFT");
          assert.equal(symbol, "RIN");
          assert.isTrue(dogTokenUri0.toString().includes("ipfs://"));
          assert.isTrue(isInitialized);
        });
      });

      describe("requestNFT", async () => {
        it("fails if payment isn't sent with the request", async () => {
          await expect(randomIpfsNft.requestNFT()).to.be.revertedWith(
            "RandomIpfsNft__NeedMoreETHSent"
          );
        });
        it("reverts if payment amount is less than the mint fee", async () => {
          const fee = await randomIpfsNft.getMintFee();
          await expect(
            randomIpfsNft.requestNFT({
              value: fee - ethers.utils.parseEther("0.001"),
            })
          ).to.be.revertedWith("RandomIpfsNft__NeedMoreETHSent");
        });
        it("emits an event and kicks off a random word request", async () => {
          const fee = await randomIpfsNft.getMintFee();
          await expect(
            randomIpfsNft.requestNFT({ value: fee.toString() })
          ).to.be.emit(randomIpfsNft, "NftRequested");
        });
      });

      describe("getBreedFromModdedRng", () => {
        it("should return pug if moddedRng < 10", async () => {
          const breed = await randomIpfsNft.getBreedFromModdedRng("7");
          assert.equal(breed.toString(), "0");
        });
        it("should return shiba-inu if 10 < moddedRng < 40", async () => {
          const breed = await randomIpfsNft.getBreedFromModdedRng("37");
          assert.equal(breed.toString(), "1");
        });
        it("should return st.bernard if moddedRng > 40", async () => {
          const breed = await randomIpfsNft.getBreedFromModdedRng("77");
          assert.equal(breed.toString(), "2");
        });
        it("should revert if moddedRng > 99", async function () {
          await expect(
            randomIpfsNft.getBreedFromModdedRng(100)
          ).to.be.revertedWith("RandomIpfsNft__RangeOutOfBounds");
        });
      });

      describe("fulfillRandomWords", () => {
        it("mints NFT after random number is returned", async () => {
          await new Promise(async (resolve, reject) => {
            randomIpfsNft.once("NftMinted", async (tokenId, breed, minter) => {
              try {
                const tokenUri = await randomIpfsNft.tokenURI(
                  tokenId.toString()
                );
                const tokenCounter = await randomIpfsNft.getTokenCounter();
                const dogUri = await randomIpfsNft.getDogTokenUris(
                  breed.toString()
                );
                assert.equal(minter, deployer.address);
                console.log(`tokenCounter: ${tokenCounter}`);
                console.log(`tokenId: ${tokenId}`);
                assert.equal(tokenCounter.toString(), tokenId.toString());
                assert.equal(dogUri, tokenUri);
                assert.isTrue(tokenUri.toString().includes("ipfs://"));
                resolve();
              } catch (error) {
                console.error(error);
                reject(error);
              }
            });
            try {
              const fee = await randomIpfsNft.getMintFee();
              const requestNftRes = await randomIpfsNft.requestNFT({
                value: fee.toString(),
              });
              const txReceipt = await requestNftRes.wait(1);
              await vrfCoordinatorV2Mock.fulfillRandomWords(
                txReceipt.events[1].args.requestId,
                randomIpfsNft.address
              );
            } catch (error) {
              console.error(error);
              reject(error);
            }
          });
        });
      });
    });
