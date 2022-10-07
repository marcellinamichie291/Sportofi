import { Contract, ContractFactory } from "ethers";
import { ethers, upgrades } from "hardhat";

async function main(): Promise<void> {
    const Authority: ContractFactory = await ethers.getContractFactory("Authority");
    const authority: Contract = await upgrades.deployProxy(
        Authority,
        [],
        { kind: "uups", initializer: "initialize" },
    );
    await authority.deployed();
    console.log("Authority deployed to : ", authority.address);

    const Treasury: ContractFactory = await ethers.getContractFactory("Treasury");
    const treasury: Contract = await upgrades.deployProxy(
        Treasury,
        [authority.address],
        { kind: "uups", initializer: "initialize" },
    );
    await treasury.deployed();
    console.log("Treasury deployed to : ", treasury.address);

    const GovernanceToken: ContractFactory = await ethers.getContractFactory("GovernanceToken");
    const gToken: Contract = await GovernanceToken.deploy("SPORTOFI", "SPORT"
    );
    await gToken.deployed();
    console.log("GovernanceToken deployed to : ", gToken.address);

    const Bet2Win: ContractFactory = await ethers.getContractFactory("Bet2Win");
    const bet2Win: Contract = await upgrades.deployProxy(
        Bet2Win,
        [authority.address, treasury.address, gToken.address, "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526"],
        { kind: "uups", initializer: "initialize" },
    );
    await bet2Win.deployed();
    console.log("Bet2Win deployed to : ", bet2Win.address);
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
