import * as dotenv from "dotenv";
import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";

dotenv.config()

async function main(): Promise<void> {
    const Treasury: ContractFactory = await ethers.getContractFactory("Treasury");
    const treasury: Contract = await upgrades.upgradeProxy(
        process.env.TREASURY || "",
        Treasury,
        { unsafeAllow: ['delegatecall']}
    );
    await treasury.deployed();
    console.log("Treasury upgraded to : ", treasury.address);

    // const Authority: ContractFactory = await ethers.getContractFactory("Authority");
    // const authority: Contract = await upgrades.upgradeProxy(
    //     process.env.AUTHORITY || "",
    //     Authority,
    // );
    // await authority.deployed();
    // console.log("Authority upgraded to : ", authority.address);

    // const Bet2Win: ContractFactory = await ethers.getContractFactory("Bet2WinUpgradeable");
    // const bet2Win: Contract = await upgrades.upgradeProxy(
    //     process.env.BET2WIN || "",
    //     Bet2Win,
    // );
    // await bet2Win.deployed();
    // console.log("Bet2Win upgraded to : ", bet2Win.address);

    // const HouseDeployer: ContractFactory = await ethers.getContractFactory("HouseDeployer");
    // const houseDeployer: Contract = await upgrades.upgradeProxy(
    //     process.env.FACTORY || "",
    //     HouseDeployer,
    //     { unsafeAllow: ['delegatecall']}
    // );
    // await houseDeployer.deployed();
    // console.log("HouseDeployer upgraded to : ", houseDeployer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });