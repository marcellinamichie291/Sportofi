import * as dotenv from "dotenv";
import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";

dotenv.config()

async function main(): Promise<void> {
    // const Treasury: ContractFactory = await ethers.getContractFactory("Treasury");
    // const treasury: Contract = await upgrades.upgradeProxy(
    //     process.env.TREASURY || "",
    //     Treasury,
    // );
    // await treasury.deployed();
    // console.log("Treasury upgraded to : ", treasury.address);

    const Authority: ContractFactory = await ethers.getContractFactory("Authority");
    const authority: Contract = await upgrades.upgradeProxy(
        process.env.AUTHORITY || "",
        Authority,
    );
    await authority.deployed();
    console.log("Authority upgraded to : ", authority.address);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });