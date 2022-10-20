import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";
import * as dotenv from "dotenv";

dotenv.config()

async function main(): Promise<void> {
    // const Authority: ContractFactory = await ethers.getContractFactory("Authority");
    // const authority: Contract = await upgrades.deployProxy(
    //     Authority,
    //     [],
    //     { kind: "uups", initializer: "initialize" },
    // );
    // await authority.deployed();
    // console.log("Authority deployed to : ", authority.address);

    // const Treasury: ContractFactory = await ethers.getContractFactory("Treasury");
    // const treasury: Contract = await upgrades.deployProxy(
    //     Treasury,
    //     [authority.address],
    //     { kind: "uups", initializer: "initialize" },
    // );
    // await treasury.deployed();
    // console.log("Treasury deployed to : ", treasury.address);

    // const GovernanceToken: ContractFactory = await ethers.getContractFactory("GovernanceToken");
    // const gToken: Contract = await GovernanceToken.deploy("SPORTOFI", "SPORT"
    // );
    // await gToken.deployed();
    // console.log("GovernanceToken deployed to : ", gToken.address);

    const Bet2Win: ContractFactory = await ethers.getContractFactory("Bet2WinUpgradeable");
    const bet2Win: Contract = await upgrades.deployProxy(
        Bet2Win,
        [3, [5000, 3000, 2000], process.env.AUTHORITY, process.env.TREASURY, "0x31Ea275ca9ED412F80eBC8b7ac705eCe5F263Cb0", process.env.GTOKEN, "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526"],
        { kind: "uups", initializer: "initialize" },
    );
    await bet2Win.deployed();
    console.log("Bet2Win deployed to : ", bet2Win.address);

    // const HouseDeployer: ContractFactory = await ethers.getContractFactory("HouseDeployer");
    // const houseDeployer: Contract = await upgrades.deployProxy(
    //     HouseDeployer,
    //     ["0x0B4769d0c9B42F1c3f929b86401C05A1498E2883", "0x9682c81CF7FbF006b4e823185acA44a6084E86Cc"],
    //     { kind: "uups", initializer: "initialize", unsafeAllow: ["selfdestruct", "delegatecall"]},
    // );
    // await houseDeployer.deployed();
    // console.log("HouseDeployer deployed to : ", houseDeployer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
